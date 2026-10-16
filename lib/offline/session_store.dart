import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/appwrite_models.dart';

/// Ce que l'appareil sait de l'utilisateur connecté, conservé chiffré.
///
/// Au démarrage sans réseau, `account.get()` ne répond pas : l'identité, le
/// rôle (labels) et le périmètre viennent de là, et l'application s'ouvre
/// directement. Le serveur n'est consulté qu'au retour du réseau.
class SessionSnapshot {
  final UniFlowUser user;
  final DateTime savedAt;

  /// Dernière fois que le serveur a confirmé la session (`account.get()`
  /// réussi). `null` tant qu'aucune vérification n'a eu lieu.
  final DateTime? verifiedAt;

  const SessionSnapshot({required this.user, required this.savedAt, this.verifiedAt});

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'savedAt': savedAt.toUtc().toIso8601String(),
        'verifiedAt': verifiedAt?.toUtc().toIso8601String(),
      };

  static SessionSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final user = raw['user'];
    if (user is! Map) return null;
    final savedAt = DateTime.tryParse(raw['savedAt']?.toString() ?? '');
    if (savedAt == null) return null;
    return SessionSnapshot(
      user: UniFlowUser.fromJson(Map<String, dynamic>.from(user)),
      savedAt: savedAt,
      verifiedAt: DateTime.tryParse(raw['verifiedAt']?.toString() ?? ''),
    );
  }
}

/// Stockage clé/valeur chiffré, isolé pour que les tests n'aient pas besoin
/// du greffon natif.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  // Options Android par défaut de la v11 (chiffrement fort géré par le
  // greffon) : les anciennes options `encryptedSharedPreferences` ont disparu.
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemoryKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class SessionStore {
  static const String _key = 'uniflow.session';
  final SecureKeyValueStore _store;
  const SessionStore(this._store);

  Future<SessionSnapshot?> read() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || raw.isEmpty) return null;
      return SessionSnapshot.fromJson(jsonDecode(raw));
    } catch (_) {
      // Un stockage corrompu ne doit pas empêcher l'application de démarrer :
      // on retombe sur l'écran de connexion.
      return null;
    }
  }

  Future<void> save(UniFlowUser user, {required DateTime now, bool verified = true}) async {
    final previous = await read();
    final snapshot = SessionSnapshot(
      user: user,
      savedAt: now,
      verifiedAt: verified ? now : previous?.verifiedAt,
    );
    await _store.write(_key, jsonEncode(snapshot.toJson()));
  }

  Future<void> clear() => _store.delete(_key);
}
