import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/client_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/appwrite_service.dart';
import '../offline/offline_providers.dart';
import '../repositories/auth_repository.dart';
import 'appwrite_provider.dart';
import 'providers.dart';

/// Sortie de session et suppression de compte, en un seul endroit.
///
/// Chaque bouton « Se déconnecter » faisait sa propre liste de providers à
/// remettre à zéro : à la première liste oubliée, un compte reconnecté
/// héritait des cours ou des conversations du précédent. Ici la séquence est
/// unique — session serveur, jar de cookies, providers, fichiers locaux — et
/// l'expiration de session passe par le même chemin que le bouton.
class SessionController {
  final Ref _ref;
  final SessionGateway _gateway;
  final AuthRepository _auth;

  /// Répertoires à vider au départ ; injectable pour les tests, qui n'ont pas
  /// de `path_provider`.
  final Future<List<Directory>> Function() _localDirectories;

  SessionController(
    this._ref,
    this._gateway,
    this._auth, {
    Future<List<Directory>> Function()? localDirectories,
  }) : _localDirectories = localDirectories ?? _defaultLocalDirectories;

  static Future<List<Directory>> _defaultLocalDirectories() async {
    final docs = await getApplicationDocumentsDirectory();
    return [
      // Le SDK Appwrite range le cookie de session ici
      // (`ClientIO._getCookiePath`) : sans cette purge, une session dont la
      // suppression serveur a échoué ressuscitait au redémarrage.
      Directory('${docs.path}/cookies'),
      Directory('${docs.path}/uniflow_cache'),
    ];
  }

  /// Ferme la session côté serveur (tolérant : déjà expirée = déjà fermée),
  /// puis oublie tout ce que l'appareil sait de l'utilisateur.
  ///
  /// [keepLocalData] : session **expirée** (et non départ volontaire). On
  /// redemande le mot de passe mais le cache hors ligne et l'outbox restent,
  /// rattachés à l'identifiant : un mois d'appels de présence saisis hors
  /// ligne ne doit pas disparaître parce que le jeton a expiré entre-temps.
  Future<void> signOut({bool deleteRemoteSession = true, bool keepLocalData = false}) async {
    if (deleteRemoteSession) {
      try {
        await _auth.logout();
      } catch (_) {
        // Session déjà expirée ou réseau coupé : l'utilisateur veut partir,
        // il ne doit pas rester bloqué sur l'écran avec une erreur.
      }
    }
    await clearLocalState(keepLocalData: keepLocalData);
  }

  /// Vide providers, cookies et fichiers locaux, et bascule sur l'écran de
  /// connexion via `authStatusProvider` (la garde GoRouter fait le reste).
  Future<void> clearLocalState({bool keepLocalData = false}) async {
    final userId = _ref.read(currentUserProvider)?.id;
    try {
      await _ref.read(sessionStoreProvider).clear();
    } catch (_) {}
    if (!keepLocalData && userId != null && userId.isNotEmpty) {
      try {
        await _ref.read(localDatabaseProvider).forgetOwner(userId);
      } catch (_) {}
    }
    try {
      await _gateway.clearCookies();
    } catch (_) {}
    for (final dir in await _safeDirectories()) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    }

    _ref.read(currentUserProvider.notifier).state = null;
    _ref.read(studentsProvider.notifier).state = const [];
    _ref.read(teachersProvider.notifier).state = const [];
    _ref.read(uesProvider.notifier).state = const [];
    _ref.read(scopeSelectionProvider.notifier).state = null;
    // Les FutureProviders dérivés (cours, EDT, conversations…) dépendent de
    // `authStatusProvider` ou de `currentUserProvider` : les invalider ici
    // évite qu'un ancien résultat s'affiche un instant après reconnexion.
    _ref.invalidate(academicSyncProvider);
    _ref.invalidate(scopedCoursesProvider);
    _ref.invalidate(scopedSchedulesProvider);
    _ref.read(authStatusProvider.notifier).state = AuthStatus.signedOut;
  }

  Future<List<Directory>> _safeDirectories() async {
    try {
      return await _localDirectories();
    } catch (_) {
      return const [];
    }
  }

  /// Vérifie le mot de passe en rouvrant une session e-mail/mot de passe.
  ///
  /// Appwrite n'a pas d'appel « vérifier le mot de passe » ; recréer la
  /// session est la seule preuve possible, et c'est ce que fait le web.
  Future<void> verifyPassword(String email, String password) async {
    try {
      await _gateway.openSession(email, password);
    } on AppwriteException catch (error) {
      if (error.code == 401) throw const AccountDeletionException('Mot de passe incorrect.');
      throw AccountDeletionException(error.message ?? 'Vérification impossible.');
    }
  }

  /// Supprime le compte de l'utilisateur connecté via `/account`
  /// (`{action: 'delete-self'}`), puis nettoie l'appareil.
  ///
  /// Le service répond `{ok: true}` ; tant qu'il n'est pas déployé, le
  /// routeur renvoie une erreur que l'on traduit en message lisible plutôt
  /// qu'en pile d'exception. Un `superadmin` est refusé côté serveur.
  Future<void> deleteOwnAccount() async {
    Map<String, dynamic> data;
    try {
      data = await _gateway.callService('/account', const {'action': 'delete-self'});
    } on AppwriteException catch (error) {
      throw AccountDeletionException(describeDeletionFailure(code: error.code, message: error.message));
    } catch (error) {
      throw AccountDeletionException(describeDeletionFailure(message: error.toString()));
    }
    if (data['ok'] != true) {
      throw AccountDeletionException(describeDeletionFailure(
        code: data['code'],
        message: data['message']?.toString(),
      ));
    }
    // Le compte n'existe plus : la session serveur est déjà invalide, on ne
    // tente pas de la supprimer (404 garanti), on nettoie seulement l'appareil.
    await clearLocalState();
  }
}

