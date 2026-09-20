import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';

import '../data/appwrite_service.dart';
import 'appwrite_adapters.dart';
import 'local_database.dart';
import 'outbox.dart';
import 'session_store.dart';
import 'sync_engine.dart';

/// Synchronisation périodique, application fermée (Android, WorkManager).
///
/// Toutes les quinze minutes au plus (minimum imposé par Android), avec
/// contrainte réseau ; « Wi-Fi seulement » passe la contrainte à
/// `unmetered`. La tâche relit la session chiffrée, ouvre la base locale et
/// exécute le même [SyncEngine] que l'application au premier plan.
abstract final class BackgroundSync {
  static const String taskName = 'uniflow.sync';
  static const String uniqueName = 'uniflow-sync-periodique';

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> initialize() async {
    if (!_supported) return;
    try {
      await Workmanager().initialize(backgroundSyncDispatcher);
    } catch (_) {
      // Greffon absent (tests, plateforme de bureau) : l'application reste
      // synchronisée au premier plan, c'est tout.
    }
  }

  static Future<void> schedule({required bool wifiOnly}) async {
    if (!_supported) return;
    try {
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
    } catch (_) {}
  }

  static Future<void> cancel() async {
    if (!_supported) return;
    try {
      await Workmanager().cancelByUniqueName(uniqueName);
    } catch (_) {}
  }
}

/// Point d'entrée de l'isolat de fond. `vm:entry-point` : sans lui, le
/// tree-shaking d'une build release retire la fonction et WorkManager échoue
/// en silence.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != BackgroundSync.taskName) return true;
    WidgetsFlutterBinding.ensureInitialized();
    LocalDatabase? db;
    try {
      await dotenv.load(fileName: '.env');
      final snapshot = await SessionStore(FlutterSecureKeyValueStore()).read();
      if (snapshot == null) return true;
      final service = AppwriteService();
      db = await LocalDatabase.open();
      final engine = SyncEngine(
        db: db,
        remote: AppwriteRemoteDocuments(service),
        outbox: Outbox(db),
        executor: AppwriteOutboxExecutor(service),
        isOnline: ({bool force = false}) => deviceIsOnline(),
      );
      final report = await engine.run(snapshot.user);
      engine.dispose();
      // Hors ligne ou erreurs : WorkManager réessaiera avec son propre
      // délai exponentiel, inutile de marquer la tâche en échec définitif.
      return !report.offline;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  });
}
