import 'package:flutter/material.dart';

import '../models/badges.dart';
import '../theme/app_theme.dart';

/// Un badge rond. Verrouillé : en gris, estompé, avec un cadenas et un anneau
/// de progression ; gagné : en couleur, avec une légère ombre portée.
///
/// L'image reste la même dans les deux états : la désaturation est faite par
/// un `ColorFiltered`, ce qui évite d'embarquer douze fichiers pour six
/// badges.
class BadgeMedal extends StatelessWidget {
  final BadgeProgress progress;
  final double size;
  final VoidCallback? onTap;

  const BadgeMedal({
    super.key,
    required this.progress,
    this.size = 84,
    this.onTap,
  });

  /// Matrice de désaturation (luminance perçue), puis éclaircie : un badge
  /// gris foncé se lisait comme « cassé », pas comme « à gagner ».
  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126 * 0.75, 0.7152 * 0.75, 0.0722 * 0.75, 0, 70, //
    0.2126 * 0.75, 0.7152 * 0.75, 0.0722 * 0.75, 0, 70, //
    0.2126 * 0.75, 0.7152 * 0.75, 0.0722 * 0.75, 0, 70, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.unlocked;
    final image = Image.asset(
      progress.badge.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.military_tech_rounded,
        size: size * 0.7,
        color: unlocked ? AppColors.warning : AppColors.textMuted,
      ),
    );

    final medal = unlocked
        ? DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: image,
          )
        : Opacity(
            opacity: 0.55,
            child: ColorFiltered(colorFilter: _greyscale, child: image),
          );

    final content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!unlocked)
            SizedBox(
              width: size * 0.98,
              height: size * 0.98,
              child: CircularProgressIndicator(
                value: progress.progress.clamp(0.0, 1.0),
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.inputBorder,
                color: AppColors.teal,
              ),
            ),
          Padding(padding: EdgeInsets.all(size * 0.08), child: medal),
          if (!unlocked)
            Positioned(
              right: size * 0.04,
              bottom: size * 0.04,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Icon(Icons.lock_rounded, size: size * 0.16, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );

    final labelled = Semantics(
      label: unlocked ? 'Badge ${progress.badge.title}, gagné' : 'Badge ${progress.badge.title}, ${progress.percent} %',
      button: onTap != null,
      child: content,
    );
    if (onTap == null) return labelled;
    return InkResponse(
      onTap: onTap,
      radius: size * 0.6,
      child: labelled,
    );
  }
}

/// Rangée des six badges pour l'accueil : les gagnés d'abord, un compteur, et
/// tout mène à l'écran détaillé.
class BadgesStrip extends StatelessWidget {
  final List<BadgeProgress> badges;
  final VoidCallback? onSeeAll;

  const BadgesStrip({super.key, required this.badges, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((b) => b.unlocked).length;
    final ordered = [...badges]..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        return b.progress.compareTo(a.progress);
      });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.inputBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unlocked == 0
                      ? 'Aucun badge pour l\'instant'
                      : '$unlocked badge${unlocked > 1 ? 's' : ''} sur ${badges.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Voir tout'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 6),
              itemCount: ordered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final item = ordered[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BadgeMedal(progress: item, size: 68, onTap: onSeeAll),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 72,
                      child: Text(
                        item.badge.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.unlocked ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
