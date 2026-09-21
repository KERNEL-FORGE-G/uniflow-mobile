// Fixtures et harnais partagés par les tests de mise en page.
//
// `layout_test.dart` balaie tous les écrans ; les tests ciblés (diagnostic d'un
// débordement précis) réutilisent le même `host`, avec les mêmes providers
// neutralisés, pour que les deux mesurent exactement la même chose.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/models/models.dart';
import 'package:uniflow_mobile/models/team_member.dart';
import 'package:uniflow_mobile/offline/local_database.dart';
import 'package:uniflow_mobile/offline/offline_providers.dart';
import 'package:uniflow_mobile/offline/sync_engine.dart';
import 'package:uniflow_mobile/providers/providers.dart';
import 'package:uniflow_mobile/repositories/messaging_repository.dart';
import 'package:uniflow_mobile/repositories/reference_repository.dart';
import 'package:uniflow_mobile/repositories/personal_repository.dart';
import 'package:uniflow_mobile/repositories/team_repository.dart';
import 'package:uniflow_mobile/services/notification_service.dart';
import 'package:uniflow_mobile/theme/app_theme.dart';
// Ces trois providers sont déclarés dans les écrans eux-mêmes, pas dans
// `providers.dart` : il faut importer les écrans pour les référencer.
import 'package:uniflow_mobile/screens/assignments.dart';
import 'package:uniflow_mobile/screens/grades.dart';
import 'package:uniflow_mobile/screens/library.dart';
import 'package:uniflow_mobile/models/assignment_models.dart';
import 'package:uniflow_mobile/models/badges.dart';
import 'package:uniflow_mobile/providers/badges_provider.dart';
import 'package:uniflow_mobile/screens/teacher_assignments.dart';

UniFlowUser user() => UniFlowUser(
      id: 'u1',
      email: 'ravel@uniflow.edu',
      name: 'NGHOMSI RAVEL',
      accountType: 'UNIVERSITY',
      role: 'ADMIN',
      username: 'ravel',
    );

const student = Student(
  id: 's1',
  matricule: '20A1234',
  firstName: 'Aliyatou',
  lastName: 'Rachid',
  filiere: 'Informatique',
  niveau: 'Licence 3',
  status: 'ACTIVE',
  university: 'Université de Yaoundé I',
);

const teacher = Teacher(
  id: 't1',
  firstName: 'Meli',
  lastName: 'William',
  status: 'ACTIVE',
  department: 'Génie logiciel',
);

const ue = UE(
  id: 'ue1',
  code: 'INF301',
  title: 'Architecture logicielle avancée',
  credits: 6,
  hours: 60,
  description: 'Conception et évaluation des architectures logicielles.',
  teacherId: 't1',
  teacherName: 'Dr Meli William',
  program: 'Informatique',
  level: 'L3',
  classroom: 'Amphi 700',
  colorHex: '#1E3A8A',
);

Enrollment enrollment() => Enrollment(
      id: 'e1',
      studentId: 's1',
      ueId: 'ue1',
      status: 'PENDING',
      date: DateTime(2026, 9, 1),
    );

/// Équipe de test, avec les cas qui cassent une mise en page : un nom très
/// long, un membre sans photo, un membre sans pastille ni pseudo GitHub, et un
/// membre de chaque équipe pour que les quatre tuiles de statistiques et les
/// filtres aient tous quelque chose à afficher.
List<TeamMember> equipeDeTest() => [
      TeamMember(
        id: 'ravel',
        slug: 'ravel',
        name: 'NGHOMSI FEUKOUO RAVEL',
        github: 'Archlord12345',
        email: 'ravelnghomsi@gmail.com',
        team: 'Leadership',
        subTeam: 'Architecture & Direction',
        role: 'Chef de projet & Architecte',
        badge: 'Lead Architect',
        accent: 'blue',
        avatarFileId: '',
        displayOrder: 0,
      ),
      TeamMember(
        id: 'aliya',
        slug: 'aliya',
        name: 'Aliyatou Rachid Oumou Tourab',
        github: 'aliya-nadi',
        email: 'oumou.aliyatou@facsciences-uy1.cm',
        team: 'Frontend',
        subTeam: 'Frontend Desktop & Web',
        role: 'Frontend Developer',
        badge: 'Web Desktop',
        accent: 'purple',
        avatarFileId: '',
        displayOrder: 1,
      ),
      TeamMember(
        id: 'sans-rien',
        slug: 'sans-rien',
        name: 'Membre Sans Photo Ni Pseudo',
        github: '',
        email: '',
        team: 'Backend',
        subTeam: '',
        role: 'Backend Developer',
        badge: '',
        accent: 'inconnue',
        avatarFileId: '',
        displayOrder: 2,
      ),
    ];

