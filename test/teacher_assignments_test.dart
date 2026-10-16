import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/models/assignment_models.dart';
import 'package:uniflow_mobile/screens/teacher_assignments.dart';

AcademicCourse _course({String program = 'ICT4D', String level = 'L2'}) => AcademicCourse(
      id: 'c1',
      code: 'INF201',
      name: 'Algorithmique',
      university: 'UY1',
      program: program,
      level: level,
    );

Assignment _assignment(String audience) => Assignment(
      id: 'a',
      title: 't',
      courseId: 'c1',
      courseCode: 'INF201',
      teacherId: 'p',
      type: AssignmentType.td,
      status: AssignmentStatus.published,
      dueDate: DateTime(2030),
      audience: audience,
    );

void main() {
  group('audienceForCourse', () {
    test('cible exactement la filière et le niveau du cours', () {
      final a = _assignment(audienceForCourse(_course()));
      expect(a.targets(filiere: 'ICT4D', niveau: 'L2'), isTrue);
      expect(a.targets(filiere: 'ICT4D', niveau: 'L1'), isFalse);
      expect(a.targets(filiere: 'MATH', niveau: 'L2'), isFalse);
    });

    test('un cours sans niveau vise toute la filière', () {
      final a = _assignment(audienceForCourse(_course(level: '')));
      expect(a.targets(filiere: 'ICT4D', niveau: 'L3'), isTrue);
      expect(a.targets(filiere: 'MATH', niveau: 'L3'), isFalse);
    });
  });
}
