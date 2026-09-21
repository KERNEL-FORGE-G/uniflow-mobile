import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/phosphor.dart';

import '../models/appwrite_models.dart';
import '../models/models.dart';
import '../offline/cached_providers.dart';
import '../providers/providers.dart';
import '../repositories/academic_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/uni_icons.dart';
import 'personal_space.dart' show dayLabel;
import 'schedule.dart' show groupByDay, normalizeTime;

/// Séances hebdomadaires d'un cours (`academic_schedules.courseId`), cache
/// d'abord. Par cours plutôt que par périmètre : l'administration ouvre une
/// UE sans avoir forcément choisi de filière dans le sélecteur.
final courseSchedulesProvider = StreamProvider.family<List<AcademicSchedule>, String>((ref, courseId) {
  if (courseId.isEmpty || ref.watch(authStatusProvider) != AuthStatus.signedIn) return Stream.value(const []);
  final repo = ref.read(academicRepositoryProvider);
  return cachedDocumentList<AcademicSchedule>(
    ref,
    collection: 'academic_schedules',
    fetch: () => repo.listAll('academic_schedules', [Query.equal('courseId', courseId)]),
    fromDocument: AcademicSchedule.fromDocument,
    select: (all) => all.where((s) => s.courseId == courseId).toList(),
  );
});

/// Fiche d'une UE, lue dans `academic_courses` et `academic_schedules`.
///
/// L'ancienne fiche affichait « CM 0h · TD 0h · TP 0h » : ces trois volumes
/// venaient de l'API intermédiaire et aucune source Appwrite ne les
/// renseigne. Le référentiel connaît le volume horaire total, les crédits,
/// l'enseignant, la salle et les créneaux : c'est cela qui est montré.
class UEDetailScreen extends ConsumerWidget {
  final String id;
  const UEDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = findUE(ref, id);
    if (u == null) {
      return const EmptyState(
        icon: PhosphorIconsDuotone.bookBookmark,
        title: 'UE introuvable',
        message: 'Ce cours ne fait pas partie de la filière et du niveau affichés.',
      );
    }
    final c = subjectColor(u.code, colorHex: u.colorHex);
    final sessions = ref.watch(courseSchedulesProvider(u.id));
    final teacher = ref.watch(teachersProvider).where((t) => t.teaches(u)).cast<Teacher?>().firstOrNull;

    return Column(
      children: [
        GradientHeader(
          title: u.title,
          subtitle: [u.code, if (u.credits > 0) '${u.credits} crédits', if (u.level.isNotEmpty) u.level].join(' · '),
          leading: IconTile(icon: subjectIcon(u.title, code: u.code), color: c, semanticLabel: u.title),
          trailing: IconButton(
            icon: const PhosphorIcon(PhosphorIconsBold.arrowLeft, color: Colors.white),
            tooltip: 'Retour aux cours',
            onPressed: () => context.go('/ues'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: AppInsets.pageList,
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('En bref', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _stat('Crédits', u.credits > 0 ? '${u.credits}' : '—', c),
                        const SizedBox(width: 8),
                        _stat('Volume', u.hours > 0 ? '${u.hours}h' : '—', c),
                        const SizedBox(width: 8),
                        _stat('Séances / sem.', sessions.maybeWhen(data: (s) => '${s.length}', orElse: () => '…'), c),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _row(UniIcons.teacher(),
                        u.teacherName.isNotEmpty ? u.teacherName : (teacher?.fullName ?? 'Enseignant non renseigné')),
                    const SizedBox(height: 8),
                    _row(
                        UniIcons.students(),
                        [if (u.program.isNotEmpty) u.program, if (u.level.isNotEmpty) u.level]
                            .join(' · ')
                            .ifEmpty('Filière non renseignée')),
                    if (u.classroom.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _row(UniIcons.room(), 'Salle ${u.classroom}'),
                    ],
                    if (u.type.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _row(PhosphorIconsDuotone.tag, u.type),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      u.description.trim().isEmpty
                          ? 'Aucune description dans le référentiel pour ce cours.'
                          : u.description,
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Créneaux de la semaine', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    sessions.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      error: (error, _) => const Text(
                        'Créneaux indisponibles pour le moment.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      data: (slots) => slots.isEmpty
                          ? const Text(
                              'Aucun créneau planifié pour ce cours dans l\'emploi du temps.',
                              style: TextStyle(color: AppColors.textSecondary),
                            )
                          : _WeekSlots(slots: slots, color: c),
                    ),
                    if (teacher != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => context.go('/enseignants/${teacher.id}'),
                          icon: const PhosphorIcon(PhosphorIconsBold.userFocus, size: 18),
                          label: Text('Fiche de ${teacher.fullName}'),
                        ),
                      ),
                    ],
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
        PhosphorIcon(i, size: 18, color: AppColors.textSecondary, duotoneSecondaryColor: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(t)),
      ]);

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _WeekSlots extends StatelessWidget {
  final List<AcademicSchedule> slots;
  final Color color;
  const _WeekSlots({required this.slots, required this.color});

  static const _order = ['LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI', 'DIMANCHE'];

  @override
  Widget build(BuildContext context) {
    final byDay = groupByDay(slots);
    final days = byDay.keys.toList()
      ..sort((a, b) {
        final ia = _order.indexOf(a);
        final ib = _order.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    return Column(
      children: [
        for (final day in days)
          for (final slot in byDay[day]!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 76,
                    child: Text(dayLabel(day), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${normalizeTime(slot.startTime)} – ${normalizeTime(slot.endTime)}'),
                        Text(
                          [
                            if (slot.classroom.isNotEmpty) 'Salle ${slot.classroom}',
                            if ((slot.type ?? '').isNotEmpty) slot.type!,
                            if (slot.group.isNotEmpty) slot.group,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
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

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

extension _IfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
