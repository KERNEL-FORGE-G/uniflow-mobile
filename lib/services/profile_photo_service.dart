// `Databases.*Document` est marqué déprécié par le SDK Dart 26 au profit de
// `TablesDB.*Row` (Appwrite 1.8). Le schéma du projet est encore déclaré en
// collections/documents (`uniflow-we/scripts/appwrite-schema.mjs`) et la
// migration vers TablesDB se fera pour les trois clients en même temps ; on
// ignore la dépréciation ici, fichier par fichier, sans assouplir l'analyse
// globale.
// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';
import '../repositories/auth_repository.dart';
import '../utils/avatar.dart';

/// Téléversement et retrait de la photo de profil dans le bucket unique
/// `uniflow_assets`, puis enregistrement de l'identifiant du fichier sur le
/// document `users` du compte.
///
/// Ce qui rend l'avatar public, c'est le `read("any")` posé sur le fichier
/// lui-même : un avatar doit s'afficher dans les listes et les conversations
/// sans exiger de session, alors que les pièces jointes du même bucket restent
/// privées.
class ProfilePhotoService {
  final AppwriteService _service;
  ProfilePhotoService(this._service);

  Storage get _storage => _service.storage;
  Databases get _databases => _service.databases;
  String get _bucket => _service.avatarBucketId;

  /// Téléverse [file] et l'enregistre sur le profil. Renvoie le nouvel
  /// identifiant de fichier.
  ///
  /// L'ancienne photo est supprimée après la mise à jour du profil, jamais
  /// avant : sinon un échec d'enregistrement laisserait le compte sans photo
  /// alors que la nouvelle image serait déjà perdue.
  Future<String> upload({
    required String userId,
    required File file,
    String? previousFileId,
  }) async {
    final invalid = validateAvatarPath(file.path);
    if (invalid != null) throw ProfilePhotoException(invalid);

    if (await file.length() > avatarMaxBytes) {
      throw ProfilePhotoException('L\'image dépasse la limite de 5 Mo.');
    }

    final String createdId;
    try {
      createdId = await _service.uploadFile(
        bucketId: _bucket,
        file: InputFile.fromPath(
          path: file.path,
          // Le nom est normalisé pour que l'extension vue par Appwrite soit
          // toujours l'une des extensions autorisées par le bucket.
          filename: 'avatar.${file.path.split('.').last.toLowerCase()}',
        ),
        // Lecture publique : l'avatar doit s'afficher partout, y compris pour
        // un visiteur non connecté. Le bucket a `fileSecurity` activé, donc ce
        // sont les permissions du fichier qui décident, pas celles du bucket.
        permissions: [Permission.read(Role.any())],
      );
    } on AppwriteException catch (error) {
      if (error.code == 404) {
        throw ProfilePhotoException(
          'Le bucket « $_bucket » est introuvable sur Appwrite.',
        );
      }
      throw ProfilePhotoException(_readable(error, 'le téléversement'));
    }

    try {
      await _databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: userId,
        data: {'avatarFileId': createdId},
      );
    } catch (error) {
      // Sans cet enregistrement l'image resterait orpheline : on la retire.
      try {
        await _storage.deleteFile(bucketId: _bucket, fileId: createdId);
      } catch (_) {}
      if (error is AppwriteException && (error.message ?? '').contains('avatarFileId')) {
        throw ProfilePhotoException(
          'L\'attribut « avatarFileId » manque sur la collection users.',
        );
      }
      throw ProfilePhotoException(
        error is AppwriteException
            ? _readable(error, 'l\'enregistrement de la photo')
            : 'L\'enregistrement de la photo a échoué.',
      );
    }

    // Au mieux : un échec ici ne signifie pas que le téléversement a échoué.
    if (previousFileId != null && previousFileId.isNotEmpty && previousFileId != createdId) {
      try {
        await _storage.deleteFile(bucketId: _bucket, fileId: previousFileId);
      } catch (_) {}
    }
    return createdId;
  }

  /// Retire la photo de profil et supprime le fichier correspondant.
  Future<void> remove({required String userId, String? fileId}) async {
    await _databases.updateDocument(
      databaseId: _service.databaseId,
      collectionId: 'users',
      documentId: userId,
      data: {'avatarFileId': ''},
    );
    if (fileId != null && fileId.isNotEmpty) {
      try {
        await _storage.deleteFile(bucketId: _bucket, fileId: fileId);
      } catch (_) {}
    }
  }

  String _readable(AppwriteException error, String operation) {
    // Le fichier est bien déposé, mais la réponse n'a pas pu être lue : le dire
    // tel quel, sinon l'utilisateur croit à un refus du serveur et retente en
    // boucle un téléversement qui a déjà abouti.
    if (error.type == 'upload_bad_response') {
      return 'L\'image a été déposée, mais le serveur a répondu dans un format '
          'inattendu. Rechargez le profil pour vérifier.';
    }
    switch (error.code) {
      case 401:
        return 'Session expirée pendant $operation. Reconnectez-vous.';
      case 403:
        return 'Ce compte n\'est pas autorisé à modifier sa photo de profil.';
      case 413:
        return 'L\'image est trop volumineuse pour le bucket Appwrite.';
      default:
        return 'Appwrite a refusé $operation (code ${error.code}).';
    }
  }
}

class ProfilePhotoException implements Exception {
  final String message;
  ProfilePhotoException(this.message);
  @override
  String toString() => message;
}

final profilePhotoServiceProvider = Provider<ProfilePhotoService>((ref) {
  return ProfilePhotoService(ref.watch(appwriteServiceProvider));
});

/// Raccourcis pour les écrans : téléverser puis rafraîchir l'état global, sans
/// que chaque appelant ait à connaître les deux fournisseurs concernés.
extension ProfilePhotoActions on WidgetRef {
  /// Téléverse [file] et met à jour le profil en mémoire, afin que l'en-tête et
  /// la barre latérale se rafraîchissent sans redémarrer l'application.
  Future<String> uploadAvatar(File file, UniFlowUser user) async {
    final fileId = await read(profilePhotoServiceProvider).upload(
      userId: user.id,
      file: file,
      previousFileId: user.avatarFileId,
    );
    read(currentUserProvider.notifier).state = user.copyWith(avatarFileId: fileId);
    return fileId;
  }

  /// Retire la photo de profil et remet l'affichage sur les initiales.
  Future<void> removeAvatar(UniFlowUser user) async {
    await read(profilePhotoServiceProvider).remove(userId: user.id, fileId: user.avatarFileId);
    read(currentUserProvider.notifier).state = user.copyWith(avatarFileId: '');
  }

  /// Relit le profil depuis Appwrite et remplace l'état en mémoire.
  Future<void> refreshProfile() async {
    final refreshed = await read(authRepositoryProvider).refreshProfile();
    if (refreshed != null) {
      read(currentUserProvider.notifier).state = refreshed;
    }
  }
}
