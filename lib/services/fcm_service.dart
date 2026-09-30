import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Options Firebase pour le projet uniflow-3270a.
/// Ces valeurs sont publiques (présentes dans google-services.json et
/// firebase.json) -- elles ne constituent pas un secret.
const FirebaseOptions _androidOptions = FirebaseOptions(
  apiKey: 'AIzaSyDVC9ILO4NQ4Tc9ZGCyznjmqd1GcyPFr18',
  appId: '1:457488057773:android:1f70b40c3bafe98eeb0d24',
  messagingSenderId: '457488057773',
  projectId: 'uniflow-3270a',
  storageBucket: 'uniflow-3270a.firebasestorage.app',
);

/// Handler appelé quand un message FCM arrive, application en arrière-plan ou
/// fermée. Doit être une fonction de niveau supérieur (contrainte Firebase).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase doit être initialisé avant tout dans le handler isolé.
  await Firebase.initializeApp(options: _androidOptions);
  debugPrint('[FCM] Message reçu en arrière-plan : ${message.messageId}');
  await _showFcmNotification(message);
}

Future<void> _showFcmNotification(RemoteMessage message) async {
  final notification = message.notification;
  final title = notification?.title
      ?? message.data['title']?.toString()
      ?? 'UniFlow';
  final body = notification?.body
      ?? message.data['body']?.toString()
      ?? '';
  if (title.isEmpty && body.isEmpty) return;
  await LocalNotifications.showUrgent(title: title, body: body);
}

/// Service FCM d'UniFlow.
///
/// Gère l'initialisation Firebase, la demande de permission, l'abonnement aux
/// topics et la réception des messages en toutes conditions (premier plan,
/// arrière-plan, app fermée). Le token FCM est exposé via [tokenStream] afin
/// que le provider Appwrite puisse l'enregistrer comme cible push.
class FcmService {
  FcmService._();

  static FcmService? _instance;
  static FcmService get instance => _instance ??= FcmService._();

  bool _initialized = false;
  String? _token;
  final _tokenController = StreamController<String>.broadcast();

  Stream<String> get tokenStream => _tokenController.stream;
  String? get currentToken => _token;

  /// Initialise Firebase et FCM. Sans effet si déjà appelé.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(options: _androidOptions);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await LocalNotifications.ensureInitialized();
      await _requestPermission();
      await _setupForegroundHandler();
      await _refreshToken();
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
      _initialized = true;
      debugPrint('[FCM] Service initialisé. Token : $_token');
    } catch (e) {
      debugPrint('[FCM] Initialisation échouée : $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Statut permission : ${settings.authorizationStatus}');
  }

  Future<void> _refreshToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _token = token;
        _tokenController.add(token);
      }
    } catch (e) {
      debugPrint('[FCM] Impossible de récupérer le token : $e');
    }
  }

  void _onTokenRefresh(String token) {
    _token = token;
    _tokenController.add(token);
    debugPrint('[FCM] Token rafraîchi : $token');
  }

  Future<void> _setupForegroundHandler() async {
    // Sur Android, les messages en premier plan n'affichent pas de notification
    // système par défaut -- on la déclenche manuellement.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('[FCM] Message en premier plan : ${message.messageId}');
      await _showFcmNotification(message);
    });

    // Message reçu en arrière-plan et l'utilisateur tape dessus.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Notification tapée : ${message.data}');
      // TODO : naviguer vers la route indiquée dans message.data['route']
    });
  }

  /// Abonne l'appareil à un topic Firebase (ex: "annonces", "devoirs").
  Future<void> subscribeTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('[FCM] Abonné au topic : $topic');
    } catch (e) {
      debugPrint('[FCM] Abonnement topic "$topic" échoué : $e');
    }
  }

  Future<void> unsubscribeTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[FCM] Désabonnement topic "$topic" échoué : $e');
    }
  }

  void dispose() {
    _tokenController.close();
  }
}
