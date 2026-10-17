import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'phosphor.dart';
import '../models/user_role.dart';
import '../offline/offline_widgets.dart';
import '../providers/providers.dart';
import '../router/shell_pages.dart';
import '../theme/app_theme.dart';
import 'uni/uni_assistant.dart';
import 'uni/uni_scenes.dart';
import 'uni_icons.dart';

/// Où le bouton d'Uni s'accroche dans la coquille.
///
/// Dérivé du [BottomEdge] déclaré par la page : le bouton ne doit jamais
/// recouvrir une commande de la page, et c'est la page qui sait ce qu'elle
/// pose en bas de l'écran.
enum UniDock {
  /// En bas à droite, sa place ordinaire.
  right,

  /// En bas à gauche : le bouton flottant de la page garde le coin droit, Uni
  /// s'écarte à la même hauteur. Le percher au-dessus du bouton flottant a été
  /// essayé : à 84 pt du bas, il atteignait le milieu d'un petit écran et
  /// recouvrait le bouton des états vides centrés (« Nouvelle conversation »).
  left,

  /// Absent : la page occupe tout le bord inférieur avec un composeur.
  hidden;

  /// Écart du bouton avec le bord latéral.
  static const double edgeInset = 14;

  /// Écart du bouton avec le bord inférieur du corps de la coquille.
  static const double bottomInset = 14;

  /// Abscisse du bord gauche du bouton dans une coquille large de [width].
  double leftIn(double width) => switch (this) {
        UniDock.left => edgeInset,
        UniDock.right || UniDock.hidden => width - edgeInset - UniLauncher.size,
      };
}

/// L'ancrage d'Uni pour une page dont le bord inférieur est [edge].
UniDock uniDockFor(BottomEdge edge) => switch (edge) {
      BottomEdge.free => UniDock.right,
      BottomEdge.fab => UniDock.left,
      BottomEdge.composer => UniDock.hidden,
    };

