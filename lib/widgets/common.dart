import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'phosphor.dart';
import '../theme/app_theme.dart';
import 'uni/uni_mascot.dart';
import 'uni/uni_scenes.dart';
import 'uni_icons.dart';
import '../utils/avatar.dart';
import '../utils/error_text.dart';

/// En-tête de page, en dégradé bleu nuit.
///
/// Il reprend le dégradé des en-têtes du web (`admin-header-gradient`) et de la
/// sidebar du desktop. Auparavant teal, il faisait du mobile une application
/// visuellement distincte des deux autres plateformes.
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Posé avant le titre : la tuile de la matière sur la fiche d'une UE.
  final Widget? leading;
  final Widget? trailing;
  final PreferredSizeWidget? bottom;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    // L'en-tête s'étend sous la barre de statut (bord à bord) et annonce des
    // icônes claires : c'est la région située en haut de l'écran qui décide
    // du style de cette barre.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.surBleu,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33152A66),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 12)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // `mainAxisSize.min` : la zone d'actions ne prend que la place
                    // nécessaire, le titre étant déjà en Expanded.
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
                if (bottom != null) ...[const SizedBox(height: 14), bottom!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ de recherche posé sur l'en-tête dégradé.
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        prefixIcon: const PhosphorIcon(PhosphorIconsBold.magnifyingGlass, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}

/// Pastille de statut, calquée sur les badges du web.
///
/// Les teintes sont celles du design system (`bg-primary/10`, `bg-emerald-100`
/// …) : fond très clair, texte saturé de la même famille.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const StatusBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Famille de couleur déduite du libellé.
  ///
  /// Le repli est volontairement bleu plutôt que gris : un statut non
  /// répertorié reste lisible, là où un gris clair sur gris clair disparaissait.
  (Color, Color) get _colors {
    switch (label.toLowerCase()) {
      case 'actif':
      case 'active':
      case 'validée':
      case 'valide':
      case 'permanent':
      case 'présent':
      case 'payé':
      case 'terminé':
        return (AppColors.success.withValues(alpha: 0.12), const Color(0xFF047857));
      case 'suspendu':
      case 'rejetée':
      case 'rejete':
      case 'absent':
      case 'échoué':
      case 'impayé':
        return (AppColors.danger.withValues(alpha: 0.12), const Color(0xFFB91C1C));
      case 'en attente':
      case 'vacataire':
      case 'brouillon':
      case 'planifié':
        return (AppColors.warning.withValues(alpha: 0.16), const Color(0xFFB45309));
      default:
        return (AppColors.info.withValues(alpha: 0.12), const Color(0xFF1D4ED8));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foregroundColor ?? fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Carte de contenu : surface blanche, bordure fine et coins arrondis, comme
/// les `bg-white rounded-xl border border-border` du web.
///
/// Construite sur un `Material` et non sur un `Container` coloré : un
/// `DecoratedBox` opaque interposé entre le `Material` ambiant et un `ListTile`
/// masque les effets d'encre de ce dernier — Flutter le signale par une
/// assertion, et la carte restait inerte au survol.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool bordered;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: bordered ? const BorderSide(color: AppColors.inputBorder) : BorderSide.none,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Titre de section, avec un trait d'accent à gauche et, si on la donne, une
/// icône Phosphor `duotone` qui annonce le contenu.
///
/// Remplace les `Text(..., fontWeight: FontWeight.bold)` disséminés dans les
/// écrans, qui n'avaient ni la même taille ni la même couleur d'un écran à
/// l'autre.
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;
  final EdgeInsets padding;

  const SectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.iconColor = AppColors.primaryBlue,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppColors.logoGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          if (icon != null) ...[
            PhosphorIcon(icon!, size: 18, color: iconColor, duotoneSecondaryColor: iconColor),
            const SizedBox(width: 7),
          ],
          // Expanded plutôt qu'un Row nu : un titre long doit se tronquer au
          // lieu de pousser le `trailing` hors de la ligne.
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Carte de statistique : tuile d'icône pleine, valeur, libellé.
class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  /// Rang dans la rangée : décale l'apparition de la tuile (cascade).
  final int index;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
    this.index = 0,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  // La pression sur la carte entière rétracte la tuile : c'est la carte qui
  // reçoit le toucher, pas la tuile.
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final card = SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(
            icon: widget.icon,
            color: widget.color,
            size: IconTile.large,
            index: widget.index,
            pressed: _pressed,
          ),
          const SizedBox(height: 12),
          // `FittedBox` : « 15,5/20 » en gras déborde d'une carte étroite, et
          // une taille qui s'ajuste vaut mieux que des points de suspension sur
          // un chiffre.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
          if (widget.caption != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );

    if (widget.onTap == null) return card;
    return InkWell(
      onTap: widget.onTap,
      onHighlightChanged: (down) => setState(() => _pressed = down),
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: card,
    );
  }
}

/// Bouton principal en dégradé bleu → teal.
///
/// `ElevatedButton` ne sait peindre qu'un aplat ; ce dégradé est la signature
/// de marque du web.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDisabled ? null : AppColors.logoGradient,
        color: isDisabled ? AppColors.inputBorder : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                else if (icon != null)
                  PhosphorIcon(icon!, size: 18, color: Colors.white),
                if (isLoading || icon != null) const SizedBox(width: 9),
                // Flexible : un libellé long se tronque au lieu de déborder.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.button.copyWith(fontSize: 14.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// État vide : icône, titre, explication et action facultative.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// Quand elle est donnée, Uni remplace l'icône (il cherche, s'excuse, dort…).
  final UniPose? pose;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.pose,
  });

  @override
  Widget build(BuildContext context) {
    // Défilement quand la hauteur manque : sur 320×568 avec texte agrandi, un
    // en-tête à barre de recherche plus un sélecteur laissent moins de place
    // que l'icône, le titre et le message n'en demandent (débordement de
    // 19 px constaté par `layout_test`).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pose != null)
                    UniMascot(pose: pose!, size: 124)
                  else
                    IconTile(
                      icon: icon,
                      color: AppColors.primaryBlue,
                      variant: IconTileVariant.soft,
                      size: IconTile.large,
                    ),
                  const SizedBox(height: 16),
                  Text(title, textAlign: TextAlign.center, style: AppTextStyles.h3),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(message!, textAlign: TextAlign.center, style: AppTextStyles.body),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 18),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'erreur, sur le modèle de celui de l'écran de connexion.
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorBanner({super.key, required this.message, this.onRetry});

  /// Rouge plus sombre que `AppColors.danger` : le rouge d'alerte est prévu
  /// pour des icônes et des bordures, il manque de contraste pour de la lecture.
  static const Color _ink = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 18, color: AppColors.danger),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Réessayer', style: AppTextStyles.link),
            ),
          ],
        ],
      ),
    );
  }
}

