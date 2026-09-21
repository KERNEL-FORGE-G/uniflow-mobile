// Vérification EN DIRECT contre Appwrite Cloud, compte par compte.
//
// `flutter test` remplace le client HTTP par un faux qui répond 400 à tout :
// une panne d'API y est indétectable. Ce fichier installe donc son propre
// binding, qui **laisse passer le vrai réseau**, et parcourt avec les vrais
// comptes tout ce que l'application lit ou écrit : session, profil (rôle par
// labels), emploi du temps, cours, notes, devoirs, bibliothèque, messagerie
// (liste, envoi, pièce jointe), forum, notifications, équipe.
//
// Il s'exécute sur le poste de travail (Linux) sans appareil :
//
//   flutter test test_live/cloud_live_test.dart \
//     --dart-define=UNIFLOW_ACCOUNTS_FILE=/chemin/hors/depot/.comptes-demo.local
//
// Le fichier de comptes est au format `email=motdepasse`, une ligne par
// compte, et vit HORS du dépôt : aucun identifiant n'est écrit ici.
// Sans ce paramètre, le test est ignoré (pas échoué) pour que la suite
// principale reste indépendante du réseau.

import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/data/appwrite_service.dart';
import 'package:uniflow_mobile/models/models.dart';
import 'package:uniflow_mobile/models/user_role.dart';
import 'package:uniflow_mobile/repositories/academic_repository.dart';
import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/repositories/forum_repository.dart';
import 'package:uniflow_mobile/repositories/messaging_repository.dart';
import 'package:uniflow_mobile/repositories/personal_repository.dart';
import 'package:uniflow_mobile/repositories/team_repository.dart';
import 'package:uniflow_mobile/screens/schedule.dart';

const _accountsFile = String.fromEnvironment('UNIFLOW_ACCOUNTS_FILE');

/// Binding de test qui n'intercepte pas HTTP.
///
/// `AutomatedTestWidgetsFlutterBinding` pose par défaut un `HttpOverrides`
/// dont chaque requête rend 400 ; `overrideHttpClient` à `false` est le
/// crochet officiel pour l'en dispenser (c'est ce que fait le binding
/// d'`integration_test`).
class _LiveBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;

  static _LiveBinding? _instance;

  static _LiveBinding ensureInitialized() => _instance ??= _LiveBinding();
}

Map<String, String> _readAccounts(String path) {
  final accounts = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    accounts[trimmed.substring(0, separator).trim()] = trimmed.substring(separator + 1);
  }
  return accounts;
}

void _log(String message) => debugPrint('LIVE $message');

