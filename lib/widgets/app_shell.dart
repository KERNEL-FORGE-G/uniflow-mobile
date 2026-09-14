import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Coquille de l'application connectée : elle porte la barre de navigation du
/// bas, commune à tous les onglets.
///
/// La barre était teal plein. Elle est désormais blanche, comme la surface des
/// pages du web, avec l'onglet actif en bleu de marque sur une pastille
/// `primary-50` : c'est le même vocabulaire que la sidebar du desktop, où
/// l'élément actif est le seul à porter la couleur d'accent.
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
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: AppColors.inputBorder)),
          boxShadow: [
            BoxShadow(
              color: Color(0x141E3A8A),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i];
                return Expanded(
                  child: _NavTab(
                    icon: t.icon,
                    activeIcon: t.active,
                    label: t.label,
                    selected: i == _currentIndex,
                    onTap: () => context.go(t.path),
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

/// Un onglet de la barre du bas.
///
/// L'icône et le libellé sont empilés dans une colonne dont les enfants sont
/// tous souples : un libellé long (« Messages ») se tronque au lieu de faire
/// déborder la colonne quand la fenêtre est étroite ou la police agrandie.
class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary50 : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(height: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
