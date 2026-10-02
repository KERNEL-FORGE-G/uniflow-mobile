import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gamification.dart';
import '../services/gamification_service.dart';
import '../widgets/common.dart';
import '../widgets/uni/uni_mascot.dart';

// ─── Écran Quêtes ────────────────────────────────────────────────────────────

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(activeQuestsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: questsAsync.when(
        loading: () => const LoadingView(label: 'Chargement des quêtes…', mascot: true),
        error: (e, _) => _QuestsError(message: e.toString()),
        data: (quests) => _QuestsBody(quests: quests),
      ),
    );
  }
}

// ─── Corps ───────────────────────────────────────────────────────────────────

class _QuestsBody extends StatefulWidget {
  final List<QuestWithProgress> quests;
  const _QuestsBody({required this.quests});

  @override
  State<_QuestsBody> createState() => _QuestsBodyState();
}

class _QuestsBodyState extends State<_QuestsBody>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekly  = widget.quests.where((q) => q.definition.period == QuestPeriod.weekly).toList();
    final monthly = widget.quests.where((q) => q.definition.period == QuestPeriod.monthly).toList();
    final annual  = widget.quests.where((q) => q.definition.period == QuestPeriod.yearly).toList();

    return NestedScrollView(
      headerSliverBuilder: (context, inner) => [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientHeader(
                title: 'Quêtes',
                subtitle: '${widget.quests.length} quêtes actives',
              ),
              Container(
                color: const Color(0xFFF0F7FF),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: _QuestsSummaryRow(quests: widget.quests),
              ),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabDelegate(
            TabBar(
              controller: _tab,
              labelColor: const Color(0xFF1E3A8A),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF0D9488),
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Semaine (${weekly.length})'),
                Tab(text: 'Mois (${monthly.length})'),
                Tab(text: 'Année (${annual.length})'),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tab,
        children: [
          _QuestsList(quests: weekly,  emptyLabel: 'Aucune quête hebdomadaire'),
          _QuestsList(quests: monthly, emptyLabel: 'Aucune quête mensuelle'),
          _QuestsList(quests: annual,  emptyLabel: 'Aucune quête annuelle'),
        ],
      ),
    );
  }
}

// ─── Résumé global ───────────────────────────────────────────────────────────

class _QuestsSummaryRow extends StatelessWidget {
  final List<QuestWithProgress> quests;
  const _QuestsSummaryRow({required this.quests});

  @override
  Widget build(BuildContext context) {
    final completed = quests.where((q) => q.progress?.completed == true).length;
    final active    = quests.where((q) => q.progress?.completed != true && q.progress != null).length;
    final pct = quests.isEmpty ? 0.0 : completed / quests.length;

    return Row(
      children: [
        _SummaryChip(icon: Icons.check_circle_rounded, label: '$completed terminées',
            color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        _SummaryChip(icon: Icons.bolt_rounded, label: '$active en cours',
            color: const Color(0xFF3B82F6)),
        const Spacer(),
        _CircleProgress(pct: pct),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _CircleProgress extends StatelessWidget {
  final double pct;
  const _CircleProgress({required this.pct});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      SizedBox(width: 44, height: 44,
        child: CircularProgressIndicator(
          value: pct,
          strokeWidth: 4,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF0D9488)),
        ),
      ),
      Text('${(pct * 100).round()}%',
          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
    ]);
  }
}

// ─── Liste de quêtes ─────────────────────────────────────────────────────────

class _QuestsList extends StatelessWidget {
  final List<QuestWithProgress> quests;
  final String emptyLabel;
  const _QuestsList({required this.quests, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const UniMascot(pose: UniPose.wave, size: 80),
          const SizedBox(height: 12),
          Text(emptyLabel,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 15)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: quests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _QuestCard(item: quests[i]),
    );
  }
}

// ─── Carte quête ─────────────────────────────────────────────────────────────

class _QuestCard extends StatelessWidget {
  final QuestWithProgress item;
  const _QuestCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final q = item.definition;
    final p = item.progress;
    final isCompleted = item.completed;
    final isExpired   = p?.resetAt != null && p!.resetAt!.isBefore(DateTime.now()) && !isCompleted;
    final current = item.currentValue;
    final target  = item.targetValue;
    final pct = item.ratio;

    final categoryColor = _categoryColor(q.criteriaType.name);
    final icon = _categoryIcon(q.criteriaType.name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: isCompleted
            ? Border.all(color: const Color(0xFF10B981).withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Icône catégorie
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: categoryColor, size: 20),
            ),
            const SizedBox(width: 10),
            // Titre + XP
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(q.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isExpired ? Colors.grey : const Color(0xFF1E293B),
                    )),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 2),
                  Text('${q.xpReward} XP',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            // Badge statut
            _StatusBadge(status: isCompleted ? 'completed' : (isExpired ? 'expired' : 'active')),
          ]),

          const SizedBox(height: 10),

          // Description
          Text(q.description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              maxLines: 2, overflow: TextOverflow.ellipsis),

          const SizedBox(height: 10),

          // Barre de progression
          _ProgressBar(current: current, target: target, pct: pct,
              color: isCompleted ? const Color(0xFF10B981) : categoryColor),
        ]),
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'attendance':  return const Color(0xFF3B82F6);
      case 'academic':    return const Color(0xFF8B5CF6);
      case 'social':      return const Color(0xFFF59E0B);
      case 'forum':       return const Color(0xFF10B981);
      case 'streak':      return const Color(0xFFEF4444);
      case 'leaderboard': return const Color(0xFFEC4899);
      case 'library':     return const Color(0xFF0EA5E9);
      default:            return const Color(0xFF6366F1);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'attendance':  return Icons.event_available_rounded;
      case 'academic':    return Icons.school_rounded;
      case 'social':      return Icons.groups_rounded;
      case 'forum':       return Icons.forum_rounded;
      case 'streak':      return Icons.local_fire_department_rounded;
      case 'leaderboard': return Icons.leaderboard_rounded;
      case 'library':     return Icons.menu_book_rounded;
      default:            return Icons.emoji_events_rounded;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label; IconData icon;
    switch (status) {
      case 'completed':
        bg = const Color(0xFF10B981).withOpacity(0.12);
        fg = const Color(0xFF10B981);
        label = 'Terminé';
        icon = Icons.check_circle_rounded;
        break;
      case 'expired':
        bg = Colors.grey.withOpacity(0.12);
        fg = Colors.grey;
        label = 'Expiré';
        icon = Icons.timer_off_rounded;
        break;
      default:
        bg = const Color(0xFF3B82F6).withOpacity(0.12);
        fg = const Color(0xFF3B82F6);
        label = 'En cours';
        icon = Icons.bolt_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int target;
  final double pct;
  final Color color;
  const _ProgressBar({required this.current, required this.target,
      required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$current / $target',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        Text('${(pct * 100).round()}%',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 6,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}

// ─── Erreur ───────────────────────────────────────────────────────────────────

class _QuestsError extends StatelessWidget {
  final String message;
  const _QuestsError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const UniMascot(pose: UniPose.sorry, size: 80),
          const SizedBox(height: 16),
          const Text('Impossible de charger les quêtes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ]),
      ),
    );
  }
}

// ─── Tab header ──────────────────────────────────────────────────────────────

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);

  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext ctx, double shrink, bool overlaps) {
    return ColoredBox(color: const Color(0xFFF0F7FF), child: tabBar);
  }

  @override
  bool shouldRebuild(_TabDelegate old) => tabBar != old.tabBar;
}
