// Projections « écran » des documents Appwrite (models.dart) : ce qui a
// remplacé les modèles de l'API REST intermédiaire. Sans réseau.
import 'package:appwrite/models.dart' as models;
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/models/models.dart';

models.Document _doc(String id, Map<String, dynamic> data, {String createdAt = '2026-09-15T08:00:00.000+00:00'}) {
  return models.Document(
    $id: id,
    $collectionId: 'academic_enrollments',
    $databaseId: 'uniflow',
    $createdAt: createdAt,
    $updatedAt: createdAt,
    $permissions: const [],
    $sequence: '0',
    data: data,
  );
}

void main() {
  group('Enrollment.fromDocument', () {
    test('lit studentId, courseId, statut et date de création', () {
      final e = Enrollment.fromDocument(_doc('e1', {'studentId': 'u1', 'courseId': 'c1', 'status': 'ACTIVE'}));
      expect(e.id, 'e1');
      expect(e.studentId, 'u1');
      expect(e.ueId, 'c1');
      expect(e.isActive, isTrue);
      expect(e.statusLabel, 'Active');
      expect(e.date.year, 2026);
    });

    test('un statut absent vaut ACTIVE (défaut du schéma)', () {
      final e = Enrollment.fromDocument(_doc('e2', {'studentId': 'u1', 'courseId': 'c1'}));
      expect(e.isActive, isTrue);
      expect(e.statusLabel, 'Active');
    });

    test('une date illisible ne fait pas planter la lecture', () {
      final e = Enrollment.fromDocument(_doc('e3', {'studentId': 'u1', 'courseId': 'c1'}, createdAt: 'n/a'));
      expect(e.date.millisecondsSinceEpoch, 0);
    });
  });

  group('enrollmentStatusLabel', () {
    test('traduit les statuts de la base', () {
      expect(enrollmentStatusLabel('ACTIVE'), 'Active');
      expect(enrollmentStatusLabel('pending'), 'En attente');
      expect(enrollmentStatusLabel('DROPPED'), 'Abandonnée');
      expect(enrollmentStatusLabel('COMPLETED'), 'Terminé');
      expect(enrollmentStatusLabel(''), 'Active');
    });

    test('rend tel quel un statut inconnu plutôt que de le masquer', () {
      expect(enrollmentStatusLabel('WAITLIST'), 'WAITLIST');
    });

    test('seuls les statuts actifs comptent comme actifs', () {
      expect(enrollmentIsActive('ACTIVE'), isTrue);
      expect(enrollmentIsActive(''), isTrue);
      expect(enrollmentIsActive('PENDING'), isFalse);
      expect(enrollmentIsActive('DROPPED'), isFalse);
    });
  });

  group('personStatusLabel', () {
    test('qualifie la personne au masculin', () {
      expect(personStatusLabel('ACTIVE'), 'Actif');
      expect(personStatusLabel('SUSPENDED'), 'Suspendu');
      expect(personStatusLabel('INACTIVE'), 'Inactif');
      expect(personStatusLabel(''), 'Actif');
    });
  });

  group('Teacher.teaches', () {
    const teacher = Teacher(id: 't1', firstName: 'Jean', lastName: 'Nkoumou', status: 'ACTIVE', department: 'ICT4D');

    test('par identifiant quand le cours en porte un', () {
      const ue = UE(
          id: 'c1', code: 'INF101', title: 'Algo', credits: 6, description: '', teacherId: 't1', colorHex: '#000000');
      expect(teacher.teaches(ue), isTrue);
    });

    test('par nom malgré titre, casse et initiale — « Dr NKOUMOU » vs « Pr. Nkoumou J. »', () {
      const ue = UE(
          id: 'c2',
          code: 'INF102',
          title: 'Réseaux',
          credits: 4,
          description: '',
          teacherName: 'Pr. Nkoumou J.',
          colorHex: '#000000');
      expect(teacher.teaches(ue), isTrue);
      expect(sameTeacherName('Dr NKOUMOU', 'Pr. Nkoumou J.'), isTrue);
    });

    test('ne confond pas deux enseignants aux noms distincts', () {
      const ue = UE(
          id: 'c3',
          code: 'MAT101',
          title: 'Analyse',
          credits: 6,
          description: '',
          teacherId: 't9',
          teacherName: 'Dr Essomba',
          colorHex: '#000000');
      expect(teacher.teaches(ue), isFalse);
    });

    test('un titre seul ne suffit pas à rapprocher deux noms', () {
      expect(sameTeacherName('Dr', 'Dr Essomba'), isFalse);
      expect(nameTokens('Pr. J.'), isEmpty);
    });
  });

  group('projections depuis les documents Appwrite', () {
    test('Student.fromDirectory découpe le nom et garde le périmètre', () {
      final entry = AcademicDirectoryEntry(
        id: 'd1',
        userId: 'u1',
        name: 'Amina Ngo Bassong',
        role: 'STUDENT',
        university: 'Université de Yaoundé I',
        program: 'ICT4D',
        level: 'L1',
        matricule: '24T001',
        status: 'ACTIVE',
      );
      final s = Student.fromDirectory(entry);
      expect(s.id, 'u1');
      expect(s.firstName, 'Amina');
      expect(s.lastName, 'Ngo Bassong');
      expect(s.fullName, 'Amina Ngo Bassong');
      expect(s.initials, 'AN');
      expect(s.filiere, 'ICT4D');
      expect(s.niveau, 'L1');
      expect(s.university, 'Université de Yaoundé I');
    });

    test('UE.fromCourse reprend le volume horaire et l\'enseignant du référentiel', () {
      final course = AcademicCourse(
        id: 'c1',
        code: 'ICT101',
        name: 'Introduction aux TIC',
        university: 'UY1',
        program: 'ICT4D',
        level: 'L1',
        teacherName: 'Dr Fouda',
        credits: 6,
        hours: 60,
        classroom: 'A250',
      );
      final ue = UE.fromCourse(course);
      expect(ue.hours, 60);
      expect(ue.credits, 6);
      expect(ue.teacherName, 'Dr Fouda');
      expect(ue.classroom, 'A250');
      expect(ue.description, '');
      expect(ue.colorHex, courseColorHex('ICT101'));
    });

    test('la couleur d\'une UE est stable et prise dans la palette', () {
      expect(courseColorHex('INF301'), courseColorHex('inf301 '));
      expect(courseColorPalette, contains(courseColorHex('INF301')));
      expect(courseColorHex(''), courseColorPalette.first);
    });

    test('un nom d\'un seul mot reste lisible', () {
      expect(splitName('Fouda'), ('Fouda', ''));
      expect(initialsOf('', ''), '?');
    });
  });
}
