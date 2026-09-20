import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../providers/providers.dart';
import '../repositories/personal_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/motion.dart';

/// Espace personnel d'un compte indépendant (`PERSONAL`) : matières, tâches,
/// agenda et notes que l'utilisateur gère seul. Aucun de ces écrans n'est
/// proposé à un compte universitaire, et inversement (voir `navDestinations`).
///
/// Chaque action (créer, terminer, supprimer) affiche un retour animé de
/// succès ou d'échec : un bouton sans effet visible est la première chose que
/// l'on prend pour une panne.

// ---------------------------------------------------------------------------
// Matières
// ---------------------------------------------------------------------------

class PersonalSubjectsScreen extends ConsumerWidget {
  const PersonalSubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(personalSubjectsProvider);
    return Scaffold(
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        label: 'Matière',
        onPressed: () => _editSubject(context, ref),
      ),
      body: Column(
        children: [
          const GradientHeader(title: 'Mes matières', subtitle: 'Les cours que vous suivez, à votre façon'),
          Expanded(
            child: subjects.when(
              loading: () => const ShimmerList(),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(
                  message: 'Vos matières n\'ont pas pu être chargées.\n$error',
                  onRetry: () => ref.invalidate(personalSubjectsProvider),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'Aucune matière',
                      message: 'Ajoutez vos premières matières : tâches, créneaux et notes s\'y rattacheront.',
                    )
                  : StaggeredList(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final subject = list[index];
                        return _SubjectCard(
                          subject: subject,
                          onTap: () => _editSubject(context, ref, subject: subject),
                          onDelete: () => _deleteSubject(context, ref, subject),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSubject(BuildContext context, WidgetRef ref, {PersonalSubject? subject}) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SubjectForm(subject: subject),
    );
    if (data == null || !context.mounted) return;
    final owner = ref.read(currentUserProvider)?.id ?? '';
    final repo = ref.read(personalRepositoryProvider);
    try {
      if (subject == null) {
        await repo.createSubject(owner, data);
      } else {
        await repo.updateSubject(owner, subject.id, data);
      }
      ref.invalidate(personalSubjectsProvider);
      if (context.mounted) {
        await showFeedbackSheet(
          context,
          kind: FeedbackKind.success,
          title: subject == null ? 'Matière ajoutée' : 'Matière mise à jour',
          message: data['name']?.toString(),
        );
      }
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Enregistrement impossible', message: '$error');
      }
    }
  }

  Future<void> _deleteSubject(BuildContext context, WidgetRef ref, PersonalSubject subject) async {
    final confirmed = await _confirm(context, 'Supprimer « ${subject.name} » ?');
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(personalRepositoryProvider).deleteSubject(subject.id);
      ref.invalidate(personalSubjectsProvider);
      if (context.mounted) await showFeedbackSheet(context, kind: FeedbackKind.success, title: 'Matière supprimée');
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Suppression impossible', message: '$error');
      }
    }
  }
}

class _SubjectCard extends StatelessWidget {
  final PersonalSubject subject;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SubjectCard({required this.subject, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(subject.colorHex) ?? AppColors.teal;
    return SectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 48,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if ((subject.code ?? '').isNotEmpty) subject.code!,
                      if ((subject.instructor ?? '').isNotEmpty) subject.instructor!,
                      if ((subject.credits ?? 0) > 0) '${subject.credits} crédits',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Supprimer',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectForm extends StatefulWidget {
  final PersonalSubject? subject;
  const _SubjectForm({this.subject});

  @override
  State<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends State<_SubjectForm> {
  late final _name = TextEditingController(text: widget.subject?.name ?? '');
  late final _code = TextEditingController(text: widget.subject?.code ?? '');
  late final _instructor = TextEditingController(text: widget.subject?.instructor ?? '');
  late final _credits = TextEditingController(text: (widget.subject?.credits ?? 0) > 0 ? '${widget.subject!.credits}' : '');
  late String _color = widget.subject?.colorHex ?? '#0d9488';
  String? _error;

  static const _palette = ['#0d9488', '#1e3a8a', '#7c3aed', '#f59e0b', '#ef4444', '#10b981', '#3b82f6'];

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _instructor.dispose();
    _credits.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Donnez un nom à la matière.');
      return;
    }
    Navigator.of(context).pop({
      'name': _name.text,
      'code': _code.text,
      'instructor': _instructor.text,
      'credits': int.tryParse(_credits.text.trim()) ?? 0,
      'colorHex': _color,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: widget.subject == null ? 'Nouvelle matière' : 'Modifier la matière',
      error: _error,
      onSubmit: _submit,
      children: [
        TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code'))),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _credits,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Crédits'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _instructor, decoration: const InputDecoration(labelText: 'Enseignant')),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hex in _palette)
              GestureDetector(
                onTap: () => setState(() => _color = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: parseHexColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == hex ? AppColors.textPrimary : Colors.transparent, width: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tâches
// ---------------------------------------------------------------------------

class PersonalTasksScreen extends ConsumerWidget {
  const PersonalTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(personalTasksProvider);
    final subjects = ref.watch(personalSubjectsProvider).value ?? const <PersonalSubject>[];
    return Scaffold(
      floatingActionButton: GradientFab(
        icon: Icons.add_task_rounded,
        label: 'Tâche',
        onPressed: () => _createTask(context, ref, subjects),
      ),
      body: Column(
        children: [
          const GradientHeader(title: 'Mes tâches', subtitle: 'Devoirs, révisions, échéances'),
          Expanded(
            child: tasks.when(
              loading: () => const ShimmerList(),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(
                  message: 'Vos tâches n\'ont pas pu être chargées.\n$error',
                  onRetry: () => ref.invalidate(personalTasksProvider),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.task_alt_outlined,
                    title: 'Aucune tâche',
                    message: 'Notez ce que vous avez à faire : la liste se trie par échéance.',
                  );
                }
                final sorted = sortTasks(list);
                return StaggeredList(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final task = sorted[index];
                    return _TaskCard(
                      task: task,
                      subject: subjects.where((s) => s.id == task.courseId).firstOrNull,
                      onToggle: () => _toggleTask(context, ref, task),
                      onDelete: () => _deleteTask(context, ref, task),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTask(BuildContext context, WidgetRef ref, List<PersonalSubject> subjects) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TaskForm(subjects: subjects),
    );
    if (data == null || !context.mounted) return;
    final owner = ref.read(currentUserProvider)?.id ?? '';
    try {
      await ref.read(personalRepositoryProvider).createTask(owner, data);
      ref.invalidate(personalTasksProvider);
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.success, title: 'Tâche ajoutée', message: data['title']?.toString());
      }
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Enregistrement impossible', message: '$error');
      }
    }
  }

  Future<void> _toggleTask(BuildContext context, WidgetRef ref, PersonalTask task) async {
    final done = task.status == 'DONE';
    try {
      await ref.read(personalRepositoryProvider).updateTask(task.id, {'status': done ? 'TODO' : 'DONE'});
      ref.invalidate(personalTasksProvider);
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Mise à jour impossible', message: '$error');
      }
    }
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref, PersonalTask task) async {
    final confirmed = await _confirm(context, 'Supprimer « ${task.title} » ?');
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(personalRepositoryProvider).deleteTask(task.id);
      ref.invalidate(personalTasksProvider);
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Suppression impossible', message: '$error');
      }
    }
  }
}

/// Tâches à faire d'abord (échéance la plus proche en tête, sans échéance en
/// queue), tâches terminées ensuite. Fonction pure, testée.
List<PersonalTask> sortTasks(List<PersonalTask> tasks) {
  DateTime? due(PersonalTask t) => DateTime.tryParse(t.dueDate ?? '');
  final sorted = [...tasks];
  sorted.sort((a, b) {
    final doneA = a.status == 'DONE', doneB = b.status == 'DONE';
    if (doneA != doneB) return doneA ? 1 : -1;
    final da = due(a), db = due(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return sorted;
}

class _TaskCard extends StatelessWidget {
  final PersonalTask task;
  final PersonalSubject? subject;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard({required this.task, required this.subject, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final done = task.status == 'DONE';
    final due = DateTime.tryParse(task.dueDate ?? '')?.toLocal();
    final late = !done && due != null && due.isBefore(DateTime.now());
    final priority = task.priority ?? 2;
    final priorityColor = switch (priority) {
      4 => AppColors.danger,
      3 => AppColors.warning,
      1 => AppColors.textMuted,
      _ => AppColors.primaryBlue,
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: done ? 0.6 : 1,
      child: SectionCard(
        child: Row(
          children: [
            Checkbox(
              value: done,
              onChanged: (_) => onToggle(),
              shape: const CircleBorder(),
              activeColor: AppColors.success,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.copyWith(decoration: done ? TextDecoration.lineThrough : null),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (subject != null) subject!.name,
                      if (due != null) formatDueDate(due),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: late ? AppColors.danger : null),
                  ),
                ],
              ),
            ),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
            IconButton(
              tooltip: 'Supprimer',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskForm extends StatefulWidget {
  final List<PersonalSubject> subjects;
  const _TaskForm({required this.subjects});

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _subjectId;
  DateTime? _due;
  String _priority = 'MEDIUM';
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date != null) setState(() => _due = DateTime(date.year, date.month, date.day, 23, 59));
  }

  void _submit() {
    if (_title.text.trim().length < 2) {
      setState(() => _error = 'Donnez un titre à la tâche.');
      return;
    }
    Navigator.of(context).pop({
      'title': _title.text,
      'description': _description.text,
      'courseId': _subjectId ?? '',
      'dueDate': _due,
      'priority': _priority,
      'status': 'TODO',
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Nouvelle tâche',
      error: _error,
      onSubmit: _submit,
      children: [
        TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Titre')),
        const SizedBox(height: 12),
        if (widget.subjects.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Matière (facultatif)'),
            items: [
              for (final s in widget.subjects)
                DropdownMenuItem(value: s.id, child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_due == null ? 'Échéance' : formatDueDate(_due!), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: const [
                  DropdownMenuItem(value: 'LOW', child: Text('Basse')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Normale')),
                  DropdownMenuItem(value: 'HIGH', child: Text('Haute')),
                  DropdownMenuItem(value: 'URGENT', child: Text('Urgente')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'MEDIUM'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Détails (facultatif)'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Agenda
// ---------------------------------------------------------------------------

class PersonalAgendaScreen extends ConsumerWidget {
  const PersonalAgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(personalSchedulesProvider);
    final subjects = ref.watch(personalSubjectsProvider).value ?? const <PersonalSubject>[];
    return Scaffold(
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        label: 'Créneau',
        onPressed: () => _createSlot(context, ref, subjects),
      ),
      body: Column(
        children: [
          const GradientHeader(title: 'Mon agenda', subtitle: 'Votre semaine type'),
          Expanded(
            child: schedules.when(
              loading: () => const ShimmerList(cardHeight: 64),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(
                  message: 'Votre agenda n\'a pas pu être chargé.\n$error',
                  onRetry: () => ref.invalidate(personalSchedulesProvider),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: 'Agenda vide',
                    message: 'Ajoutez vos créneaux de cours : ils se rangent par jour de la semaine.',
                  );
                }
                final byDay = groupSchedulesByDay(list);
                final days = byDay.keys.toList();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final slots = byDay[day]!;
                    return FadeSlideIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionTitle(title: dayLabel(day)),
                            const SizedBox(height: 8),
                            for (final slot in slots)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SlotCard(
                                  slot: slot,
                                  subject: subjects.where((s) => s.id == slot.courseId).firstOrNull,
                                  onDelete: () => _deleteSlot(context, ref, slot),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSlot(BuildContext context, WidgetRef ref, List<PersonalSubject> subjects) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SlotForm(subjects: subjects),
    );
    if (data == null || !context.mounted) return;
    final owner = ref.read(currentUserProvider)?.id ?? '';
    try {
      await ref.read(personalRepositoryProvider).createSchedule(owner, data);
      ref.invalidate(personalSchedulesProvider);
      if (context.mounted) {
        await showFeedbackSheet(
          context,
          kind: FeedbackKind.success,
          title: 'Créneau ajouté',
          message: '${dayLabel(data['dayOfWeek'].toString())} ${data['startTime']} – ${data['endTime']}',
        );
      }
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Enregistrement impossible', message: '$error');
      }
    }
  }

  Future<void> _deleteSlot(BuildContext context, WidgetRef ref, PersonalSchedule slot) async {
    final confirmed = await _confirm(context, 'Supprimer ce créneau ?');
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(personalRepositoryProvider).deleteSchedule(slot.id);
      ref.invalidate(personalSchedulesProvider);
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Suppression impossible', message: '$error');
      }
    }
  }
}

/// Créneaux groupés par jour, du lundi au dimanche, triés par heure de début.
/// Un créneau au jour inconnu est rangé en fin. Fonction pure, testée.
Map<String, List<PersonalSchedule>> groupSchedulesByDay(List<PersonalSchedule> slots) {
  final sorted = [...slots]..sort((a, b) {
      final da = a.dayIndex < 0 ? 99 : a.dayIndex;
      final db = b.dayIndex < 0 ? 99 : b.dayIndex;
      if (da != db) return da.compareTo(db);
      return a.startTime.compareTo(b.startTime);
    });
  final map = <String, List<PersonalSchedule>>{};
  for (final slot in sorted) {
    final key = slot.dayIndex < 0 ? 'AUTRE' : PersonalSchedule.days[slot.dayIndex];
    map.putIfAbsent(key, () => []).add(slot);
  }
  return map;
}

String dayLabel(String day) => switch (day.toUpperCase()) {
      'LUNDI' => 'Lundi',
      'MARDI' => 'Mardi',
      'MERCREDI' => 'Mercredi',
      'JEUDI' => 'Jeudi',
      'VENDREDI' => 'Vendredi',
      'SAMEDI' => 'Samedi',
      'DIMANCHE' => 'Dimanche',
      _ => 'Autre',
    };

class _SlotCard extends StatelessWidget {
  final PersonalSchedule slot;
  final PersonalSubject? subject;
  final VoidCallback onDelete;

  const _SlotCard({required this.slot, required this.subject, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(subject?.colorHex) ?? AppColors.teal;
    return SectionCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${slot.startTime}\n${slot.endTime}',
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject?.name ?? 'Créneau', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
                if (slot.classroom.isNotEmpty || slot.type.isNotEmpty)
                  Text(
                    [if (slot.type.isNotEmpty) slot.type, if (slot.classroom.isNotEmpty) slot.classroom].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SlotForm extends StatefulWidget {
  final List<PersonalSubject> subjects;
  const _SlotForm({required this.subjects});

  @override
  State<_SlotForm> createState() => _SlotFormState();
}

class _SlotFormState extends State<_SlotForm> {
  final _classroom = TextEditingController();
  String? _subjectId;
  String _day = 'LUNDI';
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  String? _error;

  @override
  void dispose() {
    _classroom.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  void _submit() {
    if (_fmt(_end).compareTo(_fmt(_start)) <= 0) {
      setState(() => _error = 'L\'heure de fin doit suivre l\'heure de début.');
      return;
    }
    Navigator.of(context).pop({
      'courseId': _subjectId ?? '',
      'dayOfWeek': _day,
      'startTime': _fmt(_start),
      'endTime': _fmt(_end),
      'classroom': _classroom.text,
      'type': '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Nouveau créneau',
      error: _error,
      onSubmit: _submit,
      children: [
        if (widget.subjects.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Matière'),
            items: [
              for (final s in widget.subjects)
                DropdownMenuItem(value: s.id, child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: _day,
          decoration: const InputDecoration(labelText: 'Jour'),
          items: [for (final d in PersonalSchedule.days) DropdownMenuItem(value: d, child: Text(dayLabel(d)))],
          onChanged: (v) => setState(() => _day = v ?? 'LUNDI'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(true),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text('Début ${_fmt(_start)}', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(false),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text('Fin ${_fmt(_end)}', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _classroom, decoration: const InputDecoration(labelText: 'Salle (facultatif)')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notes personnelles
// ---------------------------------------------------------------------------

class PersonalGradesView extends ConsumerWidget {
  const PersonalGradesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(personalGradesProvider);
    final subjects = ref.watch(personalSubjectsProvider).value ?? const <PersonalSubject>[];
    return Scaffold(
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        label: 'Note',
        onPressed: () => _createGrade(context, ref, subjects),
      ),
      body: Column(
        children: [
          const GradientHeader(title: 'Mes notes', subtitle: 'Vos résultats, saisis par vous'),
          Expanded(
            child: grades.when(
              loading: () => const ShimmerList(),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(
                  message: 'Vos notes n\'ont pas pu être chargées.\n$error',
                  onRetry: () => ref.invalidate(personalGradesProvider),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.grade_outlined,
                    title: 'Aucune note',
                    message: 'Saisissez vos résultats : la moyenne pondérée se calcule ici.',
                  );
                }
                final average = weightedAverage(list);
                return StaggeredList(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: list.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return StatCard(
                        label: 'Moyenne pondérée',
                        value: '${average.toStringAsFixed(2)} / 20',
                        icon: Icons.insights_outlined,
                        color: average >= 10 ? AppColors.success : AppColors.danger,
                      );
                    }
                    final grade = list[index - 1];
                    final subject = subjects.where((s) => s.id == grade.courseId).firstOrNull;
                    final good = grade.outOf20 >= 10;
                    return SectionCard(
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: (good ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              grade.score.toStringAsFixed(grade.score % 1 == 0 ? 0 : 1),
                              style: TextStyle(color: good ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(grade.evaluationTitle.isEmpty ? 'Évaluation' : grade.evaluationTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
                                Text(
                                  '${subject?.name ?? 'Sans matière'} · coef. ${grade.coefficient.toStringAsFixed(grade.coefficient % 1 == 0 ? 0 : 1)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text('/ ${grade.maxScore.toInt()}', style: AppTextStyles.bodySmall),
                          IconButton(
                            tooltip: 'Supprimer',
                            onPressed: () => _deleteGrade(context, ref, grade),
                            icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createGrade(BuildContext context, WidgetRef ref, List<PersonalSubject> subjects) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GradeForm(subjects: subjects),
    );
    if (data == null || !context.mounted) return;
    final owner = ref.read(currentUserProvider)?.id ?? '';
    try {
      await ref.read(personalRepositoryProvider).createGrade(owner, data);
      ref.invalidate(personalGradesProvider);
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.success, title: 'Note enregistrée', message: '${data['score']} / ${data['maxScore']}');
      }
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Enregistrement impossible', message: '$error');
      }
    }
  }

  Future<void> _deleteGrade(BuildContext context, WidgetRef ref, PersonalGrade grade) async {
    final confirmed = await _confirm(context, 'Supprimer cette note ?');
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(personalRepositoryProvider).deleteGrade(grade.id);
      ref.invalidate(personalGradesProvider);
    } catch (error) {
      if (context.mounted) {
        await showFeedbackSheet(context, kind: FeedbackKind.failure, title: 'Suppression impossible', message: '$error');
      }
    }
  }
}

/// Moyenne sur 20 pondérée par les coefficients ; 0 sans note. Fonction pure, testée.
double weightedAverage(List<PersonalGrade> grades) {
  var total = 0.0, weight = 0.0;
  for (final g in grades) {
    if (g.maxScore <= 0) continue;
    final coef = g.coefficient <= 0 ? 1 : g.coefficient;
    total += g.outOf20 * coef;
    weight += coef;
  }
  return weight == 0 ? 0 : total / weight;
}

class _GradeForm extends StatefulWidget {
  final List<PersonalSubject> subjects;
  const _GradeForm({required this.subjects});

  @override
  State<_GradeForm> createState() => _GradeFormState();
}

class _GradeFormState extends State<_GradeForm> {
  final _title = TextEditingController();
  final _score = TextEditingController();
  final _max = TextEditingController(text: '20');
  final _coef = TextEditingController(text: '1');
  String? _subjectId;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _score.dispose();
    _max.dispose();
    _coef.dispose();
    super.dispose();
  }

  void _submit() {
    final score = double.tryParse(_score.text.replaceAll(',', '.'));
    final max = double.tryParse(_max.text.replaceAll(',', '.')) ?? 20;
    final coef = double.tryParse(_coef.text.replaceAll(',', '.')) ?? 1;
    if (score == null || score < 0 || score > max) {
      setState(() => _error = 'La note doit être comprise entre 0 et $max.');
      return;
    }
    Navigator.of(context).pop({
      'evaluationTitle': _title.text,
      'courseId': _subjectId ?? '',
      'score': score,
      'maxScore': max,
      'coefficient': coef,
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Nouvelle note',
      error: _error,
      onSubmit: _submit,
      children: [
        TextField(controller: _title, autofocus: true, decoration: const InputDecoration(labelText: 'Évaluation')),
        const SizedBox(height: 12),
        if (widget.subjects.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Matière'),
            items: [
              for (final s in widget.subjects)
                DropdownMenuItem(value: s.id, child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: TextField(controller: _score, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Note'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _max, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Sur'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _coef, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Coef.'))),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Utilitaires partagés
// ---------------------------------------------------------------------------

/// Feuille de saisie : titre, champs, bandeau d'erreur et bouton Enregistrer.
/// Le rembourrage du bas suit le clavier pour que le bouton reste visible.
class _SheetScaffold extends StatelessWidget {
  final String title;
  final String? error;
  final VoidCallback onSubmit;
  final List<Widget> children;

  const _SheetScaffold({required this.title, required this.error, required this.onSubmit, required this.children});

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
            Text(title, style: AppTextStyles.h2),
            const SizedBox(height: 16),
            if (error != null) ...[
              FeedbackBanner(kind: FeedbackKind.failure, message: error!),
              const SizedBox(height: 12),
            ],
            ...children,
            const SizedBox(height: 20),
            PrimaryButton(label: 'Enregistrer', onPressed: onSubmit),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirmer'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// « #0d9488 » → couleur ; `null` si la chaîne n'est pas une couleur hex.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final clean = hex.replaceFirst('#', '').trim();
  if (clean.length != 6 && clean.length != 8) return null;
  final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return value == null ? null : Color(value);
}

/// « Aujourd'hui », « Demain », « Il y a 3 j », « 12/10 »…
String formatDueDate(DateTime due, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d0 = DateTime(today.year, today.month, today.day);
  final d1 = DateTime(due.year, due.month, due.day);
  final diff = d1.difference(d0).inDays;
  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Demain';
  if (diff == -1) return 'Hier';
  if (diff < 0) return 'Il y a ${-diff} j';
  if (diff < 7) return 'Dans $diff j';
  return '${d1.day.toString().padLeft(2, '0')}/${d1.month.toString().padLeft(2, '0')}';
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
