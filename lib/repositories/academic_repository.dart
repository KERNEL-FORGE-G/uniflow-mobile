import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';

class AcademicRepository {
  final AppwriteService _service;

  AcademicRepository(this._service);

  /// Cours du périmètre demandé, filtrés **par le serveur**.
  ///
  /// Depuis le chargement de toute la Faculté des Sciences (290 cours,
  /// 2026-09-20), tout rapatrier avec `limit(200)` puis trier localement
  /// tronquait silencieusement la liste : un étudiant de la dernière filière
  /// alphabétique ne voyait aucun cours. On interroge donc par filière et
  /// niveau (index `course_program_level`) et on paginate le reste.
  Future<List<AcademicCourse>> getCourses({String? program, String? level}) async {
    final filters = <String>[
      if (program != null && program.trim().isNotEmpty) Query.equal('program', program.trim()),
      if (level != null && level.trim().isNotEmpty) Query.equal('level', level.trim()),
    ];
    final docs = await _listAll('academic_courses', filters);
    return docs.map(AcademicCourse.fromDocument).toList();
  }

  /// Séances des cours donnés, par lots de 100 identifiants.
  ///
  /// Appwrite plafonne un `equal` à 100 valeurs ; une filière-niveau compte
  /// aujourd'hui jusqu'à une quarantaine de cours, une filière entière (vue
  /// enseignant) peut en dépasser cent.
  Future<List<AcademicSchedule>> getSchedulesForCourses(List<String> courseIds) async {
    final ids = courseIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];
    final out = <AcademicSchedule>[];
    for (var i = 0; i < ids.length; i += 100) {
      final batch = ids.sublist(i, (i + 100).clamp(0, ids.length));
      final docs = await _listAll('academic_schedules', [Query.equal('courseId', batch)]);
      out.addAll(docs.map(AcademicSchedule.fromDocument));
    }
    return out;
  }

  /// Toutes les séances (vue administration, sans filière) — paginées.
  Future<List<AcademicSchedule>> getSchedules() async {
    final docs = await _listAll('academic_schedules', const []);
    return docs.map(AcademicSchedule.fromDocument).toList();
  }

  /// Parcourt une collection page par page (curseur), sans plafond caché.
  Future<List<models.Document>> _listAll(String collectionId, List<String> filters) async {
    final out = <models.Document>[];
    String? cursor;
    while (true) {
      final response = await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: collectionId,
        queries: [
          ...filters,
          Query.limit(100),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      out.addAll(response.documents);
      if (response.documents.length < 100) break;
      cursor = response.documents.last.$id;
    }
    return out;
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
