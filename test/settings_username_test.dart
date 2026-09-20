// « Sur le mobile, dans Paramètres, la page de modification du pseudo ne marche
// pas et me retourne une page d'erreur rouge. »
//
// Une « page rouge » est l'écran d'erreur de Flutter : une exception non
// rattrapée pendant la construction d'un widget. Ces tests exercent donc la
// boîte de dialogue pour de vrai — ouverture, saisie, validation, fermeture —
// et vérifient qu'aucune exception ne remonte, plutôt que de se contenter de
// comparer des chaînes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/screens/settings.dart';

import 'layout_test_support.dart';

/// Dépôt de comptes factice : il n'atteint jamais Appwrite.
///
/// Il permet de distinguer les deux moitiés du défaut : ce qui casse dans la
/// boîte de dialogue elle-même, et ce qui casse dans l'appel réseau.
///
/// `implements` et non `extends` : construire un vrai `AuthRepository`
/// demanderait un `AppwriteService`, donc `flutter_dotenv` chargé et une
/// connexion — ce qu'un test unitaire ne doit pas exiger.
class _AuthFactice implements AuthRepository {
  _AuthFactice({this.resultat, this.erreur});

  /// Profil renvoyé par un enregistrement réussi.
  final UniFlowUser? resultat;

  /// Erreur levée par l'enregistrement, pour l'exercer sans réseau.
  final Object? erreur;

  /// Pseudos effectivement transmis, pour vérifier la normalisation.
  final List<String> enregistres = [];

  @override
  Future<UniFlowUser> updateUsername(String userId, String username) async {
    enregistres.add(username);
    if (erreur != null) throw erreur!;
    return resultat ?? user();
  }

  @override
  Future<UniFlowUser?> getCurrentUser() async => resultat;

  @override
  Future<UniFlowUser?> refreshProfile() async => resultat;

  @override
  Future<void> login(String email, String password, {UniFlowAccountType? accountTypeHint}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<UniFlowUser> register(RegistrationInput input) async => resultat ?? user();

  @override
  Future<void> provisionAcademicRegistration({String matricule = ''}) async {}

  @override
  Future<void> sendPasswordRecovery(String email) async {}
}

Widget _host(AuthRepository depot) => host(
      const SettingsScreen(),
      overrides: [authRepositoryProvider.overrideWithValue(depot)],
    );

/// Ouvre la boîte de dialogue de pseudo depuis la tuile des Réglages.
Future<void> _ouvrirDialogue(WidgetTester tester) async {
  await tester.tap(find.text('Pseudo de messagerie'));
  await tester.pumpAndSettle();
}

void main() {
  group('boîte de dialogue du pseudo', () {
    testWidgets('s’ouvre sur le pseudo actuel, sans exception', (tester) async {
      await tester.pumpWidget(_host(_AuthFactice()));
      await _ouvrirDialogue(tester);

      expect(find.text('Changer de pseudo'), findsOneWidget);
      // Le champ part du pseudo en place : sans cela, l'utilisateur devrait le
      // retaper en entier pour corriger une seule lettre.
      expect(find.widgetWithText(TextField, 'ravel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('se referme par « Annuler » sans exception', (tester) async {
      // C'est le geste qui déclenchait la page rouge. Le contrôleur de saisie
      // était libéré juste après la fermeture de la boîte, alors que le champ
      // était encore monté le temps de l'animation de sortie.
      await tester.pumpWidget(_host(_AuthFactice()));
      await _ouvrirDialogue(tester);

      await tester.enterText(find.byType(TextField), 'ravel.nouveau');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Changer de pseudo'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('se referme par « Enregistrer » sans exception', (tester) async {
      final depot = _AuthFactice(resultat: user().copyWith(username: 'ravel.nouveau'));
      await tester.pumpWidget(_host(depot));
      await _ouvrirDialogue(tester);

      await tester.enterText(find.byType(TextField), 'ravel.nouveau');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(depot.enregistres, ['ravel.nouveau']);
    });
  });

  group('normalisation avant enregistrement', () {
    testWidgets('la casse et les espaces sont corrigés', (tester) async {
      final depot = _AuthFactice(resultat: user().copyWith(username: 'ravel.n'));
      await tester.pumpWidget(_host(depot));
      await _ouvrirDialogue(tester);

      await tester.enterText(find.byType(TextField), '  Ravel.N  ');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(depot.enregistres, ['ravel.n']);
    });

    testWidgets('un pseudo invalide est refusé sur place, sans appel réseau', (tester) async {
      final depot = _AuthFactice();
      await tester.pumpWidget(_host(depot));
      await _ouvrirDialogue(tester);

      // « a » est trop court : inutile de faire un aller-retour réseau pour
      // l'apprendre.
      await tester.enterText(find.byType(TextField), 'a');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(depot.enregistres, isEmpty);
      expect(find.textContaining('Pseudo invalide'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un pseudo inchangé n’est pas renvoyé au serveur', (tester) async {
      final depot = _AuthFactice();
      await tester.pumpWidget(_host(depot));
      await _ouvrirDialogue(tester);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(depot.enregistres, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('échec de l’enregistrement', () {
    testWidgets('un pseudo déjà pris est annoncé en clair', (tester) async {
      final depot = _AuthFactice(
        erreur: AuthException('Le pseudo « ravel » est déjà pris. Choisissez-en un autre.'),
      );
      await tester.pumpWidget(_host(depot));
      await _ouvrirDialogue(tester);

      await tester.enterText(find.byType(TextField), 'ravel2');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Le message reste affiché sur la page, l'utilisateur n'a pas à rouvrir
      // la boîte pour le relire.
      expect(find.textContaining('déjà pris'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
