import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gamification.dart';
import '../services/gamification_service.dart';
import '../widgets/common.dart';
import '../widgets/uni/uni_mascot.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Écran Quêtes
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
//  Corps
// ─────────────────────────────────────────────────────────────────────────────

class _QuestsBody extends ConsumerStatefulWidget {
  final List<QuestWithProgress> quests;
  const _QuestsBody({required this.quests});

  @override
  ConsumerState<_QuestsBody> createState() => _QuestsBodyState();
}

class _QuestsBodyState extends ConsumerState<_QuestsBody> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daily = widget.quests.where((q) => q.definition.period == QuestPeriod.daily).toList();
    final monthly = widget.quests.where((q) => q.definition.period == QuestPeriod.monthly).toList();
    final yearly = widget.quests.where((q) => q.definition.period == QuestPeriod.yearly).toList();
    final all250 = ref.watch(all250QuestsProvider).valueOrNull ?? widget.quests;

    // Trier : en cours d'abord, puis non commencées, puis terminées
    _sortQuests(daily);
    _sortQuests(monthly);
    _sortQuests(yearly);
    _sortQuests(all250);

    return NestedScrollView(
      headerSliverBuilder: (context, inner) => [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuestsHeader(quests: widget.quests),
              const _Leaderboard(),
              Container(
                color: const Color(0xFFF0F7FF),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
              isScrollable: false,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'Jour (${daily.length})'),
                Tab(text: 'Mois (${monthly.length})'),
                Tab(text: 'Année (${yearly.length})'),
                const Tab(text: 'Tout (250)'),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tab,
        children: [
          _QuestsList(quests: daily, emptyLabel: 'Aucune quête du jour disponible'),
          _QuestsList(quests: monthly, emptyLabel: 'Aucune quête mensuelle disponible'),
          _QuestsList(quests: yearly, emptyLabel: 'Aucune quête annuelle disponible'),
          _QuestsList(quests: all250, emptyLabel: 'Catalogue de 250 quêtes en cours de chargement'),
        ],
      ),
    );
  }

  void _sortQuests(List<QuestWithProgress> list) {
    list.sort((a, b) {
      final aComp = a.completed;
      final bComp = b.completed;
      if (aComp != bComp) return aComp ? 1 : -1; // terminées en dernier
      final aStarted = (a.currentValue) > 0;
      final bStarted = (b.currentValue) > 0;
      if (aStarted != bStarted) return aStarted ? -1 : 1; // en cours d'abord
      return b.definition.xpReward - a.definition.xpReward; // plus gros XP d'abord
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Header dégradé
// ─────────────────────────────────────────────────────────────────────────────

class _QuestsHeader extends StatelessWidget {
  final List<QuestWithProgress> quests;
  const _QuestsHeader({required this.quests});

  @override
  Widget build(BuildContext context) {
    final completed = quests.where((q) => q.completed).length;
    final totalXp = quests.where((q) => q.completed).fold(0, (sum, q) => sum + q.definition.xpReward);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quêtes',
                    style:
                        TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(
                  '$completed terminées · $totalXp XP gagnés',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          // XP total badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text('$totalXp XP',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Leaderboard top 3
// ─────────────────────────────────────────────────────────────────────────────

class _Leaderboard extends ConsumerStatefulWidget {
  const _Leaderboard();

  @override
  ConsumerState<_Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends ConsumerState<_Leaderboard> {
  int _periodIndex = 0; // 0: semaine, 1: mois, 2: année

  @override
  Widget build(BuildContext context) {
    final provider = switch (_periodIndex) {
      1 => monthlyLeaderboardProvider,
      2 => annualLeaderboardProvider,
      _ => weeklyLeaderboardProvider,
    };
    final lbAsync = ref.watch(provider);

    final title = switch (_periodIndex) {
      1 => '🏆  Classement du mois',
      2 => '🏆  Classement annuel',
      _ => '🏆  Classement de la semaine',
    };

    return Container(
      color: const Color(0xFF1E3A8A),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              // Sélecteur de période
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PeriodChip(
                      label: 'Sem.',
                      selected: _periodIndex == 0,
                      onTap: () => setState(() => _periodIndex = 0),
                    ),
                    _PeriodChip(
                      label: 'Mois',
                      selected: _periodIndex == 1,
                      onTap: () => setState(() => _periodIndex = 1),
                    ),
                    _PeriodChip(
                      label: 'Année',
                      selected: _periodIndex == 2,
                      onTap: () => setState(() => _periodIndex = 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          lbAsync.when(
            loading: () => const SizedBox(
              height: 70,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white70),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (entries) {
              if (entries.isEmpty) return const SizedBox.shrink();
              final top3 = entries.take(3).toList();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: top3.asMap().entries.map((e) {
                  final rank = e.key;
                  final entry = e.value;
                  return _LeaderboardItem(entry: entry, rank: rank);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? const Color(0xFF1E3A8A) : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardItem extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank; // 0-based

  const _LeaderboardItem({required this.entry, required this.rank});

  static const _rankColors = [
    Color(0xFFFFD700), // or
    Color(0xFFC0C0C0), // argent
    Color(0xFFCD7F32), // bronze
  ];

  static const _rankSizes = [52.0, 44.0, 44.0];

  @override
  Widget build(BuildContext context) {
    final color = _rankColors[rank];
    final size = _rankSizes[rank];
    final isFirst = rank == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            if (isFirst) ...[
              const Positioned(
                top: -6,
                child: Text('👑', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              width: size,
              height: size,
              margin: EdgeInsets.only(top: isFirst ? 10 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 2.5),
              ),
              child: Center(
                child: Text(
                  entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontSize: isFirst ? 20 : 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isFirst ? Colors.white : Colors.white70,
                fontSize: isFirst ? 12 : 11,
                fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
        Text(
          '${entry.score} XP',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Résumé global
// ─────────────────────────────────────────────────────────────────────────────

class _QuestsSummaryRow extends StatelessWidget {
  final List<QuestWithProgress> quests;
  const _QuestsSummaryRow({required this.quests});

  @override
  Widget build(BuildContext context) {
    final completed = quests.where((q) => q.completed).length;
    final active = quests.where((q) => q.currentValue > 0 && !q.completed).length;
    final pct = quests.isEmpty ? 0.0 : completed / quests.length;

    return Row(children: [
      _SummaryChip(icon: Icons.check_circle_rounded, label: '$completed terminées', color: const Color(0xFF10B981)),
      const SizedBox(width: 8),
      _SummaryChip(icon: Icons.bolt_rounded, label: '$active en cours', color: const Color(0xFF3B82F6)),
      const Spacer(),
      _CircleProgress(pct: pct),
    ]);
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
        color: color.withValues(alpha: 0.12),
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
      SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(
          value: pct,
          strokeWidth: 4,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF0D9488)),
        ),
      ),
      Text('${(pct * 100).round()}%',
          style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Liste de quêtes
// ─────────────────────────────────────────────────────────────────────────────

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
          Text(emptyLabel, style: const TextStyle(color: Color(0xFF64748B), fontSize: 15)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: quests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _QuestCard(item: quests[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Carte quête
// ─────────────────────────────────────────────────────────────────────────────

class _QuestCard extends StatelessWidget {
  final QuestWithProgress item;
  const _QuestCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final q = item.definition;
    final p = item.progress;
    final isCompleted = item.completed;
    final current = item.currentValue;
    final target = item.targetValue;
    final pct = item.ratio;

    // Couleur depuis le catalogue (colorHex Appwrite) ou fallback catégorie
    final categoryColor = _parseColor(q.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: isCompleted ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Icône catégorie
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _questIcon(q.criteriaType),
                  color: categoryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              // Titre + XP
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                        )),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text('+${q.xpReward} XP',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
              // Statut + countdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(completed: isCompleted),
                  if (p?.resetAt != null && !isCompleted) ...[
                    const SizedBox(height: 3),
                    _CountdownTimer(resetAt: p!.resetAt!),
                  ],
                ],
              ),
            ]),

            const SizedBox(height: 10),

            Text(q.description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),

            const SizedBox(height: 10),

            // Barre de progression
            _ProgressBar(
              current: current,
              target: target,
              pct: pct,
              color: isCompleted ? const Color(0xFF10B981) : categoryColor,
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  IconData _questIcon(QuestCriteriaType type) => switch (type) {
        QuestCriteriaType.attendSession => Icons.event_available_rounded,
        QuestCriteriaType.submitAssignment => Icons.assignment_turned_in_rounded,
        QuestCriteriaType.earnGrade => Icons.school_rounded,
        QuestCriteriaType.postForum => Icons.forum_rounded,
        QuestCriteriaType.sendMessage => Icons.chat_bubble_rounded,
        QuestCriteriaType.loginStreak => Icons.local_fire_department_rounded,
        QuestCriteriaType.completeQuiz => Icons.quiz_rounded,
        QuestCriteriaType.perfectQuiz => Icons.military_tech_rounded,
        QuestCriteriaType.earnBadge => Icons.emoji_events_rounded,
        QuestCriteriaType.reachXp => Icons.star_rounded,
        QuestCriteriaType.rankTop => Icons.leaderboard_rounded,
        QuestCriteriaType.bestOfWeek => Icons.workspace_premium_rounded,
        QuestCriteriaType.bestOfMonth => Icons.workspace_premium_rounded,
        QuestCriteriaType.mostActive => Icons.groups_rounded,
        QuestCriteriaType.earlyBird => Icons.wb_sunny_rounded,
        QuestCriteriaType.nightOwl => Icons.nightlight_rounded,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Countdown timer (se met à jour chaque seconde)
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownTimer extends StatefulWidget {
  final DateTime resetAt;
  const _CountdownTimer({required this.resetAt});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final diff = widget.resetAt.difference(DateTime.now());
    if (mounted) setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const Text('Réinitialisation…', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)));
    }

    final d = _remaining.inDays;
    final h = _remaining.inHours.remainder(24);
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);

    final label = d > 0
        ? '${d}j ${h}h'
        : h > 0
            ? '${h}h ${m}min'
            : '${m}min ${s.toString().padLeft(2, '0')}s';

    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.timer_outlined, size: 9, color: Color(0xFF94A3B8)),
      const SizedBox(width: 2),
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets réutilisables
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool completed;
  const _StatusBadge({required this.completed});

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
          SizedBox(width: 3),
          Text('Terminé', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF3B82F6)),
        SizedBox(width: 3),
        Text('En cours', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int target;
  final double pct;
  final Color color;
  const _ProgressBar({
    required this.current,
    required this.target,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$current / $target', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        Text('${(pct * 100).round()}%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Erreur
// ─────────────────────────────────────────────────────────────────────────────

class _QuestsError extends StatelessWidget {
  final String message;
  const _QuestsError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UniMascot(pose: UniPose.graduate, size: 90),
              const SizedBox(height: 20),
              const Text(
                'Quêtes bientôt disponibles',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le catalogue de quêtes et défis du campus est en cours de synchronisation. Reviens bientôt pour accumuler des points XP !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Retour à l\'accueil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab header
// ─────────────────────────────────────────────────────────────────────────────

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext ctx, double shrink, bool overlaps) {
    return ColoredBox(color: const Color(0xFFF0F7FF), child: tabBar);
  }

  @override
  bool shouldRebuild(_TabDelegate old) => tabBar != old.tabBar;
}
