import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/phosphor.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/scope_selector.dart';
import '../widgets/uni_icons.dart';

class UEsListScreen extends ConsumerStatefulWidget {
  const UEsListScreen({super.key});

  @override
  ConsumerState<UEsListScreen> createState() => _UEsListScreenState();
}

class _UEsListScreenState extends ConsumerState<UEsListScreen> {
  String _filter = 'Tous';
  final Set<String> _offlineCourseIds = {'ue1'};

  static const List<String> _filters = ['Tous', 'En cours', 'Terminés'];

  int _progressFor(int index, String id) {
    final hash = id.codeUnits.fold<int>(index * 17, (a, b) => a + b);
    final pct = 45 + (hash % 56); // 45..100
    return pct >= 95 ? 100 : pct;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(filteredUEsProvider);
    final scope = ref.watch(effectiveScopeProvider);
    final needsSelection = scope.selectable && !scope.filterByProgram;

    final list = [
      for (var i = 0; i < all.length; i++)
        if (_filter == 'Tous' ||
            (_filter == 'Terminés' && _progressFor(i, all[i].id) >= 100) ||
            (_filter == 'En cours' && _progressFor(i, all[i].id) < 100))
          (index: i, ue: all[i], progress: _progressFor(i, all[i].id)),
    ];

    return Column(
      children: [
        GradientHeader(
          title: "Mes Cours & UEs",
          subtitle: scope.label.isEmpty ? '${all.length} UEs' : '${scope.label} · ${all.length} UEs',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SearchField(
              hint: 'Rechercher une UE...',
              onChanged: (v) => ref.read(ueSearchProvider.notifier).state = v,
            ),
          ),
        ),
        const ScopeSelector(levelOptional: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final chip in _filters)
                InkWell(
                  onTap: () => setState(() => _filter = chip),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filter == chip ? AppColors.primaryBlue : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _filter == chip ? AppColors.primaryBlue : AppColors.inputBorder,
                      ),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _filter == chip ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: needsSelection
              ? const EmptyState(
                  icon: PhosphorIconsDuotone.funnel,
                  title: 'Choisissez une filière',
                  message: 'Les unités d\'enseignement s\'affichent pour la filière sélectionnée.',
                )
              : list.isEmpty
                  ? EmptyState(
                      icon: PhosphorIconsDuotone.books,
                      title: 'Aucun cours dans « $_filter »',
                      message: 'Changez de filtre pour voir l\'ensemble de vos unités d\'enseignement.',
                    )
                  : ListView.separated(
                      padding: AppInsets.pageList,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final entry = list[i];
                        final u = entry.ue;
                        final pct = entry.progress;
                        final isOffline = _offlineCourseIds.contains(u.id);
                        final c = subjectColor(u.code, colorHex: u.colorHex);
                        return InkWell(
                          onTap: () => context.go('/ues/${u.id}'),
                          borderRadius: BorderRadius.circular(14),
                          child: SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconTile(
                                      icon: subjectIcon(u.title, code: u.code),
                                      color: c,
                                      index: entry.index,
                                      semanticLabel: u.title,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              u.code,
                                              if (u.credits > 0) '${u.credits} crédits',
                                              if (u.teacherName.isNotEmpty) u.teacherName,
                                            ].join(' · '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PhosphorIcon(
                                      PhosphorIconsBold.caretRight,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  pct >= 100 ? 'Terminé' : 'Progression du cours',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$pct%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: pct >= 100 ? AppColors.success : c,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: pct / 100,
                                              minHeight: 6,
                                              backgroundColor: c.withValues(alpha: 0.12),
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                pct >= 100 ? AppColors.success : c,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isOffline) {
                                            _offlineCourseIds.remove(u.id);
                                          } else {
                                            _offlineCourseIds.add(u.id);
                                          }
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isOffline
                                                  ? 'Support PDF retiré du cache hors-ligne (${u.code}).'
                                                  : 'Supports PDF de ${u.code} enregistrés hors-ligne.',
                                            ),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isOffline
                                              ? AppColors.teal.withValues(alpha: 0.14)
                                              : AppColors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: isOffline ? AppColors.teal : AppColors.inputBorder,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PhosphorIcon(
                                              isOffline
                                                  ? PhosphorIconsFill.checkCircle
                                                  : PhosphorIconsBold.downloadSimple,
                                              size: 13,
                                              color: isOffline ? AppColors.teal : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isOffline ? 'PDF OK' : 'PDF',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: isOffline ? AppColors.teal : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
