import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';

/// Gestion des comptes d'une université par son administration, via le
/// service `/admin-directory` du routeur.
///
/// La matrice de droits est appliquée côté serveur (`lib/caller.js`,
/// `canAssignRole`) ; le mobile la reflète pour ne proposer que ce qui sera
/// accepté : `TEACHER`, `DELEGATE` et `STUDENT` pour une administration,
/// `ADMIN` en plus pour l'administrateur de la plateforme (`superadmin`).
class AdminDirectoryRepository {
  static const String servicePath = '/admin-directory';

  final AppwriteService _service;
  AdminDirectoryRepository(this._service);

  Future<Map<String, dynamic>> _call(Map<String, dynamic> payload) async {
    final Map<String, dynamic> response;
    try {
      response = await _service.callService(servicePath, payload);
    } on AppwriteException catch (error) {
      throw AdminDirectoryException(
          error.message ?? 'Le service de gestion des comptes est injoignable (code ${error.code}).');
    }
    if (response['ok'] != true) {
      throw AdminDirectoryException(response['message']?.toString() ?? 'La gestion du compte a échoué.',
          code: response['code']?.toString());
    }
    return response;
  }

  Future<List<ManagedAccount>> list({String program = '', String level = ''}) async {
    final response = await _call({
      'action': 'list',
      if (program.isNotEmpty) 'program': program,
      if (level.isNotEmpty) 'level': level,
    });
    final entries = response['entries'];
    if (entries is! List) return const [];
    return entries.whereType<Map>().map((e) => ManagedAccount.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<ManagedAccount> create(AccountDraft draft) async {
    final response = await _call({'action': 'create', ...draft.toJson()});
    return ManagedAccount(
      userId: response['userId']?.toString() ?? '',
      name: response['name']?.toString() ?? draft.name,
      email: response['email']?.toString() ?? draft.email,
      role: response['role']?.toString() ?? draft.role.wireValue,
      university: draft.university,
      program: draft.program,
      level: draft.level,
      matricule: draft.matricule,
      status: draft.status,
    );
  }

  Future<void> update(String userId, AccountDraft draft) =>
      _call({'action': 'update', 'userId': userId, ...draft.toJson(includePassword: false)});

  Future<void> delete(String userId) => _call({'action': 'delete', 'userId': userId});
}

/// Rôles qu'un appelant peut donner, miroir de `canAssignRole` côté serveur.
List<UniFlowRole> assignableRoles(UniFlowUser? caller) {
  if (caller == null || caller.isPersonal) return const [];
  final role = mapRole(caller.role);
  if (role != UniFlowRole.admin) return const [];
  return [
    if (caller.isSuperAdmin) UniFlowRole.admin,
    UniFlowRole.teacher,
    UniFlowRole.delegate,
    UniFlowRole.student,
  ];
}

class ManagedAccount {
  final String userId;
  final String name;
  final String email;
  final String role;
  final bool isSuperAdmin;
  final String university;
  final String program;
  final String level;
  final String matricule;
  final String status;

  const ManagedAccount({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.isSuperAdmin = false,
    this.university = '',
    this.program = '',
    this.level = '',
    this.matricule = '',
    this.status = 'ACTIVE',
  });

  factory ManagedAccount.fromJson(Map<String, dynamic> json) => ManagedAccount(
        userId: json['userId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? 'STUDENT',
        isSuperAdmin: json['isSuperAdmin'] == true,
        university: json['university']?.toString() ?? '',
        program: json['program']?.toString() ?? '',
        level: json['level']?.toString() ?? '',
        matricule: json['matricule']?.toString() ?? '',
        status: json['status']?.toString() ?? 'ACTIVE',
      );

  UniFlowRole get uniflowRole => mapRole(role);
}

class AccountDraft {
  final String name;
  final String email;
  final String password;
  final UniFlowRole role;
  final String university;
  final String program;
  final String level;
  final String matricule;
  final String status;

  const AccountDraft({
    required this.name,
    required this.email,
    this.password = '',
    required this.role,
    this.university = '',
    this.program = '',
    this.level = '',
    this.matricule = '',
    this.status = 'ACTIVE',
  });

  Map<String, dynamic> toJson({bool includePassword = true}) => {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        if (includePassword) 'password': password,
        'role': role.wireValue,
        if (university.trim().isNotEmpty) 'university': university.trim(),
        if (program.trim().isNotEmpty) 'program': program.trim().toUpperCase(),
        if (level.trim().isNotEmpty) 'level': level.trim().toUpperCase(),
        if (matricule.trim().isNotEmpty) 'matricule': matricule.trim(),
        'status': status,
      };

  /// Message d'erreur ou `null`. Le serveur revalide ; ceci évite un aller-retour.
  String? validate({bool creating = true}) {
    if (name.trim().length < 2) return 'Indiquez le nom complet.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) return 'Adresse e-mail invalide.';
    if (creating && password.length < 8) return 'Le mot de passe initial doit faire au moins 8 caractères.';
    if (role == UniFlowRole.personal) {
      return 'Un compte indépendant se crée par inscription, pas par l\'administration.';
    }
    if ((role == UniFlowRole.student || role == UniFlowRole.delegate) && level.trim().isEmpty) {
      return 'Un apprenant a besoin d\'un niveau pour être inscrit à ses cours.';
    }
    return null;
  }
}

class AdminDirectoryException implements Exception {
  final String message;
  final String? code;
  AdminDirectoryException(this.message, {this.code});
  @override
  String toString() => message;
}

final adminDirectoryRepositoryProvider = Provider<AdminDirectoryRepository>((ref) {
  return AdminDirectoryRepository(ref.watch(appwriteServiceProvider));
});

final managedAccountsProvider = FutureProvider<List<ManagedAccount>>((ref) {
  if (ref.watch(currentRoleProvider) != UniFlowRole.admin) return Future.value(const []);
  return ref.watch(adminDirectoryRepositoryProvider).list();
});
