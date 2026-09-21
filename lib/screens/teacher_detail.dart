import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Fiche d'un enseignant : annuaire académique + cours d'`academic_courses`
/// qu'il dispense (par identifiant, sinon par nom — voir [Teacher.teaches]).
///
/// La liste des cours était vide pour tout le monde : elle dépendait d'un
/// champ `ueIds` que seule l'API intermédiaire renseignait, et le courriel
/// affiché sous le nom était une chaîne vide.
class TeacherDetailScreen extends ConsumerWidget {
  final String id;
  const TeacherDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = findTeacher(ref, id);
    if (t == null) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Enseignant introuvable',
        message: 'Cet identifiant ne correspond à aucun enseignant du périmètre affiché.',
      );
    }
    final ues = ref.watch(uesProvider).where(t.teaches).toList()..sort((a, b) => a.code.compareTo(b.code));
    final programs = ues.map((u) => u.program).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final levels = ues.map((u) => u.level).where((l) => l.isNotEmpty).toSet().toList()..sort();
    final subtitle = t.department.isNotEmpty
        ? t.department
        : programs.isNotEmpty
            ? programs.join(' · ')
            : (t.university.isNotEmpty ? t.university : 'Enseignant');

    return Column(
      children: [
        GradientHeader(
          title: t.fullName,
          subtitle: subtitle,
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
                        Text(
                          ues.isEmpty
                              ? 'Aucun cours dans le périmètre affiché'
                              : '${ues.length} cours${levels.isEmpty ? '' : ' · ${levels.join(', ')}'}',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        StatusBadge(label: personStatusLabel(t.status)),
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
                    if (ues.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Aucun cours ne lui est rattaché dans la filière et le niveau affichés. '
                          'Changez de filière dans « Mes cours » pour élargir la recherche.',
                          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                        ),
                      ),
                    ...ues.map((u) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.book_outlined, color: AppColors.primaryBlue),
                          title: Text(u.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${u.code} · ${u.credits} crédits'
                            '${u.level.isEmpty ? '' : ' · ${u.level}'}',
                          ),
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
