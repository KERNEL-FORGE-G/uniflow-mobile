import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/phosphor.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/scope_selector.dart';
import '../widgets/uni_icons.dart';

class UEsListScreen extends ConsumerWidget {
  const UEsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(filteredUEsProvider);
    final scope = ref.watch(effectiveScopeProvider);
    final needsSelection = scope.selectable && !scope.filterByProgram;
    return Column(
      children: [
        GradientHeader(
          title: "Unités d'enseignement",
          subtitle: scope.label.isEmpty ? '${list.length} UEs' : '${scope.label} · ${list.length} UEs',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SearchField(
              hint: 'Rechercher une UE...',
              onChanged: (v) => ref.read(ueSearchProvider.notifier).state = v,
            ),
          ),
        ),
        // Administration et plateforme choisissent filière et niveau ; les
        // UE se rechargent par `scopedCoursesProvider` → `academicSyncProvider`.
        const ScopeSelector(levelOptional: true),
        Expanded(
          child: needsSelection
              ? const EmptyState(
                  icon: PhosphorIconsDuotone.funnel,
                  title: 'Choisissez une filière',
                  message: 'Les unités d\'enseignement s\'affichent pour la filière sélectionnée.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final u = list[i];
                    final c = subjectColor(u.code, colorHex: u.colorHex);
                    return InkWell(
                      onTap: () => context.go('/ues/${u.id}'),
                      borderRadius: BorderRadius.circular(14),
                      child: SectionCard(
                        child: Row(
                          children: [
                            // L'icône est dérivée de l'intitulé (`subjectIcon`) :
                            // « Réseaux » a un graphe, « Anglais » un
                            // traducteur, comme sur le web et le desktop.
                            IconTile(
                              icon: subjectIcon(u.title, code: u.code),
                              color: c,
                              index: i,
                              semanticLabel: u.title,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                      [
                                        u.code,
                                        if (u.credits > 0) '${u.credits} crédits',
                                        if (u.teacherName.isNotEmpty) u.teacherName,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            const PhosphorIcon(PhosphorIconsBold.caretRight, size: 18, color: AppColors.textSecondary),
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
