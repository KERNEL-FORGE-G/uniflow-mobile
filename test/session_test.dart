// Déconnexion et suppression de compte.
//
// Chaque bouton « Se déconnecter » remettait sa propre liste de providers à
// zéro ; la suppression de compte n'existait pas. Ces tests exercent la
// séquence unique (`SessionController`) avec une passerelle Appwrite simulée,
// puis les deux écrans qui l'appellent.

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/offline/local_database.dart';
import 'package:uniflow_mobile/offline/offline_providers.dart';
import 'package:uniflow_mobile/offline/outbox.dart';
import 'package:uniflow_mobile/offline/session_store.dart';
import 'package:uniflow_mobile/offline/sync_engine.dart';
import 'package:uniflow_mobile/providers/providers.dart';
import 'package:uniflow_mobile/providers/session_controller.dart';
import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/screens/delete_account.dart';
import 'package:uniflow_mobile/screens/settings.dart';

import 'layout_test_support.dart';

class _Gateway implements SessionGateway {
  static const goodPassword = 'secret';
  final Map<String, dynamic> Function()? serviceResponse;
  final Object? serviceError;
  final calls = <(String, Map<String, dynamic>)>[];
  int cookiesCleared = 0;

  _Gateway({this.serviceResponse, this.serviceError});

  @override
  Future<void> openSession(String email, String password) async {
    if (password != goodPassword) throw AppwriteException('Invalid credentials', 401, 'user_invalid_credentials');
  }

  @override
  Future<Map<String, dynamic>> callService(String path, Map<String, dynamic> body) async {
    calls.add((path, body));
    if (serviceError != null) throw serviceError!;
    return serviceResponse?.call() ?? const {'ok': true};
  }

  @override
  Future<void> clearCookies() async => cookiesCleared++;
}

class _Auth implements AuthRepository {
  int logouts = 0;
  final Object? logoutError;
  _Auth({this.logoutError});

  @override
  Future<void> logout() async {
    logouts++;
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<UniFlowUser?> getCurrentUser() async => user();
  @override
  Future<UniFlowUser?> getCurrentUserStrict() async => user();
  @override
  Future<UniFlowUser?> refreshProfile() async => user();
  @override
  Future<void> login(String email, String password, {UniFlowAccountType? accountTypeHint}) async {}
  @override
  Future<UniFlowUser> register(RegistrationInput input) async => user();
  @override
  Future<bool> provisionAcademicRegistration({String matricule = ''}) async => true;
  @override
  Future<void> retryAcademicProvisioning(UniFlowUser user) async {}
  @override
  bool get academicProvisioningPending => false;
  @override
  Future<void> sendPasswordRecovery(String email) async {}
  @override
  Future<UniFlowUser> updateUsername(String userId, String username) async => user();
}

/// Un `SessionController` sur un vrai `ProviderContainer`, pour vérifier
/// l'effet réel sur les providers plutôt qu'un appel simulé.
({ProviderContainer container, _Gateway gateway, _Auth auth}) _rig({
  _Gateway? gateway,
  _Auth? auth,
  UniFlowUser? Function()? currentUser,
}) {
  final g = gateway ?? _Gateway();
  final a = auth ?? _Auth();
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(a),
    currentUserProvider.overrideWith((ref) => currentUser?.call() ?? user()),
    authStatusProvider.overrideWith((ref) => AuthStatus.signedIn),
    studentsProvider.overrideWith((ref) => const [student]),
    teachersProvider.overrideWith((ref) => const [teacher]),
    uesProvider.overrideWith((ref) => const [ue]),
    academicSyncProvider.overrideWith((ref) async {}),
    scopedCoursesProvider.overrideWith((ref) => Stream.value(const [])),
    scopedSchedulesProvider.overrideWith((ref) => Stream.value(const [])),
    // Base locale et stockage chiffré en mémoire : la déconnexion volontaire
    // oublie les données du compte, ce qu'on vérifie ici sans greffon natif.
    localDatabaseProvider.overrideWith((ref) {
      final db = LocalDatabase.memory();
      ref.onDispose(db.close);
      return db;
    }),
    sessionStoreProvider.overrideWithValue(SessionStore(InMemoryKeyValueStore())),
    syncStateProvider.overrideWith((ref) => Stream.value(const SyncState())),
    sessionControllerProvider.overrideWith(
      (ref) => SessionController(ref, g, a, localDirectories: () async => const []),
    ),
  ]);
  return (container: container, gateway: g, auth: a);
}

