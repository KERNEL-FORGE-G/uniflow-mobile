// Badges de l'apprenant : règles pures, puis rendu des médailles.
//
// Chaque badge se gagne sur des données réelles ; ces tests fixent les seuils
// (assiduité 90 % sur 5 séances, trois rendus à l'heure, moyenne 14/20 sur
// trois notes, trois sujets, un quiz à 100 %) pour qu'un réglage ne les
// déplace pas sans qu'on le voie.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/models/assignment_models.dart';
import 'package:uniflow_mobile/models/badges.dart';
import 'package:uniflow_mobile/theme/app_theme.dart';
import 'package:uniflow_mobile/widgets/badges.dart';

Assignment _assignment(String id, {AssignmentType type = AssignmentType.td, DateTime? due, double maxScore = 20}) =>
    Assignment(
      id: id,
      title: 'Devoir $id',
      courseId: 'c1',
      courseCode: 'INF201',
      teacherId: 'p',
      type: type,
      status: AssignmentStatus.published,
      dueDate: due ?? DateTime(2030),
      maxScore: maxScore,
    );

Submission _submission(String assignmentId, {DateTime? at, double? score}) => Submission(
      id: 's-$assignmentId',
      assignmentId: assignmentId,
      studentId: 'me',
      submittedAt: at ?? DateTime(2029),
      score: score,
      status: score == null ? SubmissionStatus.submitted : SubmissionStatus.graded,
    );

AcademicGrade _grade(double score, {double max = 20, double coefficient = 1}) => AcademicGrade(
      id: 'g$score',
      studentId: 'me',
      courseId: 'c1',
      courseCode: 'INF201',
      evaluationTitle: 'CC',
      score: score,
      maxScore: max,
      coefficient: coefficient,
    );

BadgeProgress _of(List<BadgeProgress> all, StudentBadge badge) => all.singleWhere((b) => b.badge == badge);

