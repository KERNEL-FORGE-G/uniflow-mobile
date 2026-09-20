import 'dart:convert';
import 'package:appwrite/models.dart' as models;

class AcademicCourse {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String university;
  final String program;
  final String level;
  final String? teacherId;
  final String? teacherName;
  final int? credits;
  final int? hours;
  final String? classroom;
  final String? type;

  AcademicCourse({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.university,
    required this.program,
    required this.level,
    this.teacherId,
    this.teacherName,
    this.credits,
    this.hours,
    this.classroom,
    this.type,
  });

  factory AcademicCourse.fromDocument(models.Document doc) {
    return AcademicCourse(
      id: doc.$id,
      code: doc.data['code'] ?? '',
      name: doc.data['name'] ?? '',
      description: doc.data['description'],
      university: doc.data['university'] ?? '',
      program: doc.data['program'] ?? '',
      level: doc.data['level'] ?? 'L1',
      teacherId: doc.data['teacherId'],
      teacherName: doc.data['teacherName'],
      credits: doc.data['credits'],
      hours: doc.data['hours'],
      classroom: doc.data['classroom'],
      type: doc.data['type'],
    );
  }
}

class AcademicSchedule {
  final String id;
  final String courseId;
  final String courseCode;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String classroom;
  final String? type;

  AcademicSchedule({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.classroom,
    this.type,
  });

  factory AcademicSchedule.fromDocument(models.Document doc) {
    return AcademicSchedule(
      id: doc.$id,
      courseId: doc.data['courseId'] ?? '',
      courseCode: doc.data['courseCode'] ?? '',
      dayOfWeek: doc.data['dayOfWeek'] ?? '',
      startTime: doc.data['startTime'] ?? '',
      endTime: doc.data['endTime'] ?? '',
      classroom: doc.data['classroom'] ?? '',
      type: doc.data['type'],
    );
  }
}

class AcademicDirectoryEntry {
  final String id;
  final String userId;
  final String name;
  final String role;
  final String university;
  final String program;
  final String level;
  final String? matricule;
  final String? status;

  AcademicDirectoryEntry({
    required this.id,
    required this.userId,
    required this.name,
    required this.role,
    required this.university,
    required this.program,
    required this.level,
    this.matricule,
    this.status,
  });

  factory AcademicDirectoryEntry.fromDocument(models.Document doc) {
    return AcademicDirectoryEntry(
      id: doc.$id,
      userId: doc.data['userId'] ?? '',
      name: doc.data['name'] ?? '',
      role: doc.data['role'] ?? 'STUDENT',
      university: doc.data['university'] ?? '',
      program: doc.data['program'] ?? '',
      level: doc.data['level'] ?? 'L1',
      matricule: doc.data['matricule'],
      status: doc.data['status'],
    );
  }
}

class AcademicGrade {
  final String id;
  final String studentId;
  final String courseId;
  final String courseCode;
  final String evaluationTitle;
  final String? type;
  final double score;
  final double maxScore;
  final double coefficient;

  AcademicGrade({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.courseCode,
    required this.evaluationTitle,
    this.type,
    required this.score,
    required this.maxScore,
    required this.coefficient,
  });

  factory AcademicGrade.fromDocument(models.Document doc) {
    return AcademicGrade(
      id: doc.$id,
      studentId: doc.data['studentId'] ?? '',
      courseId: doc.data['courseId'] ?? '',
      courseCode: doc.data['courseCode'] ?? '',
      evaluationTitle: doc.data['evaluationTitle'] ?? '',
      type: doc.data['type'],
      score: (doc.data['score'] ?? 0).toDouble(),
      maxScore: (doc.data['maxScore'] ?? 20).toDouble(),
      coefficient: (doc.data['coefficient'] ?? 1).toDouble(),
    );
  }
}

class AcademicAssignment {
  final String id;
  final String courseId;
  final String courseCode;
  final String studentId;
  final String title;
  final String? description;
  final String dueDate;
  final String? status;
  final String? grade;
  final String? feedback;
  final String? submittedAt;

  AcademicAssignment({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.studentId,
    required this.title,
    this.description,
    required this.dueDate,
    this.status,
    this.grade,
    this.feedback,
    this.submittedAt,
  });

