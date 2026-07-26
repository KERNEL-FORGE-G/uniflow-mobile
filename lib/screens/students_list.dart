import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class StudentsListScreen extends ConsumerWidget {
  const StudentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(filteredStudentsProvider);
    return Column(
      children: [
        GradientHeader(
          title: 'Étudiants',
          subtitle: '${students.length} étudiants inscrits',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SearchField(
              hint: 'Rechercher un étudiant...',
              onChanged: (v) => ref.read(studentSearchProvider.notifier).state = v,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = students[i];
              return InkWell(
                onTap: () => context.go('/etudiants/${s.id}'),
                borderRadius: BorderRadius.circular(14),
                child: SectionCard(
                  child: Row(
                    children: [
                      Avatar(initials: s.initials),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text('${s.matricule} · ${s.filiere} · ${s.niveau}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      StatusBadge(label: s.status),
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
