// Tests du moteur de correction des quiz.
//
// Le calcul d'une note est la partie du système de devoirs où une erreur se
// paie comptant : elle est donc isolée dans `QuizGrader`, sans réseau ni
// stockage, et vérifiée ici.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/assignment_models.dart';

QuizDefinition _quiz(String json) => QuizDefinition.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));

void main() {
  group('Décodage du JSON de quiz', () {
    test('lit les questions, les points et la durée', () {
      final quiz = _quiz('''
      {
        "title": "Architecture logicielle",
        "durationMinutes": 20,
        "questions": [
          {"id": "q1", "type": "single", "prompt": "Capitale du Cameroun ?",
           "choices": ["Douala", "Yaoundé"], "answer": 1, "points": 3},
          {"id": "q2", "type": "multiple", "prompt": "Langages compilés ?",
           "choices": ["C", "Python", "Rust"], "answers": [0, 2], "points": 2},
          {"id": "q3", "type": "text", "prompt": "Acronyme de TD ?",
           "answer": "Travaux dirigés", "points": 1}
        ]
      }
      ''');

      expect(quiz.title, 'Architecture logicielle');
      expect(quiz.durationMinutes, 20);
      expect(quiz.questions, hasLength(3));
      expect(quiz.questions[0].type, QuestionType.single);
      expect(quiz.questions[0].correct, [1]);
      expect(quiz.questions[1].type, QuestionType.multiple);
      expect(quiz.questions[1].correct, [0, 2]);
      expect(quiz.questions[2].type, QuestionType.text);
      expect(quiz.questions[2].expected, 'Travaux dirigés');
      expect(quiz.totalPoints, 6);
    });

    test('attribue un identifiant aux questions qui n\'en ont pas', () {
      // Sans identifiant, deux questions se recouvriraient dans les réponses
      // enregistrées et la seconde écraserait la première.
      final quiz = _quiz('''
      {"questions": [
        {"type": "single", "prompt": "A", "choices": ["x", "y"], "answer": 0},
        {"type": "single", "prompt": "B", "choices": ["x", "y"], "answer": 1}
      ]}
      ''');
      expect(quiz.questions.map((q) => q.id), ['q1', 'q2']);
    });

    test('un JSON sans questions donne un quiz vide plutôt qu\'une exception', () {
      final quiz = _quiz('{"title": "Vide"}');
      expect(quiz.questions, isEmpty);
      expect(quiz.totalPoints, 0);
    });
  });

  group('Correction', () {
    final quiz = _quiz('''
    {
      "questions": [
        {"id": "q1", "type": "single", "prompt": "…", "choices": ["a","b","c"],
         "answer": 2, "points": 2},
        {"id": "q2", "type": "multiple", "prompt": "…", "choices": ["a","b","c"],
         "answers": [0, 2], "points": 3},
        {"id": "q3", "type": "text", "prompt": "…", "answer": "Travaux dirigés",
         "points": 1}
      ]
    }
    ''');

    test('toutes les réponses justes donnent le total', () {
      final result = QuizGrader.grade(quiz, {
        'q1': 2,
        'q2': [0, 2],
        'q3': 'Travaux dirigés',
      });
      expect(result.earned, 6);
      expect(result.total, 6);
      expect(result.correctCount, 3);
      expect(result.scaledTo(20), 20);
    });

    test('une question fausse ne retire que ses propres points', () {
      final result = QuizGrader.grade(quiz, {
        'q1': 0, // faux
        'q2': [0, 2], // juste
        'q3': 'Travaux dirigés', // juste
      });
      expect(result.earned, 4);
      expect(result.scaledTo(20), closeTo(13.333, 0.001));
    });

    test('aucune réponse donne zéro, pas une exception', () {
      final result = QuizGrader.grade(quiz, const {});
      expect(result.earned, 0);
      expect(result.scaledTo(20), 0);
    });

    group('QCM à choix multiple', () {
      test('cocher une bonne réponse sur deux est faux', () {
        // C'est le point qui distingue « choix multiple » d'un simple QCM :
        // une réponse partielle ne vaut pas la moitié des points.
        expect(QuizGrader.isCorrect(quiz.questions[1], [0]), isFalse);
      });

      test('cocher une bonne réponse et une mauvaise est faux', () {
        expect(QuizGrader.isCorrect(quiz.questions[1], [0, 1, 2]), isFalse);
      });

      test('l\'ordre des réponses est indifférent', () {
        expect(QuizGrader.isCorrect(quiz.questions[1], [2, 0]), isTrue);
      });
    });

    group('Réponse libre', () {
      test('la casse et les espaces surnuméraires sont ignorés', () {
        expect(QuizGrader.isCorrect(quiz.questions[2], '  travaux   DIRIGÉS '), isTrue);
      });

      test('une réponse vide est fausse', () {
        expect(QuizGrader.isCorrect(quiz.questions[2], ''), isFalse);
        expect(QuizGrader.isCorrect(quiz.questions[2], null), isFalse);
      });

      test('une réponse partielle est fausse', () {
        expect(QuizGrader.isCorrect(quiz.questions[2], 'Travaux'), isFalse);
      });
    });

    test('un barème différent de 20 est respecté', () {
      final result = QuizGrader.grade(quiz, {
        'q1': 2,
        'q2': [0, 2],
        'q3': 'faux'
      });
      expect(result.earned, 5);
      expect(result.scaledTo(10), closeTo(8.333, 0.001));
    });

    test('un quiz sans point ne divise pas par zéro', () {
      final vide = _quiz('{"questions": []}');
      expect(QuizGrader.grade(vide, const {}).scaledTo(20), 0);
    });
  });

  group('Audience', () {
    Assignment assignment(String? audience) => Assignment(
          id: 'a1',
          title: 'Devoir',
          courseId: 'ue1',
          courseCode: 'INF301',
          teacherId: 't1',
          type: AssignmentType.td,
          status: AssignmentStatus.published,
          dueDate: DateTime(2026, 10, 1),
          audience: audience,
        );

    test('une audience vide vise tout le monde', () {
      expect(assignment(null).targets(filiere: 'Informatique', niveau: 'L3'), isTrue);
      expect(assignment('').targets(), isTrue);
    });

    test('une audience illisible vise tout le monde', () {
      // Mieux vaut un devoir visible par trop de monde qu'un devoir que
      // personne ne reçoit à cause d'une virgule mal placée.
      expect(assignment('{ceci n est pas du json').targets(filiere: 'X'), isTrue);
    });

    test('filtre sur la filière', () {
      final a = assignment('{"filieres": ["Informatique"], "niveaux": []}');
      expect(a.targets(filiere: 'Informatique', niveau: 'L3'), isTrue);
      expect(a.targets(filiere: 'Droit', niveau: 'L3'), isFalse);
    });

    test('filtre sur le niveau', () {
      final a = assignment('{"filieres": [], "niveaux": ["Licence 3"]}');
      expect(a.targets(filiere: 'Droit', niveau: 'Licence 3'), isTrue);
      expect(a.targets(filiere: 'Droit', niveau: 'Licence 1'), isFalse);
    });

    test('filière et niveau sont cumulatifs', () {
      final a = assignment('{"filieres": ["Informatique"], "niveaux": ["Licence 3"]}');
      expect(a.targets(filiere: 'Informatique', niveau: 'Licence 3'), isTrue);
      expect(a.targets(filiere: 'Informatique', niveau: 'Licence 1'), isFalse);
    });
  });

  group('Délais', () {
    Assignment due(DateTime due, {bool allowLate = false}) => Assignment(
          id: 'a1',
          title: 'Devoir',
          courseId: 'ue1',
          courseCode: 'INF301',
          teacherId: 't1',
          type: AssignmentType.td,
          status: AssignmentStatus.published,
          dueDate: due,
          allowLate: allowLate,
        );

    test('un devoir passé n\'accepte plus de rendu', () {
      final a = due(DateTime.now().subtract(const Duration(days: 1)));
      expect(a.isPastDue, isTrue);
      expect(a.acceptsSubmission, isFalse);
    });

    test('un devoir passé accepte encore un rendu si le retard est permis', () {
      final a = due(
        DateTime.now().subtract(const Duration(days: 1)),
        allowLate: true,
      );
      expect(a.isPastDue, isTrue);
      expect(a.acceptsSubmission, isTrue);
    });

    test('un devoir à venir accepte un rendu', () {
      final a = due(DateTime.now().add(const Duration(days: 3)));
      expect(a.isPastDue, isFalse);
      expect(a.acceptsSubmission, isTrue);
    });
  });
}