/// Vrai si l'erreur est un refus de session (401) : Appwrite renvoie
/// `general_unauthorized_scope` ou `user_unauthorized` selon l'appel.
bool isSessionExpired(Object? error) {
  if (error is AppwriteException) return error.code == 401;
  final text = error?.toString() ?? '';
  return text.contains('401') || text.contains('Unauthorized') || text.contains('unauthorized_scope');
}

/// Message d'échec de suppression, à partir du code Appwrite ou du code métier
/// du service. Fonction pure, testée.
String describeDeletionFailure({Object? code, String? message}) {
  final text = (message ?? '').trim();
  final numeric = code is int ? code : int.tryParse('$code');
  final symbolic = code is String ? code.toUpperCase() : '';
  if (symbolic == 'SUPERADMIN_PROTECTED' || symbolic == 'FORBIDDEN' || numeric == 403) {
    return 'Ce compte ne peut pas être supprimé : il administre la plateforme.';
  }
  if (numeric == 401 || symbolic == 'AUTH_REQUIRED') {
    return 'Votre session a expiré. Reconnectez-vous puis réessayez.';
  }
  if (numeric == 404 || symbolic == 'SERVICE_UNKNOWN' || text.toLowerCase().contains('service inconnu')) {
    return 'La suppression de compte n\'est pas encore disponible sur le serveur. Réessayez plus tard.';
  }
  if (numeric != null && numeric >= 500) {
    return 'Le serveur n\'a pas pu supprimer le compte. Réessayez plus tard.';
  }
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Appwrite est injoignable depuis cet appareil.';
  }
  return text.isEmpty ? 'La suppression du compte a échoué.' : text;
}

class AccountDeletionException implements Exception {
  final String message;
  const AccountDeletionException(this.message);
  @override
  String toString() => message;
}

/// Les trois appels Appwrite dont dépend le contrôleur, isolés pour que les
/// tests puissent les simuler sans `flutter_dotenv` ni réseau.
abstract class SessionGateway {
  Future<void> openSession(String email, String password);
  Future<Map<String, dynamic>> callService(String path, Map<String, dynamic> body);
  Future<void> clearCookies();
}

class AppwriteSessionGateway implements SessionGateway {
  final AppwriteService _service;
  AppwriteSessionGateway(this._service);

  @override
  Future<void> openSession(String email, String password) async {
    // Une session est déjà ouverte : Appwrite refuse d'en créer une seconde
    // (« Creation of a session is prohibited when a session is active »). On
    // ferme d'abord la sienne ; si le mot de passe est faux, l'utilisateur se
    // retrouve déconnecté — ce qui est l'issue attendue d'un échec ici.
    try {
      await _service.account.deleteSession(sessionId: 'current');
    } catch (_) {}
    await _service.account.createEmailPasswordSession(email: email, password: password);
  }

  @override
  Future<Map<String, dynamic>> callService(String path, Map<String, dynamic> body) => _service.callService(path, body);

  @override
  Future<void> clearCookies() async {
    final client = _service.client;
    if (client is ClientIO) await client.cookieJar.deleteAll();
  }
}

final sessionControllerProvider = Provider<SessionController>((ref) {
  return SessionController(
    ref,
    AppwriteSessionGateway(ref.watch(appwriteServiceProvider)),
    ref.watch(authRepositoryProvider),
  );
});