  factory AcademicAssignment.fromDocument(models.Document doc) {
    return AcademicAssignment(
      id: doc.$id,
      courseId: doc.data['courseId'] ?? '',
      courseCode: doc.data['courseCode'] ?? '',
      studentId: doc.data['studentId'] ?? '',
      title: doc.data['title'] ?? '',
      description: doc.data['description'],
      dueDate: doc.data['dueDate'] ?? '',
      status: doc.data['status'],
      grade: doc.data['grade'],
      feedback: doc.data['feedback'],
      submittedAt: doc.data['submittedAt'],
    );
  }
}

class AcademicLibraryEntry {
  final String id;
  final String title;
  final String courseId;
  final String course;
  final String type;
  final String category;
  final String? size;
  final String? description;
  final String? fileId;
  final String publishedAt;

  AcademicLibraryEntry({
    required this.id,
    required this.title,
    required this.courseId,
    required this.course,
    required this.type,
    required this.category,
    this.size,
    this.description,
    this.fileId,
    required this.publishedAt,
  });

  factory AcademicLibraryEntry.fromDocument(models.Document doc) {
    return AcademicLibraryEntry(
      id: doc.$id,
      title: doc.data['title'] ?? '',
      courseId: doc.data['courseId'] ?? '',
      course: doc.data['course'] ?? '',
      type: doc.data['type'] ?? '',
      category: doc.data['category'] ?? '',
      size: doc.data['size'],
      description: doc.data['description'],
      fileId: doc.data['fileId'],
      publishedAt: doc.data['publishedAt'] ?? '',
    );
  }
}

class PersonalSubject {
  final String id;
  final String ownerId;
  final String name;
  final String? code;
  final String? instructor;
  final int? credits;
  final String? colorHex;
  final String? classroom;
  final String? description;

  PersonalSubject({
    required this.id,
    required this.ownerId,
    required this.name,
    this.code,
    this.instructor,
    this.credits,
    this.colorHex,
    this.classroom,
    this.description,
  });

  factory PersonalSubject.fromDocument(models.Document doc) {
    return PersonalSubject(
      id: doc.$id,
      ownerId: doc.data['ownerId'] ?? '',
      name: doc.data['name'] ?? doc.data['title'] ?? '',
      code: doc.data['code'],
      instructor: doc.data['instructor'],
      credits: doc.data['credits'],
      colorHex: doc.data['colorHex'],
      classroom: doc.data['classroom'],
      description: doc.data['description'],
    );
  }
}

class PersonalTask {
  final String id;
  final String ownerId;
  final String title;
  final String? courseId;
  final String? dueDate;
  final String? description;
  final int? priority;
  final String? status;

  PersonalTask({
    required this.id,
    required this.ownerId,
    required this.title,
    this.courseId,
    this.dueDate,
    this.description,
    this.priority,
    this.status,
  });

  factory PersonalTask.fromDocument(models.Document doc) {
    return PersonalTask(
      id: doc.$id,
      ownerId: doc.data['ownerId'] ?? '',
      title: doc.data['title'] ?? '',
      courseId: doc.data['courseId'],
      dueDate: doc.data['dueDate'],
      description: doc.data['description'],
      priority: doc.data['priority'],
      status: doc.data['status'],
    );
  }
}

/// Créneau personnel. Le web range le détail (jour, heures, salle, type) dans
/// `title` derrière le préfixe `[UNIFLOW_SCHEDULE]`, faute d'attributs dédiés
/// dans `personal_schedules` ; le mobile lit et écrit le même format pour que
/// les deux clients voient les mêmes créneaux.
class PersonalSchedule {
  static const String metaPrefix = '[UNIFLOW_SCHEDULE]';
  static const List<String> days = ['LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI', 'DIMANCHE'];

  final String id;
  final String ownerId;
  final String courseId;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String classroom;
  final String type;
  final DateTime? startsAt;

  const PersonalSchedule({
    required this.id,
    required this.ownerId,
    required this.courseId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.classroom = '',
    this.type = '',
    this.startsAt,
  });