void main() {
  group('computeBadges', () {
    test('sans aucune donnée, les six badges sont verrouillés à 0 %', () {
      final badges = computeBadges(const BadgeInputs(studentId: 'me'));
      expect(badges.map((b) => b.badge), StudentBadge.values);
      expect(badges.every((b) => !b.unlocked && b.percent == 0), isTrue);
    });

    test('Premier pas : un seul devoir rendu suffit', () {
      final badges = computeBadges(BadgeInputs(
        studentId: 'me',
        assignments: [_assignment('a1')],
        submissions: [_submission('a1')],
      ));
      final b = _of(badges, StudentBadge.premierPas);
      expect(b.unlocked, isTrue);
      expect(b.detail, '1 devoir rendu');
    });

    test('Assidu : 90 % sur au moins 5 séances, les justifiés hors du compte', () {
      List<AttendanceMark> marks(List<String> statuses) => [
            for (var i = 0; i < statuses.length; i++) AttendanceMark(sessionId: 's$i', status: statuses[i]),
          ];
      // 4 présences sur 4 : qualité parfaite mais volume insuffisant → 80 %.
      var b = _of(computeBadges(BadgeInputs(studentId: 'me', attendance: marks(List.filled(4, 'PRESENT')))),
          StudentBadge.assidu);
      expect(b.unlocked, isFalse);
      expect(b.percent, 80);

      // 5 présences (dont un retard, qui compte comme présent) → gagné.
      b = _of(
        computeBadges(
            BadgeInputs(studentId: 'me', attendance: marks(['PRESENT', 'PRESENT', 'RETARD', 'PRESENT', 'PRESENT']))),
        StudentBadge.assidu,
      );
      expect(b.unlocked, isTrue);
      expect(b.detail, startsWith('100 % de présence'));

      // Une absence justifiée ne compte ni pour ni contre.
      b = _of(
        computeBadges(BadgeInputs(
            studentId: 'me', attendance: marks(['PRESENT', 'PRESENT', 'JUSTIFIE', 'PRESENT', 'PRESENT', 'PRESENT']))),
        StudentBadge.assidu,
      );
      expect(b.unlocked, isTrue);
      expect(b.detail, contains('5/5 séances'));

      // 4 présences, 2 absences sur 6 → 67 % : refusé, et la progression le dit.
      b = _of(
        computeBadges(BadgeInputs(
            studentId: 'me', attendance: marks(['PRESENT', 'ABSENT', 'PRESENT', 'ABSENT', 'PRESENT', 'PRESENT']))),
        StudentBadge.assidu,
      );
      expect(b.unlocked, isFalse);
      expect(b.detail, startsWith('67 % de présence'));
    });

    test('Assidu : deux relevés d\'une même séance ne comptent qu\'une fois', () {
      final b = _of(
        computeBadges(const BadgeInputs(studentId: 'me', attendance: [
          AttendanceMark(sessionId: 's1', status: 'PRESENT'),
          AttendanceMark(sessionId: 's1', status: 'PRESENT'),
          AttendanceMark(sessionId: 's2', status: 'PRESENT'),
        ])),
        StudentBadge.assidu,
      );
      expect(b.detail, contains('2/2 séances'));
    });

    test('Ponctuel : trois rendus à l\'heure ; un seul retard remet à zéro', () {
      final due = DateTime(2026, 3, 10, 23, 59);
      final assignments = [_assignment('a1', due: due), _assignment('a2', due: due), _assignment('a3', due: due)];
      var b = _of(
        computeBadges(BadgeInputs(
          studentId: 'me',
          assignments: assignments,
          submissions: [_submission('a1', at: DateTime(2026, 3, 9)), _submission('a2', at: DateTime(2026, 3, 10, 12))],
        )),
        StudentBadge.ponctuel,
      );
      expect(b.unlocked, isFalse);
      expect(b.percent, 67);
      expect(b.detail, '2/3 devoirs rendus à l\'heure');

      b = _of(
        computeBadges(BadgeInputs(
          studentId: 'me',
          assignments: assignments,
          submissions: [
            _submission('a1', at: DateTime(2026, 3, 9)),
            _submission('a2', at: DateTime(2026, 3, 10)),
            _submission('a3', at: DateTime(2026, 3, 10, 23)),
          ],
        )),
        StudentBadge.ponctuel,
      );
      expect(b.unlocked, isTrue);

      b = _of(
        computeBadges(BadgeInputs(
          studentId: 'me',
          assignments: assignments,
          submissions: [
            _submission('a1', at: DateTime(2026, 3, 9)),
            _submission('a2', at: DateTime(2026, 3, 9)),
            _submission('a3', at: DateTime(2026, 3, 11)),
          ],
        )),
        StudentBadge.ponctuel,
      );
      expect(b.unlocked, isFalse);
      expect(b.percent, 0);
      expect(b.detail, '1 devoir rendu en retard');
    });

    test('Major : moyenne pondérée de 14/20 sur trois notes au moins', () {
      var b = _of(
        computeBadges(BadgeInputs(studentId: 'me', grades: [_grade(18), _grade(17)])),
        StudentBadge.major,
      );
      expect(b.unlocked, isFalse, reason: 'deux notes, même excellentes, ne suffisent pas');
      expect(b.percent, 67);

      // (15×2 + 8×1 + 14×1) / 4 = 13,0 → refusé, même avec trois notes.
      b = _of(
        computeBadges(BadgeInputs(studentId: 'me', grades: [_grade(15, coefficient: 2), _grade(8), _grade(14)])),
        StudentBadge.major,
      );
      expect(b.unlocked, isFalse);
      expect(b.detail, startsWith('Moyenne 13,0/20'));

      // Sur 10 : 7/10 = 14/20, avec deux 15/20 → gagné.
      b = _of(
        computeBadges(BadgeInputs(studentId: 'me', grades: [_grade(7, max: 10), _grade(15), _grade(15)])),
        StudentBadge.major,
      );
      expect(b.unlocked, isTrue);
      expect(b.detail, 'Moyenne 14,7/20 · 3 notes');
    });

    test('Entraide : trois sujets publiés', () {
      expect(
          _of(computeBadges(const BadgeInputs(studentId: 'me', forumPostsByStudent: 2)), StudentBadge.entraide).percent,
          67);
      expect(
          _of(computeBadges(const BadgeInputs(studentId: 'me', forumPostsByStudent: 3)), StudentBadge.entraide)
              .unlocked,
          isTrue);
    });

    test('Sans faute : un quiz noté au maximum ; un TD parfait ne compte pas', () {
      final quiz = _assignment('q1', type: AssignmentType.quiz, maxScore: 10);
      final td = _assignment('t1', maxScore: 20);
      var b = _of(
        computeBadges(BadgeInputs(
          studentId: 'me',
          assignments: [quiz, td],
          submissions: [_submission('q1', score: 8), _submission('t1', score: 20)],
        )),
        StudentBadge.sansFaute,
      );
      expect(b.unlocked, isFalse);
      expect(b.percent, 80);
      expect(b.detail, 'Meilleur quiz : 80 %');

      b = _of(
        computeBadges(BadgeInputs(
          studentId: 'me',
          assignments: [quiz],
          submissions: [_submission('q1', score: 10)],
        )),
        StudentBadge.sansFaute,
      );
      expect(b.unlocked, isTrue);
      expect(b.detail, '1 quiz à 100 %');
    });

    test('les rendus d\'un autre étudiant sont ignorés', () {
      final other = Submission(
        id: 'x',
        assignmentId: 'a1',
        studentId: 'someone-else',
        submittedAt: DateTime(2029),
        status: SubmissionStatus.submitted,
      );
      final b = _of(
        computeBadges(BadgeInputs(studentId: 'me', assignments: [_assignment('a1')], submissions: [other])),
        StudentBadge.premierPas,
      );
      expect(b.unlocked, isFalse);
    });
  });

  group('Images des badges', () {
    test('chaque badge a son WebP détouré embarqué', () {
      for (final badge in StudentBadge.values) {
        expect(File(badge.asset).existsSync(), isTrue, reason: '${badge.asset} est absent');
      }
    });

    test('les identifiants sont stables (ce sont les noms de fichiers)', () {
      expect(StudentBadge.values.map((b) => b.id),
          ['premier_pas', 'assidu', 'ponctuel', 'major', 'entraide', 'sans_faute']);
    });
  });

  group('BadgeMedal et BadgesStrip', () {
    Widget host(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

    testWidgets('un badge verrouillé montre un cadenas et sa progression ; un gagné, ni l\'un ni l\'autre',
        (tester) async {
      const locked = BadgeProgress(badge: StudentBadge.assidu, progress: 0.4, detail: '2/5');
      const won = BadgeProgress(badge: StudentBadge.major, progress: 1, detail: 'ok');

      await tester.pumpWidget(host(const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [BadgeMedal(progress: locked), BadgeMedal(progress: won)],
      )));
      await tester.pump();

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Badge Assidu, 40 %'), findsOneWidget);
      expect(find.bySemanticsLabel('Badge Major, gagné'), findsOneWidget);
    });

    testWidgets('la rangée compte les badges gagnés et les place en tête', (tester) async {
      final badges = computeBadges(BadgeInputs(
        studentId: 'me',
        assignments: [_assignment('a1')],
        submissions: [_submission('a1')],
        forumPostsByStudent: 3,
      ));
      var seen = false;
      await tester.pumpWidget(host(SizedBox(
        width: 360,
        child: BadgesStrip(badges: badges, onSeeAll: () => seen = true),
      )));
      await tester.pump();

      expect(find.text('2 badges sur 6'), findsOneWidget);
      // Les deux gagnés sont les deux premiers de la rangée.
      final titles = tester.widgetList<Text>(find.descendant(of: find.byType(ListView), matching: find.byType(Text)));
      expect(titles.take(2).map((t) => t.data), containsAll(['Premier pas', 'Entraide']));

      await tester.tap(find.text('Voir tout'));
      expect(seen, isTrue);
    });
  });
}
