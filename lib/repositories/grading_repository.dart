import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../providers/appwrite_provider.dart';

/// Saisie des notes par l'enseignant (ou l'administration), service
/// `/academic-grades` du routeur.
///
/// Le serveur n'accepte que des entiers (`integer()`) : un 14,5 est refusé en
/// 400. Le formulaire ne propose donc que des entiers, et le barème peut être
/// porté à 40 ou 100 pour garder la demi-note.
class GradingRepository {
  static const String servicePath = '/academic-grades';

  final AppwriteService _service;
  GradingRepository(this._service);

  Future<Map<String, dynamic>> _call(Map<String, dynamic> payload) async {
    final Map<String, dynamic> response;
    try {
      response = await _service.callService(servicePath, payload);
    } on AppwriteException catch (error) {
      throw GradingException(error.message ?? 'Le service des notes est injoignable (code ${error.code}).');
    }
    if (response['ok'] != true) {
      throw GradingException(response['message']?.toString() ?? 'La saisie de note a échoué.',
          code: response['code']?.toString());
    }
    return response;
  }

  Future<CourseRoster> roster(String courseId) async {
    final response = await _call({'action': 'roster', 'courseId': courseId});
    return CourseRoster.fromJson(response);
  }

  Future<void> upsert({
    required String courseId,
    required String studentId,
    required String evaluationTitle,
    required int score,
    int maxScore = 20,
    int coefficient = 1,
    String type = 'CC',
  }) =>
      _call({
        'action': 'upsert',
        'courseId': courseId,
        'studentId': studentId,
        'evaluationTitle': evaluationTitle.trim(),
        'type': type,
        'score': score,
        'maxScore': maxScore,
        'coefficient': coefficient,
      });

  Future<void> delete({required String courseId, required String studentId, required String gradeId}) =>
      _call({'action': 'delete', 'courseId': courseId, 'studentId': studentId, 'gradeId': gradeId});
}

class RosterStudent {
  final String userId;
  final String name;
  final String matricule;
  final String role;
  const RosterStudent({required this.userId, required this.name, required this.matricule, required this.role});
}

class RosterGrade {
  final String id;
  final String studentId;
  final String evaluationTitle;
  final String type;
  final int score;
  final int maxScore;
  final int coefficient;
  const RosterGrade({
    required this.id,
    required this.studentId,
    required this.evaluationTitle,
    required this.type,
    required this.score,
    required this.maxScore,
    required this.coefficient,
  });
}

class CourseRoster {
  final String courseId;
  final String courseCode;
  final String courseName;
  final List<RosterStudent> students;
  final List<RosterGrade> grades;

  const CourseRoster({
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.students,
    required this.grades,
  });

  factory CourseRoster.fromJson(Map<String, dynamic> json) {
    final course = json['course'] is Map ? Map<String, dynamic>.from(json['course'] as Map) : const <String, dynamic>{};
    int int_(Object? v, int fallback) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
    return CourseRoster(
      courseId: course['id']?.toString() ?? '',
      courseCode: course['code']?.toString() ?? '',
      courseName: course['name']?.toString() ?? '',
      students: [
        for (final s in (json['students'] as List? ?? const []).whereType<Map>())
          RosterStudent(
            userId: s['userId']?.toString() ?? '',
            name: s['name']?.toString() ?? '',
            matricule: s['matricule']?.toString() ?? '',
            role: s['role']?.toString() ?? 'STUDENT',
          ),
      ],
      grades: [
        for (final g in (json['grades'] as List? ?? const []).whereType<Map>())
          RosterGrade(
            id: g['id']?.toString() ?? '',
            studentId: g['studentId']?.toString() ?? '',
            evaluationTitle: g['evaluationTitle']?.toString() ?? '',
            type: g['type']?.toString() ?? 'CC',
            score: int_(g['score'], 0),
            maxScore: int_(g['maxScore'], 20),
            coefficient: int_(g['coefficient'], 1),
          ),
      ],
    );
  }

  /// Intitulés d'évaluation déjà saisis pour ce cours, dans l'ordre d'apparition.
  List<String> get evaluationTitles {
    final seen = <String>{};
    final titles = <String>[];
    for (final g in grades) {
      final key = g.evaluationTitle.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      titles.add(g.evaluationTitle.trim());
    }
    return titles;
  }

  RosterGrade? gradeOf(String studentId, String evaluationTitle) {
    final key = evaluationTitle.trim().toLowerCase();
    for (final g in grades) {
      if (g.studentId == studentId && g.evaluationTitle.trim().toLowerCase() == key) return g;
    }
    return null;
  }
}

class GradingException implements Exception {
  final String message;
  final String? code;
  GradingException(this.message, {this.code});
  @override
  String toString() => message;
}

final gradingRepositoryProvider = Provider<GradingRepository>((ref) {
  return GradingRepository(ref.watch(appwriteServiceProvider));
});

final courseRosterProvider = FutureProvider.family<CourseRoster, String>((ref, courseId) {
  return ref.watch(gradingRepositoryProvider).roster(courseId);
});
