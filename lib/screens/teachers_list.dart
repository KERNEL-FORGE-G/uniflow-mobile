import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TeachersListScreen extends ConsumerWidget {
  const TeachersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(filteredTeachersProvider);
    // Nombre de cours par enseignant, compté dans les UE du périmètre : le
    // champ `ueIds` d'autrefois n'était plus renseigné par personne et
    // affichait « 0 UE » pour tout le monde.
    final ues = ref.watch(uesProvider);
    return Column(
      children: [
        GradientHeader(
          title: 'Enseignants',
          subtitle: '${list.length} enseignants',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SearchField(
              hint: 'Rechercher un enseignant...',
              onChanged: (v) => ref.read(teacherSearchProvider.notifier).state = v,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: AppInsets.pageList,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = list[i];
              final courseCount = ues.where(t.teaches).length;
              final detail = [
                if (t.department.isNotEmpty) t.department,
                courseCount == 0 ? 'Aucune UE dans ce périmètre' : '$courseCount UE',
              ].join(' · ');
              return InkWell(
                onTap: () => context.go('/enseignants/${t.id}'),
                borderRadius: BorderRadius.circular(14),
                child: SectionCard(
                  child: Row(
                    children: [
                      Avatar(initials: t.initials, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      StatusBadge(label: personStatusLabel(t.status)),
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