void main() {
  group('SessionController.signOut', () {
    test('ferme la session serveur, vide cookies et providers, bascule sur signedOut', () async {
      final r = _rig();
      addTearDown(r.container.dispose);
      expect(r.container.read(currentUserProvider), isNotNull);

      await r.container.read(sessionControllerProvider).signOut();

      expect(r.auth.logouts, 1);
      expect(r.gateway.cookiesCleared, 1);
      expect(r.container.read(currentUserProvider), isNull);
      expect(r.container.read(studentsProvider), isEmpty);
      expect(r.container.read(teachersProvider), isEmpty);
      expect(r.container.read(uesProvider), isEmpty);
      expect(r.container.read(authStatusProvider), AuthStatus.signedOut);
    });

    test('départ volontaire : cache et outbox du compte oubliés ; expiration : conservés', () async {
      final r = _rig();
      addTearDown(r.container.dispose);
      final db = r.container.read(localDatabaseProvider);
      final owner = r.container.read(currentUserProvider)!.id;
      final outbox = Outbox(db);
      await db.upsertDocuments('academic_courses', owner, [const CachedDocument(id: 'c1', data: {})]);
      await outbox.enqueue(owner: owner, kind: OutboxKind.service, payload: {'path': '/x'});

      // Session expirée : on redemande le mot de passe, rien n'est perdu.
      await r.container.read(sessionControllerProvider).signOut(deleteRemoteSession: false, keepLocalData: true);
      expect(r.container.read(authStatusProvider), AuthStatus.signedOut);
      expect(await db.countDocuments('academic_courses', owner: owner), 1);
      expect(await outbox.pendingCount(owner), 1);

      // Départ volontaire : l'appareil oublie le compte.
      r.container.read(currentUserProvider.notifier).state = user();
      await r.container.read(sessionControllerProvider).signOut();
      expect(await db.countDocuments('academic_courses', owner: owner), 0);
      expect(await outbox.pendingCount(owner), 0);
    });

    test('une session déjà expirée côté serveur ne bloque pas la sortie', () async {
      final r = _rig(auth: _Auth(logoutError: AppwriteException('User (role: guests) missing scope', 401)));
      addTearDown(r.container.dispose);

      await r.container.read(sessionControllerProvider).signOut();

      expect(r.container.read(authStatusProvider), AuthStatus.signedOut);
      expect(r.container.read(currentUserProvider), isNull);
    });
  });

  group('SessionController.deleteOwnAccount', () {
    test('appelle /account delete-self puis nettoie l\'appareil sans retoucher la session', () async {
      final r = _rig();
      addTearDown(r.container.dispose);

      await r.container.read(sessionControllerProvider).deleteOwnAccount();

      expect(r.gateway.calls.single.$1, '/account');
      expect(r.gateway.calls.single.$2, {'action': 'delete-self'});
      // Le compte n'existe plus : supprimer la session répondrait 404.
      expect(r.auth.logouts, 0);
      expect(r.gateway.cookiesCleared, 1);
      expect(r.container.read(authStatusProvider), AuthStatus.signedOut);
    });

    test('un refus du serveur laisse la session intacte et remonte un message lisible', () async {
      final r = _rig(
          gateway:
              _Gateway(serviceResponse: () => const {'ok': false, 'code': 'SUPERADMIN_PROTECTED', 'message': 'x'}));
      addTearDown(r.container.dispose);

      await expectLater(
        r.container.read(sessionControllerProvider).deleteOwnAccount(),
        throwsA(
            isA<AccountDeletionException>().having((e) => e.message, 'message', contains('administre la plateforme'))),
      );
      expect(r.container.read(authStatusProvider), AuthStatus.signedIn);
      expect(r.container.read(currentUserProvider), isNotNull);
    });

    test('service non déployé (404) : message d\'attente, pas de pile', () async {
      final r = _rig(gateway: _Gateway(serviceError: AppwriteException('Not found', 404, 'general_route_not_found')));
      addTearDown(r.container.dispose);

      await expectLater(
        r.container.read(sessionControllerProvider).deleteOwnAccount(),
        throwsA(isA<AccountDeletionException>().having((e) => e.message, 'message', contains('pas encore disponible'))),
      );
    });
  });

  group('describeDeletionFailure', () {
    test('traduit les codes usuels', () {
      expect(describeDeletionFailure(code: 500, message: 'boom'), contains('Réessayez plus tard'));
      expect(describeDeletionFailure(code: 401), contains('session a expiré'));
      expect(describeDeletionFailure(code: 'SERVICE_UNKNOWN'), contains('pas encore disponible'));
      expect(describeDeletionFailure(message: 'SocketException: Failed host lookup'), contains('injoignable'));
      expect(describeDeletionFailure(message: 'Texte serveur'), 'Texte serveur');
      expect(describeDeletionFailure(), 'La suppression du compte a échoué.');
    });

    test('isSessionExpired reconnaît un 401 Appwrite ou textuel', () {
      expect(isSessionExpired(AppwriteException('x', 401)), isTrue);
      expect(isSessionExpired(AppwriteException('x', 403)), isFalse);
      expect(isSessionExpired(Exception('HTTP 401 Unauthorized')), isTrue);
      expect(isSessionExpired(null), isFalse);
    });

    test('deletionKeywordMatches exige le mot exact', () {
      expect(deletionKeywordMatches('SUPPRIMER'), isTrue);
      expect(deletionKeywordMatches('  SUPPRIMER '), isTrue);
      expect(deletionKeywordMatches('supprimer'), isFalse);
      expect(deletionKeywordMatches(''), isFalse);
    });
  });

  group('écran Réglages : Se déconnecter', () {
    testWidgets('confirme, puis passe par le contrôleur de session', (tester) async {
      final r = _rig();
      addTearDown(r.container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: r.container,
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();

      // La section « Hors ligne » a allongé la page : le bouton est sous le
      // pli en 800×600, `scrollUntilVisible` ne garantit pas qu'il soit
      // réellement à l'écran, `ensureVisible` oui.
      await tester.scrollUntilVisible(find.text('Se déconnecter'), 200);
      await tester.ensureVisible(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(find.text('Se déconnecter ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Se déconnecter'));
      await tester.pumpAndSettle();

      expect(r.auth.logouts, 1);
      expect(r.container.read(authStatusProvider), AuthStatus.signedOut);
      expect(tester.takeException(), isNull);
    });
  });

  group('écran Supprimer mon compte', () {
    Future<void> pumpScreen(WidgetTester tester, ProviderContainer container) async {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DeleteAccountScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('mauvais mot de passe : erreur, on reste à l\'étape 1', (tester) async {
      final r = _rig();
      addTearDown(r.container.dispose);
      await pumpScreen(tester, r.container);

      await tester.enterText(find.byType(TextField), 'faux');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
      expect(find.text('Supprimer définitivement mon compte'), findsNothing);
      expect(r.gateway.calls, isEmpty);
    });

    testWidgets('bon mot de passe puis SUPPRIMER : appel du service et écran de succès', (tester) async {
      final r = _rig();
      addTearDown(r.container.dispose);
      await pumpScreen(tester, r.container);

      await tester.enterText(find.byType(TextField), 'secret');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer définitivement mon compte'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'supprimer');
      await tester.tap(find.text('Supprimer définitivement mon compte'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Recopiez exactement'), findsOneWidget);
      expect(r.gateway.calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'SUPPRIMER');
      await tester.tap(find.text('Supprimer définitivement mon compte'));
      // L'écran de succès porte Uni qui saute de joie en boucle :
      // `pumpAndSettle` ne se stabiliserait jamais, on avance d'un temps fixe.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(r.gateway.calls.single.$1, '/account');
      expect(find.text('Compte supprimé'), findsOneWidget);
      expect(r.container.read(authStatusProvider), AuthStatus.signedOut);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un superadmin n\'a pas le formulaire', (tester) async {
      final r = _rig(
        currentUser: () => UniFlowUser(
          id: 'k',
          email: 'kernel@forge.codes',
          name: 'Kernel',
          accountType: 'UNIVERSITY',
          role: 'ADMIN',
          labels: const ['ADMIN', 'superadmin'],
        ),
      );
      addTearDown(r.container.dispose);
      await pumpScreen(tester, r.container);

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('ne peut pas être supprimé'), findsOneWidget);
    });
  });
}
