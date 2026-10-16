import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/local_database.dart';
import '../offline/offline_providers.dart';

/// Clé de la préférence locale « présentation déjà parcourue au moins une
/// fois ». Elle n'est plus relue au démarrage (voir [OnboardingController]) ;
/// on la conserve pour information, dans la table `preferences` de la base
/// locale, à côté des réglages hors ligne.
const String onboardingSeenKey = 'onboarding.seen';

/// Mémorise si la présentation a été parcourue ou passée **dans le processus
/// courant**.
///
/// Décision du propriétaire (2026-09-21) : les pages d'onboarding s'affichent
/// à chaque lancement de l'application, qu'une session existe ou non. L'état
/// « vu » ne vit donc qu'en mémoire : il part de `false` à chaque démarrage à
/// froid, passe à `true` quand l'utilisateur termine ou passe la présentation,
/// et le routeur cesse alors de renvoyer vers `/bienvenue` jusqu'à la
/// fermeture de l'application. Aucune lecture disque au démarrage : c'est ce
/// qui garantit que l'onboarding revient après fermeture, sans écran de garde
/// supplémentaire.
class OnboardingController extends StateNotifier<bool> {
  final LocalDatabase _db;

  OnboardingController(this._db) : super(false);

  /// La présentation a été parcourue ou passée dans cette session.
  Future<void> markSeen() async {
    state = true;
    try {
      // Trace informative seulement : elle ne court-circuite plus rien.
      await _db.setPreference(onboardingSeenKey, '1');
    } catch (_) {}
  }
}

/// `true` : déjà vue dans le processus courant ; `false` : à montrer.
final onboardingSeenProvider = StateNotifierProvider<OnboardingController, bool>(
  (ref) => OnboardingController(ref.watch(localDatabaseProvider)),
);
