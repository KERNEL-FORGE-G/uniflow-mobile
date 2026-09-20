import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/scope_selector.dart';
import 'personal_space.dart' show dayLabel;

/// Emploi du temps officiel de la filière et du niveau du compte.
///
/// Les séances (`academic_schedules`) portent filière et niveau et se lisent
/// directement (voir `scopedSchedulesProvider`). Étudiant et délégué : leur
/// filière et leur niveau ; enseignant : ses séances ; administration et
/// plateforme : sélecteur filière → niveau alimenté par `academic_programs`.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  /// Jour sélectionné (1 = lundi … 7 = dimanche) : celui d'aujourd'hui au
  /// départ, ramené au lundi si l'on ouvre l'écran un dimanche sans cours.
  late int _day = DateTime.now().weekday;

  static const _days = ['LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI', 'DIMANCHE'];

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(effectiveScopeProvider);
    final schedules = ref.watch(scopedSchedulesProvider);
    final needsSelection = scope.selectable && !scope.filterByProgram;
    final courses = ref.watch(scopedCoursesProvider).value ?? const <AcademicCourse>[];

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Emploi du temps',
            subtitle: scope.label.isEmpty ? 'Semaine de cours' : scope.label,
          ),
          const ScopeSelector(),
          Expanded(
            child: scope.incomplete
                // Règle stricte : sans filière **et** niveau sur le profil, on
                // n'affiche rien plutôt que l'emploi du temps d'une autre
                // filière (capture du 2026-09-20 : un L1 ICT4D voyait MIB L3).
                ? const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'Profil académique incomplet',
                    message:
                        'Votre filière ou votre niveau n\'est pas renseigné : aucun emploi du temps ne peut être affiché. '
                        'Complétez votre profil ou contactez l\'administration de votre université.',
                  )
                : needsSelection
                    ? const EmptyState(
                        icon: Icons.filter_alt_outlined,
                        title: 'Choisissez une filière',
                        message: 'L\'emploi du temps s\'affiche pour la filière et le niveau sélectionnés.',
                      )
                    : schedules.when(
                        loading: () => const ShimmerList(cardHeight: 70),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: ErrorBanner(
                            message: 'L\'emploi du temps n\'a pas pu être chargé.\n$error',
                            onRetry: () => ref.invalidate(scopedSchedulesProvider),
                          ),
                        ),
                        data: (all) {
                          if (all.isEmpty) {
                            return EmptyState(
                              icon: Icons.calendar_month_outlined,
                              title: 'Aucun créneau',
                              message: scope.label.isEmpty
                                  ? 'Aucun emploi du temps n\'est publié pour le moment.'
                                  : 'Aucun emploi du temps n\'est publié pour ${scope.label}.',
                            );
                          }
                          final byDay = groupByDay(all);
                          final slots = byDay[_days[_day - 1]] ?? const <AcademicSchedule>[];
                          return Column(
                            children: [
                              _DayStrip(
                                selected: _day,
                                counts: {for (var i = 1; i <= 7; i++) i: byDay[_days[i - 1]]?.length ?? 0},
                                onSelect: (d) => setState(() => _day = d),
                              ),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: slots.isEmpty
                                      ? EmptyState(
                                          key: ValueKey('vide-$_day'),
                                          icon: Icons.free_breakfast_outlined,
                                          title: 'Pas de cours ${dayLabel(_days[_day - 1]).toLowerCase()}',
                                        )
                                      : Builder(
                                          key: ValueKey('jour-$_day'),
                                          builder: (context) {
                                            final blocks = groupByTimeSlot(slots);
                                            return StaggeredList(
                                              itemCount: blocks.length,
                                              itemBuilder: (context, index) =>
                                                  _TimeBlock(block: blocks[index], courses: courses),
                                            );
                                          },
                                        ),
                                ),
                              ),
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

/// Créneaux par jour (clé en majuscules, « LUNDI »…), triés par heure de
/// début. Les jours s'écrivent librement en base (« Lundi », « lundi ») :
/// la clé est normalisée. Fonction pure, testée.
Map<String, List<AcademicSchedule>> groupByDay(List<AcademicSchedule> slots) {
  final map = <String, List<AcademicSchedule>>{};
  for (final slot in slots) {
    map.putIfAbsent(normalizeDay(slot.dayOfWeek), () => []).add(slot);
  }
  for (final list in map.values) {
    list.sort((a, b) {
      final byStart = normalizeTime(a.startTime).compareTo(normalizeTime(b.startTime));
      if (byStart != 0) return byStart;
      final byType = (a.type ?? '').compareTo(b.type ?? '');
      return byType != 0 ? byType : a.courseCode.compareTo(b.courseCode);
    });
  }
  return map;
}

/// « 7:30 », « 07h30 », « 07:30:00 » → « 07:30 », pour que le tri des
/// créneaux ne place pas « 11:00 » avant « 7:30 » par comparaison de chaînes.
String normalizeTime(String raw) {
  final match = RegExp(r'^\s*(\d{1,2})\s*[:hH]\s*(\d{2})').firstMatch(raw);
  if (match == null) return raw.trim();
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

/// Séances d'un même jour regroupées par plage horaire (même début et même
/// fin), dans l'ordre des débuts.
///
/// Les emplois du temps réels de la Faculté des Sciences (2026-2027) placent
/// plusieurs séances sur un même créneau — TD par groupes (« TD Gr1 »,
/// « TD A »…), ou deux UE optionnelles en parallèle. Les lister une par une
/// répétait l'heure et cachait qu'il s'agissait d'un choix ; un bloc par
/// plage montre d'un coup d'œil ce qui se passe en même temps.
class TimeBlock {
  final String start;
  final String end;
  final List<AcademicSchedule> sessions;
  const TimeBlock({required this.start, required this.end, required this.sessions});

  bool get isParallel => sessions.length > 1;
}

List<TimeBlock> groupByTimeSlot(List<AcademicSchedule> daySlots) {
  final blocks = <String, TimeBlock>{};
  final order = <String>[];
  for (final slot in daySlots) {
    final start = normalizeTime(slot.startTime);
    final end = normalizeTime(slot.endTime);
    final key = '$start-$end';
    final existing = blocks[key];
    if (existing == null) {
      blocks[key] = TimeBlock(start: start, end: end, sessions: [slot]);
      order.add(key);
    } else {
      existing.sessions.add(slot);
    }
  }
  order.sort((a, b) => blocks[a]!.start.compareTo(blocks[b]!.start));
  return [for (final key in order) blocks[key]!];
}

/// Groupe de TD lu dans le type de séance (« TD Gr1 » → « Gr1 », « TD A » →
/// « A », « CM » → null). Sert à afficher une pastille de groupe.
String? tdGroupOf(String? type) {
  if (type == null) return null;
  final match = RegExp(r'^\s*(TD|TP)\s+(.+)$', caseSensitive: false).firstMatch(type.trim());
  return match?.group(2)?.trim();
}

/// « lundi », « Lundi », « LUNDI », « Monday », « 1 » → « LUNDI ».
String normalizeDay(String raw) {
  final value = raw.trim().toUpperCase();
  const aliases = {
    'MONDAY': 'LUNDI',
    'TUESDAY': 'MARDI',
    'WEDNESDAY': 'MERCREDI',
    'THURSDAY': 'JEUDI',
    'FRIDAY': 'VENDREDI',
    'SATURDAY': 'SAMEDI',
    'SUNDAY': 'DIMANCHE',
    '1': 'LUNDI',
    '2': 'MARDI',
    '3': 'MERCREDI',
    '4': 'JEUDI',
    '5': 'VENDREDI',
    '6': 'SAMEDI',
    '7': 'DIMANCHE',
  };
  return aliases[value] ?? value;
}

class _DayStrip extends StatelessWidget {
  final int selected;
  final Map<int, int> counts;
  final ValueChanged<int> onSelect;

  const _DayStrip({required this.selected, required this.counts, required this.onSelect});

  static const _short = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
      child: Row(
        children: [
          for (var d = 1; d <= 7; d++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _DayChip(
                  label: _short[d - 1],
                  count: counts[d] ?? 0,
                  selected: d == selected,
                  onTap: () => onSelect(d),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.logoGradient : null,
          color: selected ? null : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.transparent : AppColors.inputBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: count == 0
                    ? Colors.transparent
                    : selected
                        ? Colors.white
                        : AppColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un bloc horaire : l'heure une seule fois à gauche, une ou plusieurs
/// séances à droite. Plusieurs séances = mention explicite « en parallèle ».
class _TimeBlock extends StatelessWidget {
  final TimeBlock block;
  final List<AcademicCourse> courses;

  const _TimeBlock({required this.block, required this.courses});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${block.start}\n${block.end}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.primaryBlue, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.isParallel) ...[
                  Text(
                    '${block.sessions.length} séances en parallèle',
                    style: AppTextStyles.label.copyWith(color: AppColors.teal),
                  ),
                  const SizedBox(height: 6),
                ],
                for (var i = 0; i < block.sessions.length; i++) ...[
                  if (i > 0) const Divider(height: 14, color: AppColors.inputBorder),
                  _SessionLine(
                    slot: block.sessions[i],
                    course: courses
                        .where((c) =>
                            c.id == block.sessions[i].courseId ||
                            c.code.toUpperCase() == block.sessions[i].courseCode.toUpperCase())
                        .firstOrNull,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionLine extends StatelessWidget {
  final AcademicSchedule slot;
  final AcademicCourse? course;

  const _SessionLine({required this.slot, required this.course});

  @override
  Widget build(BuildContext context) {
    final type = (slot.type ?? course?.type ?? '').trim();
    // Le groupe vient du champ dédié quand la séance le porte (schéma du
    // 2026-09-20), sinon il est lu dans le type (« TD Gr1 »).
    final group = slot.group.isNotEmpty ? slot.group : tdGroupOf(type);
    final kind = group == null || !type.endsWith(group) ? type : type.substring(0, type.length - group.length).trim();
    final title = slot.courseName.isNotEmpty ? slot.courseName : (course?.name ?? slot.courseCode);
    final teacher = slot.teacherName.isNotEmpty ? slot.teacherName : (course?.teacherName ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h3,
              ),
            ),
            if (group != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Gr. $group',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.teal),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          [
            if (slot.courseCode.isNotEmpty) slot.courseCode,
            if (kind.isNotEmpty) kind,
            if (slot.classroom.isNotEmpty) slot.classroom,
            if (teacher.isNotEmpty) teacher,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
