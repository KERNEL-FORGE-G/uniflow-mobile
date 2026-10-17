import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_role.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import 'phosphor.dart';
import 'uni/uni_mascot.dart';
import 'uni_icons.dart';

/// Au-dessus de cette largeur, la feuille cesse de s'étirer : un formulaire
/// large de toute la fenêtre est inconfortable à lire. Le seuil sert aux
/// tablettes et aux fenêtres redimensionnées, pas au téléphone en portrait.
const double kAuthCompactWidth = 480;

/// Hauteur minimale du bandeau de marque ; il grandit avec le texte.
const double kAuthHeroMinHeight = 200;

/// L'accroche du bandeau : une phrase blanche dont un fragment est mis en
/// couleur (« rester **au fil** de vos cours »), comme sur la maquette.
class AuthHeadline {
  final String before;
  final String emphasis;
  final String after;

  const AuthHeadline(this.before, this.emphasis, [this.after = '']);

  String get plain => '$before$emphasis$after';
}

/// Écran hors session (connexion, inscription, mot de passe oublié), d'après
/// la maquette fournie le 2026-09-21 : un bandeau coloré en haut — accroche,
/// Uni, formes discrètes — et une feuille blanche aux coins arrondis qui monte
/// du bas pour porter le formulaire.
///
/// La mise en page s'adapte à la fenêtre : le bandeau garde une hauteur
/// minimale et grandit avec la taille du texte ; la feuille remplit le reste
/// et la page défile quand le clavier réduit la place. Aucune largeur n'est
/// imposée sans qu'un parent puisse la réduire, ce qui évite les débordements.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final AuthHeadline? headline;
  final UniPose pose;
  final VoidCallback? onBack;

  /// Pastille « UniFlow » en haut du bandeau.
  final bool showBrand;

  const AuthScaffold({
    super.key,
    required this.child,
    this.headline,
    this.pose = UniPose.wave,
    this.onBack,
    this.showBrand = true,
  });

  @override
  Widget build(BuildContext context) {
    // Le bandeau est bleu : icônes de statut claires. La feuille blanche
    // repose sur la barre de navigation : icônes sombres en bas.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.surBleu,
      child: Scaffold(
        backgroundColor: AppColors.primaryBlue,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.authHeroGradient)),
            ),
            const Positioned.fill(child: CustomPaint(painter: _HeroDecorPainter())),
            LayoutBuilder(
              builder: (context, constraints) {
                final padding = MediaQuery.paddingOf(context);
                final wide = constraints.maxWidth >= kAuthCompactWidth;
                // La feuille occupe au moins ce qui reste sous le bandeau, pour
                // que le blanc aille jusqu'en bas même avec un formulaire court.
                final sheetMin = math.max(0.0, constraints.maxHeight - kAuthHeroMinHeight - padding.top);
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _Hero(
                        headline: headline,
                        pose: pose,
                        onBack: onBack,
                        showBrand: showBrand,
                        topInset: padding.top,
                        narrow: constraints.maxWidth < 360,
                      ),
                      _Sheet(
                        minHeight: sheetMin,
                        bottomInset: padding.bottom,
                        horizontal: wide ? 32 : 22,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: kAuthCompactWidth),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                child,
                                const SizedBox(height: 22),
                                // Badge soutien technologique Axora
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primaryBlue.withValues(alpha: 0.14),
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PhosphorIcon(PhosphorIconsBold.checkCircle,
                                              size: 11, color: AppColors.primaryBlue.withValues(alpha: 0.55)),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Plateforme autonome et hors-ligne',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.primaryBlue.withValues(alpha: 0.65),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'UniFlow · KERNEL FORGE · 2026',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau : pastille de marque ou bouton retour, accroche et Uni.
class _Hero extends StatelessWidget {
  final AuthHeadline? headline;
  final UniPose pose;
  final VoidCallback? onBack;
  final bool showBrand;
  final double topInset;
  final bool narrow;

  const _Hero({
    required this.headline,
    required this.pose,
    required this.onBack,
    required this.showBrand,
    required this.topInset,
    required this.narrow,
  });

  @override
  Widget build(BuildContext context) {
    final mascotSize = narrow ? 92.0 : 118.0;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: kAuthHeroMinHeight + topInset),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Illustration décorative en fond à droite (books 3D)
          Positioned(
            right: -10,
            bottom: 0,
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/mascot/archlord_uni_duo_solid.webp',
                height: kAuthHeroMinHeight * 1.1,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (onBack != null)
                      _RoundIconButton(icon: UniIcons.back.bold, tooltip: 'Retour', onTap: onBack!)
                    else if (showBrand)
                      const BrandChip(),
                  ],
                ),
                const SizedBox(height: 14),
                _FadeUp(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: headline == null
                              ? const SizedBox.shrink()
                              : _HeadlineText(headline: headline!, narrow: narrow),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Mascotte Uni sur le bandeau d'authentification mobile
                      UniMascot(pose: pose, size: mascotSize, effects: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadlineText extends StatelessWidget {
  final AuthHeadline headline;
  final bool narrow;

  const _HeadlineText({required this.headline, required this.narrow});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: narrow ? 21 : 24,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      height: 1.22,
      letterSpacing: -0.2,
    );
    return Semantics(
      header: true,
      label: headline.plain,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: headline.before),
            TextSpan(text: headline.emphasis, style: base.copyWith(color: AppColors.authAccent)),
            TextSpan(text: headline.after),
          ],
        ),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// La feuille blanche : coins hauts arrondis, poignée, ombre vers le bandeau.
/// Elle monte du bas à l'ouverture de l'écran.
class _Sheet extends StatelessWidget {
  final Widget child;
  final double minHeight;
  final double bottomInset;
  final double horizontal;

  const _Sheet({
    required this.child,
    required this.minHeight,
    required this.bottomInset,
    required this.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 48),
        child: Opacity(opacity: t, child: child),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusAuthSheet)),
            border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée : elle dit « feuille », comme la maquette.
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Fondu + glissement vers le haut, pour l'accroche du bandeau.
class _FadeUp extends StatelessWidget {
  final Widget child;
  const _FadeUp({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
    );
  }
}

/// Pastille « UniFlow » : écusson sur pastille claire, nom en blanc.
class BrandChip extends StatelessWidget {
  const BrandChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'uniflow-brand',
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/brand/uniflow_logo_final.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) =>
                      const PhosphorIcon(PhosphorIconsFill.graduationCap, color: AppColors.primaryBlue, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'UniFlow',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.22))),
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: PhosphorIcon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Anneaux et points en filigrane sur le bandeau, comme sur la maquette.
/// Peints plutôt qu'en image : nets à toute densité, et sans octet embarqué.
class _HeroDecorPainter extends CustomPainter {
  const _HeroDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(Offset(size.width * 0.86, 62), 58, ring);
    canvas.drawCircle(Offset(size.width * 0.86, 62), 92, ring..color = Colors.white.withValues(alpha: 0.08));
    canvas.drawCircle(Offset(-20, size.height * 0.3), 70, ring..color = Colors.white.withValues(alpha: 0.10));

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.22);
    const step = 14.0;
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 4; j++) {
        canvas.drawCircle(Offset(24 + i * step, 118 + j * step), 1.6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeroDecorPainter oldDelegate) => false;
}

