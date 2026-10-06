import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/gamification.dart';
import '../../services/gamification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/phosphor.dart';
import '../../widgets/uni/uni_mascot.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DailyReminderCard
//
//  Widget compact affiché sur le dashboard : programme du jour + quêtes actives.
//  Se positionne naturellement dans une liste verticale ou un SliverList.
//  Taille fixe (pas de scroll interne) — hauteur ~180 dp.
// ─────────────────────────────────────────────────────────────────────────────

/// Card principale « Programme du jour » — affichée sur l'accueil.
///
/// Affiche :
///   • XP actuel + barre de niveau
///   • Top 3 quêtes actives du jour
///   • Mascotte Uni (coin droit) avec pose contextuelle
class DailyReminderCard extends ConsumerWidget {
  final VoidCallback? onViewSchedule;
  const DailyReminderCard({super.key, this.onViewSchedule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpAsync = ref.watch(userXpProvider);
    final questsAsync = ref.watch(activeQuestsProvider);

    return xpAsync.when(
      loading: () => const _CardShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (xp) => questsAsync.when(
        loading: () => const _CardShimmer(),
        error: (_, __) => _CardContent(xp: xp, quests: const []),
        data: (quests) => _CardContent(xp: xp, quests: quests),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  final UserXp? xp;
  final List<QuestWithProgress> quests;

  const _CardContent({this.xp, required this.quests});

  @override
  Widget build(BuildContext context) {
    final todayQuests = quests.where((q) => !q.completed).take(3).toList();
    final level = xp?.level ?? 1;

    // Pose Uni selon le nombre de quêtes complétées
    final completedCount = quests.where((q) => q.completed).length;
    UniPose pose;
    if (completedCount == 0) {
      pose = UniPose.pointing;
    } else if (completedCount >= quests.length) {
      pose = UniPose.wave;
    } else {
      pose = UniPose.graduate;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Fond décoratif ───────────────────────────────────────────
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue.withValues(alpha: 0.05),
                ),
              ),
            ),
            // ── Contenu ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 100, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // En-tête : titre + niveau
                  Row(
                    children: [
                      const Icon(PhosphorIconsBold.sparkle,
                          size: 16, color: AppColors.primaryBlue),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Programme du jour',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _LevelChip(level: level),
                    ],
                  ),
                  // Barre XP
                  if (xp != null) ...[
                    const SizedBox(height: 8),
                    _XpBar(xp: xp!),
                  ],
                  const SizedBox(height: 10),
                  // Quêtes du jour
                  if (todayQuests.isEmpty)
                    Text(
                      'Toutes tes quêtes du jour sont terminées 🎉',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    )
                  else
                    ...todayQuests.map(
                      (q) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _QuestLine(quest: q),
                      ),
                    ),
                ],
              ),
            ),
            // ── Mascotte Uni (coin droit) ─────────────────────────────
            Positioned(
              right: 4,
              bottom: 0,
              child: UniMascot(pose: pose, size: 90),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LevelChip extends StatelessWidget {
  final int level;
  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'Niv. $level',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final UserXp xp;
  const _XpBar({required this.xp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${xp.xpInCurrentLevel} XP',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue),
            ),
            Text(
              '${xp.xpToNextLevel} XP',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: xp.progressPercent,
            minHeight: 6,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
          ),
        ),
      ],
    );
  }
}

class _QuestLine extends StatelessWidget {
  final QuestWithProgress quest;
  const _QuestLine({required this.quest});

  @override
  Widget build(BuildContext context) {
    final pct = quest.progressPercent;
    return Row(
      children: [
        // Mini icône progression
        SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: quest.ratio,
                strokeWidth: 2.5,
                backgroundColor: const Color(0xFFE5E7EB),
                color: pct >= 100 ? const Color(0xFF10B981) : AppColors.primaryBlue,
              ),
              if (pct >= 100)
                const Icon(Icons.check, size: 11, color: Color(0xFF10B981)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            quest.definition.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
              decoration: pct >= 100 ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          quest.progressLabel,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CardShimmer extends StatefulWidget {
  const _CardShimmer();

  @override
  State<_CardShimmer> createState() => _CardShimmerState();
}

class _CardShimmerState extends State<_CardShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        height: 130,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFF3F4F6), const Color(0xFFE5E7EB), _anim.value),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