/// Coquille de l'application connectée : elle porte la barre de navigation du
/// bas, commune à tous les onglets.
///
/// La barre était teal plein. Elle est désormais blanche, comme la surface des
/// pages du web, avec l'onglet actif en bleu de marque sur une pastille
/// `primary-50` : c'est le même vocabulaire que la sidebar du desktop, où
/// l'élément actif est le seul à porter la couleur d'accent.
///
/// Les onglets ne sont plus une liste figée : ils viennent de
/// [bottomBarFor], donc du rôle. Un étudiant n'a pas d'onglet « Étudiants »,
/// un enseignant n'a pas d'onglet « Présence ». Les entrées qui ne tiennent pas
/// dans la barre restent accessibles depuis l'accueil.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Index de l'onglet actif, ou -1 si la page courante vit dans le menu.
  int _currentIndex(List<NavDestination> tabs) => tabs.indexWhere((t) => widget.location.startsWith(t.path));

  void _openMenu(BuildContext context, List<NavDestination> entries) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _MenuSheet(
        entries: entries,
        location: widget.location,
        onSelect: (path) {
          Navigator.of(sheetContext).pop();
          context.go(path);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    final tabs = primaryTabsFor(role);
    final menu = menuEntriesFor(role);
    final current = _currentIndex(tabs);
    final menuActive = menu.any((d) => widget.location.startsWith(d.path));
    final dock = uniDockFor(bottomEdgeAt(widget.location, role));
    final reduce = MediaQuery.disableAnimationsOf(context);

    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    final content = LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Column(children: [const OfflineBanner(), Expanded(child: widget.child)]),
          // Uni : le bouton flottant de l'assistant. Sa place dépend de ce
          // que la page pose en bas de l'écran (voir `shell_pages.dart`) : il
          // glisse dans le coin gauche quand la page a son propre bouton
          // flottant et s'efface devant un composeur, au lieu de recouvrir
          // le bouton d'envoi ou « Nouvelle conversation » comme avant. La
          // position est toujours donnée par `left` pour que le glissement
          // d'un coin à l'autre s'anime au changement de page.
          if (dock != UniDock.hidden)
            AnimatedPositioned(
              duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              left: dock.leftIn(constraints.maxWidth),
              bottom: UniDock.bottomInset,
              child: UniLauncher(onOpen: () => showUniAssistant(context)),
            ),
          // Sa première apparition par le bord droit pour se présenter (une
          // fois par lancement), au-dessus de la hauteur du bouton.
          if (dock != UniDock.hidden)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: UniDock.bottomInset + UniLauncher.size + 12),
                child: UniPeek(
                  id: 'hello-shell',
                  message: 'Salut ! Je suis Uni. Une question sur tes cours ou l’appli ? Touche-moi.',
                  onTap: () => showUniAssistant(context),
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                _DesktopSidebar(location: widget.location, role: role),
                Expanded(child: content),
              ],
            )
          : content,
      // Sur grand écran desktop, la sidebar latérale claire remplace la barre du bas.
      bottomNavigationBar: isDesktop
          ? null
          : AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppSystemUi.surClair,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppColors.inputBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            Expanded(
                              child: _NavTab(
                                icon: tabs[i].icon,
                                label: tabs[i].label,
                                selected: i == current,
                                onTap: () => context.go(tabs[i].path),
                              ),
                            ),
                          Expanded(
                            child: _MenuTab(
                              selected: current == -1 && menuActive,
                              onTap: () => _openMenu(context, menu),
                            ),
                          ),
                        ],
                      ),
                    ),
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
///
/// L'icône Phosphor passe de `bold` (repos) à `fill` (actif) ; le changement
/// de graisse est fondu et légèrement grossi par un `AnimatedSwitcher`, ce qui
/// donne le « clic » visuel demandé par le propriétaire sans animation
/// infinie — `pumpAndSettle` se pose toujours.
class _NavTab extends StatelessWidget {
  final UniIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textSecondary;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final glyph = PhosphorIcon(
      icon(selected ? UniIconStyle.fill : UniIconStyle.bold),
      // La clé porte l'état : sans elle, l'`AnimatedSwitcher` ne verrait qu'un
      // même type de widget et ne jouerait aucune transition.
      key: ValueKey(selected),
      color: color,
      size: 20,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary50 : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: reduce
                  ? glyph
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: glyph,
                    ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: -0.1,
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

/// 5e place de la barre : le bouton « Menu ». Il s'allume quand la page
/// courante fait partie des entrées repliées dans le menu.
class _MenuTab extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _MenuTab({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textSecondary;
    return Semantics(
      button: true,
      label: 'Menu, autres rubriques',
      child: InkWell(
        key: const ValueKey('nav-menu'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(Icons.menu_rounded, color: color, size: 22),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  'Menu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

/// Feuille du menu : grille de toutes les rubriques qui ne tiennent pas dans
/// la barre (emploi du temps, devoirs, forum, notifications, réglages…).
class _MenuSheet extends StatelessWidget {
  final List<NavDestination> entries;
  final String location;
  final ValueChanged<String> onSelect;

  const _MenuSheet({
    required this.entries,
    required this.location,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Toutes les rubriques',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Accède au reste d’UniFlow en un geste.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, i) {
                    final d = entries[i];
                    final active = location.startsWith(d.path);
                    return InkWell(
                      onTap: () => onSelect(d.path),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary50 : AppColors.background,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? AppColors.primaryBlue : AppColors.inputBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.cardWhite,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.10),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  d.icon(active ? UniIconStyle.fill : UniIconStyle.duotone),
                                  size: 22,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              d.label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre latérale de navigation claire pour les écrans larges Desktop (>= 800 pt).
///
/// Fidèle aux planches de maquettes : fond blanc pur `#FFFFFF`, bordure droite subtile,
/// logo officiel UniFlow, badge de rôle dynamique, liste scrollable des rubriques autorisées,
/// indicateur de synchronisation Campus LAN et pied de page profil avec réglages.
class _DesktopSidebar extends ConsumerWidget {
  final String location;
  final UniFlowRole role;

  const _DesktopSidebar({
    required this.location,
    required this.role,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final destinations = destinationsFor(role);

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(
          right: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // En-tête : Logo et Nom de marque
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/brand/uniflow_logo_final.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UniFlow',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlue,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          // Liste scrollable des destinations
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              itemCount: destinations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 3),
              itemBuilder: (context, index) {
                final d = destinations[index];
                final active = location.startsWith(d.path);
                return InkWell(
                  onTap: () => context.go(d.path),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.primaryBlue.withValues(alpha: 0.25) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        PhosphorIcon(
                          d.icon(active ? UniIconStyle.fill : UniIconStyle.duotone),
                          size: 19,
                          color: active ? AppColors.primaryBlue : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            d.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              color: active ? AppColors.primaryBlue : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (active)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Indicateur de statut réseau & LAN Campus
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Campus UY1 · Synchronisé',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.inputBorder),
          // Profil utilisateur en pied de sidebar
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary50,
                  child: Text(
                    user?.name.isNotEmpty == true ? user!.name.substring(0, 1).toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name.isNotEmpty == true ? user!.name : 'Utilisateur',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Réglages',
                  icon: const PhosphorIcon(PhosphorIconsDuotone.gearSix, size: 18, color: AppColors.textSecondary),
                  onPressed: () => context.go('/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
