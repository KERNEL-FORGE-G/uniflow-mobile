import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum UserRole { student, delegate, teacher, admin }

class RoleBasedShell extends StatelessWidget {
  final Widget child;
  final String location;
  final UserRole role;

  const RoleBasedShell({
    super.key,
    required this.child,
    required this.location,
    required this.role,
  });

  List<({IconData icon, IconData active, String label, String path})> get _tabs {
    switch (role) {
      case UserRole.student:
        return [
          (icon: Icons.home_outlined, active: Icons.home, label: 'Accueil', path: '/student/dashboard'),
          (icon: Icons.calendar_today_outlined, active: Icons.calendar_today, label: 'Emploi du temps', path: '/student/edt'),
          (icon: Icons.book_outlined, active: Icons.book, label: 'Cours', path: '/student/courses'),
          (icon: Icons.notifications_none, active: Icons.notifications, label: 'Notifications', path: '/shared/notifications'),
          (icon: Icons.person_outline, active: Icons.person, label: 'Profil', path: '/shared/profile'),
        ];
      case UserRole.delegate:
        return [
          (icon: Icons.home_outlined, active: Icons.home, label: 'Accueil', path: '/delegate/dashboard'),
          (icon: Icons.group_outlined, active: Icons.group, label: 'Classe', path: '/delegate/class'),
          (icon: Icons.chat_bubble_outline, active: Icons.chat_bubble, label: 'Communications', path: '/shared/messages'),
          (icon: Icons.folder_outlined, active: Icons.folder, label: 'Documents', path: '/delegate/docs'),
          (icon: Icons.person_outline, active: Icons.person, label: 'Profil', path: '/shared/profile'),
        ];
      case UserRole.teacher:
        return [
          (icon: Icons.home_outlined, active: Icons.home, label: 'Accueil', path: '/teacher/dashboard'),
          (icon: Icons.class_outlined, active: Icons.class_, label: 'Mes cours', path: '/teacher/courses'),
          (icon: Icons.calendar_month_outlined, active: Icons.calendar_month, label: 'Calendrier', path: '/teacher/edt'),
          (icon: Icons.message_outlined, active: Icons.message, label: 'Messages', path: '/shared/messages'),
          (icon: Icons.person_outline, active: Icons.person, label: 'Profil', path: '/shared/profile'),
        ];
      case UserRole.admin:
        return [
          (icon: Icons.dashboard_outlined, active: Icons.dashboard, label: 'Tableau de bord', path: '/admin/dashboard'),
          (icon: Icons.people_outline, active: Icons.people, label: 'Utilisateurs', path: '/admin/users'),
          (icon: Icons.school_outlined, active: Icons.school, label: 'Académique', path: '/admin/academic'),
          (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Rapports', path: '/admin/reports'),
          (icon: Icons.settings_outlined, active: Icons.settings, label: 'Paramètres', path: '/shared/settings'),
        ];
    }
  }

  int get _currentIndex {
    final tabs = _tabs;
    final i = tabs.indexWhere((t) => location.startsWith(t.path.split('/').take(3).join('/')));
    return i == -1 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => context.go(tabs[i].path),
        items: tabs.map((t) {
          final isSelected = tabs.indexOf(t) == _currentIndex;
          return BottomNavigationBarItem(
            icon: Icon(isSelected ? t.active : t.icon),
            label: t.label,
          );
        }).toList(),
      ),
    );
  }
}