/// Référentiel académique de test pour le formulaire d'inscription : deux
/// universités, une faculté, une filière à trois niveaux. Les libellés sont
/// longs à dessein, pour que les listes déroulantes prouvent qu'elles
/// tronquent au lieu de déborder.
const universiteDeTest =
    University(code: 'UT1', name: 'Université de Test Numéro Un', shortName: 'UT1', city: 'Yaoundé');
const autreUniversite = University(code: 'UT2', name: 'Université de Test Deux', shortName: 'UT2');
const faculteDeTest =
    Faculty(universityCode: 'UT1', code: 'FS', name: 'Faculté des Sciences et Technologies Appliquées');
const filiereDeTest = AcademicProgram(
  universityCode: 'UT1',
  facultyCode: 'FS',
  code: 'TEST',
  name: 'Filière de Test aux Technologies de l\'Information',
  levels: ['L1', 'L2', 'L3'],
);

/// Les douze filières de la Faculté des Sciences telles qu'en base
/// (2026-09-20), avec leurs niveaux réels (M1 pour certaines) : le formulaire
/// doit toutes les proposer et n'offrir que les niveaux de la filière choisie.
const List<AcademicProgram> douzeFilieres = [
  AcademicProgram(
      universityCode: 'UT1', facultyCode: 'FS', code: 'MAT', name: 'Mathématiques', levels: ['L1', 'L2', 'L3', 'M1']),
  AcademicProgram(
      universityCode: 'UT1', facultyCode: 'FS', code: 'PHY', name: 'Physique', levels: ['L1', 'L2', 'L3', 'M1']),
  AcademicProgram(universityCode: 'UT1', facultyCode: 'FS', code: 'CHM', name: 'Chimie', levels: ['L1', 'L2', 'L3']),
  AcademicProgram(
      universityCode: 'UT1', facultyCode: 'FS', code: 'INF', name: 'Informatique', levels: ['L1', 'L2', 'L3', 'M1']),
  AcademicProgram(
      universityCode: 'UT1', facultyCode: 'FS', code: 'GEO', name: 'Sciences de la Terre', levels: ['L1', 'L2', 'L3']),
  AcademicProgram(
      universityCode: 'UT1', facultyCode: 'FS', code: 'BIOS', name: 'Biosciences', levels: ['L1', 'L2', 'L3']),
  AcademicProgram(
      universityCode: 'UT1', facultyCode: 'FS', code: 'MIB', name: 'Microbiologie', levels: ['L1', 'L2', 'L3']),
  AcademicProgram(
      universityCode: 'UT1',
      facultyCode: 'FS',
      code: 'BOA',
      name: 'Biologie des Organismes Animaux',
      levels: ['L1', 'L2', 'L3']),
  AcademicProgram(
      universityCode: 'UT1',
      facultyCode: 'FS',
      code: 'BOV',
      name: 'Biologie des Organismes Végétaux',
      levels: ['L1', 'L2', 'L3']),
  AcademicProgram(universityCode: 'UT1', facultyCode: 'FS', code: 'BCH', name: 'Biochimie', levels: ['L1', 'L2', 'L3']),
  AcademicProgram(
      universityCode: 'UT1',
      facultyCode: 'FS',
      code: 'ENR',
      name: 'Énergies Renouvelables',
      levels: ['L1', 'L2', 'L3']),
  AcademicProgram(
      universityCode: 'UT1',
      facultyCode: 'FS',
      code: 'ICT4D',
      name: 'TIC pour le Développement',
      levels: ['L1', 'L2', 'L3']),
];

List<PersonalSubject> matieresDeTest() => [
      PersonalSubject(
          id: 'm1',
          ownerId: 'u1',
          name: 'Analyse numérique et méthodes de résolution approchée',
          code: 'MAT204',
          instructor: 'Pr. Très Long Nom De Famille',
          credits: 6,
          colorHex: '#7c3aed'),
      PersonalSubject(id: 'm2', ownerId: 'u1', name: 'Anglais'),
    ];

List<PersonalTask> tachesDeTest() => [
      PersonalTask(
          id: 't1',
          ownerId: 'u1',
          title: 'Rendre le TP de programmation orientée objet avant la fin de la semaine',
          courseId: 'm1',
          dueDate: '2026-09-21T23:59:00.000Z',
          priority: 4),
      PersonalTask(id: 't2', ownerId: 'u1', title: 'Lire le chapitre 3', status: 'DONE', priority: 1),
    ];

List<PersonalSchedule> creneauxDeTest() => [
      const PersonalSchedule(
          id: 'c1',
          ownerId: 'u1',
          courseId: 'm1',
          dayOfWeek: 'LUNDI',
          startTime: '08:00',
          endTime: '10:00',
          classroom: 'Amphi 1000 — bâtiment principal',
          type: 'CM'),
      const PersonalSchedule(
          id: 'c2', ownerId: 'u1', courseId: 'm2', dayOfWeek: 'MERCREDI', startTime: '14:00', endTime: '16:00'),
    ];