  factory PersonalSchedule.fromDocument(models.Document doc) {
    final startsAt = DateTime.tryParse(doc.data['startsAt']?.toString() ?? '')?.toLocal();
    final endsAt = DateTime.tryParse(doc.data['endsAt']?.toString() ?? '')?.toLocal();
    final meta = decodeMeta(doc.data['title']?.toString() ?? '');
    String clock(DateTime? d) => d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return PersonalSchedule(
      id: doc.$id,
      ownerId: doc.data['ownerId'] ?? '',
      courseId: meta?['courseId']?.toString() ?? '',
      dayOfWeek: meta?['dayOfWeek']?.toString() ?? (startsAt == null ? '' : days[startsAt.weekday - 1]),
      startTime: meta?['startTime']?.toString() ?? clock(startsAt),
      endTime: meta?['endTime']?.toString() ?? clock(endsAt),
      classroom: meta?['classroom']?.toString() ?? '',
      type: meta?['type']?.toString() ?? '',
      startsAt: startsAt,
    );
  }

  static Map<String, dynamic>? decodeMeta(String title) {
    if (!title.startsWith(metaPrefix)) return null;
    try {
      final decoded = jsonDecode(title.substring(metaPrefix.length).trim());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  int get dayIndex => days.indexOf(dayOfWeek.toUpperCase());
}

class PersonalGrade {
  final String id;
  final String ownerId;
  final String courseId;
  final String evaluationTitle;
  final double score;
  final double maxScore;
  final double coefficient;

  const PersonalGrade({
    required this.id,
    required this.ownerId,
    required this.courseId,
    required this.evaluationTitle,
    required this.score,
    required this.maxScore,
    required this.coefficient,
  });

  factory PersonalGrade.fromDocument(models.Document doc) {
    double num_(Object? v, double fallback) => double.tryParse(v?.toString() ?? '') ?? fallback;
    final d = doc.data;
    return PersonalGrade(
      id: doc.$id,
      ownerId: d['ownerId'] ?? '',
      courseId: (d['courseId'] ?? d['subjectId'] ?? '').toString(),
      evaluationTitle: (d['evaluationTitle'] ?? d['label'] ?? d['title'] ?? '').toString(),
      score: num_(d['score'], 0),
      maxScore: num_(d['maxScore'], 20),
      coefficient: num_(d['coefficient'], 1),
    );
  }

  /// Note ramenée sur 20, pour comparer des évaluations aux barèmes différents.
  double get outOf20 => maxScore <= 0 ? 0 : score / maxScore * 20;
}

class UniFlowUser {
  final String id;
  final String email;
  final String name;
  final String accountType; // 'UNIVERSITY' | 'PERSONAL'

  /// Rôle effectif, en valeur de transport (`STUDENT`, `DELEGATE`, `TEACHER`,
  /// `ADMIN`, ou `PERSONAL` pour un compte indépendant).
  ///
  /// Il est **calculé** par `UniFlowRole.fromLabels` à partir des labels du
  /// compte Appwrite, jamais recopié tel quel depuis `users.role` : ce champ
  /// n'est qu'un miroir d'affichage, et un client qui l'écrirait pourrait
  /// s'attribuer n'importe quel rôle.
  final String role;

  /// Labels Appwrite du compte (`account.get().labels`), conservés pour
  /// distinguer l'administrateur de la plateforme (`superadmin`).
  final List<String> labels;
  final String? university;
  final String? program;
  final String? level;
  final String? country;

  /// Pseudo unique : c'est le référent de la messagerie.
  final String? username;

  /// Fichier de la photo de profil dans le bucket `uniflow_assets`.
  final String? avatarFileId;

  UniFlowUser({
    required this.id,
    required this.email,
    required this.name,
    required this.accountType,
    required this.role,
    this.labels = const [],
    this.university,
    this.program,
    this.level,
    this.country,
    this.username,
    this.avatarFileId,
  });

  bool get isPersonal => accountType.toUpperCase() == 'PERSONAL';

  /// Vrai pour l'administrateur de la plateforme : le seul à pouvoir créer
  /// d'autres comptes `ADMIN`.
  bool get isSuperAdmin =>
      labels.any((label) => label.trim().toLowerCase() == 'superadmin');

  UniFlowUser copyWith({String? name, String? username, String? avatarFileId}) {
    return UniFlowUser(
      id: id,
      email: email,
      name: name ?? this.name,
      accountType: accountType,
      role: role,
      labels: labels,
      university: university,
      program: program,
      level: level,
      country: country,
      username: username ?? this.username,
      avatarFileId: avatarFileId ?? this.avatarFileId,
    );
  }
}
