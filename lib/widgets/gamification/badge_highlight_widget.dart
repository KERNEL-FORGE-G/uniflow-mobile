import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/gamification.dart';
import '../../services/gamification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/phosphor.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BadgeHighlightWidget
//
//  Affiche :
//    • Dernier badge débloqué (mise en valeur, image réseau depuis Appwrite)
//    • Progression vers le prochain badge non débloqué
//    • Compteur total : X/200 badges
//  Hauteur fixe ~180 dp, pas de scroll interne.
// ─────────────────────────────────────────────────────────────────────────────

class BadgeHighlightWidget extends ConsumerWidget {
  const BadgeHighlightWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesWithProgressProvider);

    return badgesAsync.when(
      loading: () => _shimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (badges) {
        if (badges.isEmpty) return const SizedBox.shrink();

        final unlocked = badges.where((b) => b.unlocked).toList();
        final locked = badges.where((b) => !b.unlocked).toList();

        // Dernier badge débloqué
        final latest = unlocked.isNotEmpty ? unlocked.last : null;
        // Prochain badge le plus avancé
        final next = locked.isNotEmpty
            ? (locked..sort((a, b) => b.progressPercent.compareTo(a.progressPercent))).first
            : null;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête
                Row(
                  children: [
                    const Icon(PhosphorIconsBold.medal,
                        size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    const Text(
                      'Mes badges',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    _CounterChip(
                        unlocked: unlocked.length, total: badges.length),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Dernier badge débloqué
                    if (latest != null) ...[
                      Expanded(
                        child: _BadgeCard(
                          badge: latest.definition,
                          subtitle: 'Dernier badge',
                          unlocked: true,
                          imageFileId: latest.definition.imageFileId,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    // Prochain badge
                    if (next != null)
                      Expanded(
                        child: _BadgeCard(
                          badge: next.definition,
                          subtitle: 'Prochain : ${next.progressPercent}%',
                          unlocked: false,
                          imageFileId: next.definition.imageFileId,
                          progress: next.progressPercent / 100,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shimmer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CounterChip extends StatelessWidget {
  final int unlocked;
  final int total;
  const _CounterChip({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$unlocked/$total',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final BadgeDefinition badge;
  final String subtitle;
  final bool unlocked;
  final String imageFileId;
  final double? progress;

  const _BadgeCard({
    required this.badge,
    required this.subtitle,
    required this.unlocked,
    required this.imageFileId,
    this.progress,
  });

  Color get _rarityColor {
    switch (badge.rarity) {
      case BadgeRarity.common:    return const Color(0xFF6B7280);
      case BadgeRarity.uncommon:  return const Color(0xFF10B981);
      case BadgeRarity.rare:      return const Color(0xFF3B82F6);
      case BadgeRarity.epic:      return const Color(0xFF8B5CF6);
      case BadgeRarity.legendary: return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? color.withValues(alpha: 0.06)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? color.withValues(alpha: 0.3)
              : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image du badge depuis Appwrite
          _BadgeImage(
            fileId: imageFileId,
            size: 52,
            color: color,
            unlocked: unlocked,
          ),
          const SizedBox(height: 6),
          // Nom du badge
          Text(
            badge.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: unlocked ? color : Colors.grey[600],
            ),
          ),
          // Rarity
          Text(
            badge.rarity.name.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: unlocked ? 0.8 : 0.4),
              letterSpacing: 0.5,
            ),
          ),
          // Sous-titre / barre progression
          const SizedBox(height: 4),
          if (progress != null && !unlocked) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Affiche l'image du badge depuis le bucket Appwrite.
/// Si fileId est vide ou l'image échoue, affiche l'icône trophée.
class _BadgeImage extends StatelessWidget {
  final String fileId;
  final double size;
  final Color color;
  final bool unlocked;

  const _BadgeImage({
    required this.fileId,
    required this.size,
    required this.color,
    required this.unlocked,
  });

  /// Construit l'URL de prévisualisation Appwrite.
  /// La base est lue depuis l'env ou fallback cloud.
  static const _endpoint = 'https://cloud.appwrite.io/v1';
  static const _projectId = 'uniflow'; // remplacé par la vraie valeur à l'init
  static const _bucketId = 'uniflow_assets';

  String get _imageUrl {
    if (fileId.isEmpty) return '';
    return '$_endpoint/storage/buckets/$_bucketId/files/$fileId/view'
        '?project=$_projectId&mode=admin';
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cercle fond
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: unlocked ? 0.12 : 0.05),
              border: Border.all(
                  color: color.withValues(alpha: unlocked ? 0.4 : 0.15),
                  width: 2),
            ),
          ),
          // Image ou icône fallback
          if (url.isNotEmpty)
            ClipOval(
              child: Image.network(
                url,
                width: size * 0.7,
                height: size * 0.7,
                fit: BoxFit.contain,
                color: unlocked ? null : Colors.grey,
                colorBlendMode: unlocked ? null : BlendMode.saturation,
                errorBuilder: (_, __, ___) => Icon(
                  PhosphorIconsBold.trophy,
                  size: size * 0.45,
                  color: color.withValues(alpha: unlocked ? 1.0 : 0.3),
                ),
              ),
            )
          else
            Icon(
              PhosphorIconsBold.trophy,
              size: size * 0.45,
              color: color.withValues(alpha: unlocked ? 1.0 : 0.3),
            ),
          // Overlay verrouillé
          if (!unlocked)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF6B7280),
                ),
                child: const Icon(Icons.lock, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
