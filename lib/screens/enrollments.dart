import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Inscriptions aux cours, lues dans `academic_enrollments` (Appwrite Cloud).
///
/// Apprenant : ses propres inscriptions, cours par cours. Administration :
/// celles des cours du périmètre affiché, avec l'étudiant concerné. La liste
/// était auparavant alimentée par l'API REST intermédiaire, disparue avec la
/// migration : l'écran restait vide quoi qu'il arrive et ses onglets
/// (« Semaine actuelle », « Demandes ») ne correspondaient à rien en base.
class EnrollmentsScreen extends ConsumerStatefulWidget {
  const EnrollmentsScreen({super.key});
  @override
  ConsumerState<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

class _EnrollmentsScreenState extends ConsumerState<EnrollmentsScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(enrollmentsProvider);
    final sync = ref.watch(academicSyncProvider);
    final role = ref.watch(currentRoleProvider);
    final mine = role.isLearner;
    final active = all.where((e) => e.isActive).toList();
    final others = all.where((e) => !e.isActive).toList();
    final list = tab == 0 ? active : others;

    return Column(
      children: [
        GradientHeader(
          title: mine ? 'Mes inscriptions' : 'Inscriptions',
          subtitle: _subtitle(all.length, mine),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration:
                  BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  _tab('Actives (${active.length})', 0),
                  _tab('Autres (${others.length})', 1),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: sync.when(
            loading: () => all.isEmpty ? const LoadingView(label: 'Lecture des inscriptions…') : _list(list, mine),
            error: (error, _) => all.isEmpty
                ? LoadErrorView(
                    title: 'Les inscriptions n\'ont pas pu être lues',
                    error: error,
                    onRetry: () => ref.invalidate(academicSyncProvider),
                  )
                : _list(list, mine),
            data: (_) => _list(list, mine),
          ),
        ),
      ],
    );
  }

  String _subtitle(int count, bool mine) {
    if (count == 0) return mine ? 'Aucun cours pour l\'instant' : 'Aucune inscription dans ce périmètre';
    final noun = count == 1 ? 'inscription' : 'inscriptions';
    return mine ? '$count $noun à vos cours' : '$count $noun au total';
  }

  Widget _list(List<Enrollment> list, bool mine) {
    if (list.isEmpty) {
      return EmptyState(
        icon: tab == 0 ? Icons.how_to_reg_outlined : Icons.inbox_outlined,
        title: tab == 0 ? 'Aucune inscription active' : 'Rien d\'autre à signaler',
        message: tab == 0
            ? (mine
                ? 'Vos inscriptions aux cours de votre filière apparaîtront ici dès que l\'administration les aura enregistrées.'
                : 'Choisissez une filière et un niveau, ou attendez les premières inscriptions.')
            : 'Aucune inscription en attente, suspendue ou abandonnée.',
      );
    }
    final ues = ref.watch(uesProvider);
    final students = ref.watch(studentsProvider);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = list[i];
        final ue = ues.where((x) => x.id == e.ueId).cast<UE?>().firstOrNull;
        final student = students.where((x) => x.id == e.studentId).cast<Student?>().firstOrNull;
        return _EnrollmentTile(enrollment: e, ue: ue, student: mine ? null : student);
      },
    );
  }

  Widget _tab(String label, int i) {
    final active = tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  // Bleu de marque et non teal : l'onglet actif doit se lire
                  // comme le reste des éléments actifs de l'application.
                  color: active ? AppColors.primaryBlue : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ),
      ),
    );
  }
}

class _EnrollmentTile extends StatelessWidget {
  final Enrollment enrollment;
  final UE? ue;

  /// Étudiant concerné ; `null` sur la vue « Mes inscriptions », où c'est
  /// toujours l'utilisateur lui-même.
  final Student? student;

  const _EnrollmentTile({required this.enrollment, required this.ue, required this.student});

  @override
  Widget build(BuildContext context) {
    final course = ue;
    final color = course == null ? AppColors.primaryBlue : Color(int.parse('FF${course.colorHex.substring(1)}', radix: 16));
    final title = student?.fullName ?? course?.title ?? 'Cours ${enrollment.ueId}';
    final subtitle = student != null
        ? (course == null ? 'Cours ${enrollment.ueId}' : '${course.code} · ${course.title}')
        : (course == null ? 'Cours hors du périmètre affiché' : '${course.code} · ${course.credits} crédits');

    return InkWell(
      onTap: course == null ? null : () => context.go('/ues/${course.id}'),
      borderRadius: BorderRadius.circular(14),
      child: SectionCard(
        child: Row(
          children: [
            if (student != null)
              Avatar(initials: student!.initials)
            else
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  course == null || course.code.isEmpty ? '?' : course.code.substring(0, course.code.length.clamp(0, 3)),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(label: enrollment.statusLabel),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
