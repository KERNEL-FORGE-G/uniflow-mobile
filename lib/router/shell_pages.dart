// Les pages de l'application connectée, et ce qu'elles occupent en bas de
// l'écran.
//
// Cette table est la source unique de deux choses qui doivent rester
// d'accord : les routes de la coquille (`app_router.dart` les génère d'ici) et
// l'ancrage du bouton d'Uni (`AppShell` le lit ici). Avant, le bouton était
// posé au même endroit sur toutes les pages, et il recouvrait le bouton
// « Nouvelle conversation » de la messagerie et le bouton d'envoi d'une
// conversation (constat du propriétaire, 2026-09-21). Une page qui pose un
// bouton flottant ou un composeur en bas de l'écran le **déclare** ici ; le
// test `uni_dock_test.dart` monte chaque page de la table, pour chaque rôle,
// et échoue si Uni recouvre une commande : une page ajoutée sans déclaration
// est attrapée avant d'atteindre un téléphone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_role.dart';
import '../providers/providers.dart';
import '../repositories/messaging_repository.dart';
import '../screens/about.dart';
import '../screens/access_denied.dart';
import '../screens/accounts.dart';
import '../screens/assignments.dart';
import '../screens/badges.dart';
import '../screens/conversation.dart';
import '../screens/dashboard.dart';
import '../screens/enrollments.dart';
import '../screens/forum.dart';
import '../screens/grades.dart';
import '../screens/library.dart';
import '../screens/messages.dart';
import '../screens/notifications.dart';
import '../screens/personal_space.dart';
import '../screens/presence.dart';
import '../screens/schedule.dart';
import '../screens/settings.dart';
import '../screens/student_detail.dart';
import '../screens/students_list.dart';
import '../screens/teacher_assignments.dart';
import '../screens/teacher_detail.dart';
import '../screens/teachers_list.dart';
import '../screens/teams.dart';
import '../screens/ue_detail.dart';
import '../screens/ues_list.dart';

/// Ce qu'une page pose au bord inférieur de l'écran, là où vit Uni.
enum BottomEdge {
  /// Rien : Uni garde son coin, en bas à droite.
  free,

  /// Un bouton flottant en bas à droite (`floatingActionButton`) : Uni se
  /// perche au-dessus, dans la même colonne.
  fab,

  /// Un composeur pleine largeur (champ de saisie et bouton d'envoi) : Uni
  /// s'efface, il n'y a plus de place pour lui sans cacher une commande.
  composer,
}

/// Paramètres d'une route, détachés de `GoRouterState` pour que la table
/// puisse être montée en test sans configuration de routeur.
class PageArgs {
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;
  final Object? extra;

  const PageArgs({
    this.pathParameters = const {},
    this.queryParameters = const {},
    this.extra,
  });

  factory PageArgs.of(GoRouterState state) => PageArgs(
        pathParameters: state.pathParameters,
        queryParameters: state.uri.queryParameters,
        extra: state.extra,
      );
}

/// Une page de la coquille : son adresse, son écran, et son bord inférieur
/// selon le rôle (la même adresse peut porter un bouton flottant pour un
/// enseignant et rien pour un étudiant, comme `/devoirs`).
class ShellPage {
  /// Motif d'adresse au format go_router (`/messages/:id`).
  final String path;

  final Widget Function(PageArgs args) builder;

  final BottomEdge Function(UniFlowRole role) _bottomEdge;

  /// Paramètres d'exemple pour monter la page hors routeur (tests).
  final PageArgs sampleArgs;

  const ShellPage({
    required this.path,
    required this.builder,
    BottomEdge Function(UniFlowRole role)? bottomEdge,
    this.sampleArgs = const PageArgs(),
  }) : _bottomEdge = bottomEdge ?? _alwaysFree;

  /// Page dont le bord inférieur est le même pour tous les rôles.
  const ShellPage.every({
    required this.path,
    required this.builder,
    required BottomEdge edge,
    this.sampleArgs = const PageArgs(),
  }) : _bottomEdge = edge == BottomEdge.fab
            ? _alwaysFab
            : edge == BottomEdge.composer
                ? _alwaysComposer
                : _alwaysFree;

  BottomEdge bottomEdgeFor(UniFlowRole role) => _bottomEdge(role);

  static BottomEdge _alwaysFree(UniFlowRole _) => BottomEdge.free;
  static BottomEdge _alwaysFab(UniFlowRole _) => BottomEdge.fab;
  static BottomEdge _alwaysComposer(UniFlowRole _) => BottomEdge.composer;

  /// Vrai si [location] (une adresse concrète, `/messages/abc`) répond à ce
  /// motif. Un segment `:nom` accepte n'importe quel segment non vide.
  bool matches(String location) {
    final pattern = path.split('/');
    final actual = _stripQuery(location).split('/');
    if (pattern.length != actual.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (pattern[i].startsWith(':')) {
        if (actual[i].isEmpty) return false;
      } else if (pattern[i] != actual[i]) {
        return false;
      }
    }
    return true;
  }

  /// L'adresse concrète d'exemple, [sampleArgs] injectés dans le motif.
  String get samplePath {
    final segments = path.split('/').map((s) => s.startsWith(':') ? sampleArgs.pathParameters[s.substring(1)] ?? s : s);
    return segments.join('/');
  }

