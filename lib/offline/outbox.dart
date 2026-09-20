import 'dart:math';

import 'local_database.dart';

/// Natures d'écriture différées. Le `payload` est ce qu'il faut pour rejouer
/// l'appel tel qu'il aurait été fait en ligne.
abstract final class OutboxKind {
  /// `{path: '/attendance-secure', body: {...}}` — appel d'un service du
  /// routeur `uniflow-api`.
  static const String service = 'service';

  /// `{collection, documentId, data, permissions?}`.
  static const String documentCreate = 'document.create';

  /// `{collection, documentId, data}`.
  static const String documentUpdate = 'document.update';
}

abstract final class OutboxStatus {
  static const String pending = 'pending';
  static const String retry = 'retry';
  static const String conflict = 'conflict';
  static const String failed = 'failed';
}

/// Politique de résolution quand le serveur et l'appareil divergent.
enum ConflictPolicy {
  /// Référentiel académique (cours, séances, filières…) : l'appareil ne fait
  /// pas autorité, ce qui arrive du serveur remplace.
  serverWins,

  /// Données de l'utilisateur (rendus, présences, réglages, messages) : la
  /// dernière écriture — donc le rejeu de l'outbox — l'emporte.
  lastWriteWins,
}

ConflictPolicy policyFor(String collection) {
  const referential = {'universities', 'faculties', 'classrooms', 'team_members', 'users_directory'};
  if (collection.startsWith('academic_') && collection != 'academic_submissions') return ConflictPolicy.serverWins;
  if (referential.contains(collection)) return ConflictPolicy.serverWins;
  return ConflictPolicy.lastWriteWins;
}

/// Fusionne un document reçu du serveur avec la copie locale.
///
/// Retourne le document à conserver et, dans `discardedLocal`, si une
/// écriture locale en attente a été écrasée (compte comme « conflit à revoir »
/// dans le rapport de synchronisation).
({CachedDocument kept, bool discardedLocal}) mergeIncoming(
    CachedDocument? local, CachedDocument server, ConflictPolicy policy) {
  if (local == null || !local.pending) return (kept: server, discardedLocal: false);
  if (policy == ConflictPolicy.serverWins) return (kept: server, discardedLocal: true);
  // Dernière écriture gagne : la version locale est en attente d'envoi et
  // sera rejouée après le delta ; elle écrasera celle du serveur.
  return (kept: local, discardedLocal: false);
}

/// Attente avant la tentative suivante : 30 s, 1 min, 2 min… plafonnée à
/// six heures, pour ne pas vider la batterie d'un téléphone dont le réseau
/// revient et repart (bord de couverture).
Duration backoffDelay(int attempts) {
  const base = Duration(seconds: 30);
  const cap = Duration(hours: 6);
  if (attempts <= 0) return Duration.zero;
  final factor = 1 << min(attempts - 1, 12);
  final delay = base * factor;
  return delay > cap ? cap : delay;
}

/// Rejette une entrée pour de bon (règle métier violée, droit refusé) : la
/// rejouer donnerait le même refus.
class OutboxRejected implements Exception {
  final String message;
  final bool conflict;
  const OutboxRejected(this.message, {this.conflict = false});
  @override
  String toString() => message;
}

/// Le réseau n'est pas là : inutile d'essayer les entrées suivantes, elles
/// échoueraient de la même façon et consommeraient leurs tentatives.
class OutboxOffline implements Exception {
  final String message;
  const OutboxOffline([this.message = 'Réseau indisponible']);
  @override
  String toString() => message;
}

abstract class OutboxExecutor {
  Future<void> execute(OutboxRow entry);
}

class ReplayReport {
  int sent = 0;
  int conflicts = 0;
  int failed = 0;
  int deferred = 0;
  bool stoppedOffline = false;

  bool get isEmpty => sent == 0 && conflicts == 0 && failed == 0 && deferred == 0;

