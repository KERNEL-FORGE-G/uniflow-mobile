import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

/// Base SQLite locale de l'application (Drift, SQL écrit à la main).
///
/// Pourquoi pas une table Drift générée par collection : les besoins sont
/// identiques pour toutes (retrouver par identifiant, par propriétaire, par
/// `$updatedAt`), et chaque nouvelle collection aurait exigé une migration de
/// schéma. Un magasin JSON indexé par `(collection, id)` rend le même service,
/// et le document Appwrite complet (`toMap`) est conservé : les modèles Dart
/// se reconstruisent avec les mêmes `fromDocument` que depuis le réseau.
///
/// **Aucune expiration** : ce qui a été synchronisé une fois reste lisible
/// jusqu'au prochain delta — l'appareil peut rester un mois sans réseau.
class LocalDatabase extends GeneratedDatabase {
  LocalDatabase(super.executor);

  /// Base en mémoire, pour les tests.
  LocalDatabase.memory() : super(NativeDatabase.memory());

  /// Base sur disque, dans le dossier privé de l'application.
  static Future<LocalDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/uniflow_local.sqlite');
    return LocalDatabase(NativeDatabase.createInBackground(file));
  }

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => _createSchema(), beforeOpen: (_) => _createSchema());

  Future<void> _createSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS documents(
        collection TEXT NOT NULL,
        id TEXT NOT NULL,
        owner TEXT NOT NULL DEFAULT '',
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT '',
        pending INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(collection, id)
      )''');
    await customStatement('CREATE INDEX IF NOT EXISTS documents_owner ON documents(owner, collection, updated_at)');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_cursors(
        owner TEXT NOT NULL,
        collection TEXT NOT NULL,
        scope TEXT NOT NULL DEFAULT '',
        last_updated_at TEXT,
        page_cursor TEXT,
        completed_at TEXT,
        PRIMARY KEY(owner, collection)
      )''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS outbox(
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL UNIQUE,
        owner TEXT NOT NULL,
        kind TEXT NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        last_error TEXT
      )''');
    await customStatement('CREATE TABLE IF NOT EXISTS preferences(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cached_files(
        file_id TEXT PRIMARY KEY,
        bucket TEXT NOT NULL,
        path TEXT NOT NULL,
        bytes INTEGER NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        last_opened_at TEXT NOT NULL
      )''');
  }

  // ---------------------------------------------------------------- documents

  Future<void> upsertDocuments(String collection, String owner, Iterable<CachedDocument> docs) async {
    if (docs.isEmpty) return;
    await transaction(() async {
      for (final doc in docs) {
        await customStatement(
          'INSERT INTO documents(collection, id, owner, data, updated_at, created_at, pending) '
          'VALUES (?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(collection, id) DO UPDATE SET '
          'owner = excluded.owner, data = excluded.data, updated_at = excluded.updated_at, '
          'created_at = excluded.created_at, pending = excluded.pending',
          [collection, doc.id, owner, jsonEncode(doc.data), doc.updatedAt, doc.createdAt, doc.pending ? 1 : 0],
        );
      }
    });
  }

  Future<List<CachedDocument>> documents(String collection, {String? owner}) async {
    final rows = await customSelect(
      'SELECT id, data, updated_at, created_at, pending FROM documents '
      'WHERE collection = ? ${owner == null ? '' : 'AND owner = ?'} ORDER BY updated_at',
      variables: [Variable(collection), if (owner != null) Variable(owner)],
    ).get();
    return rows.map(_documentFromRow).toList();
  }

  Future<CachedDocument?> document(String collection, String id) async {
    final row = await customSelect(
      'SELECT id, data, updated_at, created_at, pending FROM documents WHERE collection = ? AND id = ?',
      variables: [Variable(collection), Variable(id)],
    ).getSingleOrNull();
    return row == null ? null : _documentFromRow(row);
  }

  CachedDocument _documentFromRow(QueryRow row) => CachedDocument(
        id: row.read<String>('id'),
        data: Map<String, dynamic>.from(jsonDecode(row.read<String>('data')) as Map),
        updatedAt: row.read<String>('updated_at'),
        createdAt: row.read<String>('created_at'),
        pending: row.read<int>('pending') == 1,
      );

  Future<void> deleteDocument(String collection, String id) =>
      customStatement('DELETE FROM documents WHERE collection = ? AND id = ?', [collection, id]);

  /// Remplace tout le contenu d'une collection pour un propriétaire : utilisé
  /// pour les réponses de Function (conversations, annuaire) qui ne sont pas
  /// des deltas mais des listes complètes.
  Future<void> replaceCollection(String collection, String owner, Iterable<CachedDocument> docs) async {
    await transaction(() async {
      await customStatement(
          'DELETE FROM documents WHERE collection = ? AND owner = ? AND pending = 0', [collection, owner]);
      await upsertDocuments(collection, owner, docs);
    });
  }

  Future<int> countDocuments(String collection, {String? owner}) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM documents WHERE collection = ? ${owner == null ? '' : 'AND owner = ?'}',
      variables: [Variable(collection), if (owner != null) Variable(owner)],
    ).getSingle();
    return row.read<int>('n');
  }

  // ------------------------------------------------------------------ cursors

  Future<SyncCursor?> cursor(String owner, String collection) async {
    final row = await customSelect(
      'SELECT scope, last_updated_at, page_cursor, completed_at FROM sync_cursors WHERE owner = ? AND collection = ?',
      variables: [Variable(owner), Variable(collection)],
    ).getSingleOrNull();
    if (row == null) return null;
    return SyncCursor(
      scope: row.read<String>('scope'),
      lastUpdatedAt: row.readNullable<String>('last_updated_at'),
      pageCursor: row.readNullable<String>('page_cursor'),
      completedAt: row.readNullable<String>('completed_at'),
    );
  }

  Future<void> saveCursor(String owner, String collection, SyncCursor cursor) => customStatement(
        'INSERT INTO sync_cursors(owner, collection, scope, last_updated_at, page_cursor, completed_at) '
        'VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(owner, collection) DO UPDATE SET scope = excluded.scope, '
        'last_updated_at = excluded.last_updated_at, page_cursor = excluded.page_cursor, completed_at = excluded.completed_at',
        [owner, collection, cursor.scope, cursor.lastUpdatedAt, cursor.pageCursor, cursor.completedAt],
      );

  Future<void> clearCursor(String owner, String collection) =>
      customStatement('DELETE FROM sync_cursors WHERE owner = ? AND collection = ?', [owner, collection]);

  // ------------------------------------------------------------------- outbox

  Future<void> insertOutbox(OutboxRow row) => customStatement(
        'INSERT OR IGNORE INTO outbox(client_id, owner, kind, label, payload, created_at, attempts, next_attempt_at, status, last_error) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          row.clientId,
          row.owner,
          row.kind,
          row.label,
          jsonEncode(row.payload),
          row.createdAt,
          row.attempts,
          row.nextAttemptAt,
          row.status,
          row.lastError,
        ],
      );

  Future<List<OutboxRow>> outbox(String owner, {String? status}) async {
    final rows = await customSelect(
      'SELECT * FROM outbox WHERE owner = ? ${status == null ? '' : 'AND status = ?'} ORDER BY seq',
      variables: [Variable(owner), if (status != null) Variable(status)],
    ).get();
    return rows.map(_outboxFromRow).toList();
  }

  Future<int> countOutbox(String owner, {List<String> statuses = const ['pending', 'retry']}) async {
    final marks = List.filled(statuses.length, '?').join(',');
    final row = await customSelect(
      'SELECT COUNT(*) AS n FROM outbox WHERE owner = ? AND status IN ($marks)',
      variables: [Variable(owner), ...statuses.map(Variable.new)],
    ).getSingle();
    return row.read<int>('n');
  }

  OutboxRow _outboxFromRow(QueryRow row) => OutboxRow(
        seq: row.read<int>('seq'),
        clientId: row.read<String>('client_id'),
        owner: row.read<String>('owner'),
        kind: row.read<String>('kind'),
        label: row.read<String>('label'),
        payload: Map<String, dynamic>.from(jsonDecode(row.read<String>('payload')) as Map),
        createdAt: row.read<String>('created_at'),
        attempts: row.read<int>('attempts'),
        nextAttemptAt: row.read<String>('next_attempt_at'),
        status: row.read<String>('status'),
        lastError: row.readNullable<String>('last_error'),
      );

  Future<void> updateOutbox(
    String clientId, {
    required String status,
    int? attempts,
    String? nextAttemptAt,
    String? lastError,
  }) =>
      customStatement(
        'UPDATE outbox SET status = ?, attempts = COALESCE(?, attempts), '
        'next_attempt_at = COALESCE(?, next_attempt_at), last_error = ? WHERE client_id = ?',
        [status, attempts, nextAttemptAt, lastError, clientId],
      );

  Future<void> deleteOutbox(String clientId) => customStatement('DELETE FROM outbox WHERE client_id = ?', [clientId]);

  // -------------------------------------------------------------- preferences

  Future<String?> preference(String key) async {
    final row =
        await customSelect('SELECT value FROM preferences WHERE key = ?', variables: [Variable(key)]).getSingleOrNull();
    return row?.read<String>('value');
  }

  Future<void> setPreference(String key, String value) => customStatement(
        'INSERT INTO preferences(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        [key, value],
      );

  // ------------------------------------------------------------- cached files

  Future<List<CachedFileRow>> cachedFiles() async {
    final rows = await customSelect('SELECT * FROM cached_files ORDER BY last_opened_at').get();
    return rows
        .map((r) => CachedFileRow(
              fileId: r.read<String>('file_id'),
              bucket: r.read<String>('bucket'),
              path: r.read<String>('path'),
              bytes: r.read<int>('bytes'),
              name: r.read<String>('name'),
              lastOpenedAt: r.read<String>('last_opened_at'),
            ))
        .toList();
  }

  Future<void> upsertCachedFile(CachedFileRow row) => customStatement(
        'INSERT INTO cached_files(file_id, bucket, path, bytes, name, last_opened_at) VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(file_id) DO UPDATE SET path = excluded.path, bytes = excluded.bytes, name = excluded.name, '
        'last_opened_at = excluded.last_opened_at',
        [row.fileId, row.bucket, row.path, row.bytes, row.name, row.lastOpenedAt],
      );

  Future<void> deleteCachedFile(String fileId) =>
      customStatement('DELETE FROM cached_files WHERE file_id = ?', [fileId]);

  /// Oublie tout ce qui appartient à un utilisateur (déconnexion volontaire).
  /// Une expiration de session **ne** passe **pas** par ici : l'outbox et le
  /// cache restent rattachés à l'identifiant et survivent à la reconnexion.
  Future<void> forgetOwner(String owner) async {
    await transaction(() async {
      await customStatement('DELETE FROM documents WHERE owner = ?', [owner]);
      await customStatement('DELETE FROM sync_cursors WHERE owner = ?', [owner]);
      await customStatement('DELETE FROM outbox WHERE owner = ?', [owner]);
    });
  }
}

/// Document Appwrite tel qu'il est conservé localement : `data` est le
/// `toMap()` complet (`$id`, `$updatedAt`, `data`…), pas seulement les champs.
class CachedDocument {
  final String id;
  final Map<String, dynamic> data;
  final String updatedAt;
  final String createdAt;

  /// Créé hors ligne, pas encore envoyé : l'écran l'affiche avec la mention
  /// « en attente d'envoi ».
  final bool pending;

  const CachedDocument({
    required this.id,
    required this.data,
    this.updatedAt = '',
    this.createdAt = '',
    this.pending = false,
  });

  /// Champs métier du document (sans les métadonnées `$…`).
  Map<String, dynamic> get fields => data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : const {};
}

class SyncCursor {
  final String scope;

  /// Plus grand `$updatedAt` serveur intégré : le prochain delta part de là.
  /// On compare des horodatages **serveur** entre eux, jamais l'heure locale,
  /// qui peut être fausse d'un mois sur un téléphone resté éteint.
  final String? lastUpdatedAt;

  /// Dernier document reçu de la page en cours : une synchronisation coupée
  /// au milieu d'un lot de 100 reprend ici au lieu de tout recommencer.
  final String? pageCursor;
  final String? completedAt;

  const SyncCursor({this.scope = '', this.lastUpdatedAt, this.pageCursor, this.completedAt});

  SyncCursor copyWith(
          {String? scope, String? lastUpdatedAt, String? pageCursor, String? completedAt, bool clearPage = false}) =>
      SyncCursor(
        scope: scope ?? this.scope,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
        pageCursor: clearPage ? null : (pageCursor ?? this.pageCursor),
        completedAt: completedAt ?? this.completedAt,
      );
}

class OutboxRow {
  final int seq;
  final String clientId;
  final String owner;
  final String kind;
  final String label;
  final Map<String, dynamic> payload;
  final String createdAt;
  final int attempts;
  final String nextAttemptAt;
  final String status;
  final String? lastError;

  const OutboxRow({
    this.seq = 0,
    required this.clientId,
    required this.owner,
    required this.kind,
    this.label = '',
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    required this.nextAttemptAt,
    this.status = 'pending',
    this.lastError,
  });
}

class CachedFileRow {
  final String fileId;
  final String bucket;
  final String path;
  final int bytes;
  final String name;
  final String lastOpenedAt;

  const CachedFileRow({
    required this.fileId,
    required this.bucket,
    required this.path,
    required this.bytes,
    this.name = '',
    required this.lastOpenedAt,
  });
}
