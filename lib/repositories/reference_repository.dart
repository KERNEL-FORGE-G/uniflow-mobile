// `Databases.*Document` est marqué déprécié par le SDK Dart 26 au profit de
// `TablesDB.*Row` (Appwrite 1.8). Le schéma du projet est encore déclaré en
// collections/documents (`uniflow-we/scripts/appwrite-schema.mjs`) et la
// migration vers TablesDB se fera pour les trois clients en même temps ; on
// ignore la dépréciation ici, fichier par fichier, sans assouplir l'analyse
// globale.
// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';

/// Référentiel académique lu sans session : universités, facultés, filières,
/// salles. Ces quatre collections sont `read("any")` dans le schéma
/// (`uniflow-we/scripts/appwrite-schema.mjs`) précisément pour que le
/// formulaire d'inscription puisse les proposer avant toute connexion.
///
/// Rien n'est codé en dur : une université, une faculté ou une filière ne
/// sont que des documents parmi d'autres (douze filières et 34 salles à ce
/// jour), et la base peut en recevoir d'autres sans mise à jour du mobile.
class University {
  final String code;
  final String name;
  final String shortName;
  final String city;
  final String country;
  final bool active;

  const University({
    required this.code,
    required this.name,
    this.shortName = '',
    this.city = '',
    this.country = '',
    this.active = true,
  });

  factory University.fromDocument(models.Document doc) => University(
        code: _text(doc.data['code']),
        name: _text(doc.data['name']),
        shortName: _text(doc.data['shortName']),
        city: _text(doc.data['city']),
        country: _text(doc.data['country']),
        active: doc.data['active'] != false,
      );
}

class Faculty {
  final String universityCode;
  final String code;
  final String name;
  final bool active;

  const Faculty({
    required this.universityCode,
    required this.code,
    required this.name,
    this.active = true,
  });

  factory Faculty.fromDocument(models.Document doc) => Faculty(
        universityCode: _text(doc.data['universityCode']),
        code: _text(doc.data['code']),
        name: _text(doc.data['name']),
        active: doc.data['active'] != false,
      );
}

class AcademicProgram {
  final String universityCode;
  final String facultyCode;

  /// Code court, celui que portent `users.program` et
  /// `academic_courses.program` (« PHY », « INF », « ENR »…).
  final String code;
  final String name;

  /// Niveaux ouverts, dans l'ordre du document (« L1,L2,L3 »).
  final List<String> levels;
  final String description;
  final bool active;

  const AcademicProgram({
    required this.universityCode,
    required this.facultyCode,
    required this.code,
    required this.name,
    required this.levels,
    this.description = '',
    this.active = true,
  });

  factory AcademicProgram.fromDocument(models.Document doc) => AcademicProgram(
        universityCode: _text(doc.data['universityCode']),
        facultyCode: _text(doc.data['facultyCode']),
        code: _text(doc.data['code']),
        name: _text(doc.data['name']),
        levels: parseLevels(doc.data['levels']),
        description: _text(doc.data['description']),
        active: doc.data['active'] != false,
      );
}

class Classroom {
  final String universityCode;
  final String facultyCode;
  final String code;
  final String name;
  final String kind;
  final int capacity;
  final String building;

  const Classroom({
    required this.universityCode,
    required this.facultyCode,
    required this.code,
    required this.name,
    required this.kind,
    required this.capacity,
    required this.building,
  });

  factory Classroom.fromDocument(models.Document doc) => Classroom(
        universityCode: _text(doc.data['universityCode']),
        facultyCode: _text(doc.data['facultyCode']),
        code: _text(doc.data['code']),
        name: _text(doc.data['name']),
        kind: _text(doc.data['kind']),
        capacity: (doc.data['capacity'] as num?)?.toInt() ?? 0,
        building: _text(doc.data['building']),
      );
}

String _text(Object? value) => value is String ? value.trim() : '';

/// Niveaux d'une filière depuis la chaîne du schéma (« L1,L2,L3 »).
///
/// Le schéma choisit une chaîne plutôt qu'un tableau pour simplifier les
/// requêtes ; on tolère les espaces, les doublons et une casse variable, et
/// l'ordre du document est conservé (c'est l'ordre d'affichage).
List<String> parseLevels(Object? raw) {
  if (raw is! String) return const [];
  final seen = <String>{};
  final levels = <String>[];
  for (final part in raw.split(RegExp(r'[,;\s]+'))) {
    final level = part.trim().toUpperCase();
    if (level.isEmpty || !seen.add(level)) continue;
    levels.add(level);
  }
  return levels;
}

