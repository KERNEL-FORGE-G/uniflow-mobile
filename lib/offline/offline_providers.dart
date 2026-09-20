import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';
import 'appwrite_adapters.dart';
import 'background_sync.dart';
import 'local_database.dart';
import 'outbox.dart';
import 'session_store.dart';
import 'sync_engine.dart';

/// Base locale, ouverte paresseusement : `path_provider` est asynchrone et un
/// `Provider` doit rendre une valeur tout de suite.
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase(LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    return NativeDatabase.createInBackground(File('${dir.path}/uniflow_local.sqlite'));
  }));
  ref.onDispose(db.close);
  return db;
});

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore(FlutterSecureKeyValueStore()));

final outboxProvider = Provider<Outbox>((ref) => Outbox(ref.watch(localDatabaseProvider)));

/// Réglages du mode hors ligne, persistés dans la base locale.
class OfflinePreferences {
  final bool wifiOnly;
  final int fileQuotaMb;
  const OfflinePreferences({this.wifiOnly = false, this.fileQuotaMb = 200});

  OfflinePreferences copyWith({bool? wifiOnly, int? fileQuotaMb}) =>
      OfflinePreferences(wifiOnly: wifiOnly ?? this.wifiOnly, fileQuotaMb: fileQuotaMb ?? this.fileQuotaMb);
}

class OfflinePreferencesController extends StateNotifier<OfflinePreferences> {
  final LocalDatabase _db;
  OfflinePreferencesController(this._db) : super(const OfflinePreferences()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final wifi = await _db.preference('offline.wifiOnly');
      final quota = await _db.preference('offline.fileQuotaMb');
      state = OfflinePreferences(
        wifiOnly: wifi == '1',
        fileQuotaMb: int.tryParse(quota ?? '') ?? 200,
      );
    } catch (_) {}
  }

  Future<void> setWifiOnly(bool value) async {
    state = state.copyWith(wifiOnly: value);
    await _db.setPreference('offline.wifiOnly', value ? '1' : '0');
    // La contrainte réseau de la tâche périodique doit suivre le réglage.
    await BackgroundSync.schedule(wifiOnly: value);
  }

  Future<void> setFileQuotaMb(int value) async {
    state = state.copyWith(fileQuotaMb: value);
    await _db.setPreference('offline.fileQuotaMb', '$value');
  }
}

final offlinePreferencesProvider = StateNotifierProvider<OfflinePreferencesController, OfflinePreferences>(
  (ref) => OfflinePreferencesController(ref.watch(localDatabaseProvider)),
);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  final engine = SyncEngine(
    db: ref.watch(localDatabaseProvider),
    remote: AppwriteRemoteDocuments(service),
    outbox: ref.watch(outboxProvider),
    executor: AppwriteOutboxExecutor(service),
    // La synchronisation automatique respecte « Wi-Fi seulement » ; le bouton
    // « Synchroniser maintenant » passe outre (voir [SyncCoordinator]).
    isOnline: ({bool force = false}) =>
        deviceIsOnline(wifiOnly: !force && ref.read(offlinePreferencesProvider).wifiOnly),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// État de synchronisation pour l'en-tête et les Réglages.
final syncStateProvider = StreamProvider<SyncState>((ref) async* {
  final engine = ref.watch(syncEngineProvider);
  final user = ref.watch(currentUserProvider);
  var initial = engine.state;
  if (user != null) {
    initial = initial.copyWith(
      lastSyncAt: await engine.lastSyncAt(user.id),
      pendingCount: await ref.read(outboxProvider).pendingCount(user.id),
    );
  }
  yield initial;
  yield* engine.states;
});

/// Déclenche la synchronisation : au retour du réseau, au passage au premier
/// plan, et à la demande. Vit aussi longtemps que l'application.
class SyncCoordinator with WidgetsBindingObserver {
  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _wasOffline = false;

  SyncCoordinator(this._ref) {
    WidgetsBinding.instance.addObserver(this);
    try {
      _connectivity = Connectivity().onConnectivityChanged.listen((results) {
        final offline = results.every((r) => r == ConnectivityResult.none);
        if (!offline && _wasOffline) unawaited(syncNow(reason: 'réseau retrouvé'));
        _wasOffline = offline;
      });
    } catch (_) {
      // Sans greffon (tests), on se contente des déclenchements manuels.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow(reason: 'premier plan'));
  }

  /// [force] : ignore « Wi-Fi seulement » (bouton « Synchroniser maintenant »).
  Future<SyncReport?> syncNow({String reason = '', bool force = false}) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return null;
    final report = await _ref.read(syncEngineProvider).run(user, force: force);
    // Les écrans « cache d'abord » relisent le cache après un delta.
    _ref.invalidate(scopedCoursesProvider);
    _ref.invalidate(scopedSchedulesProvider);
    return report;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
  }
}

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final coordinator = SyncCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
