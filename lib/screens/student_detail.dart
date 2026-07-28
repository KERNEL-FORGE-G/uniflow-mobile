import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class StudentDetailScreen extends ConsumerWidget {
  final String id;
  const StudentDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = findStudent(ref, id);
    if (s == null) return const Center(child: Text('Étudiant introuvable'));
    final ues =
        ref.watch(uesProvider).where((u) => s.ueIds.contains(u.id)).toList();
    return Column(
      children: [
        GradientHeader(
          title: s.fullName,
          subtitle: s.matricule,
          trailing: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/etudiants'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Row(
                  children: [
                    Avatar(initials: s.initials, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.fullName,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${s.filiere} · ${s.niveau}',
                              style:
                                  const TextStyle(color: AppColors.textMuted)),
                          const SizedBox(height: 8),
                          StatusBadge(label: s.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informations',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _row(Icons.email_outlined, s.email),
                    const SizedBox(height: 8),
                    _row(Icons.phone_outlined, s.phone),
                    const SizedBox(height: 8),
                    _row(Icons.badge_outlined, 'Matricule : ${s.matricule}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UEs inscrites (${ues.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...ues.map((u) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                _hex(u.colorHex).withValues(alpha: 0.15),
                            child: Text(u.code.substring(0, 3),
                                style: TextStyle(
                                    color: _hex(u.colorHex),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
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

  Widget _row(IconData i, String t) => Row(children: [
        Icon(i, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(t)),
      ]);

  Color _hex(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));
}
