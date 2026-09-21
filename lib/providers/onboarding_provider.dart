import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/local_database.dart';
import '../offline/offline_providers.dart';

/// Clé de la préférence locale « présentation déjà vue ».
const String onboardingSeenKey = 'onboarding.seen';

/// Mémorise si la présentation du premier lancement a déjà été vue.
///
/// `null` tant que la préférence n'a pas été relue sur le disque : le routeur
/// ne doit pas décider entre la présentation et la connexion avant de savoir,
/// sinon un utilisateur qui l'a déjà vue la reverrait une fraction de seconde
/// à chaque démarrage. Rangée dans la table `preferences` de la base locale,
/// à côté des réglages hors ligne — même mécanisme, pas de nouveau greffon.
class OnboardingController extends StateNotifier<bool?> {
  final LocalDatabase _db;

  OnboardingController(this._db) : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = await _db.preference(onboardingSeenKey) == '1';
    } catch (_) {
      // Base locale illisible : on ne bloque pas le démarrage, et on ne
      // rejoue pas la présentation à quelqu'un qui l'a peut-être déjà vue.
      state = true;
    }
  }

  /// La présentation a été parcourue ou passée.
  Future<void> markSeen() async {
    state = true;
    try {
      await _db.setPreference(onboardingSeenKey, '1');
    } catch (_) {}
  }

  /// Pour « Revoir la présentation » : la préférence est effacée, la
  /// présentation reviendra au prochain démarrage hors session.
  Future<void> reset() async {
    state = false;
    try {
      await _db.setPreference(onboardingSeenKey, '0');
    } catch (_) {}
  }
}

/// `true` : déjà vue ; `false` : à montrer ; `null` : pas encore relue.
final onboardingSeenProvider = StateNotifierProvider<OnboardingController, bool?>(
  (ref) => OnboardingController(ref.watch(localDatabaseProvider)),
);
