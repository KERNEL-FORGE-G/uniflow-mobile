import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';

/// Espace personnel d'un compte indépendant : matières, tâches, créneaux et
/// notes que l'utilisateur gère seul, sans université.
///
/// Les documents portent les mêmes champs et le même encodage que ceux du web
/// (`uniflow-we/src/lib/appwrite.ts`, `personalAppwriteApi`) : un compte qui
/// passe d'un client à l'autre retrouve ses données.
class PersonalRepository {
  final AppwriteService _service;

  PersonalRepository(this._service);

  Databases get _db => _service.databases;
  String get _dbId => _service.databaseId;

  /// Les collections personnelles sont en `documentSecurity` : la création
  /// est ouverte aux comptes connectés, mais lecture, modification et
  /// suppression ne le sont que pour le propriétaire, document par document.
  /// Sans ces permissions le document serait créé puis invisible à son auteur.
  List<String> _owner(String ownerId) => [
        Permission.read(Role.user(ownerId)),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ];

  Future<List<T>> _list<T>(String collection, String ownerId, T Function(dynamic) build, {String order = '\$createdAt', bool asc = false}) async {
    final response = await _db.listDocuments(
      databaseId: _dbId,
      collectionId: collection,
      queries: [Query.equal('ownerId', ownerId), asc ? Query.orderAsc(order) : Query.orderDesc(order), Query.limit(200)],
    );
    return response.documents.map(build).toList();
  }

  // --- Matières -----------------------------------------------------------

  Future<List<PersonalSubject>> getSubjects(String ownerId) =>
      _list('personal_subjects', ownerId, (doc) => PersonalSubject.fromDocument(doc));

  Future<PersonalSubject> createSubject(String ownerId, Map<String, dynamic> data) async {
    final doc = await _db.createDocument(
      databaseId: _dbId,
      collectionId: 'personal_subjects',
      documentId: ID.unique(),
      data: subjectPayload(ownerId, data),
      permissions: _owner(ownerId),
    );
    return PersonalSubject.fromDocument(doc);
  }

  Future<PersonalSubject> updateSubject(String ownerId, String id, Map<String, dynamic> data) async {
    final doc = await _db.updateDocument(
      databaseId: _dbId,
      collectionId: 'personal_subjects',
      documentId: id,
      data: subjectPayload(ownerId, data)..remove('ownerId'),
    );
    return PersonalSubject.fromDocument(doc);
  }

  Future<void> deleteSubject(String id) =>
      _db.deleteDocument(databaseId: _dbId, collectionId: 'personal_subjects', documentId: id);

  // --- Tâches -------------------------------------------------------------

  Future<List<PersonalTask>> getTasks(String ownerId) =>
      _list('personal_tasks', ownerId, (doc) => PersonalTask.fromDocument(doc));

  Future<PersonalTask> createTask(String ownerId, Map<String, dynamic> data) async {
    final doc = await _db.createDocument(
      databaseId: _dbId,
      collectionId: 'personal_tasks',
      documentId: ID.unique(),
      data: taskPayload(ownerId, data),
      permissions: _owner(ownerId),
    );
    return PersonalTask.fromDocument(doc);
  }

  Future<PersonalTask> updateTask(String id, Map<String, dynamic> data) async {
    final doc = await _db.updateDocument(databaseId: _dbId, collectionId: 'personal_tasks', documentId: id, data: data);
    return PersonalTask.fromDocument(doc);
  }

  Future<void> deleteTask(String id) =>
      _db.deleteDocument(databaseId: _dbId, collectionId: 'personal_tasks', documentId: id);

  // --- Créneaux -----------------------------------------------------------

  Future<List<PersonalSchedule>> getSchedules(String ownerId) =>
      _list('personal_schedules', ownerId, (doc) => PersonalSchedule.fromDocument(doc), order: 'startsAt', asc: true);

  Future<PersonalSchedule> createSchedule(String ownerId, Map<String, dynamic> data) async {
    final doc = await _db.createDocument(
      databaseId: _dbId,
      collectionId: 'personal_schedules',
      documentId: ID.unique(),
      data: schedulePayload(ownerId, data),
      permissions: _owner(ownerId),
    );
    return PersonalSchedule.fromDocument(doc);
  }

  Future<void> deleteSchedule(String id) =>
      _db.deleteDocument(databaseId: _dbId, collectionId: 'personal_schedules', documentId: id);

  // --- Notes --------------------------------------------------------------

  Future<List<PersonalGrade>> getGrades(String ownerId) =>
      _list('personal_grades', ownerId, (doc) => PersonalGrade.fromDocument(doc));

  Future<PersonalGrade> createGrade(String ownerId, Map<String, dynamic> data) async {
    final doc = await _db.createDocument(
      databaseId: _dbId,
      collectionId: 'personal_grades',
      documentId: ID.unique(),
      data: gradePayload(ownerId, data),
      permissions: _owner(ownerId),
    );
    return PersonalGrade.fromDocument(doc);
  }

  Future<void> deleteGrade(String id) =>
      _db.deleteDocument(databaseId: _dbId, collectionId: 'personal_grades', documentId: id);
}

