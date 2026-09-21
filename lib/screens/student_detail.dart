import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Fiche d'un étudiant, à partir de l'annuaire académique et de ses
/// inscriptions (`academic_enrollments`) — les deux lus sur Appwrite Cloud.
///
/// La fiche affichait un courriel et un téléphone toujours vides, hérités du
/// modèle de l'API intermédiaire : l'annuaire ne les porte pas, et exposer les
/// coordonnées d'un camarade à toute la promotion n'aurait de toute façon pas
/// sa place ici. On montre ce que la base sait : filière, niveau, université,
/// matricule, statut et cours suivis.
class StudentDetailScreen extends ConsumerWidget {
  final String id;
  const StudentDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = findStudent(ref, id);
    if (s == null) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Étudiant introuvable',
        message: 'Cet identifiant ne correspond à aucun étudiant du périmètre affiché.',
      );
    }
    final enrollments = ref.watch(enrollmentsProvider).where((e) => e.studentId == s.id).toList();
    final ues = ref.watch(uesProvider);
    final courses = <(Enrollment, UE?)>[
      for (final e in enrollments) (e, ues.where((u) => u.id == e.ueId).cast<UE?>().firstOrNull),
    ];
    final activeCount = enrollments.where((e) => e.isActive).length;

    return Column(
      children: [
        GradientHeader(
          title: s.fullName,
          subtitle: s.matricule.isEmpty ? '${s.filiere} · ${s.niveau}' : s.matricule,
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
                          Text(s.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${s.filiere} · ${s.niveau}', style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          StatusBadge(label: personStatusLabel(s.status)),
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
                    const Text('Informations', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _row(Icons.badge_outlined,
                        s.matricule.isEmpty ? 'Matricule non renseigné' : 'Matricule : ${s.matricule}'),
                    const SizedBox(height: 8),
                    _row(Icons.school_outlined, '${s.filiere} · ${s.niveau}'),
                    if (s.university.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _row(Icons.account_balance_outlined, s.university),
                    ],
                    const SizedBox(height: 8),
                    _row(Icons.how_to_reg_outlined,
                        '$activeCount ${activeCount == 1 ? 'inscription active' : 'inscriptions actives'}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cours suivis (${courses.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (courses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Aucune inscription enregistrée pour cet étudiant.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ...courses.map((pair) {
                      final (e, u) = pair;
                      final color = u == null ? AppColors.primaryBlue : _hex(u.colorHex);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Text(
                            u == null || u.code.isEmpty ? '?' : u.code.substring(0, u.code.length.clamp(0, 3)),
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(u?.title ?? 'Cours ${e.ueId}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(u == null ? 'Hors du périmètre affiché' : '${u.code} · ${u.credits} crédits'),
                        trailing: e.isActive ? const Icon(Icons.chevron_right) : StatusBadge(label: e.statusLabel),
                        onTap: u == null ? null : () => context.go('/ues/${u.id}'),
                      );
                    }),
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
        Icon(i, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(t)),
      ]);

  Color _hex(String h) => Color(int.parse('FF${h.substring(1)}', radix: 16));
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
