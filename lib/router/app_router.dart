import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../providers/providers.dart';
import '../widgets/app_shell.dart';
import '../screens/login.dart';
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
import '../screens/library.dart';
import '../screens/forum.dart';
import '../screens/messages.dart';
import '../screens/conversation.dart';
import '../repositories/messaging_repository.dart';
import '../screens/sentinelle.dart';
import '../screens/teams.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter ne suit pas nativement les providers Riverpod : ce notifier lui
  // sert de signal pour réévaluer le redirect quand la session change.
  final sessionChanged = ValueNotifier<int>(0);
  ref.listen(authStatusProvider, (_, __) => sessionChanged.value++);
  ref.onDispose(sessionChanged.dispose);

  return GoRouter(
    initialLocation: '/accueil',
    refreshListenable: sessionChanged,
    // Tant que la session n'est pas résolue ou qu'aucun compte n'est connecté,
    // tout ramène à /login ; une fois connecté, /login renvoie vers l'accueil.
    redirect: (context, state) {
      final signedIn = ref.read(authStatusProvider) == AuthStatus.signedIn;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn) return atLogin ? null : '/login';
      return atLogin ? '/accueil' : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
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
          GoRoute(path: '/notes', builder: (_, __) => const GradesScreen()),
          GoRoute(path: '/devoirs', builder: (_, __) => const AssignmentsScreen()),
          GoRoute(path: '/bibliotheque', builder: (_, __) => const LibraryScreen()),
          GoRoute(path: '/forum', builder: (_, __) => const ForumScreen()),
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
          GoRoute(path: '/sentinelle', builder: (_, __) => const SentinelleScreen()),
          GoRoute(path: '/equipe', builder: (_, __) => const TeamsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
    errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('Page introuvable'))),
  );
});