// --- Charges utiles, fonctions pures (testées) -------------------------------

/// `name` et `title` portent tous deux le libellé : le schéma exige `name`, le
/// web lit `title` en premier.
Map<String, dynamic> subjectPayload(String ownerId, Map<String, dynamic> data) {
  final name = (data['name'] ?? data['title'] ?? '').toString().trim();
  return {
    'ownerId': ownerId,
    'name': name,
    'title': name,
    'code': (data['code'] ?? '').toString().trim(),
    'instructor': (data['instructor'] ?? '').toString().trim(),
    'credits': (data['credits'] is num) ? (data['credits'] as num).toInt() : int.tryParse('${data['credits'] ?? ''}') ?? 0,
    'colorHex': (data['colorHex'] ?? '').toString().isEmpty ? '#0d9488' : data['colorHex'].toString(),
    'classroom': (data['classroom'] ?? '').toString().trim(),
    'description': (data['description'] ?? '').toString().trim(),
  };
}

/// Priorités : le schéma stocke un entier 1–4 ; le web affiche LOW…URGENT.
const Map<String, int> taskPriorityCodes = {'LOW': 1, 'MEDIUM': 2, 'HIGH': 3, 'URGENT': 4};

Map<String, dynamic> taskPayload(String ownerId, Map<String, dynamic> data) {
  final rawPriority = data['priority'];
  final priority = rawPriority is int
      ? rawPriority.clamp(1, 4)
      : taskPriorityCodes[rawPriority?.toString().toUpperCase()] ?? 2;
  final due = data['dueDate'];
  final dueDate = due is DateTime ? due.toUtc().toIso8601String() : (due ?? '').toString();
  return {
    'ownerId': ownerId,
    'title': (data['title'] ?? '').toString().trim(),
    'courseId': (data['courseId'] ?? '').toString(),
    'dueDate': dueDate,
    'description': (data['description'] ?? '').toString(),
    'priority': priority,
    'status': (data['status'] ?? 'TODO').toString(),
  };
}

/// Le schéma stocke score, barème et coefficient en chaînes.
Map<String, dynamic> gradePayload(String ownerId, Map<String, dynamic> data) {
  final title = (data['evaluationTitle'] ?? data['label'] ?? '').toString().trim();
  final courseId = (data['courseId'] ?? data['subjectId'] ?? '').toString();
  return {
    'ownerId': ownerId,
    'subjectId': courseId,
    'courseId': courseId,
    'label': title,
    'evaluationTitle': title,
    'score': '${data['score'] ?? 0}',
    'maxScore': '${data['maxScore'] ?? 20}',
    'coefficient': '${data['coefficient'] ?? 1}',
  };
}

/// Créneau hebdomadaire projeté sur la semaine courante, avec le détail dans
/// `title` derrière `[UNIFLOW_SCHEDULE]` — le format du web.
Map<String, dynamic> schedulePayload(String ownerId, Map<String, dynamic> data, {DateTime? now}) {
  final startTime = (data['startTime'] ?? '00:00').toString();
  final endTime = (data['endTime'] ?? startTime).toString();
  final dayOfWeek = (data['dayOfWeek'] ?? 'LUNDI').toString().toUpperCase();
  final dayIndex = PersonalSchedule.days.indexOf(dayOfWeek).clamp(0, 6);
  final today = now ?? DateTime.now();
  final monday = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
  final date = monday.add(Duration(days: dayIndex));
  DateTime at(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }
  final meta = {
    'courseId': (data['courseId'] ?? '').toString(),
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'classroom': (data['classroom'] ?? '').toString(),
    'type': (data['type'] ?? '').toString(),
  };
  return {
    'ownerId': ownerId,
    'title': '${PersonalSchedule.metaPrefix} ${jsonEncode(meta)}',
    'startsAt': at(startTime).toUtc().toIso8601String(),
    'endsAt': at(endTime).toUtc().toIso8601String(),
  };
}

final personalRepositoryProvider = Provider<PersonalRepository>((ref) {
  return PersonalRepository(ref.watch(appwriteServiceProvider));
});

String _ownerId(Ref ref) => ref.watch(currentUserProvider)?.id ?? '';

final personalSubjectsProvider = FutureProvider<List<PersonalSubject>>((ref) {
  final owner = _ownerId(ref);
  if (owner.isEmpty) return Future.value(const []);
  return ref.watch(personalRepositoryProvider).getSubjects(owner);
});

final personalTasksProvider = FutureProvider<List<PersonalTask>>((ref) {
  final owner = _ownerId(ref);
  if (owner.isEmpty) return Future.value(const []);
  return ref.watch(personalRepositoryProvider).getTasks(owner);
});

final personalSchedulesProvider = FutureProvider<List<PersonalSchedule>>((ref) {
  final owner = _ownerId(ref);
  if (owner.isEmpty) return Future.value(const []);
  return ref.watch(personalRepositoryProvider).getSchedules(owner);
});

final personalGradesProvider = FutureProvider<List<PersonalGrade>>((ref) {
  final owner = _ownerId(ref);
  if (owner.isEmpty) return Future.value(const []);
  return ref.watch(personalRepositoryProvider).getGrades(owner);
});
