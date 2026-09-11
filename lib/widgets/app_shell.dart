import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home, label: 'Accueil', path: '/accueil'),
    (icon: Icons.book_outlined, active: Icons.book, label: 'Études', path: '/ues'),
    (icon: Icons.chat_bubble_outline, active: Icons.chat_bubble, label: 'Messages', path: '/messages'),
    (icon: Icons.qr_code_scanner, active: Icons.qr_code_scanner, label: 'Présence', path: '/presence'),
    (icon: Icons.settings_outlined, active: Icons.settings, label: 'Réglages', path: '/settings'),
  ];

  int get _currentIndex {
    final i = _tabs.indexWhere((t) => location.startsWith(t.path));
    return i == -1 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.teal,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i];
                final selected = i == _currentIndex;
                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(t.path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(selected ? t.active : t.icon,
                            color: selected ? Colors.white : Colors.white70, size: 22),
                        const SizedBox(height: 4),
                        Text(t.label,
                            style: TextStyle(
                                fontSize: 10,
                                color: selected ? Colors.white : Colors.white70,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
