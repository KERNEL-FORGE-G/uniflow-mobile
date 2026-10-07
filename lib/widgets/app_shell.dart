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
  DateTime? _lastBack;

  /// Index de l'onglet actif, ou -1 si la page courante vit dans le menu.
  int _currentIndex(List<NavDestination> tabs) =>
      tabs.indexWhere((t) => widget.location.startsWith(t.path));

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBack = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appuyez encore une fois pour quitter'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        // Le bandeau hors ligne / en attente d'envoi coiffe chaque page ; il
        // se replie tout seul quand tout est synchronisé.
        body: LayoutBuilder(
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
      ),
      // Bord à bord : la barre blanche se prolonge sous la barre de navigation
      // système (SafeArea) et annonce des icônes sombres pour celle-ci — c'est
      // la région en bas de l'écran qui en décide.
      bottomNavigationBar: AnnotatedRegion<SystemUiOverlayStyle>(
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
