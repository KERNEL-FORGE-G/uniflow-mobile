import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/gamification.dart';
import '../../services/gamification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/phosphor.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  QuestSummaryWidget
//
//  Affiche un résumé compact des quêtes quotidiennes, hebdo et mensuelles.
//  Conçu pour le dashboard, hauteur fixe ~220 dp.
//  Pas de scroll interne — s'intègre dans la liste verticale de l'accueil.
// ─────────────────────────────────────────────────────────────────────────────

enum _QuestTab { daily, weekly, monthly }

class QuestSummaryWidget extends ConsumerStatefulWidget {
  const QuestSummaryWidget({super.key});

  @override
  ConsumerState<QuestSummaryWidget> createState() => _QuestSummaryWidgetState();
}

class _QuestSummaryWidgetState extends ConsumerState<QuestSummaryWidget> {
  _QuestTab _tab = _QuestTab.daily;

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête avec onglets ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(PhosphorIconsBold.trophy, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 6),
                const Text(
                  'Mes quêtes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _TabPills(
                      current: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // ── Contenu selon onglet ─────────────────────────────────────
          _TabBody(tab: _tab),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TabPills extends StatelessWidget {
  final _QuestTab current;
  final ValueChanged<_QuestTab> onChanged;

  const _TabPills({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            label: 'Jour',
            active: current == _QuestTab.daily,
            onTap: () => onChanged(_QuestTab.daily),
          ),
          _Pill(
            label: 'Semaine',
            active: current == _QuestTab.weekly,
            onTap: () => onChanged(_QuestTab.weekly),
          ),
          _Pill(
            label: 'Mois',
            active: current == _QuestTab.monthly,
            onTap: () => onChanged(_QuestTab.monthly),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TabBody extends ConsumerWidget {
  final _QuestTab tab;
  const _TabBody({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = switch (tab) {
      _QuestTab.daily => activeQuestsProvider,
      _QuestTab.weekly => weeklyQuestsProvider,
      _QuestTab.monthly => monthlyQuestsProvider,
    };

    final async = ref.watch(provider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Impossible de charger les quêtes.', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
      data: (quests) {
        if (quests.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Aucune quête pour cette période 🎉', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          );
        }

        final pending = quests.where((q) => !q.completed).take(5).toList();
        final done = quests.where((q) => q.completed).length;
        final total = quests.length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre progression globale
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _GlobalBar(done: done, total: total),
            ),
            // Liste des quêtes en attente
            ...pending.map(
              (q) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _QuestTile(quest: q),
              ),
            ),
            if (done > 0 && pending.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  '$done quête${done > 1 ? 's' : ''} terminée${done > 1 ? 's' : ''} 🏆',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GlobalBar extends StatelessWidget {
  final int done;
  final int total;

  const _GlobalBar({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? const Color(0xFF10B981) : AppColors.primaryBlue,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$done/$total',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }
}

class _QuestTile extends StatelessWidget {
  final QuestWithProgress quest;
  const _QuestTile({required this.quest});

  String get _periodEmoji {
    switch (quest.definition.period) {
      case QuestPeriod.daily:
        return '📅';
      case QuestPeriod.weekly:
        return '📆';
      case QuestPeriod.monthly:
        return '🗓️';
      case QuestPeriod.yearly:
        return '🏆';
      case QuestPeriod.oneshot:
        return '⭐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = quest.ratio;
    final isComplete = quest.completed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isComplete ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icône période
          Text(_periodEmoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          // Titre + barre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.definition.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isComplete ? const Color(0xFF10B981) : Colors.grey[800],
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? const Color(0xFF10B981) : AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // XP reward
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '+${quest.definition.xpReward} XP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isComplete ? const Color(0xFF10B981) : AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
