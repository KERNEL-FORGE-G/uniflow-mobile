// Écrans hors session d'après la maquette du 2026-09-21 : bandeau coloré avec
// accroche et Uni, feuille blanche qui porte le formulaire.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/screens/register.dart';
import 'package:uniflow_mobile/theme/app_theme.dart';
import 'package:uniflow_mobile/widgets/auth_widgets.dart';
import 'package:uniflow_mobile/widgets/uni/uni_mascot.dart';

import 'layout_test_support.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget bare(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  group('AuthScaffold', () {
    testWidgets('accroche avec le mot mis en couleur, Uni, pastille de marque et feuille', (tester) async {
      await tester.pumpWidget(bare(const AuthScaffold(
        headline: AuthHeadline('Connectez-vous pour rester ', 'au fil', ' de vos cours.'),
        pose: UniPose.wave,
        child: SizedBox(height: 40),
      )));
      await tester.pump(const Duration(milliseconds: 600));

      // L'accroche est exposée d'un bloc aux lecteurs d'écran.
      expect(find.bySemanticsLabel('Connectez-vous pour rester au fil de vos cours.'), findsOneWidget);
      final rich = tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && w.textSpan != null));
      final spans = (rich.textSpan as TextSpan).children!.cast<TextSpan>();
      expect(spans[1].text, 'au fil');
      expect(spans[1].style?.color, AppColors.authAccent);
      expect(spans[0].style?.color, isNull, reason: 'le reste hérite du blanc de base');

      expect(find.byType(UniMascot), findsOneWidget);
      expect(find.byType(BrandChip), findsOneWidget);
      expect(find.text('UniFlow'), findsOneWidget);
      expect(find.byTooltip('Retour'), findsNothing);
    });

    testWidgets('avec onBack, un bouton retour remplace la pastille', (tester) async {
      var back = false;
      await tester.pumpWidget(bare(AuthScaffold(
        onBack: () => back = true,
        child: const SizedBox(height: 40),
      )));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(BrandChip), findsNothing);
      await tester.tap(find.byTooltip('Retour'));
      expect(back, isTrue);
    });

    testWidgets('la feuille descend jusqu\'en bas même avec un contenu court', (tester) async {
      tester.view.physicalSize = const Size(411, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(bare(const AuthScaffold(child: SizedBox(height: 10))));
      await tester.pump(const Duration(milliseconds: 600));

      // La feuille = le conteneur blanc aux coins hauts arrondis.
      final sheet = tester.getRect(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius ==
              const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusAuthSheet))));
      expect(sheet.bottom, greaterThanOrEqualTo(800));
      expect(sheet.top, greaterThanOrEqualTo(kAuthHeroMinHeight));
    });

    testWidgets('le sélecteur de type de compte est un segment à deux choix', (tester) async {
      UniFlowAccountType? chosen;
      await tester.pumpWidget(bare(Scaffold(
        body: AccountTypeSelector(value: UniFlowAccountType.university, onChanged: (t) => chosen = t),
      )));
      await tester.tap(find.text('Compte indépendant'));
      expect(chosen, UniFlowAccountType.personal);
    });
  });

  group('Inscription', () {
    test('la confirmation du mot de passe doit reprendre le mot de passe', () {
      expect(passwordConfirmationError('motdepasse', ''), 'Confirmez votre mot de passe.');
      expect(passwordConfirmationError('motdepasse', 'motdepass'), 'Les deux mots de passe ne correspondent pas.');
      expect(passwordConfirmationError('motdepasse', 'motdepasse'), isNull);
    });

    testWidgets('le formulaire demande la confirmation et bascule vers la connexion', (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Créer un compte'), findsOneWidget);
      expect(find.text('Déjà un compte ?'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Confirmer le mot de passe'), findsOneWidget);
      expect(find.text('Créer mon compte étudiant'), findsOneWidget);
      // Aucun bouton de connexion sociale : Appwrite n'a pas de fournisseur
      // OAuth configuré, et un bouton qui ne mène nulle part ne serait pas
      // « 100 % fonctionnel ».
      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('Apple'), findsNothing);
    });
  });
}
