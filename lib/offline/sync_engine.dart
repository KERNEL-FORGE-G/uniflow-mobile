import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../models/appwrite_models.dart';
import 'document_cache.dart';
import 'local_database.dart';
import 'outbox.dart';

/// Source distante des documents, isolée pour que les tests branchent un
/// serveur simulé (« 30 jours hors ligne puis retour réseau »).
abstract class RemoteDocuments {
  Future<List<models.Document>> list(String collection, List<String> queries);
}

/// Une collection à synchroniser, avec les filtres qui bornent ce que
/// l'appareil garde : un étudiant ne stocke que **sa** filière et **son**
/// niveau, pas les 527 séances de la faculté.
class SyncCollection {
  final String collection;
  final List<String> filters;

  /// Clé du périmètre (« PHY/L3 ») : si elle change (changement de niveau),
  /// le curseur de delta repart de zéro pour rapatrier le nouveau périmètre.
  final String scopeKey;

  const SyncCollection(this.collection, {this.filters = const [], this.scopeKey = ''});
}

/// Collections à garder pour ce compte. Le référentiel de la filière + le
/// niveau, plus tout ce qui appartient à l'utilisateur.
List<SyncCollection> syncPlanFor(UniFlowUser user) {
  final program = (user.program ?? '').trim();
  final level = (user.level ?? '').trim();
  final scoped = <String>[
    if (program.isNotEmpty) Query.equal('program', program),
    if (level.isNotEmpty) Query.equal('level', level),
  ];
  final scopeKey = '$program/$level';
  final mine = user.id;
  final isStaff = const {'TEACHER', 'ADMIN'}.contains(user.role.toUpperCase());
  return [
    SyncCollection('users', filters: [Query.equal('\$id', mine)]),
    if (!user.isPersonal) ...[
      const SyncCollection('academic_programs'),
      // Plateforme et administration sans filière : pas de référentiel massif
      // en cache — l'écran leur demande de choisir une filière, et ce choix
      // est mis en cache par les providers « cache d'abord ».
      if (program.isNotEmpty) ...[
        SyncCollection('academic_courses', filters: scoped, scopeKey: scopeKey),
        SyncCollection('academic_schedules', filters: scoped, scopeKey: scopeKey),
      ],
      const SyncCollection('academic_directory'),
      const SyncCollection('academic_library'),
      if (!isStaff) ...[
        SyncCollection('academic_grades', filters: [Query.equal('studentId', mine)]),
        SyncCollection('academic_assignments', filters: [Query.equal('studentId', mine)]),
      ],
    ],
  ];
}

enum SyncPhase { idle, syncing, offline }

class SyncState {
  final SyncPhase phase;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final String? lastReport;
  final String? error;

  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.lastReport,
    this.error,
  });

  bool get isOffline => phase == SyncPhase.offline;
  bool get isSyncing => phase == SyncPhase.syncing;

  SyncState copyWith(
          {SyncPhase? phase,
          DateTime? lastSyncAt,
          int? pendingCount,
          String? lastReport,
          String? error,
          bool clearError = false}) =>
      SyncState(
        phase: phase ?? this.phase,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pendingCount: pendingCount ?? this.pendingCount,
        lastReport: lastReport ?? this.lastReport,
        error: clearError ? null : (error ?? this.error),
      );
}

class SyncReport {
  int documents = 0;
  int conflicts = 0;
  ReplayReport outbox = ReplayReport();
  final List<String> errors = [];
  bool offline = false;

  String describe() {
    if (offline) return 'Hors ligne : rien n\'a pu être synchronisé';
    final parts = <String>[];
    if (documents > 0) parts.add('$documents document${documents > 1 ? 's' : ''} reçu${documents > 1 ? 's' : ''}');
    // Les conflits de fusion (écriture locale écrasée par le référentiel)
    // s'ajoutent à ceux du rejeu : c'est le même « à revoir » pour l'usager.
    final merged = ReplayReport()
      ..sent = outbox.sent
      ..conflicts = outbox.conflicts + conflicts
      ..failed = outbox.failed
      ..deferred = outbox.deferred
      ..stoppedOffline = outbox.stoppedOffline;
    if (!merged.isEmpty || merged.stoppedOffline) parts.add(merged.describe());
    if (errors.isNotEmpty) parts.add('${errors.length} collection${errors.length > 1 ? 's' : ''} en erreur');
    return parts.isEmpty ? 'À jour' : parts.join(' · ');
  }
}

/// Synchronisation delta paginée et reprenable, puis rejeu de l'outbox.
class SyncEngine {
  static const int pageSize = 100;

  final LocalDatabase db;
  final RemoteDocuments remote;
  final Outbox outbox;
  final OutboxExecutor executor;

  /// `force` : l'utilisateur a demandé la synchronisation lui-même ; le
  /// réglage « Wi-Fi seulement » ne s'applique pas à ce cas.
  final Future<bool> Function({bool force}) isOnline;
  final DateTime Function() clock;

  final _states = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  Future<SyncReport>? _running;