List<PersonalGrade> notesPersonnellesDeTest() => [
      const PersonalGrade(
          id: 'g1',
          ownerId: 'u1',
          courseId: 'm1',
          evaluationTitle: 'Contrôle continu numéro un de la session',
          score: 14.5,
          maxScore: 20,
          coefficient: 2),
      const PersonalGrade(
          id: 'g2', ownerId: 'u1', courseId: '', evaluationTitle: '', score: 7, maxScore: 10, coefficient: 1),
    ];

List<AcademicCourse> coursDeTest() => [
      AcademicCourse(
          id: 'k1',
          code: 'INF211',
          name: 'Programmation orientée objet et conception de logiciels',
          university: 'UT',
          program: 'TEST',
          level: 'L2',
          teacherName: 'Pr. Nom Très Long Pour Déborder',
          type: 'CM'),
    ];

List<AcademicSchedule> emploiDuTempsDeTest() => [
      for (final day in ['LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI', 'DIMANCHE'])
        AcademicSchedule(
            id: day,
            courseId: 'k1',
            courseCode: 'INF211',
            dayOfWeek: day,
            startTime: '08:00',
            endTime: '10:00',
            classroom: 'Amphi 1000 — bâtiment principal',
            type: 'CM'),
    ];

/// Enveloppe un écran dans son `ProviderScope` et son `MaterialApp`, avec les
/// providers réseau neutralisés : un test de mise en page ne doit dépendre
/// d'aucun accès à Appwrite.
Widget host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user()),
      studentsProvider.overrideWith((ref) => const [student]),
      teachersProvider.overrideWith((ref) => const [teacher]),
      uesProvider.overrideWith((ref) => const [ue]),
      enrollmentsProvider.overrideWith((ref) => [enrollment()]),
      academicSyncProvider.overrideWith((ref) async {}),
      gradesListProvider.overrideWith((ref) => Stream.value(<AcademicGrade>[])),
      assignmentBoardProvider.overrideWith(
        (ref) async => const AssignmentBoard(assignments: [], submissions: {}),
      ),
      libraryListProvider.overrideWith((ref) async => <AcademicLibraryEntry>[]),
      // La page Équipe lit la collection `team_members` : sans cette
      // neutralisation, le test de mise en page lancerait un appel réseau.
      teamMembersProvider.overrideWith((ref) async => equipeDeTest()),
      // La messagerie et les notifications interrogent la Function Appwrite :
      // sans ces neutralisations, l'écran de messagerie lancerait un appel
      // réseau pendant un test de mise en page.
      conversationsProvider.overrideWith((ref) => Stream.value(const <Conversation>[])),
      notificationsProvider.overrideWith((ref) => Stream.value(const <AppNotification>[])),
      urgentNotificationsProvider.overrideWith((ref) => Stream.value(0)),
      // L'état de synchronisation lit la base locale et le service Appwrite :
      // ni l'un ni l'autre n'existent dans un test de mise en page.
      syncStateProvider.overrideWith((ref) => Stream.value(const SyncState())),
      localDatabaseProvider.overrideWith((ref) {
        final db = LocalDatabase.memory();
        ref.onDispose(db.close);
        return db;
      }),
      // Espace personnel et emploi du temps : quelques documents pour que les
      // cartes aient du contenu à faire tenir.
      personalSubjectsProvider.overrideWith((ref) async => matieresDeTest()),
      personalTasksProvider.overrideWith((ref) async => tachesDeTest()),
      personalSchedulesProvider.overrideWith((ref) async => creneauxDeTest()),
      personalGradesProvider.overrideWith((ref) async => notesPersonnellesDeTest()),
      scopedCoursesProvider.overrideWith((ref) => Stream.value(coursDeTest())),
      scopedSchedulesProvider.overrideWith((ref) => Stream.value(emploiDuTempsDeTest())),
      scopedEnrollmentsProvider.overrideWith((ref) => Stream.value([enrollment()])),
      universitiesProvider.overrideWith((ref) async => const [universiteDeTest, autreUniversite]),
      facultiesProvider.overrideWith((ref, code) async => code == 'UT1' ? const [faculteDeTest] : const []),
      programsProvider
          .overrideWith((ref, key) async => key.startsWith('UT1') ? const [filiereDeTest, ...douzeFilieres] : const []),
      selectableProgramsProvider.overrideWith((ref) async => douzeFilieres),
      // Badges et accueil enseignant : présences, sujets du forum et devoirs
      // publiés viennent d'Appwrite ; ici, des listes vides suffisent.
      myAttendanceProvider.overrideWith((ref) => Stream.value(const <AttendanceMark>[])),
      myForumPostCountProvider.overrideWith((ref) => Stream.value(0)),
      teacherAssignmentsProvider.overrideWith((ref) async => const <Assignment>[]),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      // Uni boucle sans fin sur les écrans hors session et les états vides ;
      // `pumpAndSettle` ne se poserait jamais. La mascotte respecte la
      // préférence « moins de mouvement » : on la déclare pour tous les tests.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
}
