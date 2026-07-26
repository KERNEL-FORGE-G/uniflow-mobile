import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TeacherDetailScreen extends ConsumerWidget {
  final String id;
  const TeacherDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = findTeacher(ref, id);
    if (t == null) return const Center(child: Text('Enseignant introuvable'));
    final ues = ref.watch(uesProvider).where((u) => t.ueIds.contains(u.id)).toList();
    return Column(
      children: [
        GradientHeader(
          title: t.fullName,
          subtitle: t.department,
          trailing: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/enseignants'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Row(children: [
                  Avatar(initials: t.initials, color: AppColors.info, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(t.email, style: const TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        StatusBadge(label: t.status),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cours dispensés (${ues.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...ues.map((u) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.book_outlined, color: AppColors.teal),
                          title: Text(u.title),
                          subtitle: Text('${u.code} · ${u.credits} crédits'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/ues/${u.id}'),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
