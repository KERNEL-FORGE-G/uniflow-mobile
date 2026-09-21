import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../providers/providers.dart';
import '../repositories/grading_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/motion.dart';

/// Saisie des notes, face enseignant/administration de l'onglet « Notes ».
///
/// Un enseignant n'avait aucun moyen de saisir une note depuis le mobile alors
/// que le service `/academic-grades` existait. Il choisit un cours de son
/// périmètre, une évaluation (existante ou nouvelle), puis note chaque
/// apprenant inscrit ; chaque enregistrement affiche son retour.
class GradingScreen extends ConsumerStatefulWidget {
  const GradingScreen({super.key});

  @override
  ConsumerState<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends ConsumerState<GradingScreen> {
  String? _courseId;
  String? _evaluation;

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(scopedCoursesProvider);
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentRoleProvider);
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Saisie des notes', subtitle: 'Par cours et par évaluation'),
          Expanded(
            child: courses.when(
              loading: () => const ShimmerList(),
              error: (error, _) => LoadErrorView(
                title: 'Cours indisponibles',
                error: error,
                onRetry: () => ref.invalidate(scopedCoursesProvider),
              ),
              data: (list) {
                // Le serveur refuse un enseignant sur un cours qui n'est pas le
                // sien (COURSE_ASSIGNMENT_DENIED) : ne pas le proposer.
                final mine = role == UniFlowRole.teacher && user != null
                    ? list.where((c) => c.teacherId == user.id).toList()
                    : list;
                if (mine.isEmpty) {
                  return const EmptyState(
                    icon: Icons.grading_outlined,
                    title: 'Aucun cours à noter',
                    message: 'Aucun cours de votre périmètre ne vous est affecté pour l\'instant.',
                  );
                }
                final course = mine.where((c) => c.id == _courseId).firstOrNull ?? mine.first;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: DropdownButtonFormField<String>(
                        initialValue: course.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Cours', prefixIcon: Icon(Icons.menu_book_outlined, size: 20)),
                        items: [
                          for (final c in mine)
                            DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.code} · ${c.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() {
                          _courseId = v;
                          _evaluation = null;
                        }),
                      ),
                    ),
                    Expanded(
                        child: _RosterView(
                            course: course,
                            evaluation: _evaluation,
                            onEvaluation: (e) => setState(() => _evaluation = e))),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterView extends ConsumerWidget {
  final AcademicCourse course;
  final String? evaluation;
  final ValueChanged<String?> onEvaluation;

  const _RosterView({required this.course, required this.evaluation, required this.onEvaluation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(courseRosterProvider(course.id));
    return roster.when(
      loading: () => const ShimmerList(),
      error: (error, _) => LoadErrorView(
        title: 'Liste des inscrits indisponible',
        error: error,
        onRetry: () => ref.invalidate(courseRosterProvider(course.id)),
      ),
      data: (data) {
        if (data.students.isEmpty) {
          return const EmptyState(
              icon: Icons.people_outline,
              title: 'Aucun inscrit',
              message: 'Aucun apprenant n\'est inscrit à ce cours.');
        }
        final titles = data.evaluationTitles;
        final current = evaluation ?? (titles.isNotEmpty ? titles.first : null);
        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                children: [
                  for (final t in titles)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t),
                        selected: current == t,
                        onSelected: (_) => onEvaluation(t),
                        selectedColor: AppColors.primary100,
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Évaluation'),
                    onPressed: () async {
                      final title = await _askTitle(context);
                      if (title != null && title.trim().isNotEmpty) onEvaluation(title.trim());
                    },
                  ),
                ],
              ),
            ),
            if (current == null)
              const Expanded(
                child: EmptyState(
                  icon: Icons.post_add_outlined,
                  title: 'Créez une évaluation',
                  message: 'CC1, TP, Examen… puis notez chaque apprenant.',
                ),
              )
            else
              Expanded(
                child: StaggeredList(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: data.students.length,
                  itemBuilder: (context, index) {
                    final student = data.students[index];
                    final grade = data.gradeOf(student.userId, current);
                    return _StudentRow(
                      student: student,
                      grade: grade,
                      onTap: () => _enterGrade(context, ref,
                          course: course, student: student, evaluation: current, existing: grade),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<String?> _askTitle(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Nouvelle évaluation'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Intitulé (CC1, TP, Examen…)')),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(d).pop(controller.text), child: const Text('Créer')),
        ],
      ),
    );
  }

  Future<void> _enterGrade(
    BuildContext context,
    WidgetRef ref, {
    required AcademicCourse course,
    required RosterStudent student,
    required String evaluation,
    RosterGrade? existing,
  }) async {
    final result = await showModalBottomSheet<_GradeInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GradeSheet(student: student, evaluation: evaluation, existing: existing),
    );
    if (result == null || !context.mounted) return;
    final repo = ref.read(gradingRepositoryProvider);
    try {
      if (result.delete && existing != null) {
        await repo.delete(courseId: course.id, studentId: student.userId, gradeId: existing.id);
      } else {
        await repo.upsert(
          courseId: course.id,
          studentId: student.userId,
          evaluationTitle: evaluation,
          score: result.score,
          maxScore: result.maxScore,
          coefficient: result.coefficient,
          type: result.type,
        );
      }
      ref.invalidate(courseRosterProvider(course.id));
      if (context.mounted) {
        await showFeedbackSheet(
          context,
          kind: FeedbackKind.success,
          title: result.delete ? 'Note supprimée' : 'Note enregistrée',
          message: result.delete ? student.name : '${student.name} · ${result.score}/${result.maxScore}',
        );
      }
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context,
            kind: FeedbackKind.failure, title: 'Saisie refusée', message: error.toString());
      }
    }
  }
}