void main() {
  final binding = _LiveBinding.ensureInitialized();
  // Le client Appwrite range ses cookies de session dans le dossier
  // « documents » de la plateforme, via `path_provider`. Sur le poste de
  // travail il n'y a pas de plateforme : sans ce faux canal, chaque appel
  // échoue en `MissingPluginException` avant même d'atteindre le réseau.
  final cookieDir = Directory.systemTemp.createTempSync('uniflow_live_');
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => cookieDir.path,
  );

  if (_accountsFile.isEmpty) {
    test('vérification en direct ignorée (UNIFLOW_ACCOUNTS_FILE absent)', () {
      _log('aucun fichier de comptes fourni ; rien n\'est vérifié contre le Cloud.');
    });
    return;
  }

  final accounts = _readAccounts(_accountsFile);
  // `.env` lu directement depuis le disque : `rootBundle` n'est pas fiable
  // hors d'un `testWidgets`, et ce fichier est de toute façon versionné.
  dotenv.loadFromString(envString: File('.env').readAsStringSync());
  final service = AppwriteService();
  final auth = AuthRepository(service);
  final academic = AcademicRepository(service);
  final messaging = MessagingRepository(service);
  final forum = ForumRepository(service);
  final team = TeamRepository(service);
  final personal = PersonalRepository(service);

  const longTimeout = Timeout(Duration(minutes: 6));

  for (final entry in accounts.entries) {
    final email = entry.key;
    test('$email : session, profil et lectures selon le rôle', () async {
      await auth.login(email, entry.value);
      final user = await auth.getCurrentUser();
      expect(user, isNotNull, reason: 'profil relu après connexion');
      final role = mapRole(user!.role);
      _log('$email -> role=${user.role} labels=${user.labels} type=${user.accountType} '
          'university=${user.university} program=${user.program} level=${user.level} username=${user.username}');

      if (role == UniFlowRole.personal) {
        // Le service `/messaging` refuse un compte hors annuaire académique
        // (« La messagerie est réservée aux membres de l'annuaire… ») : le
        // mobile ne lui propose donc ni Messages ni Notifications.
        final subjects = await personal.getSubjects(user.id);
        final tasks = await personal.getTasks(user.id);
        _log('$email personal subjects=${subjects.length} tasks=${tasks.length}');
        final posts = await forum.getPosts();
        final members = await team.getMembers();
        _log('$email forum posts=${posts.length} team members=${members.length}');
        return;
      }

      // Écrans communs aux rôles universitaires.
      final conversations = await messaging.getConversations();
      _log('$email conversations=${conversations.length}');
      final notifications = await messaging.getNotifications();
      _log('$email notifications=${notifications.length}');
      final posts = await forum.getPosts();
      _log('$email forum posts=${posts.length}');
      final reactions = await forum.getMyReactions();
      _log('$email forum reactions=${reactions.length}');
      final members = await team.getMembers();
      _log('$email team members=${members.length} '
          'photos=${members.where((m) => m.avatarFileId.isNotEmpty).length}');
      expect(members.length, greaterThanOrEqualTo(8), reason: 'les 8 membres de l\'équipe (liste du 2026-09-21)');

      final courses = await academic.getCourses(
        program: role.isLearner ? user.program : null,
        level: role.isLearner ? user.level : null,
      );
      final schedules = await academic.getSchedulesForCourses([for (final c in courses) c.id]);
      final library = await academic.getLibrary();
      _log('$email courses=${courses.length} schedules=${schedules.length} library=${library.length}');
      final directory = await academic.getDirectory();
      _log('$email directory=${directory.length}');
      // Inscriptions (écran « Inscriptions », fiches étudiant/enseignant/UE) :
      // lues comme le fait `scopedEnrollmentsProvider`, par étudiant pour un
      // apprenant, par lot de cours pour le personnel.
      final enrollmentDocs = role.isLearner
          ? await academic.listAll('academic_enrollments', [Query.equal('studentId', user.id)])
          : courses.isEmpty
              ? const <models.Document>[]
              : await academic.listAll('academic_enrollments', [
                  Query.equal('courseId', [for (final c in courses.take(100)) c.id]),
                ]);
      final enrollments = enrollmentDocs.map(Enrollment.fromDocument).toList();
      _log('$email enrollments=${enrollments.length} actives=${enrollments.where((e) => e.isActive).length}');
      if (role.isLearner) {
        expect(enrollments.every((e) => e.studentId == user.id), isTrue, reason: 'un apprenant ne lit que les siennes');
        final grades = await academic.getGrades(user.id);
        final assignments = await academic.getAssignments(user.id);
        _log('$email grades=${grades.length} assignments=${assignments.length}');
        // Un étudiant doit voir les cours de SA filière et de SON niveau.
        final mine = courses.where((c) => c.program == user.program && c.level == user.level);
        _log('$email cours de ma filière/niveau=${mine.length}');
      }
      if (library.isNotEmpty && (library.first.fileId ?? '').isNotEmpty) {
        final bytes = await academic.downloadLibraryFile(library.first.fileId!);
        _log('$email library download "${library.first.title}" bytes=${bytes.length}');
        expect(bytes, isNotEmpty);
      }
    }, timeout: longTimeout);
  }

  test('messagerie : envoi d\'un message et d\'une pièce jointe entre deux comptes', () async {
    final sender = accounts.keys.firstWhere((e) => e.startsWith('etudiant.ict4d.l1'), orElse: () => '');
    final receiver = accounts.keys.firstWhere((e) => e.startsWith('delegue.'), orElse: () => '');
    if (sender.isEmpty || receiver.isEmpty) {
      _log('comptes étudiant/délégué absents : envoi non vérifié');
      return;
    }
    await auth.login(receiver, accounts[receiver]!);
    final receiverUser = (await auth.getCurrentUser())!;
    final username = receiverUser.username ?? '';
    if (username.isEmpty) {
      _log('le délégué n\'a pas de pseudo : envoi non vérifié');
      return;
    }

    await auth.login(sender, accounts[sender]!);
    final me = (await auth.getCurrentUser())!;
    final contacts = await messaging.searchContacts(username);
    _log('search "$username" -> ${contacts.map((c) => c.username).toList()}');
    final conversation = await messaging.openByUsername(username);
    _log('open -> conversation=${conversation.id}');

    final stamp = DateTime.now().toIso8601String();
    final notified = await messaging.sendMessage(conversation.id, 'Sonde mobile $stamp');
    _log('send text -> notified=$notified messages=${messaging.lastUpdate?.messages.length}');

    final tmp = File('${Directory.systemTemp.path}/uniflow_sonde_${DateTime.now().millisecondsSinceEpoch}.txt');
    await tmp.writeAsString('pièce jointe de sonde $stamp');
    try {
      final fileId = await messaging.uploadAttachment(
        conversationId: conversation.id,
        myUserId: me.id,
        path: tmp.path,
        fileName: 'sonde.txt',
      );
      _log('upload -> fileId=$fileId');
      final notifiedFile = await messaging.sendMessage(conversation.id, '', fileId: fileId);
      _log('send file -> notified=$notifiedFile');
      final bytes = await messaging.downloadAttachment(fileId);
      _log('download -> bytes=${bytes.length}');
      expect(bytes, isNotEmpty);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync();
    }

    await messaging.markRead(conversation.id);
    final after = await messaging.getConversations();
    expect(after.any((c) => c.id == conversation.id), isTrue);
  }, timeout: longTimeout);

  /// Référentiel réel de la Faculté des Sciences (chargé le 2026-09-20) : le
  /// filtrage doit se faire côté serveur par filière + niveau, puis charger
  /// les séances par `courseId`. PHY L3 compte 40 séances avec plusieurs
  /// séances simultanées ; ENR L3 a des créneaux 07:30-10:30 / 11:00-14:00 /
  /// 14:30-17:30.
  test('emplois du temps réels : PHY L3 (40 séances, parallèles) et ENR L3 (créneaux)', () async {
    final email = accounts.keys.first;
    await auth.login(email, accounts[email]!);

    final phy = await academic.getCourses(program: 'PHY', level: 'L3');
    final phySlots = await academic.getSchedulesForCourses([for (final c in phy) c.id]);
    _log('PHY L3 -> cours=${phy.length} séances=${phySlots.length}');
    expect(phy, isNotEmpty);
    expect(phySlots.length, 40);
    final phyDays = groupByDay(phySlots);
    final parallel = phyDays.values.expand(groupByTimeSlot).where((b) => b.isParallel).toList();
    _log('PHY L3 -> jours=${phyDays.keys.toList()} blocs parallèles=${parallel.length} '
        'ex=${parallel.isEmpty ? '-' : '${parallel.first.start}-${parallel.first.end} × ${parallel.first.sessions.length}'}');
    expect(parallel, isNotEmpty, reason: 'PHY L3 a plusieurs séances par créneau');

    final enr = await academic.getCourses(program: 'ENR', level: 'L3');
    final enrSlots = await academic.getSchedulesForCourses([for (final c in enr) c.id]);
    final starts = enrSlots.map((s) => normalizeTime(s.startTime)).toSet();
    _log('ENR L3 -> cours=${enr.length} séances=${enrSlots.length} débuts=$starts');
    expect(enr, isNotEmpty);
    expect(starts, containsAll(['07:30', '11:00', '14:30']));

    final all = await academic.getCourses();
    _log('academic_courses total=${all.length} filières=${all.map((c) => c.program).toSet()}');
    expect(all.length, greaterThanOrEqualTo(290));
  }, timeout: longTimeout);

  test('Function inconnue : le routeur répond proprement', () async {
    final email = accounts.keys.first;
    await auth.login(email, accounts[email]!);
    final data = await service.callService('/service-inexistant', {'action': 'ping'});
    _log('service inconnu -> $data');
    expect(data['ok'], isFalse);
  }, timeout: longTimeout);

  tearDownAll(() async {
    try {
      await service.account.deleteSession(sessionId: 'current');
    } on AppwriteException catch (_) {}
  });
}