  static String _stripQuery(String location) {
    final q = location.indexOf('?');
    return q == -1 ? location : location.substring(0, q);
  }
}

/// Toutes les pages de la coquille, dans l'ordre des routes.
final List<ShellPage> shellPages = [
  ShellPage(path: '/accueil', builder: (_) => const DashboardScreen()),
  ShellPage(path: '/badges', builder: (_) => const BadgesScreen()),
  ShellPage(path: '/etudiants', builder: (_) => const StudentsListScreen()),
  ShellPage(
    path: '/etudiants/:id',
    builder: (a) => StudentDetailScreen(id: a.pathParameters['id']!),
    sampleArgs: const PageArgs(pathParameters: {'id': 's1'}),
  ),
  ShellPage(path: '/enseignants', builder: (_) => const TeachersListScreen()),
  ShellPage(
    path: '/enseignants/:id',
    builder: (a) => TeacherDetailScreen(id: a.pathParameters['id']!),
    sampleArgs: const PageArgs(pathParameters: {'id': 't1'}),
  ),
  ShellPage(path: '/ues', builder: (_) => const UEsListScreen()),
  ShellPage(
    path: '/ues/:id',
    builder: (a) => UEDetailScreen(id: a.pathParameters['id']!),
    sampleArgs: const PageArgs(pathParameters: {'id': 'ue1'}),
  ),
  ShellPage(path: '/inscriptions', builder: (_) => const EnrollmentsScreen()),
  ShellPage(path: '/presence', builder: (_) => const PresenceScreen()),
  ShellPage(path: '/emploi-du-temps', builder: (_) => const ScheduleScreen()),
  // L'administration crée des comptes depuis un bouton flottant.
  ShellPage.every(path: '/comptes', builder: (_) => const AccountsScreen(), edge: BottomEdge.fab),
  // Les notes personnelles s'ajoutent depuis un bouton flottant ; les notes
  // universitaires se consultent seulement.
  ShellPage(
    path: '/notes',
    builder: (_) => const GradesScreen(),
    bottomEdge: (role) => role == UniFlowRole.personal ? BottomEdge.fab : BottomEdge.free,
  ),
  // Même adresse, deux métiers : l'apprenant rend, l'enseignant publie (depuis
  // un bouton flottant).
  ShellPage(
    path: '/devoirs',
    builder: (_) => Consumer(
      builder: (_, ref, __) =>
          ref.watch(currentRoleProvider).isStaff ? const TeacherAssignmentsScreen() : const AssignmentsScreen(),
    ),
    bottomEdge: (role) => role.isStaff ? BottomEdge.fab : BottomEdge.free,
  ),
  ShellPage(path: '/bibliotheque', builder: (_) => const LibraryScreen()),
  ShellPage.every(path: '/forum', builder: (_) => const ForumScreen(), edge: BottomEdge.fab),
  ShellPage(path: '/notifications', builder: (_) => const NotificationsScreen()),
  ShellPage.every(path: '/messages', builder: (_) => const MessagesScreen(), edge: BottomEdge.fab),
  // La conversation est transmise par la liste via `extra`, ce qui permet de
  // peindre le fil sans attendre le réseau. Un accès direct à l'URL (sans
  // `extra`) reste valide : l'écran recharge alors par identifiant.
  ShellPage.every(
    path: '/messages/:id',
    builder: (a) => ConversationScreen(
      conversationId: a.pathParameters['id']!,
      initial: a.extra is Conversation ? a.extra as Conversation : null,
    ),
    edge: BottomEdge.composer,
    sampleArgs: const PageArgs(pathParameters: {'id': 'c1'}),
  ),
  // Espace personnel (comptes indépendants uniquement, voir navDestinations) :
  // chaque page ajoute depuis un bouton flottant.
  ShellPage.every(path: '/matieres', builder: (_) => const PersonalSubjectsScreen(), edge: BottomEdge.fab),
  ShellPage.every(path: '/taches', builder: (_) => const PersonalTasksScreen(), edge: BottomEdge.fab),
  ShellPage.every(path: '/agenda', builder: (_) => const PersonalAgendaScreen(), edge: BottomEdge.fab),
  ShellPage(path: '/equipe', builder: (_) => const TeamsScreen()),
  ShellPage(path: '/settings', builder: (_) => const SettingsScreen()),
  ShellPage(path: '/a-propos', builder: (_) => const AboutScreen()),
  // Hors de la barre du bas : cette page ne s'atteint qu'en se faisant
  // rediriger, et elle doit rester dans la coquille pour que l'utilisateur
  // puisse repartir d'un onglet.
  ShellPage(
    path: '/acces-refuse',
    builder: (a) => AccessDeniedScreen(depuis: a.queryParameters['depuis']),
  ),
];

/// La page de la table qui répond à [location], ou `null` hors table.
ShellPage? shellPageFor(String location) {
  for (final page in shellPages) {
    if (page.matches(location)) return page;
  }
  return null;
}

/// Le bord inférieur de la page affichée à [location] pour [role] ; une
/// adresse hors table est traitée comme libre.
BottomEdge bottomEdgeAt(String location, UniFlowRole role) =>
    shellPageFor(location)?.bottomEdgeFor(role) ?? BottomEdge.free;
