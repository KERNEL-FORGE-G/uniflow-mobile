import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/screens/schedule.dart';

/// Les emplois du temps réels de la Faculté des Sciences (2026-2027) placent
/// plusieurs séances sur un même créneau (TD par groupes, UE optionnelles) et
/// écrivent les heures « 07:30 » comme « 7:30 » selon la filière.
AcademicSchedule s(String code, String start, String end, {String? type, String day = 'Lundi'}) => AcademicSchedule(
      id: '$code-$start-$type',
      courseId: code,
      courseCode: code,
      dayOfWeek: day,
      startTime: start,
      endTime: end,
      classroom: 'S005',
      type: type,
    );

void main() {
  test('normalizeTime uniformise les heures pour le tri', () {
    expect(normalizeTime('7:30'), '07:30');
    expect(normalizeTime('07h30'), '07:30');
    expect(normalizeTime('11:00:00'), '11:00');
    expect(normalizeTime('14:30'), '14:30');
  });

  test('groupByDay trie « 7:30 » avant « 11:00 » (créneaux ENR L3)', () {
    final day = groupByDay([s('B', '11:00', '14:00'), s('C', '14:30', '17:30'), s('A', '7:30', '10:30')])['LUNDI']!;
    expect(day.map((x) => x.courseCode), ['A', 'B', 'C']);
  });

  test('groupByTimeSlot fusionne les séances simultanées (PHY L3)', () {
    final blocks = groupByTimeSlot(groupByDay([
      s('PHY311', '07:30', '10:30', type: 'CM'),
      s('PHY312', '11:00', '14:00', type: 'TD Gr1'),
      s('PHY312', '11:00', '14:00', type: 'TD Gr2'),
      s('PHY315', '11:00', '14:00', type: 'CM'),
    ])['LUNDI']!);
    expect(blocks.length, 2);
    expect(blocks.first.isParallel, isFalse);
    expect(blocks.last.start, '11:00');
    expect(blocks.last.sessions.length, 3);
    expect(blocks.last.isParallel, isTrue);
  });

  test('tdGroupOf extrait le groupe de TD', () {
    expect(tdGroupOf('TD Gr1'), 'Gr1');
    expect(tdGroupOf('TD A'), 'A');
    expect(tdGroupOf('td b'), 'b');
    expect(tdGroupOf('CM'), isNull);
    expect(tdGroupOf(null), isNull);
  });
}
