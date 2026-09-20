import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appwrite_models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'personal_space.dart' show dayLabel;

/// Emploi du temps officiel de la filière et du niveau du compte.
///
/// L'onglet existait dans la table de navigation sans écran derrière. Les
/// créneaux (`academic_schedules`) ne portent ni filière ni niveau : ils se
/// rattachent à un cours, et c'est le cours qui décide (voir
/// `scopedSchedulesProvider`). Un enseignant voit tous les niveaux de sa
/// filière, l'administration toute l'université.
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
    final scope = ref.watch(academicScopeProvider);
    final schedules = ref.watch(scopedSchedulesProvider);
    final courses = ref.watch(scopedCoursesProvider).value ?? const <AcademicCourse>[];

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Emploi du temps',
            subtitle: scope.label.isEmpty ? 'Semaine de cours' : scope.label,
          ),
          Expanded(
            child: schedules.when(
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
                            : StaggeredList(
                                key: ValueKey('jour-$_day'),
                                itemCount: slots.length,
                                itemBuilder: (context, index) {
                                  final slot = slots[index];
                                  final course = courses.where((c) => c.id == slot.courseId || c.code.toUpperCase() == slot.courseCode.toUpperCase()).firstOrNull;
                                  return _SlotCard(slot: slot, course: course);
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
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
  }
  return map;
}

/// « lundi », « Lundi », « LUNDI », « Monday », « 1 » → « LUNDI ».
String normalizeDay(String raw) {
  final value = raw.trim().toUpperCase();
  const aliases = {
    'MONDAY': 'LUNDI', 'TUESDAY': 'MARDI', 'WEDNESDAY': 'MERCREDI', 'THURSDAY': 'JEUDI',
    'FRIDAY': 'VENDREDI', 'SATURDAY': 'SAMEDI', 'SUNDAY': 'DIMANCHE',
    '1': 'LUNDI', '2': 'MARDI', '3': 'MERCREDI', '4': 'JEUDI', '5': 'VENDREDI', '6': 'SAMEDI', '7': 'DIMANCHE',
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

class _SlotCard extends StatelessWidget {
  final AcademicSchedule slot;
  final AcademicCourse? course;

  const _SlotCard({required this.slot, required this.course});

  @override
  Widget build(BuildContext context) {
    final type = (slot.type ?? course?.type ?? '').trim();
    return SectionCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${slot.startTime}\n${slot.endTime}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course?.name ?? slot.courseCode,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (slot.courseCode.isNotEmpty) slot.courseCode,
                    if (type.isNotEmpty) type,
                    if (slot.classroom.isNotEmpty) slot.classroom,
                    if ((course?.teacherName ?? '').isNotEmpty) course!.teacherName!,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