  SyncEngine({
    required this.db,
    required this.remote,
    required this.outbox,
    required this.executor,
    required this.isOnline,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  SyncState get state => _state;
  Stream<SyncState> get states => _states.stream;

  void _emit(SyncState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  Future<void> refreshPending(String owner) async {
    _emit(_state.copyWith(pendingCount: await outbox.pendingCount(owner)));
  }

  /// Une seule synchronisation à la fois : un retour réseau et un passage au
  /// premier plan simultanés ne doivent pas rejouer l'outbox deux fois.
  Future<SyncReport> run(UniFlowUser user, {bool force = false}) {
    return _running ??= _run(user, force).whenComplete(() => _running = null);
  }

  Future<SyncReport> _run(UniFlowUser user, bool force) async {
    final report = SyncReport();
    final owner = user.id;
    if (!await isOnline(force: force)) {
      report.offline = true;
      _emit(_state.copyWith(phase: SyncPhase.offline, pendingCount: await outbox.pendingCount(owner)));
      return report;
    }
    _emit(_state.copyWith(phase: SyncPhase.syncing, clearError: true));

    // L'outbox d'abord : ce que l'utilisateur a fait hors ligne part avant
    // qu'on relise le serveur, sinon le delta rapatrie l'état d'avant ses
    // écritures et l'écran « recule » un instant.
    report.outbox = await outbox.replay(owner, executor);

    for (final target in syncPlanFor(user)) {
      try {
        final result = await pullDelta(owner, target);
        report.documents += result.documents;
        report.conflicts += result.conflicts;
      } on OutboxOffline {
        report.offline = true;
        break;
      } catch (error) {
        report.errors.add('${target.collection}: $error');
      }
    }

    final pending = await outbox.pendingCount(owner);
    if (report.offline) {
      _emit(_state.copyWith(phase: SyncPhase.offline, pendingCount: pending, lastReport: report.describe()));
      return report;
    }
    final now = clock();
    await db.setPreference('lastSyncAt.$owner', now.toUtc().toIso8601String());
    _emit(SyncState(phase: SyncPhase.idle, lastSyncAt: now, pendingCount: pending, lastReport: report.describe()));
    return report;
  }

  Future<DateTime?> lastSyncAt(String owner) async {
    final raw = await db.preference('lastSyncAt.$owner');
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  /// Rapatrie ce qui a changé depuis le dernier passage, par lots de 100,
  /// en persistant le curseur après **chaque** page : une coupure au milieu
  /// d'un mois de retard reprend là où elle s'est arrêtée.
  Future<({int documents, int conflicts})> pullDelta(String owner, SyncCollection target) async {
    var cursor = await db.cursor(owner, target.collection) ?? const SyncCursor();
    if (cursor.scope != target.scopeKey) {
      cursor = SyncCursor(scope: target.scopeKey);
    }
    var documents = 0;
    var conflicts = 0;
    var maxUpdatedAt = cursor.lastUpdatedAt ?? '';
    final policy = policyFor(target.collection);

    while (true) {
      final page = await _listPage(target, cursor);
      if (page.isEmpty) break;
      final toStore = <CachedDocument>[];
      for (final doc in page) {
        final local = await db.document(target.collection, doc.$id);
        final merged = mergeIncoming(local, cacheDocument(doc), policy);
        if (merged.discardedLocal) conflicts++;
        toStore.add(merged.kept);
        if (doc.$updatedAt.compareTo(maxUpdatedAt) > 0) maxUpdatedAt = doc.$updatedAt;
      }
      await db.upsertDocuments(target.collection, owner, toStore);
      documents += page.length;
      if (page.length < pageSize) break;
      cursor = cursor.copyWith(pageCursor: page.last.$id);
      await db.saveCursor(owner, target.collection, cursor);
    }

    await db.saveCursor(
      owner,
      target.collection,
      cursor.copyWith(
        lastUpdatedAt: maxUpdatedAt.isEmpty ? null : maxUpdatedAt,
        clearPage: true,
        completedAt: clock().toUtc().toIso8601String(),
      ),
    );
    return (documents: documents, conflicts: conflicts);
  }

  Future<List<models.Document>> _listPage(SyncCollection target, SyncCursor cursor) async {
    final queries = <String>[
      ...target.filters,
      // Comparaison d'horodatages **serveur** : on demande ce qui est plus
      // récent que le dernier `$updatedAt` reçu, jamais que l'heure locale.
      if (cursor.lastUpdatedAt != null) Query.greaterThan('\$updatedAt', cursor.lastUpdatedAt!),
      Query.orderAsc('\$updatedAt'),
      Query.limit(pageSize),
      if (cursor.pageCursor != null) Query.cursorAfter(cursor.pageCursor!),
    ];
    try {
      return await remote.list(target.collection, queries);
    } on AppwriteException catch (error) {
      if (error.code == 400 && cursor.pageCursor != null) {
        // Le document-curseur a été supprimé côté serveur entre deux pages :
        // Appwrite refuse `cursorAfter`. On reprend la page sans curseur.
        return remote.list(target.collection, queries.where((q) => !q.contains('cursorAfter')).toList());
      }
      if (error.code == 0 || error.code == null) throw const OutboxOffline();
      rethrow;
    }
  }

  void dispose() {
    _states.close();
  }
}

/// Filtre local des séances sur la filière et le niveau du compte : le cache
/// peut contenir d'anciens périmètres (changement de niveau), l'écran ne doit
/// montrer que le courant.
List<AcademicSchedule> schedulesForScope(Iterable<AcademicSchedule> all, {String? program, String? level}) {
  final p = (program ?? '').trim().toUpperCase();
  final l = (level ?? '').trim().toUpperCase();
  return all.where((s) {
    if (p.isNotEmpty && s.program.trim().toUpperCase() != p) return false;
    if (l.isNotEmpty && s.level.trim().toUpperCase() != l) return false;
    return true;
  }).toList();
}
