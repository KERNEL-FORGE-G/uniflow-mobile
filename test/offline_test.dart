import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/offline/appwrite_adapters.dart';
import 'package:uniflow_mobile/offline/document_cache.dart';
import 'package:uniflow_mobile/offline/local_database.dart';
import 'package:uniflow_mobile/offline/outbox.dart';
import 'package:uniflow_mobile/offline/session_store.dart';
import 'package:uniflow_mobile/offline/sync_engine.dart';

/// Serveur Appwrite simulé : des collections en mémoire, un interrupteur
/// réseau, et l'horodatage `$updatedAt` posé par le « serveur ».
class _FakeServer implements RemoteDocuments, OutboxExecutor {
  final Map<String, List<models.Document>> collections = {};
  final List<OutboxRow> received = [];
  bool online = true;
  DateTime serverClock;
  int listCalls = 0;

  /// Codes de refus à renvoyer pour un `clientId` donné (test des conflits).
  final Map<String, String> refusals = {};

  _FakeServer(this.serverClock);

  models.Document put(String collection, String id, Map<String, dynamic> fields) {
    final stamp = serverClock.toUtc().toIso8601String();
    final list = collections.putIfAbsent(collection, () => []);
    final existing = list.indexWhere((d) => d.$id == id);
    final doc = models.Document(
      $id: id,
      $sequence: '${list.length + 1}',
      $collectionId: collection,
      $databaseId: 'uniflow',
      $createdAt: existing >= 0 ? list[existing].$createdAt : stamp,
      $updatedAt: stamp,
      $permissions: const [],
      data: fields,
    );
    if (existing >= 0) {
      list[existing] = doc;
    } else {
      list.add(doc);
    }
    return doc;
  }

  @override
  Future<List<models.Document>> list(String collection, List<String> queries) async {
    if (!online) throw AppwriteException('Failed host lookup', 0);
    listCalls++;
    var docs = List<models.Document>.from(collections[collection] ?? const []);
    String? after;
    String? cursorAfter;
    var limit = 25;
    final equals = <String, String>{};
    for (final raw in queries) {
      final q = _parse(raw);
      switch (q.method) {
        case 'greaterThan':
          after = q.values.first;
        case 'orderAsc':
          break;
        case 'limit':
          limit = int.parse(q.values.first);
        case 'cursorAfter':
          cursorAfter = q.values.first;
        case 'equal':
          equals[q.attribute!] = q.values.first;
      }
    }
    docs = docs.where((d) {
      for (final e in equals.entries) {
        final value = e.key == '\$id' ? d.$id : d.data[e.key]?.toString();
        if (value != e.value) return false;
      }
      return after == null || d.$updatedAt.compareTo(after) > 0;
    }).toList()
      ..sort((a, b) => a.$updatedAt.compareTo(b.$updatedAt));
    if (cursorAfter != null) {
      final index = docs.indexWhere((d) => d.$id == cursorAfter);
      docs = index < 0 ? docs : docs.sublist(index + 1);
    }
    return docs.take(limit).toList();
  }

  @override
  Future<void> execute(OutboxRow entry) async {
    if (!online) throw const OutboxOffline();
    final refusal = refusals[entry.clientId];
    if (refusal != null) throw classifyServiceRefusal(refusal, 'refus $refusal');
    received.add(entry);
  }

  static ({String method, String? attribute, List<String> values}) _parse(String raw) {
    // Les `Query.*` du SDK 26 sont du JSON : {"method":"equal","attribute":"x","values":[...]}.
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return (
      method: map['method'] as String,
      attribute: map['attribute'] as String?,
      values: ((map['values'] as List?) ?? const []).map((v) => v.toString()).toList(),
    );
  }
}

UniFlowUser _student({String program = 'PHY', String level = 'L3'}) => UniFlowUser(
      id: 'u1',
      email: 'etu@uniflow.test',
      name: 'Étudiant Test',
      accountType: 'UNIVERSITY',
      role: 'STUDENT',
      university: 'Université de Yaoundé I',
      faculty: 'FS',
      program: program,
      level: level,
    );

Map<String, dynamic> _seance(String program, String level, String day, String start) => {
      'courseId': 'c_${program}_$level',
      'courseCode': '${program}101',
      'dayOfWeek': day,
      'startTime': start,
      'endTime': '10:30',
      'classroom': 'A1',
      'type': 'CM',
      'program': program,
      'level': level,
      'courseName': 'Cours $program',
      'teacherName': 'Pr Test',
    };

