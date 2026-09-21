import 'package:flutter/material.dart';
import 'phosphor.dart';

import '../theme/app_theme.dart';
import 'uni/uni_mascot.dart';

/// Issue d'une action utilisateur, pour un retour visuel homogène.
enum FeedbackKind { success, failure, info }

/// Retour de succès ou d'échec animé, commun à toutes les actions
/// (envoi de message, rendu de devoir, scan de présence, inscription…).
///
/// Une même pastille qui s'anime de la même façon partout : l'utilisateur
/// reconnaît le résultat avant d'avoir lu le texte. L'animation est purement
/// implicite (`TweenAnimationBuilder`) : pas de dépendance Lottie, et elle
/// tourne aussi dans les tests de mise en page.
class FeedbackView extends StatelessWidget {
  final FeedbackKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  const FeedbackView({
    super.key,
    required this.kind,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  Color get _color => switch (kind) {
        FeedbackKind.success => AppColors.success,
        FeedbackKind.failure => AppColors.danger,
        FeedbackKind.info => AppColors.primaryBlue,
      };

  PhosphorIconData get _icon => switch (kind) {
        FeedbackKind.success => PhosphorIconsBold.check,
        FeedbackKind.failure => PhosphorIconsBold.x,
        FeedbackKind.info => PhosphorIconsBold.info,
      };

  /// Pose d'Uni qui accompagne la pastille en plein écran : il saute de joie
  /// sur un succès, s'excuse sur un échec. En mode compact, la pastille seule.
  UniPose get _pose => switch (kind) {
        FeedbackKind.success => UniPose.celebrate,
        FeedbackKind.failure => UniPose.sorry,
        FeedbackKind.info => UniPose.pointing,
      };

  @override
  Widget build(BuildContext context) {
    final size = compact ? 64.0 : 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Center(child: UniMascot(pose: _pose, size: 130)),
          const SizedBox(height: 6),
        ],
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _color.withValues(alpha: 0.12),
                border: Border.all(color: _color.withValues(alpha: 0.35), width: 2),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Opacity(
                  opacity: value.clamp(0, 1),
                  child: Transform.scale(scale: 0.6 + value * 0.4, child: child),
                ),
                child: PhosphorIcon(_icon, color: _color, size: size * 0.5),
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 14 : 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: compact ? AppTextStyles.h3 : AppTextStyles.h2,
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message!, textAlign: TextAlign.center, style: AppTextStyles.body),
        ],
        if (onAction != null) ...[
          SizedBox(height: compact ? 16 : 24),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(actionLabel ?? 'Continuer', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
        if (onSecondary != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSecondary,
            child: Text(secondaryLabel ?? 'Retour', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );
  }
}

/// Affiche le retour dans une feuille modale et rend la main une fois fermée.
///
/// Utilisé après une action ponctuelle (envoi, rendu, scan) : la feuille
/// laisse l'écran d'origine en place, contrairement à une page qui casserait
/// le retour arrière.
Future<void> showFeedbackSheet(
  BuildContext context, {
  required FeedbackKind kind,
  required String title,
  String? message,
  String actionLabel = 'Fermer',
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.cardWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: FeedbackView(
          kind: kind,
          title: title,
          message: message,
          compact: true,
          actionLabel: actionLabel,
          onAction: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    ),
  );
}

/// Bandeau discret de succès ou d'échec, à poser en haut d'un formulaire.
class FeedbackBanner extends StatelessWidget {
  final FeedbackKind kind;
  final String message;

  const FeedbackBanner({super.key, required this.kind, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      FeedbackKind.success => AppColors.success,
      FeedbackKind.failure => AppColors.danger,
      FeedbackKind.info => AppColors.primaryBlue,
    };
    final icon = switch (kind) {
      FeedbackKind.success => PhosphorIconsFill.checkCircle,
      FeedbackKind.failure => PhosphorIconsFill.warningCircle,
      FeedbackKind.info => PhosphorIconsFill.info,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhosphorIcon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          // `Flexible` : le message peut être long (erreur Appwrite brute), il
          // doit se replier sur plusieurs lignes et non élargir l'encadré.
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: Color.lerp(color, Colors.black, 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
