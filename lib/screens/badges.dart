import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/badges.dart';
import '../providers/badges_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/badges.dart' show badgeColor, badgeIcon, BadgeCircle;
import '../widgets/common.dart';
import '../widgets/phosphor.dart';
import '../widgets/uni/uni_mascot.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(studentBadgesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: badgesAsync.when(
        loading: () => const LoadingView(label: 'Calcul de vos badges…', mascot: true),
        error: (_, __) => const EmptyState(
          icon: PhosphorIconsDuotone.cloudSlash,
          title: 'Badges indisponibles',
          message: 'Vos données n\'ont pas pu être lues.',
          pose: UniPose.sorry,
        ),
        data: (badges) => _BadgesBody(badges: badges),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _BadgesBody extends StatelessWidget {
  final List<BadgeProgress> badges;
  const _BadgesBody({required this.badges});

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((b) => b.unlocked).length;
    final all = unlocked == badges.length && badges.isNotEmpty;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildHeader(context, unlocked, all),
        _buildProgressBar(unlocked, badges.length),
        _buildGrid(badges),
        // Détail plein-écran pour le badge sélectionné (liste en-dessous de la grille)
        _buildDetailList(badges),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int unlocked, bool all) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF0A0A14)],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(PhosphorIconsBold.medal,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mes badges',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                Text(
                  all ? 'Collection complète !' : '$unlocked sur ${badges.length} obtenus',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5),
                ),
              ]),
              const Spacer(),
              if (all)
                UniMascot(pose: UniPose.celebrate, size: 52, effects: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int unlocked, int total) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progression globale',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                Text('${total == 0 ? 0 : (unlocked * 100 ~/ total)}%',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : unlocked / total,
                minHeight: 8,
                backgroundColor: const Color(0xFF1A1A2E),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<BadgeProgress> badges) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _BadgeTile(progress: badges[i], index: i),
          childCount: badges.length,
        ),
      ),
    );
  }

  Widget _buildDetailList(List<BadgeProgress> badges) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BadgeDetailCard(progress: badges[i]),
          ),
          childCount: badges.length,
        ),
      ),
    );
  }
}

// ─── Tuile grille ─────────────────────────────────────────────────────────────

class _BadgeTile extends StatefulWidget {
  final BadgeProgress progress;
  final int index;
  const _BadgeTile({required this.progress, required this.index});

  @override
  State<_BadgeTile> createState() => _BadgeTileState();
}

class _BadgeTileState extends State<_BadgeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    Future.delayed(
        Duration(milliseconds: 100 + widget.index * 80), _anim.forward);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final color = p.unlocked ? badgeColor(p.badge) : const Color(0xFF374151);
    final icon = badgeIcon(p.badge);

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeCircle(
              color: color,
              icon: icon,
              unlocked: p.unlocked,
              progress: p.progress.clamp(0.0, 1.0),
            ),
            const SizedBox(height: 8),
            Text(
              p.badge.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.unlocked ? Colors.white : const Color(0xFF6B7280),
                fontSize: 11.5,
                fontWeight: p.unlocked ? FontWeight.w700 : FontWeight.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte détail ─────────────────────────────────────────────────────────────

class _BadgeDetailCard extends StatelessWidget {
  final BadgeProgress progress;
  const _BadgeDetailCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final badge = progress.badge;
    final unlocked = progress.unlocked;
    final color = unlocked ? badgeColor(badge) : const Color(0xFF374151);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? color.withValues(alpha: 0.3)
              : const Color(0xFF2D2D4E),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          BadgeCircle(
            color: color,
            icon: badgeIcon(badge),
            unlocked: unlocked,
            progress: progress.progress.clamp(0.0, 1.0),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(badge.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: unlocked ? Colors.white : const Color(0xFF6B7280),
                        )),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: unlocked
                          ? color.withValues(alpha: 0.15)
                          : const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      unlocked ? 'Gagné ✓' : '${progress.percent}%',
                      style: TextStyle(
                        color: unlocked ? color : const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 5),
                Text(
                  unlocked ? badge.unlockedMessage : badge.rule,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: const Color(0xFF1F2937),
                    valueColor: AlwaysStoppedAnimation(
                        unlocked ? color : color.withValues(alpha: 0.4)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(progress.detail,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
