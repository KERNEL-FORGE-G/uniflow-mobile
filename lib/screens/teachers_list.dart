import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TeachersListScreen extends ConsumerWidget {
  const TeachersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(filteredTeachersProvider);
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
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = list[i];
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
                            Text('${t.department} · ${t.ueIds.length} UE',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      StatusBadge(label: t.status),
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
