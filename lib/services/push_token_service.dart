/// push_token_service.dart — Enregistre le token FCM dans Appwrite Messaging.
///
/// Appwrite Messaging permet d'envoyer des notifications push via FCM en
/// ciblant des "targets" (appareils) associés à un utilisateur.
///
/// Flux correct (SDK appwrite 26.x) :
///  1. Account.createPushTarget — crée un target FCM pour cet appareil
///  2. Messaging.createSubscriber — abonne ce target aux topics voulus
library push_token_service;

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';
import 'fcm_service.dart';

/// ID du fournisseur FCM déclaré dans Appwrite Messaging → Providers.
const String _fcmProviderId = 'uniflow-fcm-android';

/// Enregistre le token FCM de cet appareil dans Appwrite Messaging.
///
/// Crée un nouveau PushTarget si inexistant, ou met à jour le token si
/// l'appareil a déjà un target enregistré. Ensuite abonne ce target aux
/// topics `all_users` et `morning_greetings`.
Future<void> registerPushToken({
  required Client client,
  required Messaging messaging,
  required String userId,
  required String fcmToken,
}) async {
  final targetId = 'push_${userId}_android';
  final account = Account(client);

  // ── 1. Créer ou mettre à jour le PushTarget ──────────────────────────────
  try {
    await account.createPushTarget(
      targetId: targetId,
      identifier: fcmToken,
      providerId: _fcmProviderId,
    );
    debugPrint('[Push] PushTarget créé : $targetId');
  } on AppwriteException catch (e) {
    if (e.code == 409) {
      // Déjà existant → mise à jour du token
      try {
        await account.updatePushTarget(
          targetId: targetId,
          identifier: fcmToken,
        );
        debugPrint('[Push] PushTarget mis à jour : $targetId');
      } on AppwriteException catch (e2) {
        debugPrint('[Push] updatePushTarget erreur : ${e2.message}');
      }
    } else {
      debugPrint('[Push] createPushTarget erreur : ${e.message}');
    }
  } catch (e) {
    debugPrint('[Push] PushTarget exception : $e');
  }

  // ── 2. Abonner ce target aux topics ──────────────────────────────────────
  for (final topicId in ['all_users', 'morning_greetings']) {
    try {
      await messaging.createSubscriber(
        topicId: topicId,
        subscriberId: '${targetId}_$topicId',
        targetId: targetId,
      );
      debugPrint('[Push] Abonné au topic : $topicId');
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        debugPrint('[Push] Déjà abonné au topic : $topicId');
      } else {
        debugPrint('[Push] Erreur abonnement $topicId : ${e.message}');
      }
    } catch (e) {
      debugPrint('[Push] Exception abonnement $topicId : $e');
    }
  }
}

/// Provider qui écoute le token FCM et l'enregistre dans Appwrite dès qu'un
/// utilisateur est connecté et qu'un token est disponible.
final pushTokenRegistrationProvider = Provider<_PushTokenRegistration>((ref) {
  final reg = _PushTokenRegistration(ref);
  ref.onDispose(reg.dispose);
  return reg;
});

class _PushTokenRegistration {
  final Ref _ref;
  String? _lastToken;
  String? _lastUserId;

  _PushTokenRegistration(this._ref) {
    _init();
  }

  void _init() {
    FcmService.instance.tokenStream.listen(_onToken);
    final token = FcmService.instance.currentToken;
    if (token != null) _onToken(token);
  }

  void _onToken(String token) {
    if (token == _lastToken) return;
    _lastToken = token;
    _tryRegister();
  }

  void _tryRegister() {
    final user = _ref.read(currentUserProvider);
    final status = _ref.read(authStatusProvider);
    if (user == null || status != AuthStatus.signedIn) return;
    if (_lastToken == null) return;
    if (_lastToken == _lastToken && user.id == _lastUserId) return;

    _lastUserId = user.id;
    final svc = _ref.read(appwriteServiceProvider);
    registerPushToken(
      client: svc.client,
      messaging: Messaging(svc.client),
      userId: user.id,
      fcmToken: _lastToken!,
    );
  }

  void dispose() {}
}
