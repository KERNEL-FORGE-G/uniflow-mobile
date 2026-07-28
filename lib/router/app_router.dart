import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import '../screens/students_list.dart';
import '../screens/student_detail.dart';
import '../screens/teachers_list.dart';
import '../screens/teacher_detail.dart';
import '../screens/ues_list.dart';
import '../screens/ue_detail.dart';
import '../screens/enrollments.dart';
import '../screens/presence.dart';
import '../screens/settings.dart';
import '../screens/auth_screens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/etudiants',
            builder: (_, __) => const StudentsListScreen(),
          ),
          GoRoute(
            path: '/etudiants/:id',
            builder: (_, s) => StudentDetailScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/enseignants',
            builder: (_, __) => const TeachersListScreen(),
          ),
          GoRoute(
            path: '/enseignants/:id',
            builder: (_, s) => TeacherDetailScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(path: '/ues', builder: (_, __) => const UEsListScreen()),
          GoRoute(
            path: '/ues/:id',
            builder: (_, s) => UEDetailScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/inscriptions',
            builder: (_, __) => const EnrollmentsScreen(),
          ),
          GoRoute(
            path: '/presence',
            builder: (_, __) => const PresenceScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, __) =>
        const Scaffold(body: Center(child: Text('Page introuvable'))),
  );
});
