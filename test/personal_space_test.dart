import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/repositories/personal_repository.dart';
import 'package:uniflow_mobile/screens/personal_space.dart';
import 'package:uniflow_mobile/screens/schedule.dart';

/// L'espace personnel partage ses documents avec le web : les charges utiles
/// doivent porter exactement les champs que le web écrit et relit.
void main() {
  models.Document doc(Map<String, dynamic> data) => models.Document(
        $id: 'd1',
        $sequence: '1',
        $collectionId: 'c',
        $databaseId: 'uniflow',
        $createdAt: '2026-09-20T08:00:00.000+00:00',
        $updatedAt: '2026-09-20T08:00:00.000+00:00',
        $permissions: const [],
        data: data,
      );

  group('charges utiles', () {
    test('subjectPayload écrit name ET title, et la couleur par défaut du web', () {
      final p = subjectPayload('me', {'title': ' Algèbre ', 'credits': '4'});
      expect(p['ownerId'], 'me');
      expect(p['name'], 'Algèbre');
      expect(p['title'], 'Algèbre');
      expect(p['credits'], 4);
      expect(p['colorHex'], '#0d9488');
    });

    test('taskPayload traduit la priorité en entier 1–4 et l\'échéance en ISO', () {
      final due = DateTime.utc(2026, 10, 1, 23, 59);
      final p = taskPayload('me', {'title': 'Réviser', 'priority': 'URGENT', 'dueDate': due});
      expect(p['priority'], 4);
      expect(p['status'], 'TODO');
      expect(p['dueDate'], '2026-10-01T23:59:00.000Z');
      expect(taskPayload('me', {'title': 'x', 'priority': 'inconnue'})['priority'], 2);
      expect(taskPayload('me', {'title': 'x', 'priority': 9})['priority'], 4);
    });

    test('gradePayload stocke score, barème et coefficient en chaînes, et double subjectId/courseId', () {
      final p = gradePayload('me', {'evaluationTitle': 'CC1', 'courseId': 's1', 'score': 14.5, 'maxScore': 20, 'coefficient': 2});
      expect(p['score'], '14.5');
      expect(p['maxScore'], '20');
      expect(p['coefficient'], '2');
      expect(p['subjectId'], 's1');
      expect(p['courseId'], 's1');
      expect(p['label'], 'CC1');
    });

    test('schedulePayload encode le détail dans title derrière le préfixe du web et projette sur la semaine courante', () {
      final p = schedulePayload('me', {'dayOfWeek': 'MERCREDI', 'startTime': '08:00', 'endTime': '10:00', 'classroom': 'S12'}, now: DateTime(2026, 9, 18));
      expect(p['title'], startsWith(PersonalSchedule.metaPrefix));
      final back = PersonalSchedule.fromDocument(doc({...p}));
      expect(back.dayOfWeek, 'MERCREDI');
      expect(back.startTime, '08:00');
      expect(back.endTime, '10:00');
      expect(back.classroom, 'S12');
      // Le 18/09/2026 est un vendredi : le mercredi de cette semaine est le 16.
      expect(back.startsAt, DateTime(2026, 9, 16, 8, 0));
    });

    test('un créneau sans métadonnées (écrit par un autre client) se lit depuis startsAt', () {
      final s = PersonalSchedule.fromDocument(doc({
        'ownerId': 'me',
        'title': 'Cours libre',
        'startsAt': DateTime(2026, 9, 15, 14, 30).toUtc().toIso8601String(),
        'endsAt': DateTime(2026, 9, 15, 16, 0).toUtc().toIso8601String(),
      }));
      expect(s.dayOfWeek, 'MARDI');
      expect(s.startTime, '14:30');
      expect(s.endTime, '16:00');
    });
  });

  group('logique des écrans', () {
    PersonalTask tache(String id, {String? due, String status = 'TODO'}) =>
        PersonalTask(id: id, ownerId: 'me', title: id, dueDate: due, status: status);

    test('sortTasks : échéances proches d\'abord, sans échéance ensuite, terminées en queue', () {
      final sorted = sortTasks([
        tache('sans'),
        tache('faite', due: '2026-01-01', status: 'DONE'),
        tache('loin', due: '2026-12-01'),
        tache('proche', due: '2026-09-21'),
      ]);
      expect(sorted.map((t) => t.id), ['proche', 'loin', 'sans', 'faite']);
    });

    test('groupSchedulesByDay range du lundi au dimanche puis par heure', () {
      PersonalSchedule slot(String id, String day, String start) =>
          PersonalSchedule(id: id, ownerId: 'me', courseId: '', dayOfWeek: day, startTime: start, endTime: start);
      final grouped = groupSchedulesByDay([slot('c', 'MARDI', '10:00'), slot('a', 'LUNDI', '14:00'), slot('b', 'LUNDI', '08:00'), slot('z', 'FLOU', '08:00')]);
      expect(grouped.keys.toList(), ['LUNDI', 'MARDI', 'AUTRE']);
      expect(grouped['LUNDI']!.map((s) => s.id), ['b', 'a']);
    });

    test('weightedAverage ramène sur 20 et pondère par le coefficient', () {
      PersonalGrade note(double score, double max, double coef) =>
          PersonalGrade(id: '', ownerId: '', courseId: '', evaluationTitle: '', score: score, maxScore: max, coefficient: coef);
      expect(weightedAverage([]), 0);
      expect(weightedAverage([note(10, 20, 1), note(5, 10, 1)]), 10);
      expect(weightedAverage([note(20, 20, 3), note(0, 20, 1)]), 15);
    });

    test('formatDueDate parle en jours relatifs puis en date', () {
      final now = DateTime(2026, 9, 20);
      expect(formatDueDate(DateTime(2026, 9, 20, 23), now: now), 'Aujourd\'hui');
      expect(formatDueDate(DateTime(2026, 9, 21), now: now), 'Demain');
      expect(formatDueDate(DateTime(2026, 9, 19), now: now), 'Hier');
      expect(formatDueDate(DateTime(2026, 9, 17), now: now), 'Il y a 3 j');
      expect(formatDueDate(DateTime(2026, 9, 24), now: now), 'Dans 4 j');
      expect(formatDueDate(DateTime(2026, 10, 5), now: now), '05/10');
    });

    test('parseHexColor accepte # facultatif et refuse le reste', () {
      expect(parseHexColor('#0d9488'), const Color(0xFF0D9488));
      expect(parseHexColor('1e3a8a'), const Color(0xFF1E3A8A));
      expect(parseHexColor('rouge'), isNull);
      expect(parseHexColor(null), isNull);
    });

    test('emploi du temps universitaire : normalizeDay et groupByDay tolèrent la casse et l\'anglais', () {
      expect(normalizeDay('lundi'), 'LUNDI');
      expect(normalizeDay('Monday'), 'LUNDI');
      expect(normalizeDay('3'), 'MERCREDI');
      AcademicSchedule s(String id, String day, String start) =>
          AcademicSchedule(id: id, courseId: id, courseCode: id, dayOfWeek: day, startTime: start, endTime: start, classroom: '');
      final grouped = groupByDay([s('b', 'Lundi', '10:00'), s('a', 'LUNDI', '08:00'), s('c', 'mardi', '08:00')]);
      expect(grouped['LUNDI']!.map((x) => x.id), ['a', 'b']);
      expect(grouped['MARDI']!.length, 1);
    });
  });
}
