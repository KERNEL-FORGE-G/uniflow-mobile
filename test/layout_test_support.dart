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
import 'package:uniflow_mobile/providers/providers.dart';
import 'package:uniflow_mobile/repositories/messaging_repository.dart';
import 'package:uniflow_mobile/repositories/team_repository.dart';
import 'package:uniflow_mobile/services/notification_service.dart';
import 'package:uniflow_mobile/theme/app_theme.dart';
// Ces trois providers sont déclarés dans les écrans eux-mêmes, pas dans
// `providers.dart` : il faut importer les écrans pour les référencer.
import 'package:uniflow_mobile/screens/assignments.dart';
import 'package:uniflow_mobile/screens/grades.dart';
import 'package:uniflow_mobile/screens/library.dart';

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
  status: 'Actif',
  email: 'aliyatou@uniflow.edu',
  phone: '+237 600 000 000',
  ueIds: ['ue1'],
);

const teacher = Teacher(
  id: 't1',
  firstName: 'Meli',
  lastName: 'William',
  status: 'Permanent',
  email: 'william@uniflow.edu',
  department: 'Génie logiciel',
  ueIds: ['ue1'],
);

const ue = UE(
  id: 'ue1',
  code: 'INF301',
  title: 'Architecture logicielle avancée',
  credits: 6,
  cm: 30,
  td: 20,
  tp: 10,
  description: 'Conception et évaluation des architectures logicielles.',
  colorHex: '#1E3A8A',
);

Enrollment enrollment() => Enrollment(
      id: 'e1',
      studentId: 's1',
      ueId: 'ue1',
      status: 'En attente',
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
      gatewaySyncProvider.overrideWith((ref) async {}),
      gradesListProvider.overrideWith((ref) async => <AcademicGrade>[]),
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
      conversationsProvider.overrideWith((ref) async => const <Conversation>[]),
      notificationsProvider.overrideWith((ref) async => const <AppNotification>[]),
      urgentNotificationsProvider.overrideWith((ref) => Stream.value(0)),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}