/// Titre de la feuille, centré, avec la phrase de bascule vers l'autre écran
/// (« Pas encore de compte ? S'inscrire »).
class AuthSheetTitle extends StatelessWidget {
  final String title;
  final String? prompt;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AuthSheetTitle({
    super.key,
    required this.title,
    this.prompt,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h1,
        ),
        if (prompt != null && actionLabel != null) ...[
          const SizedBox(height: 4),
          // `Wrap` plutôt que `Row` : aux grandes échelles de texte les deux
          // segments ne tiennent pas côte à côte et déborderaient.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(prompt!, style: AppTextStyles.bodySmall),
              const SizedBox(width: 2),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!, style: AppTextStyles.link),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Le contenu d'un formulaire hors session, empilé et étiré.
///
/// Conservé pour les écrans qui l'utilisent : la feuille blanche et son ombre
/// sont désormais dessinées par [AuthScaffold].
class AuthCard extends StatelessWidget {
  final List<Widget> children;

  const AuthCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Choix du type de compte, identique au web : un compte rattaché à une
/// université, ou un compte indépendant qui gère seul ses matières.
///
/// Un sélecteur segmenté plutôt que deux grandes tuiles : la feuille de la
/// maquette est compacte, et ce choix n'est qu'une indication à la connexion.
class AccountTypeSelector extends StatelessWidget {
  final UniFlowAccountType value;
  final ValueChanged<UniFlowAccountType>? onChanged;

  const AccountTypeSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isUni = value == UniFlowAccountType.university;
    final isPersonal = value == UniFlowAccountType.personal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'CHOISISSEZ VOTRE TYPE D\'ESPACE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Carte 1 : Compte Universitaire
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged!(UniFlowAccountType.university),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUni ? AppColors.primaryBlue.withValues(alpha: 0.08) : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUni ? AppColors.primaryBlue : AppColors.inputBorder,
                        width: isUni ? 2.0 : 1.0,
                      ),
                      boxShadow: isUni
                          ? [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isUni ? AppColors.primaryBlue : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: PhosphorIcon(
                                PhosphorIconsBold.buildings,
                                size: 18,
                                color: isUni ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            if (isUni)
                              const PhosphorIcon(
                                PhosphorIconsFill.checkCircle,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Universitaire',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Faculté des Sciences UY1',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Carte 2 : Compte Indépendant
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged!(UniFlowAccountType.personal),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: isPersonal ? const Color(0xFF0D9488).withValues(alpha: 0.08) : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPersonal ? const Color(0xFF0D9488) : AppColors.inputBorder,
                        width: isPersonal ? 2.0 : 1.0,
                      ),
                      boxShadow: isPersonal
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isPersonal ? const Color(0xFF0D9488) : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: PhosphorIcon(
                                PhosphorIconsBold.userCircle,
                                size: 18,
                                color: isPersonal ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            if (isPersonal)
                              const PhosphorIcon(
                                PhosphorIconsFill.checkCircle,
                                size: 18,
                                color: Color(0xFF0D9488),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Indépendant',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Espace libre & personnel',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sélecteur des 3 rôles disponibles pour les comptes indépendants :
/// Étudiant (cursus personnel), Délégué (coordination groupe), Enseignant (espace cours/notes).
class IndependentRoleSelector extends StatelessWidget {
  final UniFlowRole value;
  final ValueChanged<UniFlowRole>? onChanged;

  const IndependentRoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              selected: value == UniFlowRole.student,
              icon: UniIcons.students,
              title: 'Étudiant',
              onTap: onChanged == null ? null : () => onChanged!(UniFlowRole.student),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _Segment(
              selected: value == UniFlowRole.delegate,
              icon: UniIcons.megaphone,
              title: 'Délégué',
              onTap: onChanged == null ? null : () => onChanged!(UniFlowRole.delegate),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _Segment(
              selected: value == UniFlowRole.teacher,
              icon: UniIcons.teacher,
              title: 'Enseignant',
              onTap: onChanged == null ? null : () => onChanged!(UniFlowRole.teacher),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final bool selected;

  /// Une `UniIcon` plutôt qu'un glyphe : le segment choisit lui-même la
  /// graisse, pleine quand il est sélectionné, `bold` sinon.
  final UniIcon icon;
  final String title;
  final VoidCallback? onTap;

  const _Segment({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.cardWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(selected ? icon.fill : icon.bold, color: color, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton principal, en dégradé bleu → teal avec une ombre portée colorée.
///
/// Construit à la main plutôt qu'avec `ElevatedButton` : `ElevatedButton` ne
/// sait pas peindre un dégradé, et c'est ce dégradé qui rattache visuellement
/// les écrans hors session au reste de la charte.
class GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDisabled ? null : AppColors.logoGradient,
        color: isDisabled ? AppColors.inputBorder : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: SizedBox(
            height: 52,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            PhosphorIcon(icon!, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child:
                                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.button),
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
