// Voir auth_repository.dart : dépréciation `Databases.*Document` ignorée en
// attendant la migration TablesDB commune aux trois clients.
// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/appwrite_service.dart';
import 'local_database.dart';
import 'outbox.dart';
import 'sync_engine.dart';

/// Lecture des collections via le SDK, pour le moteur de synchronisation.
class AppwriteRemoteDocuments implements RemoteDocuments {
  final AppwriteService _service;
  const AppwriteRemoteDocuments(this._service);

  @override
  Future<List<models.Document>> list(String collection, List<String> queries) async {
    try {
      final response = await _service.databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: collection,
        queries: queries,
      );
      return response.documents;
    } on SocketException {
      throw const OutboxOffline();
    } on HandshakeException {
      throw const OutboxOffline('Connexion TLS impossible');
    }
  }
}

/// Rejoue une écriture différée contre Appwrite, et classe l'échec : réseau
/// absent (on arrête tout), refus définitif (on ne réessaie pas), conflit
/// (l'utilisateur tranche), ou erreur passagère (réessai exponentiel).
class AppwriteOutboxExecutor implements OutboxExecutor {
  final AppwriteService _service;
  const AppwriteOutboxExecutor(this._service);

  @override
  Future<void> execute(OutboxRow entry) async {
    try {
      switch (entry.kind) {
        case OutboxKind.service:
          await _service_(entry);
        case OutboxKind.documentCreate:
          await _create(entry);
        case OutboxKind.documentUpdate:
          await _update(entry);
        default:
          throw OutboxRejected('Type d\'écriture inconnu : ${entry.kind}');
      }
    } on SocketException {
      throw const OutboxOffline();
    } on HandshakeException {
      throw const OutboxOffline('Connexion TLS impossible');
    } on AppwriteException catch (error) {
      throw classifyAppwriteFailure(error.code, error.message);
    }
  }

  Future<void> _service_(OutboxRow entry) async {
    final path = entry.payload['path']?.toString() ?? '';
    final body = Map<String, dynamic>.from(entry.payload['body'] as Map? ?? const {});
    // L'identifiant client voyage avec la requête : un service qui le lit
    // peut dédoublonner un rejeu ; ceux qui ne le lisent pas l'ignorent.
    body['clientId'] = entry.clientId;
    final response = await _service.callService(path, body);
    if (response['ok'] == true) return;
    final code = response['code']?.toString() ?? '';
    final message = response['message']?.toString() ?? 'Le serveur a refusé l\'envoi.';
    throw classifyServiceRefusal(code, message);
  }

  Future<void> _create(OutboxRow entry) async {
    try {
      await _service.databases.createDocument(
        databaseId: _service.databaseId,
        collectionId: entry.payload['collection'].toString(),
        documentId: entry.payload['documentId'].toString(),
        data: Map<String, dynamic>.from(entry.payload['data'] as Map),
        permissions: (entry.payload['permissions'] as List?)?.map((e) => e.toString()).toList(),
      );
    } on AppwriteException catch (error) {
      // Déjà créé lors d'un rejeu précédent coupé avant l'accusé : c'est un
      // succès, pas un conflit — l'identifiant client garantit l'idempotence.
      if (error.code == 409) return;
      rethrow;
    }
  }

  Future<void> _update(OutboxRow entry) => _service.databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: entry.payload['collection'].toString(),
        documentId: entry.payload['documentId'].toString(),
        data: Map<String, dynamic>.from(entry.payload['data'] as Map),
      );
}

/// Classement d'une `AppwriteException` pour le rejeu. Fonction pure, testée.
Exception classifyAppwriteFailure(int? code, String? message) {
  final text = message ?? 'Erreur Appwrite $code';
  if (code == null || code == 0) return OutboxOffline(text);
  if (code == 409) return OutboxRejected(text, conflict: true);
  // 401 : session expirée — l'entrée reste en file, elle partira après la
  // reconnexion. On la signale comme passagère (réessai), pas comme refus.
  if (code == 401 || code >= 500 || code == 429) return _Transient(text);
  if (code >= 400) return OutboxRejected(text);
  return _Transient(text);
}

/// Classement d'un refus métier `{ok:false, code}` d'un service du routeur.
Exception classifyServiceRefusal(String code, String message) {
  const conflicts = {
    'ROLL_DUPLICATE',
    'ALREADY_SUBMITTED',
    'CONFLICT',
    'SESSION_CLOSED',
    'QR_EXPIRED',
    'DEADLINE_PASSED'
  };
  const transient = {'AUTH_REQUIRED', 'RATE_LIMITED', 'INTERNAL', 'SERVICE_UNAVAILABLE'};
  if (conflicts.contains(code)) return OutboxRejected(message, conflict: true);
  if (transient.contains(code)) return _Transient(message);
  return OutboxRejected(message);
}

class _Transient implements Exception {
  final String message;
  const _Transient(this.message);
  @override
  String toString() => message;
}

/// Vrai si l'appareil a une interface réseau active. Ce n'est pas une preuve
/// qu'Appwrite répond ; le moteur le découvrira au premier appel.
Future<bool> deviceIsOnline({bool wifiOnly = false}) async {
  try {
    final results = await Connectivity().checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) return false;
    if (!wifiOnly) return true;
    return results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
  } catch (_) {
    // Greffon indisponible (tests, plateforme inconnue) : on tente le réseau.
    return true;
  }
}