class ReferenceRepository {
  final AppwriteService _service;
  ReferenceRepository(this._service);

  Future<List<T>> _list<T>(
    String collectionId,
    T Function(models.Document) build, {
    List<String> queries = const [],
  }) async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: collectionId,
      queries: [...queries, Query.limit(200)],
    );
    return response.documents.map(build).toList();
  }

  Future<List<University>> universities() async {
    final all = await _list('universities', University.fromDocument, queries: [Query.orderAsc('name')]);
    return all.where((u) => u.active).toList();
  }

  Future<List<Faculty>> faculties(String universityCode) async {
    final all = await _list(
      'faculties',
      Faculty.fromDocument,
      queries: [Query.equal('universityCode', universityCode), Query.orderAsc('name')],
    );
    return all.where((f) => f.active).toList();
  }

  Future<List<AcademicProgram>> programs(String universityCode, {String? facultyCode}) async {
    final all = await _list(
      'academic_programs',
      AcademicProgram.fromDocument,
      queries: [
        Query.equal('universityCode', universityCode),
        if (facultyCode != null && facultyCode.isNotEmpty) Query.equal('facultyCode', facultyCode),
        Query.orderAsc('name'),
      ],
    );
    return all.where((p) => p.active).toList();
  }

  /// Toutes les filières actives, toutes universités : pour l'administrateur
  /// de la plateforme, qui n'appartient à aucune.
  Future<List<AcademicProgram>> allPrograms() async {
    final all = await _list('academic_programs', AcademicProgram.fromDocument, queries: [Query.orderAsc('name')]);
    return all.where((p) => p.active).toList();
  }

  Future<List<Classroom>> classrooms(String universityCode) =>
      _list('classrooms', Classroom.fromDocument, queries: [Query.equal('universityCode', universityCode)]);
}

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) {
  return ReferenceRepository(ref.watch(appwriteServiceProvider));
});

final universitiesProvider = FutureProvider<List<University>>((ref) {
  return ref.watch(referenceRepositoryProvider).universities();
});

final facultiesProvider = FutureProvider.family<List<Faculty>, String>((ref, universityCode) {
  if (universityCode.isEmpty) return Future.value(const []);
  return ref.watch(referenceRepositoryProvider).faculties(universityCode);
});

/// Clé « université|faculté » : Riverpod n'accepte qu'un paramètre de famille.
final programsProvider = FutureProvider.family<List<AcademicProgram>, String>((ref, key) {
  final parts = key.split('|');
  final universityCode = parts.first;
  final facultyCode = parts.length > 1 ? parts[1] : '';
  if (universityCode.isEmpty) return Future.value(const []);
  return ref.watch(referenceRepositoryProvider).programs(universityCode, facultyCode: facultyCode);
});

/// Filières que le compte connecté peut sélectionner (écrans Cours et Emploi
/// du temps des comptes au périmètre « sélectionnable »).
///
/// `users.university` porte le **nom** de l'université, pas son code : on le
/// résout contre `universities` (nom ou sigle, sans casse). Une administration
/// est limitée à sa faculté (`users.faculty`) ; l'admin de la plateforme, sans
/// université, voit toutes les filières.
final selectableProgramsProvider = FutureProvider<List<AcademicProgram>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(referenceRepositoryProvider);
  if (user == null || user.isPersonal) return const [];
  final universityName = (user.university ?? '').trim();
  if (user.isPlatform || universityName.isEmpty) return repo.allPrograms();
  final universities = await repo.universities();
  final match = resolveUniversity(universities, universityName);
  if (match == null) return repo.allPrograms();
  return repo.programs(match.code, facultyCode: (user.faculty ?? '').trim());
});

/// Université dont le nom, le sigle ou le code vaut [nameOrCode] (sans casse,
/// espaces ignorés). Fonction pure, testée.
University? resolveUniversity(List<University> all, String nameOrCode) {
  String norm(String v) => v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final wanted = norm(nameOrCode);
  if (wanted.isEmpty) return null;
  for (final u in all) {
    if (norm(u.name) == wanted || norm(u.shortName) == wanted || norm(u.code) == wanted) return u;
  }
  return null;
}
