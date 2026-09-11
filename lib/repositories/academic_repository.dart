import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';

class AcademicRepository {
  final AppwriteService _service;

  AcademicRepository(this._service);

  Future<List<AcademicCourse>> getCourses() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_courses',
      queries: [Query.limit(200)],
    );
    return response.documents.map((doc) => AcademicCourse.fromDocument(doc)).toList();
  }

  Future<List<AcademicSchedule>> getSchedules() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_schedules',
      queries: [Query.limit(200)],
    );
    return response.documents.map((doc) => AcademicSchedule.fromDocument(doc)).toList();
  }

  Future<List<AcademicDirectoryEntry>> getDirectory() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_directory',
      queries: [Query.limit(200)],
    );
    return response.documents.map((doc) => AcademicDirectoryEntry.fromDocument(doc)).toList();
  }

  Future<List<AcademicGrade>> getGrades(String studentId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_grades',
      queries: [
        Query.equal('studentId', studentId),
        Query.limit(200),
      ],
    );
    return response.documents.map((doc) => AcademicGrade.fromDocument(doc)).toList();
  }

  Future<List<AcademicAssignment>> getAssignments(String studentId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_assignments',
      queries: [
        Query.equal('studentId', studentId),
        Query.limit(200),
      ],
    );
    return response.documents.map((doc) => AcademicAssignment.fromDocument(doc)).toList();
  }

  Future<List<AcademicLibraryEntry>> getLibrary() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'academic_library',
      queries: [Query.limit(200)],
    );
    return response.documents.map((doc) => AcademicLibraryEntry.fromDocument(doc)).toList();
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return AcademicRepository(service);
});