void main() {
  late LocalDatabase db;
  late _FakeServer server;
  var now = DateTime.utc(2026, 9, 20, 8);

  SyncEngine engine() => SyncEngine(
        db: db,
        remote: server,
        outbox: Outbox(db, clock: () => now),
        executor: server,
        isOnline: ({bool force = false}) async => server.online,
        clock: () => now,
      );

  setUp(() {
    db = LocalDatabase.memory();
    server = _FakeServer(DateTime.utc(2026, 9, 1));
    now = DateTime.utc(2026, 9, 20, 8);
  });

  tearDown(() => db.close());

  group('cache d\'abord', () {
    test('émet le cache puis le frais, et range le frais', () async {
      final stored = <String>[];
      final values = await cacheFirst<String>(
        readCache: () async => 'cache',
        fetch: () async => 'frais',
        store: (v) async => stored.add(v),
      ).toList();
      expect(values, ['cache', 'frais']);
      expect(stored, ['frais']);
    });

    test('réseau en panne mais cache présent : l\'écran garde le cache, sans erreur', () async {
      final values = await cacheFirst<String>(
        readCache: () async => 'cache',
        fetch: () async => throw AppwriteException('Failed host lookup', 0),
        store: (_) async {},
      ).toList();
      expect(values, ['cache']);
    });

    test('réseau en panne et cache vide : l\'erreur remonte', () {
      expect(
        cacheFirst<String>(
          readCache: () async => null,
          fetch: () async => throw AppwriteException('Failed host lookup', 0),
          store: (_) async {},
        ).toList(),
        throwsA(isA<AppwriteException>()),
      );
    });
  });

  group('base locale', () {
    test('conserve un document Appwrite et le restitue identique', () async {
      final doc = server.put('academic_courses', 'c1', {'code': 'PHY101', 'program': 'PHY', 'level': 'L3'});
      await db.upsertDocuments('academic_courses', 'u1', [cacheDocument(doc)]);
      final back = restoreDocument((await db.document('academic_courses', 'c1'))!);
      expect(back.$id, 'c1');
      expect(back.$updatedAt, doc.$updatedAt);
      expect(AcademicCourse.fromDocument(back).code, 'PHY101');
    });

    test('n\'expire jamais : un document vieux d\'un an reste lisible', () async {
      server.serverClock = DateTime.utc(2025, 9, 1);
      final doc = server.put('academic_courses', 'vieux', {'code': 'OLD'});
      await db.upsertDocuments('academic_courses', 'u1', [cacheDocument(doc)]);
      now = DateTime.utc(2026, 10, 1);
      expect(await db.countDocuments('academic_courses', owner: 'u1'), 1);
    });
  });

  group('outbox', () {
    test('rejoue dans l\'ordre, supprime ce qui est parti, garde l\'identifiant client', () async {
      final outbox = Outbox(db, clock: () => now);
      final a = await outbox.enqueue(owner: 'u1', kind: OutboxKind.service, payload: {'path': '/x', 'body': {}});
      final b = await outbox.enqueue(owner: 'u1', kind: OutboxKind.service, payload: {'path': '/y', 'body': {}});
      expect(a, isNot(b));
      expect(await outbox.pendingCount('u1'), 2);

      final report = await outbox.replay('u1', server);
      expect(report.sent, 2);
      expect(server.received.map((e) => e.clientId), [a, b]);
      expect(await outbox.pendingCount('u1'), 0);
    });

    test('même identifiant client réinséré : ignoré (idempotence)', () async {
      final outbox = Outbox(db, clock: () => now);
      await outbox.enqueue(owner: 'u1', kind: OutboxKind.service, payload: {'path': '/x'}, clientId: 'cli_fixe');
      await outbox.enqueue(owner: 'u1', kind: OutboxKind.service, payload: {'path': '/x'}, clientId: 'cli_fixe');
      expect(await outbox.pendingCount('u1'), 1);
    });

    test('hors ligne : s\'arrête à la première entrée sans consommer de tentative', () async {
      final outbox = Outbox(db, clock: () => now);
      await outbox.enqueue(owner: 'u1', kind: OutboxKind.service, payload: {'path': '/x'});
      server.online = false;
      final report = await outbox.replay('u1', server);
      expect(report.stoppedOffline, isTrue);
      expect(report.sent, 0);
      final entry = (await outbox.entries('u1')).single;
      expect(entry.attempts, 0);
      expect(entry.status, OutboxStatus.pending);
    });

    test('erreur passagère : réessai exponentiel, différé jusqu\'à l\'échéance', () async {
      final outbox = Outbox(db, clock: () => now);
      final failing = _FlakyExecutor(failures: 1);
      await outbox.enqueue(owner: 'u1', kind: OutboxKind.service, payload: {'path': '/x'});

      var report = await outbox.replay('u1', failing);
      expect(report.deferred, 1);
      var entry = (await outbox.entries('u1')).single;
      expect(entry.attempts, 1);
      expect(entry.status, OutboxStatus.retry);

      // Pas encore l'heure : rien ne part.
      report = await outbox.replay('u1', failing);
      expect(report.sent, 0);
      expect(report.deferred, 1);

      now = now.add(backoffDelay(1));
      report = await outbox.replay('u1', failing);
      expect(report.sent, 1);
      expect(await outbox.pendingCount('u1'), 0);
    });

    test('refus métier : conflit à revoir ou refus définitif, jamais rejoué', () async {
      final outbox = Outbox(db, clock: () => now);
      final dup = await outbox.enqueue(owner: 'u1', kind: OutboxKind.service, payload: {'path': '/a'});
      final denied = await outbox.enqueue(owner: 'u1', kind: OutboxKind.service, payload: {'path': '/b'});
      server.refusals[dup] = 'ROLL_DUPLICATE';
      server.refusals[denied] = 'ROLE_DENIED';
      final report = await outbox.replay('u1', server);
      expect(report.conflicts, 1);
      expect(report.failed, 1);
      expect(report.describe(), '1 conflit à revoir, 1 refusé');
      final rows = await outbox.entries('u1');
      expect(rows.map((r) => r.status), [OutboxStatus.conflict, OutboxStatus.failed]);
      expect(await outbox.pendingCount('u1'), 0);
    });

    test('délai exponentiel plafonné à six heures', () {
      expect(backoffDelay(1), const Duration(seconds: 30));
      expect(backoffDelay(2), const Duration(minutes: 1));
      expect(backoffDelay(4), const Duration(minutes: 4));
      expect(backoffDelay(20), const Duration(hours: 6));
    });
  });

  group('politique de conflit', () {
    test('référentiel : serveur gagne ; données utilisateur : dernière écriture gagne', () {
      expect(policyFor('academic_schedules'), ConflictPolicy.serverWins);
      expect(policyFor('academic_courses'), ConflictPolicy.serverWins);
      expect(policyFor('academic_programs'), ConflictPolicy.serverWins);
      expect(policyFor('team_members'), ConflictPolicy.serverWins);
      expect(policyFor('academic_submissions'), ConflictPolicy.lastWriteWins);
      expect(policyFor('attendance_records'), ConflictPolicy.lastWriteWins);
      expect(policyFor('users'), ConflictPolicy.lastWriteWins);
    });

    test('fusion : une écriture locale en attente est écrasée par le référentiel, gardée sinon', () {
      final local = localDocument(id: 'x', collection: 'c', fields: {'v': 'local'}, now: now);
      const server = CachedDocument(id: 'x', data: {'v': 'serveur'}, updatedAt: '2026-09-20T00:00:00.000+00:00');

      final ref = mergeIncoming(local, server, ConflictPolicy.serverWins);
      expect(ref.kept.data['v'], 'serveur');
      expect(ref.discardedLocal, isTrue);

      final mine = mergeIncoming(local, server, ConflictPolicy.lastWriteWins);
      expect(mine.kept.pending, isTrue);
      expect(mine.discardedLocal, isFalse);

      final clean = mergeIncoming(null, server, ConflictPolicy.lastWriteWins);
      expect(clean.kept.data['v'], 'serveur');
    });

    test('classement des erreurs Appwrite au rejeu', () {
      expect(classifyAppwriteFailure(0, 'réseau'), isA<OutboxOffline>());
      expect(
          classifyAppwriteFailure(409, 'existe'), isA<OutboxRejected>().having((e) => e.conflict, 'conflict', isTrue));
      expect(classifyAppwriteFailure(403, 'interdit'),
          isA<OutboxRejected>().having((e) => e.conflict, 'conflict', isFalse));
      expect(classifyAppwriteFailure(401, 'session'), isNot(isA<OutboxRejected>()));
      expect(classifyAppwriteFailure(503, 'panne'), isNot(isA<OutboxRejected>()));
    });
  });

  group('session conservée', () {
    test('se rétablit depuis le stockage chiffré, sans serveur', () async {
      final store = SessionStore(InMemoryKeyValueStore());
      final user = UniFlowUser(
        id: 'u1',
        email: 'delegue@uniflow.test',
        name: 'Délégué',
        accountType: 'UNIVERSITY',
        role: 'DELEGATE',
        labels: const ['DELEGATE'],
        program: 'ICT4D',
        level: 'L1',
      );
      await store.save(user, now: now);
      final back = await store.read();
      expect(back, isNotNull);
      expect(back!.user.role, 'DELEGATE');
      expect(back.user.labels, ['DELEGATE']);
      expect(back.user.program, 'ICT4D');
      expect(back.verifiedAt, now);
    });

    test('stockage corrompu : pas de plantage, simple absence de session', () async {
      final raw = InMemoryKeyValueStore();
      raw.values['uniflow.session'] = '{pas du json';
      expect(await SessionStore(raw).read(), isNull);
    });
  });

  group('filtrage du cache des séances', () {
    test('ne garde que ma filière et mon niveau', () {
      final all = [
        AcademicSchedule.fromDocument(server.put('academic_schedules', 's1', _seance('PHY', 'L3', 'Lundi', '07:30'))),
        AcademicSchedule.fromDocument(server.put('academic_schedules', 's2', _seance('PHY', 'L2', 'Lundi', '07:30'))),
        AcademicSchedule.fromDocument(server.put('academic_schedules', 's3', _seance('ENR', 'L3', 'Mardi', '11:00'))),
      ];
      expect(schedulesForScope(all, program: 'PHY', level: 'L3').map((s) => s.id), ['s1']);
      expect(schedulesForScope(all, program: 'phy').length, 2);
      expect(schedulesForScope(all).length, 3);
    });
  });

  group('synchronisation delta', () {
    test('plan : un étudiant ne rapatrie que sa filière et son niveau', () {
      final plan = syncPlanFor(_student());
      final schedules = plan.singleWhere((c) => c.collection == 'academic_schedules');
      expect(schedules.filters.length, 2);
      expect(schedules.scopeKey, 'PHY/L3');
      expect(plan.map((c) => c.collection), contains('academic_grades'));
    });

    test('paginé par 100, curseur persistant, delta ensuite', () async {
      for (var i = 0; i < 230; i++) {
        server.serverClock = server.serverClock.add(const Duration(seconds: 1));
        server.put('academic_schedules', 's$i', _seance('PHY', 'L3', 'Lundi', '07:30'));
      }
      final e = engine();
      final report = await e.run(_student());
      expect(report.documents, 230);
      expect(await db.countDocuments('academic_schedules', owner: 'u1'), 230);
      final cursor = await db.cursor('u1', 'academic_schedules');
      expect(cursor!.pageCursor, isNull);
      expect(cursor.lastUpdatedAt, server.collections['academic_schedules']!.last.$updatedAt);

      // Un seul changement côté serveur : le delta ne rapatrie que lui.
      server.listCalls = 0;
      server.serverClock = server.serverClock.add(const Duration(days: 1));
      server.put('academic_schedules', 's7', _seance('PHY', 'L3', 'Mardi', '11:00'));
      final again = await e.run(_student());
      expect(again.documents, 1);
      final s7 = AcademicSchedule.fromDocument(restoreDocument((await db.document('academic_schedules', 's7'))!));
      expect(s7.dayOfWeek, 'Mardi');
      e.dispose();
    });

    test('changement de niveau : le curseur repart pour le nouveau périmètre', () async {
      server.put('academic_schedules', 'l3', _seance('PHY', 'L3', 'Lundi', '07:30'));
      server.serverClock = server.serverClock.add(const Duration(seconds: 1));
      server.put('academic_schedules', 'm1', _seance('PHY', 'M1', 'Lundi', '07:30'));
      final e = engine();
      await e.run(_student());
      expect((await db.cursor('u1', 'academic_schedules'))!.scope, 'PHY/L3');
      final report = await e.run(_student(level: 'M1'));
      expect(report.documents, greaterThanOrEqualTo(1));
      expect((await db.cursor('u1', 'academic_schedules'))!.scope, 'PHY/M1');
      final cached = (await db.documents('academic_schedules', owner: 'u1'))
          .map((c) => AcademicSchedule.fromDocument(restoreDocument(c)))
          .toList();
      expect(schedulesForScope(cached, program: 'PHY', level: 'M1').map((s) => s.id), ['m1']);
      e.dispose();
    });
  });

  group('trente jours hors ligne', () {
    test('démarrage sans réseau, présences locales, puis retour : rejeu complet et état cohérent', () async {
      // Jour 0 : en ligne, première synchronisation complète.
      server.put('academic_programs', 'PHY', {'code': 'PHY', 'name': 'Physique', 'levels': 'L1,L2,L3,M1'});
      server.put('academic_courses', 'c1', {'code': 'PHY301', 'name': 'Optique', 'program': 'PHY', 'level': 'L3'});
      for (var i = 0; i < 40; i++) {
        server.put('academic_schedules', 's$i', _seance('PHY', 'L3', i.isEven ? 'Lundi' : 'Mardi', '07:30'));
      }
      final store = SessionStore(InMemoryKeyValueStore());
      final delegate = UniFlowUser(
        id: 'u1',
        email: 'd@uniflow.test',
        name: 'Délégué PHY',
        accountType: 'UNIVERSITY',
        role: 'DELEGATE',
        labels: const ['DELEGATE'],
        program: 'PHY',
        level: 'L3',
      );
      await store.save(delegate, now: now);
      var e = engine();
      final first = await e.run(delegate);
      expect(first.documents, 42);
      e.dispose();

      // Coupure : trente jours sans réseau, téléphone redémarré chaque jour.
      server.online = false;
      final outbox = Outbox(db, clock: () => now);
      for (var day = 1; day <= 30; day++) {
        now = now.add(const Duration(days: 1));
        // Démarrage : identité depuis le stockage chiffré, sans account.get().
        final snapshot = await store.read();
        expect(snapshot!.user.role, 'DELEGATE');
        // Emploi du temps et cours consultables depuis le cache.
        final schedules = (await db.documents('academic_schedules', owner: 'u1'))
            .map((c) => AcademicSchedule.fromDocument(restoreDocument(c)));
        expect(schedulesForScope(schedules, program: 'PHY', level: 'L3').length, 40);
        expect(await db.countDocuments('academic_courses', owner: 'u1'), 1);
        // Appel de présence enregistré localement, avec identifiant client.
        await outbox.enqueue(
          owner: 'u1',
          kind: OutboxKind.service,
          label: 'Appel du jour $day',
          payload: {
            'path': '/attendance-secure',
            'body': {
              'action': 'roll',
              'courseId': 'c1',
              'date': now.toIso8601String(),
              'rows': [
                {'studentId': 'e1', 'status': 'PRESENT'},
              ],
            },
          },
        );
        // Une tentative de synchronisation hors ligne ne casse rien.
        e = engine();
        final attempt = await e.run(delegate);
        expect(attempt.offline, isTrue);
        expect(e.state.isOffline, isTrue);
        expect(e.state.pendingCount, day);
        e.dispose();
      }
      expect(await outbox.pendingCount('u1'), 30);

      // Pendant ce temps le serveur a bougé : deux séances modifiées, une
      // nouvelle UE. Puis le réseau revient.
      server.serverClock = now.subtract(const Duration(days: 2));
      server.put('academic_schedules', 's3', _seance('PHY', 'L3', 'Vendredi', '14:30'));
      server.put('academic_schedules', 's5', _seance('PHY', 'L3', 'Samedi', '07:30'));
      server.put('academic_courses', 'c2', {'code': 'PHY302', 'name': 'Thermo', 'program': 'PHY', 'level': 'L3'});
      server.online = true;

      e = engine();
      final back = await e.run(delegate);
      expect(back.offline, isFalse);
      expect(back.outbox.sent, 30);
      expect(server.received.length, 30);
      // Rejoués dans l'ordre des jours, chacun avec son identifiant client.
      expect(server.received.map((r) => r.label).first, 'Appel du jour 1');
      expect(server.received.map((r) => r.label).last, 'Appel du jour 30');
      expect(server.received.map((r) => r.clientId).toSet().length, 30);
      // Delta : seulement ce qui a changé.
      expect(back.documents, 3);
      final s3 = AcademicSchedule.fromDocument(restoreDocument((await db.document('academic_schedules', 's3'))!));
      expect(s3.dayOfWeek, 'Vendredi');
      expect(await db.countDocuments('academic_courses', owner: 'u1'), 2);
      expect(e.state.pendingCount, 0);
      expect(e.state.lastSyncAt, now);
      expect(back.describe(), contains('30 éléments envoyés'));
      e.dispose();
    });
  });
}

/// Exécuteur qui échoue [failures] fois puis réussit (panne passagère).
class _FlakyExecutor implements OutboxExecutor {
  int failures;
  _FlakyExecutor({required this.failures});

  @override
  Future<void> execute(OutboxRow entry) async {
    if (failures > 0) {
      failures--;
      throw Exception('Erreur 503 passagère');
    }
  }
}
