import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';
import '../repositories/messaging_repository.dart';

/// Notifications système d'UniFlow.
///
/// Elles sont déclenchées par l'application elle-même, à l'arrivée d'un
/// message urgent sur le canal temps réel d'Appwrite — et non par un service de
/// push. Conséquence à connaître : l'alerte n'arrive que si l'application est
/// ouverte ou en arrière-plan récent. Une alerte application fermée exige un
/// projet Firebase et le fichier `google-services.json`, que seul le
/// propriétaire du projet peut créer.
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Identifiant du canal Android. Un canal « urgent » distinct de celui des
  /// notifications ordinaires permet à l'utilisateur de couper l'un sans
  /// l'autre, et autorise une vibration plus marquée.
  static const String channelId = 'uniflow_urgent';
  static const String channelName = 'Messages urgents';
  static const String channelDescription = 'Alertes des messages signalés comme urgents par leur expéditeur.';

  /// Prépare le greffon. Sans effet s'il l'est déjà : appelable depuis
  /// plusieurs points de démarrage sans créer deux canaux.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (error) {
      // Un échec d'initialisation ne doit jamais empêcher l'application de
      // démarrer : la messagerie reste utilisable sans notifications.
      debugPrint('Notifications locales indisponibles : $error');
    }
  }

  /// Demande l'autorisation d'afficher des notifications (Android 13+ et iOS).
  static Future<bool> requestPermission() async {
    await ensureInitialized();
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
    } catch (error) {
      debugPrint('Autorisation de notification refusée : $error');
    }
    return true;
  }

  /// Affiche l'alerte d'un message urgent.
  static Future<void> showUrgent({
    required String title,
    required String body,
    String payload = '',
  }) async {
    await ensureInitialized();
    if (!_initialized) return;
    // `vibrationPattern` est un `Int64List` : une liste Dart ordinaire est
    // refusée à la compilation.
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        // Le message urgent doit se distinguer au premier regard, d'où une
        // vibration appuyée plutôt que le motif par défaut.
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
    try {
      await _plugin.show(
        // L'identifiant doit varier d'une notification à l'autre : une valeur
        // fixe remplacerait l'alerte précédente au lieu de s'y ajouter.
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (error) {
      debugPrint('Affichage de la notification impossible : $error');
    }
  }
}

/// Répartition d'un événement temps réel Appwrite.
///
/// `RealtimeMessage` expose `events` et `payload` séparément : le premier dit
/// ce qui s'est passé (`….create`), le second porte le document. On ne garde
/// que les créations de notifications urgentes appartenant à l'utilisateur.
@visibleForTesting
bool isUrgentNotificationFor(
  List<String> events,
  Map<String, dynamic> document,
  String userId,
) {
  if (userId.isEmpty) return false;
  if (!events.any((event) => event.endsWith('.create'))) return false;
  return document['ownerId'] == userId && document['type'] == 'MESSAGE_URGENT';
}

/// Écoute le canal temps réel et déclenche les notifications système.
///
/// Le fournisseur expose le nombre de notifications non lues, ce qui alimente
/// la pastille de l'interface. Il se relance à chaque changement de compte et
/// s'arrête à la déconnexion, pour ne pas laisser une socket ouverte sur la
/// session précédente.
final urgentNotificationsProvider = StreamProvider<int>((ref) async* {
  final user = ref.watch(currentUserProvider);
  final status = ref.watch(authStatusProvider);
  if (user == null || status != AuthStatus.signedIn) {
    yield 0;
    return;
  }

  await LocalNotifications.requestPermission();
  final repository = ref.watch(messagingRepositoryProvider);

  // Compteur initial, pour que la pastille soit juste dès l'ouverture sans
  // attendre le premier événement.
  int unread;
  try {
    unread = (await repository.getNotifications()).where((notification) => !notification.isRead).length;
  } catch (_) {
    // Messagerie momentanément injoignable : la pastille part de zéro plutôt
    // que d'empêcher l'écoute de démarrer.
    unread = 0;
  }
  yield unread;

  final service = ref.watch(appwriteServiceProvider);
  final realtime = Realtime(service.client);
  final subscription = realtime.subscribe([
    'databases.${service.databaseId}.collections.notifications.documents',
  ]);

  try {
    await for (final event in subscription.stream) {
      if (!isUrgentNotificationFor(event.events, event.payload, user.id)) continue;

      unread += 1;
      yield unread;

      await LocalNotifications.showUrgent(
        title: event.payload['title']?.toString() ?? 'Message urgent',
        body: event.payload['message']?.toString() ?? '',
        payload: event.payload['link']?.toString() ?? '',
      );
      // La liste affichée à l'écran doit refléter l'arrivée immédiatement.
      ref.invalidate(notificationsProvider);
    }
  } finally {
    await subscription.close();
  }
});

/// Liste des notifications, rechargée à la demande.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(messagingRepositoryProvider).getNotifications();
});