  /// « 37 éléments envoyés, 2 conflits à revoir ».
  String describe() {
    final parts = <String>[];
    if (sent > 0) parts.add('$sent élément${sent > 1 ? 's' : ''} envoyé${sent > 1 ? 's' : ''}');
    if (conflicts > 0) parts.add('$conflicts conflit${conflicts > 1 ? 's' : ''} à revoir');
    if (failed > 0) parts.add('$failed refusé${failed > 1 ? 's' : ''}');
    if (deferred > 0) parts.add('$deferred à réessayer');
    if (stoppedOffline) parts.add('réseau coupé pendant l\'envoi');
    return parts.isEmpty ? 'Rien à envoyer' : parts.join(', ');
  }
}

/// File d'attente des écritures faites hors ligne, rejouées dans l'ordre.
class Outbox {
  final LocalDatabase _db;
  final DateTime Function() _clock;
  final Random _random;

  Outbox(this._db, {DateTime Function()? clock, Random? random})
      : _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure();

  /// Identifiant client unique : c'est lui qui rend le rejeu idempotent
  /// (une entrée réinsérée avec le même identifiant est ignorée, et le
  /// serveur peut le recevoir dans le corps pour dédoublonner).
  String newClientId() {
    final millis = _clock().toUtc().millisecondsSinceEpoch.toRadixString(36);
    final salt = List.generate(6, (_) => _random.nextInt(36).toRadixString(36)).join();
    return 'cli_${millis}_$salt';
  }

  Future<String> enqueue({
    required String owner,
    required String kind,
    required Map<String, dynamic> payload,
    String label = '',
    String? clientId,
  }) async {
    final id = clientId ?? newClientId();
    final now = _clock().toUtc().toIso8601String();
    await _db.insertOutbox(OutboxRow(
      clientId: id,
      owner: owner,
      kind: kind,
      label: label,
      payload: payload,
      createdAt: now,
      nextAttemptAt: now,
    ));
    return id;
  }

  Future<int> pendingCount(String owner) => _db.countOutbox(owner);

  Future<List<OutboxRow>> entries(String owner) => _db.outbox(owner);

  Future<void> discard(String clientId) => _db.deleteOutbox(clientId);

  /// Remet une entrée en conflit ou refusée dans la file (l'utilisateur a
  /// choisi « réessayer »).
  Future<void> retryNow(String clientId) => _db.updateOutbox(clientId,
      status: OutboxStatus.pending, attempts: 0, nextAttemptAt: _clock().toUtc().toIso8601String());

  /// Rejoue les entrées dues, dans l'ordre d'insertion.
  Future<ReplayReport> replay(String owner, OutboxExecutor executor) async {
    final report = ReplayReport();
    final now = _clock().toUtc();
    final rows = await _db.outbox(owner);
    for (final row in rows) {
      if (row.status != OutboxStatus.pending && row.status != OutboxStatus.retry) continue;
      final due = DateTime.tryParse(row.nextAttemptAt)?.toUtc();
      if (due != null && due.isAfter(now)) {
        report.deferred++;
        continue;
      }
      try {
        await executor.execute(row);
        await _db.deleteOutbox(row.clientId);
        report.sent++;
      } on OutboxOffline {
        report.stoppedOffline = true;
        break;
      } on OutboxRejected catch (error) {
        await _db.updateOutbox(
          row.clientId,
          status: error.conflict ? OutboxStatus.conflict : OutboxStatus.failed,
          lastError: error.message,
        );
        if (error.conflict) {
          report.conflicts++;
        } else {
          report.failed++;
        }
      } catch (error) {
        final attempts = row.attempts + 1;
        await _db.updateOutbox(
          row.clientId,
          status: OutboxStatus.retry,
          attempts: attempts,
          nextAttemptAt: now.add(backoffDelay(attempts)).toIso8601String(),
          lastError: error.toString(),
        );
        report.deferred++;
      }
    }
    return report;
  }
}
