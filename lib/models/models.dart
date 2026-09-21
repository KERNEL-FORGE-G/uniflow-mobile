import 'package:appwrite/models.dart' as documents;

import 'appwrite_models.dart';

/// Projections « écran » des documents Appwrite Cloud : annuaire académique
/// (`academic_directory`), cours (`academic_courses`) et inscriptions
/// (`academic_enrollments`).
///
/// Ces classes portaient auparavant la forme des réponses de l'API REST
/// intermédiaire (NestJS, `api-uniflow.kernelforge.codes`), avec des champs
/// que plus aucune source ne renseignait : les écrans affichaient alors un
/// courriel vide, un téléphone vide, « 0h » de CM/TD/TP et aucune UE inscrite.
/// Elles ne se construisent désormais qu'à partir des documents Appwrite, et
/// n'exposent que ce que la base contient réellement.
class Student {
  final String id;
  final String matricule;
  final String firstName;
  final String lastName;
  final String filiere;
  final String niveau;
  final String status;
  final String university;

  const Student({
    required this.id,
    required this.matricule,
    required this.firstName,
    required this.lastName,
    required this.filiere,
    required this.niveau,
    required this.status,
    this.university = '',
  });

  factory Student.fromDirectory(AcademicDirectoryEntry entry) {
    final (first, last) = splitName(entry.name);
    return Student(
      id: entry.userId,
      matricule: entry.matricule ?? '',
      firstName: first,
      lastName: last,
      filiere: entry.program,
      niveau: entry.level,
      status: entry.status ?? 'ACTIVE',
      university: entry.university,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get initials => initialsOf(firstName, lastName);
}

class Teacher {
  final String id;
  final String firstName;
  final String lastName;
  final String status;

  /// Filière de rattachement (`academic_directory.program`) ; vide pour un
  /// enseignant qui intervient dans plusieurs filières.
  final String department;
  final String university;

  const Teacher({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.department,
    this.university = '',
  });

  factory Teacher.fromDirectory(AcademicDirectoryEntry entry) {
    final (first, last) = splitName(entry.name);
    return Teacher(
      id: entry.userId,
      firstName: first,
      lastName: last,
      status: entry.status ?? 'ACTIVE',
      department: entry.program,
      university: entry.university,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get initials => initialsOf(firstName, lastName);

  /// Vrai si [ue] est dispensée par cet enseignant.
  ///
  /// L'identifiant (`academic_courses.teacherId`) fait foi quand il est
  /// renseigné ; sinon on compare les noms, parce que le référentiel importé
  /// des emplois du temps ne connaît l'enseignant que par son nom, écrit
  /// tantôt « Dr NKOUMOU », tantôt « Pr. Nkoumou J. ».
  bool teaches(UE ue) {
    if (ue.teacherId.isNotEmpty && ue.teacherId == id) return true;
    return sameTeacherName(fullName, ue.teacherName);
  }
}

class UE {
  final String id;
  final String code;
  final String title;
  final int credits;

  /// Volume horaire total du cours (`academic_courses.hours`) ; `0` quand le
  /// référentiel ne le précise pas.
  final int hours;
  final String description;
  final String teacherId;
  final String teacherName;
  final String program;
  final String level;
  final String classroom;
  final String type;
  final String colorHex;

  const UE({
    required this.id,
    required this.code,
    required this.title,
    required this.credits,
    this.hours = 0,
    required this.description,
    this.teacherId = '',
    this.teacherName = '',
    this.program = '',
    this.level = '',
    this.classroom = '',
    this.type = '',
    required this.colorHex,
  });

  factory UE.fromCourse(AcademicCourse course) => UE(
        id: course.id,
        code: course.code,
        title: course.name,
        credits: course.credits ?? 0,
        hours: course.hours ?? 0,
        description: course.description ?? '',
        teacherId: course.teacherId ?? '',
        teacherName: course.teacherName ?? '',
        program: course.program,
        level: course.level,
        classroom: course.classroom ?? '',
        type: course.type ?? '',
        colorHex: courseColorHex(course.code),
      );
}

class Enrollment {
  final String id;
  final String studentId;

  /// Identifiant du cours (`academic_enrollments.courseId`), qui est celui du
  /// document `academic_courses` — donc de [UE.id].
  final String ueId;

  /// Statut brut de la base : `ACTIVE` (défaut du schéma), `PENDING`,
  /// `DROPPED`… Voir [enrollmentStatusLabel] pour l'affichage.
  final String status;
  final DateTime date;

  const Enrollment({
    required this.id,
    required this.studentId,
    required this.ueId,
    required this.status,
    required this.date,
  });

  factory Enrollment.fromDocument(documents.Document doc) => Enrollment(
        id: doc.$id,
        studentId: '${doc.data['studentId'] ?? ''}',
        ueId: '${doc.data['courseId'] ?? ''}',
        status: '${doc.data['status'] ?? 'ACTIVE'}',
        date: DateTime.tryParse(doc.$createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get isActive => enrollmentIsActive(status);
  String get statusLabel => enrollmentStatusLabel(status);
}

/// Une inscription compte comme « active » sauf statut explicite contraire :
/// le schéma met `ACTIVE` par défaut, et une valeur vide (ancien document)
/// doit se lire pareil, pas comme une anomalie.
bool enrollmentIsActive(String status) {
  final s = status.trim().toUpperCase();
  return s.isEmpty || s == 'ACTIVE' || s == 'ACTIF' || s == 'VALIDATED' || s == 'VALIDEE' || s == 'VALIDÉE';
}

/// Libellé français d'un statut d'inscription, tel que [StatusBadge] le
/// colore (vert pour active, ambre pour en attente, rouge pour abandonnée).
String enrollmentStatusLabel(String status) {
  switch (status.trim().toUpperCase()) {
    case '':
    case 'ACTIVE':
    case 'ACTIF':
    case 'VALIDATED':
    case 'VALIDEE':
    case 'VALIDÉE':
      return 'Active';
    case 'PENDING':
    case 'EN ATTENTE':
      return 'En attente';
    case 'DROPPED':
    case 'INACTIVE':
    case 'CANCELLED':
    case 'ABANDONNEE':
    case 'ABANDONNÉE':
      return 'Abandonnée';
    case 'COMPLETED':
    case 'TERMINE':
    case 'TERMINÉ':
      return 'Terminé';
    case 'SUSPENDED':
      return 'Suspendu';
    default:
      return status.trim();
  }
}

/// Libellé français du statut d'un compte de l'annuaire (`ACTIVE`, `INACTIVE`,
/// `SUSPENDED`…), au masculin puisqu'il qualifie la personne.
String personStatusLabel(String status) {
  switch (status.trim().toUpperCase()) {
    case '':
    case 'ACTIVE':
    case 'ACTIF':
      return 'Actif';
    case 'INACTIVE':
    case 'INACTIF':
      return 'Inactif';
    case 'SUSPENDED':
    case 'SUSPENDU':
      return 'Suspendu';
    case 'PENDING':
    case 'EN ATTENTE':
      return 'En attente';
    default:
      return status.trim();
  }
}

/// Découpe « Prénom Nom(s) » en (prénom, reste). Un nom d'un seul mot va dans
/// le prénom pour que [fullName] le restitue tel quel.
(String, String) splitName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return ('', '');
  return (parts.first, parts.skip(1).join(' '));
}

String initialsOf(String firstName, String lastName) {
  final a = firstName.isNotEmpty ? firstName[0] : '';
  final b = lastName.isNotEmpty ? lastName[0] : '';
  final initials = '$a$b'.toUpperCase();
  return initials.isEmpty ? '?' : initials;
}

/// Titres et civilités qui ne distinguent pas deux enseignants.
const Set<String> _honorifics = {'dr', 'pr', 'prof', 'professeur', 'docteur', 'm', 'mr', 'mme', 'mlle', 'ing'};

/// Mots significatifs d'un nom de personne : minuscules, sans accents, sans
/// titre ni initiale isolée (« J. »).
Set<String> nameTokens(String name) {
  final ascii = name
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');
  return ascii.split(RegExp(r'[^a-z]+')).where((t) => t.length > 1 && !_honorifics.contains(t)).toSet();
}

/// Vrai si deux écritures désignent vraisemblablement le même enseignant :
/// leurs mots significatifs se recoupent (« Dr NKOUMOU » ~ « Pr. Nkoumou J. »).
bool sameTeacherName(String a, String b) {
  final ta = nameTokens(a);
  final tb = nameTokens(b);
  if (ta.isEmpty || tb.isEmpty) return false;
  return ta.intersection(tb).isNotEmpty;
}

/// Palette des cartes de cours : une couleur stable par code d'UE, pour que
/// « INF301 » garde la même teinte d'un écran à l'autre sans que la base ait à
/// stocker une couleur.
const List<String> courseColorPalette = [
  '#1E3A8A',
  '#0D9488',
  '#7C3AED',
  '#D97706',
  '#DB2777',
  '#2563EB',
  '#059669',
  '#DC2626',
];

String courseColorHex(String code) {
  var hash = 0;
  for (final unit in code.trim().toUpperCase().codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return courseColorPalette[hash % courseColorPalette.length];
}
