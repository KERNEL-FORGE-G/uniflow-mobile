import 'dart:typed_data';

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

  /// Octets d'une ressource de la bibliothèque.
  ///
  /// Les fichiers sont déposés dans le bucket `uniflow_assets` — celui que
  /// `scripts/appwrite-schema.mjs` déclare sous le nom `bucketId`, et dont
  /// `APPWRITE_STORAGE_BUCKET_ID` porte le nom côté client. Le bouton de
  /// téléchargement de l'écran Bibliothèque affichait auparavant « bientôt
  /// disponible » alors que la ressource était déjà là et lisible.
  Future<Uint8List> downloadLibraryFile(String fileId) async {
    try {
      return await _service.storage.getFileDownload(
        bucketId: _service.storageBucketId,
        fileId: fileId,
      );
    } on AppwriteException catch (error) {
      throw Exception(
        error.code == 404
            ? 'Ce document a été retiré de la bibliothèque.'
            : 'Le téléchargement a échoué (code ${error.code}).',
      );
    }
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return AcademicRepository(service);
});

/// Nom de fichier local d'une ressource de la bibliothèque.
///
/// Le titre vient de la base : il peut contenir une barre oblique, un deux-points
/// ou un retour à la ligne, qui feraient échouer l'écriture ou créeraient un
/// dossier inattendu. On ne garde donc que lettres, chiffres, espaces, points,
/// tirets et soulignés ; si tout disparaît, on retombe sur un nom neutre.
///
/// `\w` est écarté volontairement : il ne couvre que l'ASCII, et « réseaux »
/// serait devenu « r_seaux ». On garde les lettres Unicode.
///
/// Fonction pure, donc testable sans réseau ni système de fichiers.
String libraryFileName(String title, String id) {
  final nettoye = title
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s._-]', unicode: true), '_')
      // Un retour à la ligne ou une tabulation deviennent une espace, et les
      // suites d'espaces se réduisent : « Réseaux\n» et « Réseaux  » donnent le
      // même nom.
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'_{2,}'), '_')
      // Un titre qui n'était que ponctuation ne laisse que des soulignés et des
      // points : on les retire des bords avant de juger s'il reste quelque
      // chose. Un nom commençant par un point serait de surcroît caché sous
      // Unix.
      .replaceAll(RegExp(r'^[_\s.-]+|[_\s.-]+$'), '');
  return 'uniflow_${id}_${nettoye.isEmpty ? 'ressource' : nettoye}';
}
