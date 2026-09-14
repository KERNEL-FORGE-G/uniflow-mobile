import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/appwrite_provider.dart';
import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';

class AuthRepository {
  final AppwriteService _service;
  AuthRepository(this._service);

  Account get _account => _service.account;
  Databases get _databases => _service.databases;

  Future<void> login(String email, String password) async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _account.deleteSession(sessionId: 'current');
  }

  Future<UniFlowUser?> getCurrentUser() async {
    try {
      final account = await _account.get();
      final doc = await _databases.getDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: account.$id,
      );

      return UniFlowUser(
        id: account.$id,
        email: account.email,
        name: account.name,
        accountType: doc.data['accountType'] ?? 'UNIVERSITY',
        role: doc.data['role'] ?? 'STUDENT',
        university: doc.data['university'],
        program: doc.data['program'],
        level: doc.data['level'],
        country: doc.data['country'],
        username: doc.data['username'],
        avatarFileId: doc.data['avatarFileId'],
      );
    } catch (e) {
      return null;
    }
  }

  /// Relit uniquement le document de profil, sans repasser par le compte.
  ///
  /// Utilisé après un changement de photo : le compte Appwrite n'a pas bougé,
  /// seul le document `users` a été mis à jour.
  Future<UniFlowUser?> refreshProfile() => getCurrentUser();

  /// Change le pseudo du compte connecté et renvoie le profil à jour.
  ///
  /// Le pseudo est l'adresse de la messagerie : il doit être unique. Cette
  /// unicité est garantie par un index unique côté Appwrite, qui répond 409 —
  /// c'est donc le serveur qui tranche, et non une vérification préalable qui
  /// laisserait passer deux inscriptions simultanées.
  Future<UniFlowUser> updateUsername(String userId, String username) async {
    try {
      await _databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: userId,
        data: {'username': username},
      );
    } on AppwriteException catch (error) {
      throw AuthException(_usernameMessage(error, username));
    }

    final profile = await getCurrentUser();
    if (profile == null) {
      throw AuthException('Pseudo enregistré, mais le profil n\'a pas pu être relu.');
    }
    return profile;
  }

  String _usernameMessage(AppwriteException error, String username) {
    switch (error.code) {
      case 409:
        return 'Le pseudo « $username » est déjà pris. Choisissez-en un autre.';
      case 401:
        return 'Session expirée. Reconnectez-vous pour changer de pseudo.';
      case 403:
        return 'Ce compte n\'est pas autorisé à modifier son profil.';
      case 400:
        // Appwrite refuse un document qui viole le format d'un attribut ; le
        // seul cas atteignable ici est le pseudo, déjà validé côté client.
        return 'Ce pseudo n\'est pas accepté par Appwrite.';
      default:
        return 'Le changement de pseudo a échoué (code ${error.code}).';
    }
  }
}

/// Erreur destinée à l'utilisateur, portant un texte déjà rédigé.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Pseudo normalisé, ou `null` s'il est inutilisable.
///
/// La règle est volontairement stricte : le pseudo sert d'adresse de
/// messagerie, donc de minuscules sans espace ni accent, comme un identifiant.
/// Elle est appliquée avant l'appel réseau pour donner un retour immédiat ;
/// l'unicité, elle, ne peut venir que du serveur.
String? normalizeUsername(String raw) {
  final cleaned = raw.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
  if (cleaned.length < 3) return null;
  if (cleaned.length > 32) return null;
  if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(cleaned)) return null;
  if (cleaned.endsWith('.') || cleaned.endsWith('-') || cleaned.endsWith('_')) {
    return null;
  }
  return cleaned;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return AuthRepository(service);
});