/// Échec de chargement d'un écran entier : Uni s'excuse, la phrase lisible,
/// le code technique en petit et « Réessayer ».
///
/// Remplace les bandeaux rouges posés au milieu d'un écran vide : chaque
/// écran avait le sien, avec ou sans bouton, avec ou sans détail. Le bandeau
/// (`ErrorBanner`) reste pour une erreur inline au-dessus d'un contenu.
class LoadErrorView extends StatelessWidget {
  final String title;
  final Object error;
  final VoidCallback? onRetry;

  const LoadErrorView({super.key, required this.title, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final text = describeError(error);
    return UniOops(
      title: title,
      message: text.detail,
      pose: UniPose.sorry,
      size: 124,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const PhosphorIcon(PhosphorIconsBold.arrowsClockwise, size: 18),
              label: const Text('Réessayer'),
            ),
      secondaryAction: ErrorCodeChip(code: text.code),
    );
  }
}

/// Le code technique d'une erreur, en petit et en monospace : lisible sur une
/// capture d'écran envoyée par un utilisateur.
class ErrorCodeChip extends StatelessWidget {
  final String code;

  const ErrorCodeChip({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Text(
        code,
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textMuted),
      ),
    );
  }
}

/// Indicateur de chargement centré, avec un libellé facultatif.
class LoadingView extends StatelessWidget {
  final String? label;

  /// Uni réfléchit à la place du cercle : pour les chargements pleine page.
  final bool mascot;

  const LoadingView({super.key, this.label, this.mascot = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mascot) ...[
            const UniMascot(pose: UniPose.thinking, size: 110),
            const SizedBox(height: 10),
            const UniDots(),
          ] else
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!, style: AppTextStyles.body),
          ],
        ],
      ),
    );
  }
}

/// Avatar rond : photo si un fichier Appwrite est fourni, initiales sinon.
class Avatar extends StatelessWidget {
  final String initials;
  final Color? color;
  final double size;

  /// Identifiant du fichier dans le bucket Appwrite `uniflow_assets`. Quand il
  /// est renseigné, la photo remplace les initiales ; sinon l'affichage reste
  /// exactement celui d'avant, si bien que les appels existants ne changent pas.
  final String? avatarFileId;

  const Avatar({
    super.key,
    required this.initials,
    this.color,
    this.size = 44,
    this.avatarFileId,
  });

  @override
  Widget build(BuildContext context) {
    // Bleu de marque par défaut : les initiales étaient teal, ce qui les
    // détachait du reste de la charte.
    final c = color ?? AppColors.primaryBlue;
    final url = avatarUrl(avatarFileId);

    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials.toUpperCase(),
            maxLines: 1,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.38,
            ),
          ),
        );

    if (url == null) return fallback();

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Une photo supprimée côté serveur ou un réseau coupé ne doit pas
        // laisser un trou : on retombe sur les initiales.
        errorBuilder: (_, __, ___) => fallback(),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}

/// Photo d'un membre de l'équipe KERNEL FORGE, ou silhouette neutre.
///
/// Contrairement à [Avatar], ce widget n'affiche **jamais** d'initiales. Sur
/// demande du propriétaire, aucune écriture ne doit apparaître sur la photo de
/// profil : un rond gris et une icône de personne se lisent comme « pas encore
/// de photo », alors que des initiales donnent l'impression d'une image ratée.
///
/// L'écran `/equipe` l'utilise à la place d'[Avatar] ; les autres écrans, qui
/// montrent des comptes utilisateurs et non des membres de l'équipe, gardent
/// les initiales.
class SilhouetteAvatar extends StatelessWidget {
  final String? avatarFileId;
  final double size;

  /// Coins arrondis. `null` donne un cercle, comme la page web pour les
  /// comptes ; les cartes de l'équipe passent un rayon plus doux.
  final BorderRadius? borderRadius;

  final Color background;
  final Color foreground;

  const SilhouetteAvatar({
    super.key,
    this.avatarFileId,
    this.size = 56,
    this.borderRadius,
    this.background = AppColors.surfaceMuted,
    this.foreground = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 2);

    Widget silhouette() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: background, borderRadius: radius),
          alignment: Alignment.center,
          child: PhosphorIcon(PhosphorIconsFill.user, size: size * 0.5, color: foreground),
        );

    final url = avatarUrl(avatarFileId);
    if (url == null) return silhouette();

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Une photo retirée du bucket ou un réseau coupé ramène à la
        // silhouette, jamais à un trou ni à des initiales.
        errorBuilder: (_, __, ___) => silhouette(),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: background, borderRadius: radius),
              ),
      ),
    );
  }
}
