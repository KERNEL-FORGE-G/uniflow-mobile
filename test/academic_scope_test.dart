import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/academic_scope.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';

/// Le périmètre académique est ce qui empêche un L2 de voir les cours des L1
/// et un physicien de voir ceux d'informatique : rien n'est codé en dur, tout
/// vient du document `users` du compte (douze filières en base).
void main() {
  UniFlowUser compte(String role,
          {String? program = 'ICT4D',
          String? level = 'L2',
          String type = 'UNIVERSITY',
          String? university = 'Université de Yaoundé I',
          String? faculty,
          List<String> labels = const []}) =>
      UniFlowUser(
          id: 'u',
          email: 'u@t.cm',
          name: 'U',
          accountType: type,
          role: role,
          labels: labels,
          university: university,
          faculty: faculty,
          program: program,
          level: level);

  AcademicCourse cours(String code, String program, String level, {String university = 'Université de Yaoundé I'}) =>
      AcademicCourse(id: code, code: code, name: code, university: university, program: program, level: level);

  AcademicDirectoryEntry membre(String role, String program, String level) => AcademicDirectoryEntry(
      id: role + program + level,
      userId: role,
      name: role,
      role: role,
      university: 'Université de Yaoundé I',
      program: program,
      level: level);

  final cours1 = cours('INF111', 'ICT4D', 'L1');
  final cours2 = cours('INF211', 'ICT4D', 'L2');
  final phys = cours('PHY111', 'PHYS', 'L1');

  test('un étudiant ne voit que sa filière et son niveau', () {
    final scope = AcademicScope.forUser(compte('STUDENT'));
    expect(scope.courses([cours1, cours2, phys]), [cours2]);
    expect(scope.label, 'ICT4D · L2');
  });

  test('la comparaison ignore la casse : « ict4d » et « l2 » passent', () {
    final scope = AcademicScope.forUser(compte('DELEGATE', program: 'ict4d', level: 'l2'));
    expect(scope.courses([cours1, cours2]), [cours2]);
  });

  test('un enseignant voit toute sa filière, tous niveaux', () {
    final scope = AcademicScope.forUser(compte('TEACHER', level: 'L1'));
    expect(scope.courses([cours1, cours2, phys]), [cours1, cours2]);
    expect(scope.label, 'ICT4D');
  });

  test('l\'administration voit toute son université', () {
    final scope = AcademicScope.forUser(compte('ADMIN'));
    expect(scope.courses([cours1, cours2, phys]), [cours1, cours2, phys]);
    expect(scope.courses([cours('X', 'Y', 'L1', university: 'Autre')]), isEmpty);
  });

  test('l\'administrateur de la plateforme (PLATFORM, superadmin) voit tout, sans périmètre', () {
    for (final scope in [
      AcademicScope.forUser(compte('ADMIN', type: 'PLATFORM', program: null, level: null, university: null)),
      AcademicScope.forUser(
          compte('ADMIN', labels: const ['ADMIN', 'superadmin'], program: null, level: null, university: null)),
    ]) {
      expect(scope.nothing, isFalse);
      expect(scope.selectable, isTrue);
      expect(scope.filterByProgram, isFalse);
      expect(scope.courses([cours1, cours2, phys, cours('X', 'Y', 'L1', university: 'Autre')]).length, 4);
      expect(scope.label, '');
    }
  });

  test('l\'administration d\'université porte université + faculté et choisit la filière', () {
    final scope = AcademicScope.forUser(compte('ADMIN', faculty: 'FS', program: null, level: null));
    expect(scope.selectable, isTrue);
    expect(scope.label, 'Université de Yaoundé I — FS');
    final resserre = scope.narrowedTo(program: 'PHYS', level: 'L1');
    expect(resserre.courses([cours1, cours2, phys]), [phys]);
    expect(resserre.label, 'PHYS · L1');
    expect(scope.narrowedTo(program: 'ICT4D').courses([cours1, cours2, phys]), [cours1, cours2]);
  });

  test('un compte au type inconnu est traité comme universitaire, jamais personnel', () {
    final scope = AcademicScope.forUser(compte('STUDENT', type: 'BIZARRE'));
    expect(scope.nothing, isFalse);
    expect(scope.courses([cours1, cours2, phys]), [cours2]);
  });

  test('un compte indépendant n\'a aucun périmètre académique', () {
    final scope = AcademicScope.forUser(compte('STUDENT', type: 'PERSONAL', program: '', level: null));
    expect(scope.nothing, isTrue);
    expect(scope.courses([cours1]), isEmpty);
    expect(scope.byCourse([cours1], [cours1], (c) => c.id), isEmpty);
  });

  test('un profil sans filière ni niveau ne filtre pas : tout vaut mieux qu\'un écran vide', () {
    final scope = AcademicScope.forUser(compte('STUDENT', program: '', level: ''));
    expect(scope.courses([cours1, cours2, phys]).length, 3);
    expect(AcademicScope.forUser(null).courses([cours1]), [cours1]);
  });

  test('l\'annuaire garde les enseignants et l\'administration de la filière, mais filtre les étudiants par niveau',
      () {
    final scope = AcademicScope.forUser(compte('STUDENT'));
    final entries = [
      membre('STUDENT', 'ICT4D', 'L1'),
      membre('STUDENT', 'ICT4D', 'L2'),
      membre('DELEGATE', 'ICT4D', 'L2'),
      membre('TEACHER', 'ICT4D', 'L1'),
      membre('ADMIN', 'ICT4D', ''),
      membre('STUDENT', 'PHYS', 'L2'),
    ];
    final kept = scope.directory(entries).map((e) => '${e.role}/${e.program}/${e.level}').toList();
    expect(kept, ['STUDENT/ICT4D/L2', 'DELEGATE/ICT4D/L2', 'TEACHER/ICT4D/L1', 'ADMIN/ICT4D/']);
  });

  test('emploi du temps et bibliothèque suivent le cours, par identifiant ou par code', () {
    final scope = AcademicScope.forUser(compte('STUDENT'));
    final slots = [
      AcademicSchedule(
          id: 'a',
          courseId: 'INF211',
          courseCode: '',
          dayOfWeek: 'LUNDI',
          startTime: '08:00',
          endTime: '10:00',
          classroom: ''),
      AcademicSchedule(
          id: 'b',
          courseId: 'autre',
          courseCode: 'inf211',
          dayOfWeek: 'MARDI',
          startTime: '08:00',
          endTime: '10:00',
          classroom: ''),
      AcademicSchedule(
          id: 'c',
          courseId: 'INF111',
          courseCode: 'INF111',
          dayOfWeek: 'MARDI',
          startTime: '08:00',
          endTime: '10:00',
          classroom: ''),
    ];
    final kept =
        scope.byCourse(slots, scope.courses([cours1, cours2]), (s) => s.courseId, courseCodeOf: (s) => s.courseCode);
    expect(kept.map((s) => s.id), ['a', 'b']);
  });
}
