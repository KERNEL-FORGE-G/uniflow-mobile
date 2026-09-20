import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../providers/providers.dart';
import '../models/user_role.dart';
import '../widgets/app_shell.dart';
import '../screens/access_denied.dart';
import '../screens/login.dart';
import '../screens/register.dart';
import '../screens/forgot_password.dart';
import '../repositories/auth_repository.dart';
import '../screens/dashboard.dart';
import '../screens/students_list.dart';
import '../screens/student_detail.dart';
import '../screens/teachers_list.dart';
import '../screens/teacher_detail.dart';
import '../screens/ues_list.dart';
import '../screens/ue_detail.dart';
import '../screens/enrollments.dart';
import '../screens/presence.dart';
import '../screens/settings.dart';
import '../screens/grades.dart';
import '../screens/assignments.dart';
import '../screens/teacher_assignments.dart';
import '../screens/library.dart';
import '../screens/forum.dart';
import '../screens/messages.dart';
import '../screens/notifications.dart';
import '../screens/conversation.dart';
import '../repositories/messaging_repository.dart';
import '../screens/teams.dart';
import '../screens/personal_space.dart';
import '../screens/schedule.dart';
import '../screens/accounts.dart';

/// Adresses accessibles sans session. Une fois connecté, elles ramènent à
/// l'accueil : revenir sur l'inscription avec une session ouverte ferait
/// échouer `account.create`.
const Set<String> publicPaths = {'/login', '/register', '/mot-de-passe-oublie'};

final appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter ne suit pas nativement les providers Riverpod : ce notifier lui
  // sert de signal pour réévaluer le redirect quand la session change.
  final sessionChanged = ValueNotifier<int>(0);
  ref.listen(authStatusProvider, (_, __) => sessionChanged.value++);
  // Le rôle change sans que l'état d'authentification bouge — un administrateur
  // qui corrige le rôle d'un compte pendant que celui-ci est ouvert. Sans cette
  // écoute, le routeur garderait la décision prise au démarrage.
  ref.listen(currentUserProvider, (_, __) => sessionChanged.value++);
  ref.onDispose(sessionChanged.dispose);

  return GoRouter(
    initialLocation: '/accueil',
    refreshListenable: sessionChanged,
    // Tant que la session n'est pas résolue ou qu'aucun compte n'est connecté,
    // tout ramène à /login ; une fois connecté, /login renvoie vers l'accueil.
    //
    // La seconde règle est celle des rôles : une adresse que le rôle n'a pas le
    // droit d'atteindre ramène à l'accueil, avec un message. Masquer un onglet
    // ne suffit pas — l'adresse reste tapable, et un écran d'administration
    // atteignable par URL n'est pas restreint du tout.
    redirect: (context, state) {
      final signedIn = ref.read(authStatusProvider) == AuthStatus.signedIn;
      final atPublic = publicPaths.contains(state.matchedLocation);
      if (!signedIn) return atPublic ? null : '/login';
      if (atPublic) return '/accueil';

      final role = ref.read(currentRoleProvider);
      if (!canAccessPath(role, state.matchedLocation)) {
        return '/acces-refuse?depuis=${Uri.encodeComponent(state.matchedLocation)}';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, s) => RegisterScreen(
          initialType: UniFlowAccountType.tryParse(s.uri.queryParameters['type']) ?? UniFlowAccountType.university,
        ),
      ),
      GoRoute(path: '/mot-de-passe-oublie', builder: (_, __) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/accueil', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/etudiants', builder: (_, __) => const StudentsListScreen()),
          GoRoute(path: '/etudiants/:id', builder: (_, s) => StudentDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/enseignants', builder: (_, __) => const TeachersListScreen()),
          GoRoute(path: '/enseignants/:id', builder: (_, s) => TeacherDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/ues', builder: (_, __) => const UEsListScreen()),
          GoRoute(path: '/ues/:id', builder: (_, s) => UEDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/inscriptions', builder: (_, __) => const EnrollmentsScreen()),
          GoRoute(path: '/presence', builder: (_, __) => const PresenceScreen()),
          GoRoute(path: '/emploi-du-temps', builder: (_, __) => const ScheduleScreen()),
          GoRoute(path: '/comptes', builder: (_, __) => const AccountsScreen()),
          GoRoute(path: '/notes', builder: (_, __) => const GradesScreen()),
          GoRoute(
            path: '/devoirs',
            // Même adresse, deux métiers : l'apprenant rend, l'enseignant publie.
            builder: (_, __) => Consumer(
              builder: (_, ref, __) =>
                  ref.watch(currentRoleProvider).isStaff ? const TeacherAssignmentsScreen() : const AssignmentsScreen(),
            ),
          ),
          GoRoute(path: '/bibliotheque', builder: (_, __) => const LibraryScreen()),
          GoRoute(path: '/forum', builder: (_, __) => const ForumScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
          // La conversation est transmise par la liste via `extra`, ce qui
          // permet de peindre le fil sans attendre le réseau. Un accès direct
          // à l'URL (sans `extra`) reste valide : l'écran recharge alors par
          // identifiant.
          GoRoute(
            path: '/messages/:id',
            builder: (_, s) => ConversationScreen(
              conversationId: s.pathParameters['id']!,
              initial: s.extra is Conversation ? s.extra as Conversation : null,
            ),
          ),
          // Espace personnel (comptes indépendants uniquement, voir navDestinations).
          GoRoute(path: '/matieres', builder: (_, __) => const PersonalSubjectsScreen()),
          GoRoute(path: '/taches', builder: (_, __) => const PersonalTasksScreen()),
          GoRoute(path: '/agenda', builder: (_, __) => const PersonalAgendaScreen()),
          GoRoute(path: '/equipe', builder: (_, __) => const TeamsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          // Hors de la barre du bas : cette page ne s'atteint qu'en se faisant
          // rediriger, et elle doit rester dans la coquille pour que
          // l'utilisateur puisse repartir d'un onglet.
          GoRoute(
            path: '/acces-refuse',
            builder: (_, s) => AccessDeniedScreen(
              depuis: s.uri.queryParameters['depuis'],
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('Page introuvable'))),
  );
});
