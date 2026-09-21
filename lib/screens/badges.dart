import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/phosphor.dart';

import '../models/badges.dart';
import '../providers/badges_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/badges.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/uni/uni_mascot.dart';

/// Les six badges de l'apprenant, avec la règle de chacun et où il en est.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(studentBadgesProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Mes badges',
            subtitle: 'Gagnés sur vos présences, notes, devoirs et forum',
          ),
          Expanded(
            child: badgesAsync.when(
              loading: () => const LoadingView(label: 'Calcul de vos badges…', mascot: true),
              error: (_, __) => const EmptyState(
                icon: PhosphorIconsDuotone.cloudSlash,
                title: 'Badges indisponibles',
                message: 'Vos données n\'ont pas pu être lues.',
                pose: UniPose.sorry,
              ),
              data: (badges) => _BadgesBody(badges: badges),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesBody extends StatelessWidget {
  final List<BadgeProgress> badges;
  const _BadgesBody({required this.badges});

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((b) => b.unlocked).length;
    final all = unlocked == badges.length && badges.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, uniClearance),
      children: [
        FadeSlideIn(
          index: 0,
          child: SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                UniMascot(
                  pose: all ? UniPose.celebrate : UniPose.pointing,
                  size: 78,
                  effects: all,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        all
                            ? 'Collection complète !'
                            : '$unlocked/${badges.length} badge${unlocked > 1 ? 's' : ''} gagné${unlocked > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        all
                            ? 'Vous avez tout gagné. Uni est très fier.'
                            : 'Chaque badge se gagne sur des faits réels : ils sont les mêmes sur le web et le desktop.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: badges.isEmpty ? 0 : unlocked / badges.length,
                          minHeight: 8,
                          backgroundColor: AppColors.inputBorder,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < badges.length; i++)
          FadeSlideIn(
            index: i + 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BadgeCard(progress: badges[i]),
            ),
          ),
      ],
    );
  }
}

/// Un badge sur toute la largeur : médaille, titre, règle ou message de
/// réussite, barre de progression et détail chiffré.
class _BadgeCard extends StatelessWidget {
  final BadgeProgress progress;
  const _BadgeCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final badge = progress.badge;
    final unlocked = progress.unlocked;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BadgeMedal(progress: progress, size: 84),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        badge.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: unlocked ? 'Gagné' : '${progress.percent} %',
                      backgroundColor: unlocked ? AppColors.success.withValues(alpha: 0.12) : AppColors.inputFill,
                      foregroundColor: unlocked ? AppColors.success : AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked ? badge.unlockedMessage : badge.rule,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.inputBorder,
                    color: unlocked ? AppColors.success : AppColors.teal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progress.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
