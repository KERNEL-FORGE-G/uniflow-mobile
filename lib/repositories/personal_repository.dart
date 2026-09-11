import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';

class PersonalRepository {
  final AppwriteService _service;

  PersonalRepository(this._service);

  Future<List<PersonalSubject>> getSubjects(String ownerId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'personal_subjects',
      queries: [
        Query.equal('ownerId', ownerId),
        Query.orderDesc('\$createdAt'),
      ],
    );
    return response.documents.map((doc) => PersonalSubject.fromDocument(doc)).toList();
  }

  Future<List<PersonalTask>> getTasks(String ownerId) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'personal_tasks',
      queries: [
        Query.equal('ownerId', ownerId),
        Query.orderDesc('\$createdAt'),
      ],
    );
    return response.documents.map((doc) => PersonalTask.fromDocument(doc)).toList();
  }

  Future<PersonalSubject> createSubject(String ownerId, Map<String, dynamic> data) async {
    final doc = await _service.databases.createDocument(
      databaseId: _service.databaseId,
      collectionId: 'personal_subjects',
      documentId: ID.unique(),
      data: {'ownerId': ownerId, ...data},
    );
    return PersonalSubject.fromDocument(doc);
  }
}

final personalRepositoryProvider = Provider<PersonalRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return PersonalRepository(service);
});
