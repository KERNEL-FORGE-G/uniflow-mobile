// Sonde réseau exécutée SUR L'APPAREIL.
//
// `flutter test` remplace le client HTTP par un faux qui répond 400 à tout :
// une panne d'API y est donc indétectable. Ce fichier-ci tourne sur le
// téléphone, avec le vrai réseau et la vraie session Appwrite, et rapporte
// l'erreur exacte que rencontre l'application.
//
// Il ne fait échouer la suite que si l'appel échoue : c'est bien le but.
//
// Lancement :
//   flutter test integration_test/messaging_probe_test.dart -d <appareil>

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:uniflow_mobile/data/appwrite_service.dart';
import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/repositories/messaging_repository.dart';

/// Compte de test. Surchargeable par `--dart-define=EMAIL=… --dart-define=PASSWORD=…`.
const _email = String.fromEnvironment('EMAIL', defaultValue: 'kernel@forge.codes');
const _password = String.fromEnvironment('PASSWORD', defaultValue: 'raveliop456');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la messagerie répond sur un appareil réel', (tester) async {
    // Le point d'entrée de l'application n'est pas exécuté ici : c'est à la
    // sonde de charger la configuration, exactement comme le fait `main()`.
    await dotenv.load(fileName: '.env');
    final service = AppwriteService();

    final auth = AuthRepository(service);
    final messaging = MessagingRepository(service);

    // 1. Connexion.
    Object? loginError;
    try {
      await auth.login(_email, _password);
    } catch (error) {
      loginError = error;
    }
    expect(loginError, isNull, reason: 'connexion : $loginError');

    // 2. Liste des conversations — c'est l'appel que fait l'écran Messagerie.
    Object? listError;
    Object? conversations;
    try {
      conversations = await messaging.getConversations();
    } catch (error) {
      listError = error;
    }
    // ignore: avoid_print
    print('SONDE list -> error=$listError conversations=$conversations');
    expect(listError, isNull, reason: 'list : $listError');

    // 3. Recherche de contact — le second appel de l'écran.
    Object? searchError;
    try {
      await messaging.searchContacts('ravel');
    } catch (error) {
      searchError = error;
    }
    // ignore: avoid_print
    print('SONDE search -> error=$searchError');
    expect(searchError, isNull, reason: 'search : $searchError');
  });
}
