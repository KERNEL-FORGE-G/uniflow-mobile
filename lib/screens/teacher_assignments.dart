import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/appwrite_models.dart';
import '../models/assignment_models.dart';
import '../providers/providers.dart';
import '../repositories/assignment_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/motion.dart';
import '../widgets/phosphor.dart';

/// Devoirs, face enseignant : ses énoncés (brouillons compris), leur nombre de
/// rendus, et la création d'un nouveau devoir PDF/TD visant la filière et le
/// niveau du cours.
///
/// L'enseignant ne pouvait que consulter la liste des étudiants ; la création
/// d'énoncé existait dans le dépôt (`createAssignment`) sans aucun écran.
final teacherAssignmentsProvider = FutureProvider<List<Assignment>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.read(assignmentRepositoryProvider).listForTeacher(user.id);
});

final submissionCountProvider = FutureProvider.family<int, String>((ref, assignmentId) async {
  return (await ref.read(assignmentRepositoryProvider).listSubmissions(assignmentId)).length;
});

class TeacherAssignmentsScreen extends ConsumerWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(teacherAssignmentsProvider);
    return Scaffold(
      floatingActionButton: GradientFab(
        icon: PhosphorIconsFill.filePlus,
        label: 'Devoir',
        onPressed: () => _create(context, ref),
      ),
      body: Column(
        children: [
          const GradientHeader(title: 'Mes devoirs', subtitle: 'Énoncés publiés et rendus reçus'),
          Expanded(
            child: assignments.when(
              loading: () => const ShimmerList(),
              error: (error, _) => LoadErrorView(
                title: 'Vos devoirs n\'ont pas pu être chargés',
                error: error,
                onRetry: () => ref.invalidate(teacherAssignmentsProvider),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: PhosphorIconsDuotone.clipboardText,
                      title: 'Aucun devoir',
                      message:
                          'Publiez un premier énoncé : les apprenants de la filière et du niveau du cours le recevront.',
                    )
                  : StaggeredList(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: list.length,
                      itemBuilder: (context, index) => _AssignmentCard(
                        assignment: list[index],
                        onDelete: () => _delete(context, ref, list[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final courses = ref.read(scopedCoursesProvider).value ?? const <AcademicCourse>[];
    final mine = courses.where((c) => c.teacherId == user.id).toList();
    final draft = await showModalBottomSheet<Assignment>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AssignmentForm(teacher: user, courses: mine.isEmpty ? courses : mine),
    );
    if (draft == null || !context.mounted) return;
    try {
      await ref.read(assignmentRepositoryProvider).createAssignment(draft);
      ref.invalidate(teacherAssignmentsProvider);
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.success, title: 'Devoir publié', message: draft.title);
      }
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context,
            kind: FeedbackKind.failure, title: 'Publication impossible', message: '$error');
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Assignment assignment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer ce devoir ?'),
        content: Text('« ${assignment.title} » disparaîtra pour les apprenants.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(assignmentRepositoryProvider).deleteAssignment(assignment.id);
      ref.invalidate(teacherAssignmentsProvider);
      if (context.mounted) await showFeedbackSheet(context, kind: FeedbackKind.success, title: 'Devoir supprimé');
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context,
            kind: FeedbackKind.failure, title: 'Suppression impossible', message: '$error');
      }
    }
  }
}

/// Audience d'un devoir depuis le cours : sa filière et son niveau, dans le
/// JSON que lit `Assignment.targets`. Fonction pure, testée.
String audienceForCourse(AcademicCourse course) => jsonEncode({
      'filieres': [if (course.program.trim().isNotEmpty) course.program.trim()],
      'niveaux': [if (course.level.trim().isNotEmpty) course.level.trim()],
    });

class _AssignmentCard extends ConsumerWidget {
  final Assignment assignment;
  final VoidCallback onDelete;
  const _AssignmentCard({required this.assignment, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(submissionCountProvider(assignment.id));
    final due = DateFormat('dd/MM/yyyy à HH:mm').format(assignment.dueDate.toLocal());
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            // Mêmes glyphes que la liste des devoirs côté apprenant.
            child: PhosphorIcon(
              switch (assignment.type) {
                AssignmentType.quiz => PhosphorIconsDuotone.exam,
                AssignmentType.pdf => PhosphorIconsDuotone.filePdf,
                AssignmentType.td => PhosphorIconsDuotone.pencilSimpleLine,
              },
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assignment.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text('${assignment.courseCode} · échéance $due',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                Text(
                  count.when(
                    data: (n) => n == 0 ? 'Aucun rendu' : '$n rendu${n > 1 ? 's' : ''}',
                    loading: () => 'Rendus…',
                    error: (_, __) => 'Rendus indisponibles',
                  ),
                  style: AppTextStyles.label.copyWith(color: AppColors.teal),
                ),
              ],
            ),
          ),
          IconButton(
              tooltip: 'Supprimer',
              onPressed: onDelete,
              icon: const PhosphorIcon(PhosphorIconsBold.trash, color: AppColors.textMuted, size: 20)),
        ],
      ),
    );
  }
}

class _AssignmentForm extends StatefulWidget {
  final UniFlowUser teacher;
  final List<AcademicCourse> courses;
  const _AssignmentForm({required this.teacher, required this.courses});

  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _max = TextEditingController(text: '20');
  AcademicCourse? _course;
  AssignmentType _type = AssignmentType.td;
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  bool _allowLate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.courses.isNotEmpty) _course = widget.courses.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    setState(() => _due = DateTime(date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59));
  }

  void _submit() {
    final course = _course;
    if (course == null) {
      setState(() => _error = 'Aucun cours de votre périmètre : impossible de publier un devoir.');
      return;
    }
    if (_title.text.trim().length < 3) {
      setState(() => _error = 'Donnez un titre au devoir.');
      return;
    }
    final max = double.tryParse(_max.text.replaceAll(',', '.')) ?? 20;
    Navigator.of(context).pop(Assignment(
      id: '',
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      courseId: course.id,
      courseCode: course.code,
      teacherId: widget.teacher.id,
      teacherName: widget.teacher.name,
      type: _type,
      status: AssignmentStatus.published,
      dueDate: _due,
      maxScore: max,
      allowLate: _allowLate,
      audience: audienceForCourse(course),
    ));
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
            const Text('Nouveau devoir', style: AppTextStyles.h2),
            const SizedBox(height: 16),
            if (_error != null) ...[
              FeedbackBanner(kind: FeedbackKind.failure, message: _error!),
              const SizedBox(height: 12),
            ],
            if (widget.courses.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _course?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Cours', prefixIcon: PhosphorIcon(PhosphorIconsBold.bookOpenText, size: 20)),
                items: [
                  for (final c in widget.courses)
                    DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.code} · ${c.name} (${c.program} ${c.level})',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _course = widget.courses.where((c) => c.id == v).firstOrNull),
              ),
            const SizedBox(height: 12),
            TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Titre')),
            const SizedBox(height: 12),
            TextField(controller: _description, maxLines: 4, decoration: const InputDecoration(labelText: 'Consignes')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final t in [AssignmentType.td, AssignmentType.pdf])
                  ChoiceChip(
                    label: Text(t == AssignmentType.td ? 'Travaux dirigés' : 'Énoncé PDF'),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: AppColors.primary100,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _pickDue,
                    icon: const PhosphorIcon(PhosphorIconsBold.calendarBlank, size: 18),
                    label:
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(_due), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: _max,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Barème'))),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accepter les rendus en retard'),
              value: _allowLate,
              onChanged: (v) => setState(() => _allowLate = v),
            ),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Publier le devoir', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