class _StudentRow extends StatelessWidget {
  final RosterStudent student;
  final RosterGrade? grade;
  final VoidCallback onTap;
  const _StudentRow({required this.student, required this.grade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final good = grade != null && grade!.score * 2 >= grade!.maxScore;
    return SectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
                  Text(
                    [if (student.matricule.isNotEmpty) student.matricule, if (student.role == 'DELEGATE') 'Délégué']
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: grade == null
                    ? AppColors.surfaceMuted
                    : (good ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: grade == null ? AppColors.inputBorder : Colors.transparent),
              ),
              child: Text(
                grade == null ? 'Noter' : '${grade!.score}/${grade!.maxScore}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: grade == null ? AppColors.textSecondary : (good ? AppColors.success : AppColors.danger),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeInput {
  final int score;
  final int maxScore;
  final int coefficient;
  final String type;
  final bool delete;
  const _GradeInput({this.score = 0, this.maxScore = 20, this.coefficient = 1, this.type = 'CC', this.delete = false});
}

class _GradeSheet extends StatefulWidget {
  final RosterStudent student;
  final String evaluation;
  final RosterGrade? existing;
  const _GradeSheet({required this.student, required this.evaluation, required this.existing});

  @override
  State<_GradeSheet> createState() => _GradeSheetState();
}

class _GradeSheetState extends State<_GradeSheet> {
  late final _score = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.score}');
  late final _max = TextEditingController(text: '${widget.existing?.maxScore ?? 20}');
  late final _coef = TextEditingController(text: '${widget.existing?.coefficient ?? 1}');
  late String _type = widget.existing?.type ?? 'CC';
  String? _error;

  @override
  void dispose() {
    _score.dispose();
    _max.dispose();
    _coef.dispose();
    super.dispose();
  }

  void _submit() {
    final max = int.tryParse(_max.text.trim()) ?? 20;
    final score = int.tryParse(_score.text.trim());
    final coef = int.tryParse(_coef.text.trim()) ?? 1;
    final invalid = validateGradeInput(score: score, maxScore: max, coefficient: coef);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    Navigator.of(context).pop(_GradeInput(score: score!, maxScore: max, coefficient: coef, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.student.name, style: AppTextStyles.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(widget.evaluation, style: AppTextStyles.bodySmall),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _score,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Note (entier)'),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: _max,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Sur'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: _coef,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Coef.'))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final t in const ['CC', 'TP', 'TD', 'EXAMEN', 'RATTRAPAGE'])
                  ChoiceChip(
                      label: Text(t),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                      selectedColor: AppColors.primary100),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Le serveur n\'accepte que des notes entières : pour une demi-note, notez sur 40.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Enregistrer', onPressed: _submit),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(const _GradeInput(delete: true)),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Supprimer cette note'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Règles du serveur (`integer()` : note 0..barème, barème 1..1000,
/// coefficient 1..100), appliquées avant l'appel. Fonction pure, testée.
String? validateGradeInput({required int? score, required int maxScore, required int coefficient}) {
  if (maxScore < 1 || maxScore > 1000) return 'Le barème doit être compris entre 1 et 1000.';
  if (score == null) return 'Saisissez une note entière.';
  if (score < 0 || score > maxScore) return 'La note doit être comprise entre 0 et $maxScore.';
  if (coefficient < 1 || coefficient > 100) return 'Le coefficient doit être compris entre 1 et 100.';
  return null;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
