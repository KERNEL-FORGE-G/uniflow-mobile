// Bord à bord et barres système.
//
// Android 15 rend les barres de statut et de navigation transparentes pour
// toute application visant l'API 35 : c'est l'application qui dit la couleur
// de leurs icônes. Rien ne le disait, et les icônes blanches par défaut
// disparaissaient au-dessus du fond clair de la connexion. Ces tests lisent le
// style effectivement transmis à la plateforme (`SystemChrome.latestStyle`)
// après le rendu de chaque région.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/theme/app_theme.dart';
import 'package:uniflow_mobile/widgets/auth_widgets.dart';
import 'package:uniflow_mobile/widgets/common.dart';

void main() {
  Widget host(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

  group('Styles des barres système', () {
    test('les deux styles laissent les barres transparentes, sans voile de contraste', () {
      for (final style in [AppSystemUi.surBleu, AppSystemUi.surClair]) {
        expect(style.statusBarColor, Colors.transparent);
        expect(style.systemNavigationBarColor, Colors.transparent);
        // Android 10-14 pose sinon un voile semi-opaque sous les icônes quand
        // la barre est transparente : un bandeau gris au-dessus de la barre
        // du bas blanche.
        expect(style.systemStatusBarContrastEnforced, isFalse);
        expect(style.systemNavigationBarContrastEnforced, isFalse);
        // La barre de navigation repose toujours sur une surface claire.
        expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      }
      expect(AppSystemUi.surBleu.statusBarIconBrightness, Brightness.light);
      expect(AppSystemUi.surClair.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('appliquer() demande le mode bord à bord à la plateforme', (tester) async {
      final appels = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        appels.add(call);
        return null;
      });
      await AppSystemUi.appliquer();
      final mode = appels.where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode');
      expect(mode, hasLength(1));
      expect(mode.single.arguments, 'SystemUiMode.edgeToEdge');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('Régions annotées', () {
    testWidgets('un en-tête bleu demande des icônes de statut claires', (tester) async {
      await tester.pumpWidget(host(const Scaffold(body: Column(children: [GradientHeader(title: 'Accueil')]))));
      await tester.pump();
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
      expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    });

    testWidgets('l\'écran de connexion demande des icônes de statut sombres', (tester) async {
      await tester.pumpWidget(host(const AuthScaffold(showBrand: false, child: SizedBox(height: 40))));
      await tester.pump();
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
      expect(SystemChrome.latestStyle?.systemNavigationBarIconBrightness, Brightness.dark);
    });

    testWidgets('une AppBar du thème garde la barre de statut transparente', (tester) async {
      // AppBar peindrait sinon la barre de statut en bleu opaque sur
      // Android < 15, différent du dégradé des autres écrans.
      await tester.pumpWidget(host(Scaffold(appBar: AppBar(title: const Text('Conversation')))));
      await tester.pump();
      expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    });
  });
}
