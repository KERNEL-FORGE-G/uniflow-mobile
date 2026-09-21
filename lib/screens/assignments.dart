import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/assignment_models.dart';
import '../providers/providers.dart';
import '../repositories/assignment_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'assignment_detail.dart';

/// Devoirs et rendus de l'élève, chargés d'un seul tenant.
///
/// Les deux requêtes partent ensemble : afficher la liste sans savoir ce qui a
/// déjà été rendu obligerait à peindre des cartes « à faire » qui se
/// transformeraient ensuite en « rendu », un clignotement à chaque ouverture.
class AssignmentBoard {
  final List<Assignment> assignments;
  final Map<String, Submission> submissions;

  const AssignmentBoard({
    required this.assignments,
    required this.submissions,
  });

  Submission? submissionFor(String assignmentId) => submissions[assignmentId];

  /// Reste à rendre, délai non dépassé.
  List<Assignment> get todo => assignments.where((a) => !submissions.containsKey(a.id) && a.acceptsSubmission).toList();

  /// Délai dépassé, rien de rendu : ce sont les seuls devoirs qu'un élève doit
  /// voir en rouge, et ils sont traités à part pour ne pas se noyer dans la
  /// liste des devoirs à venir.
  List<Assignment> get overdue =>
      assignments.where((a) => !submissions.containsKey(a.id) && !a.acceptsSubmission).toList();

  List<Assignment> get done => assignments.where((a) => submissions.containsKey(a.id)).toList();

  bool get isEmpty => assignments.isEmpty;
}

