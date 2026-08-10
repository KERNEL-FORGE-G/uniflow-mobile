import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../widgets/role_based_shell.dart';
import '../screens/auth_screens.dart';
import '../screens/student_screens.dart';
import '../screens/delegate_screens.dart';
import '../screens/teacher_screens.dart';
import '../screens/admin_screens.dart';
import '../screens/shared_screens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash', // Start with splash screen
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // STUDENT ROLE
      ShellRoute(
        builder: (context, state, child) => RoleBasedShell(location: state.uri.path, role: UserRole.student, child: child),
        routes: [
          GoRoute(path: '/student/dashboard', builder: (_, __) => const StudentDashboardScreen()),
          GoRoute(path: '/student/edt', builder: (_, __) => const StudentEdtScreen()),
          GoRoute(path: '/student/courses', builder: (_, __) => const StudentCoursesScreen()),
        ],
      ),

      // DELEGATE ROLE
      ShellRoute(
        builder: (context, state, child) => RoleBasedShell(location: state.uri.path, role: UserRole.delegate, child: child),
        routes: [
          GoRoute(path: '/delegate/dashboard', builder: (_, __) => const DelegateDashboardScreen()),
          GoRoute(path: '/delegate/class', builder: (_, __) => const DelegateClassScreen()),
          GoRoute(path: '/delegate/docs', builder: (_, __) => const DelegateDocsScreen()),
        ],
      ),

      // TEACHER ROLE
      ShellRoute(
        builder: (context, state, child) => RoleBasedShell(location: state.uri.path, role: UserRole.teacher, child: child),
        routes: [
          GoRoute(path: '/teacher/dashboard', builder: (_, __) => const TeacherDashboardScreen()),
          GoRoute(path: '/teacher/courses', builder: (_, __) => const TeacherCoursesScreen()),
          GoRoute(path: '/teacher/edt', builder: (_, __) => const TeacherEdtScreen()),
        ],
      ),

      // ADMIN ROLE
      ShellRoute(
        builder: (context, state, child) => RoleBasedShell(location: state.uri.path, role: UserRole.admin, child: child),
        routes: [
          GoRoute(path: '/admin/dashboard', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
          GoRoute(path: '/admin/academic', builder: (_, __) => const AdminAcademicScreen()),
          GoRoute(path: '/admin/reports', builder: (_, __) => const AdminReportsScreen()),
        ],
      ),

      // SHARED SCREENS (Accessible from any role via path prefix)
      GoRoute(path: '/shared/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/shared/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/shared/messages', builder: (_, __) => const MessagesScreen()),
      GoRoute(path: '/shared/settings', builder: (_, __) => const SettingsScreen()),
    ],
    errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('Page introuvable'))),
  );
});