final assignmentBoardProvider = FutureProvider<AssignmentBoard>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const AssignmentBoard(assignments: [], submissions: {});
  }

  final repository = ref.read(assignmentRepositoryProvider);
  final assignments = await repository.listForStudent(
    filiere: user.program,
    niveau: user.level,
  );
  final submissions = await repository.listStudentSubmissions(user.id);

  return AssignmentBoard(
    assignments: assignments,
    submissions: {for (final submission in submissions) submission.assignmentId: submission},
  );
});

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(assignmentBoardProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Mes Devoirs',
            subtitle: 'Quiz, PDF et travaux dirigés',
          ),
          Expanded(
            child: boardAsync.when(
              data: (board) {
                if (board.isEmpty) {
                  return const EmptyState(
                    icon: Icons.task_alt,
                    title: 'Aucun devoir en attente',
                    message: 'Vous êtes à jour sur tous vos rendus.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(assignmentBoardProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (board.overdue.isNotEmpty) ...[
                        _SectionHeader(
                          label: 'En retard',
                          count: board.overdue.length,
                          color: AppColors.danger,
                        ),
                        for (final assignment in board.overdue) ...[
                          _AssignmentTile(
                            assignment: assignment,
                            submission: null,
                            onTap: () => _open(context, ref, assignment),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                      ],
                      if (board.todo.isNotEmpty) ...[
                        _SectionHeader(
                          label: 'À rendre',
                          count: board.todo.length,
                          color: AppColors.warning,
                        ),
                        for (final assignment in board.todo) ...[
                          _AssignmentTile(
                            assignment: assignment,
                            submission: null,
                            onTap: () => _open(context, ref, assignment),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                      ],
                      if (board.done.isNotEmpty) ...[
                        _SectionHeader(
                          label: 'Rendus',
                          count: board.done.length,
                          color: AppColors.success,
                        ),
                        for (final assignment in board.done) ...[
                          _AssignmentTile(
                            assignment: assignment,
                            submission: board.submissionFor(assignment.id),
                            onTap: () => _open(context, ref, assignment),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                );
              },
              loading: () => const LoadingView(label: 'Chargement de vos devoirs…'),
              error: (error, _) => LoadErrorView(
                title: 'Vos devoirs n\'ont pas pu être chargés',
                error: error,
                onRetry: () => ref.invalidate(assignmentBoardProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Assignment assignment) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssignmentDetailScreen(
          assignment: assignment,
          submission: ref.read(assignmentBoardProvider).valueOrNull?.submissionFor(assignment.id),
        ),
      ),
    );
    // Le devoir a pu être rendu pendant la visite : la liste doit se recalculer,
    // sans quoi la carte resterait indéfiniment dans « À rendre ».
    ref.invalidate(assignmentBoardProvider);
  }
}

/// Bandeau de section, coloré selon l'urgence : « En retard » ne doit pas
/// ressembler à « Rendus ».
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un devoir dans la liste.
class _AssignmentTile extends StatelessWidget {
  final Assignment assignment;
  final Submission? submission;
  final VoidCallback onTap;

  const _AssignmentTile({
    required this.assignment,
    required this.submission,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final urgency = _urgencyColor();

    return SectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: urgency.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_typeIcon(), color: urgency, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          assignment.courseCode.isEmpty
                              ? assignment.type.label
                              : '${assignment.courseCode} · ${assignment.type.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _badge(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: urgency),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _deadlineLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: urgency),
                    ),
                  ),
                  if (assignment.hasFile) ...[
                    const Icon(Icons.attach_file, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    const Text(
                      'Énoncé',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge() {
    if (submission != null) {
      if (submission!.score != null) {
        return StatusBadge(
          label: '${_format(submission!.score!)}/${_format(assignment.maxScore)}',
          backgroundColor: AppColors.success.withValues(alpha: 0.14),
          foregroundColor: AppColors.success,
        );
      }
      return StatusBadge(
        label: submission!.status.label,
        backgroundColor: AppColors.info.withValues(alpha: 0.14),
        foregroundColor: AppColors.info,
      );
    }
    if (!assignment.acceptsSubmission) {
      return StatusBadge(
        label: 'Manqué',
        backgroundColor: AppColors.danger.withValues(alpha: 0.14),
        foregroundColor: AppColors.danger,
      );
    }
    return StatusBadge(
      label: assignment.isPastDue ? 'Retard permis' : 'À faire',
      backgroundColor: AppColors.warning.withValues(alpha: 0.16),
      foregroundColor: const Color(0xFFB45309),
    );
  }

  IconData _typeIcon() => switch (assignment.type) {
        AssignmentType.quiz => Icons.quiz_outlined,
        AssignmentType.pdf => Icons.picture_as_pdf_outlined,
        AssignmentType.td => Icons.edit_note_outlined,
      };

  Color _urgencyColor() {
    if (submission != null) return AppColors.success;
    if (!assignment.acceptsSubmission) return AppColors.danger;
    // Moins de 48 h : le devoir passe en orange, c'est le seul signal qui
    // distingue « à faire cette semaine » de « à rendre demain ».
    if (assignment.dueDate.difference(DateTime.now()).inHours < 48) {
      return AppColors.warning;
    }
    return AppColors.primaryBlue;
  }

  String _deadlineLabel() {
    final due = assignment.dueDate;
    final now = DateTime.now();
    final days = due.difference(now).inDays;

    if (submission != null) {
      return 'Rendu le ${DateFormat('dd/MM/yyyy à HH:mm').format(submission!.submittedAt)}';
    }
    if (due.isBefore(now)) {
      final late = now.difference(due).inDays;
      return assignment.allowLate ? 'Délai dépassé de $late j — retard accepté' : 'Délai dépassé de $late j';
    }
    if (days == 0) return 'À rendre aujourd\'hui avant ${DateFormat('HH:mm').format(due)}';
    if (days == 1) return 'À rendre demain avant ${DateFormat('HH:mm').format(due)}';
    return 'À rendre le ${DateFormat('dd/MM/yyyy à HH:mm').format(due)} · dans $days j';
  }

  /// 12.0 s'affiche « 12 », 12.5 reste « 12,5 » : une note ronde ne doit pas
  /// traîner une décimale inutile.
  static String _format(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1).replaceAll('.', ',');
  }
}
