// Icônes UniFlow : la table `subjectIcon` de `docs/icones-uniflow.md`, la
// couleur d'une matière, et la tuile `IconTile`.
//
// `subjectIcon` est une fonction pure partagée par les trois plateformes : ces
// tests fixent les cas de la spécification pour qu'un réordonnancement de la
// table ne change pas silencieusement l'icône d'un cours.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/widgets/phosphor.dart';
import 'package:uniflow_mobile/models/models.dart' show courseColorHex;
import 'package:uniflow_mobile/theme/app_theme.dart';
import 'package:uniflow_mobile/widgets/uni_icons.dart';

void main() {
  group('subjectIcon', () {
    test('cas de la spécification', () {
      expect(subjectIcon('Mathématiques'), PhosphorIconsDuotone.mathOperations);
      expect(subjectIcon('Anglais technique'), PhosphorIconsDuotone.translate);
      expect(subjectIcon('Réseaux informatiques'), PhosphorIconsDuotone.network);
      expect(subjectIcon('Bases de données avancées'), PhosphorIconsDuotone.database);
      expect(subjectIcon('Systèmes d\'exploitation'), PhosphorIconsDuotone.terminal);
      expect(subjectIcon('Introduction à la philosophie'), PhosphorIconsDuotone.feather);
    });

    test('insensible à la casse et aux accents', () {
      expect(subjectIcon('MATHÉMATIQUES'), PhosphorIconsDuotone.mathOperations);
      expect(subjectIcon('Systemes d exploitation'), PhosphorIconsDuotone.terminal);
      expect(subjectIcon('économie générale'), PhosphorIconsDuotone.coins);
    });

    test('le premier mot-clé de la table gagne', () {
      // « statistiques » et « informatique » : « statisti » précède « info ».
      expect(subjectIcon('Statistiques pour l\'informatique'), PhosphorIconsDuotone.chartLine);
      // « réseau » précède « sécur ».
      expect(subjectIcon('Sécurité des réseaux'), PhosphorIconsDuotone.network);
    });

    test('les mots très courts sont ancrés en début de mot', () {
      // « ia » n'est pas dans « Matériaux » ; « art » n'est pas dans
      // « Cartographie » ; « geo » n'attrape pas « algèbre géométrique »
      // (déjà pris par math).
      expect(subjectIcon('Matériaux composites'), subjectDefaultIcon.duotone);
      expect(subjectIcon('Cartographie'), subjectDefaultIcon.duotone);
      expect(subjectIcon('Intelligence artificielle'), PhosphorIconsDuotone.brain);
      expect(subjectIcon('IA et société'), PhosphorIconsDuotone.brain);
      expect(subjectIcon('Arts plastiques'), PhosphorIconsDuotone.palette);
    });

    test('le code n\'est consulté qu\'après le nom', () {
      // Le nom décide : le code « INF301 » n'impose pas l'icône de code.
      expect(subjectIcon('Réseaux', code: 'INF301'), PhosphorIconsDuotone.network);
      // Sans mot-clé dans le nom, le code sert de repli.
      expect(subjectIcon('UE optionnelle', code: 'MATH204'), PhosphorIconsDuotone.mathOperations);
    });

    test('BookOpen par défaut', () {
      expect(subjectIcon('Séminaire de rentrée'), PhosphorIconsDuotone.bookOpen);
      expect(subjectIcon(''), PhosphorIconsDuotone.bookOpen);
      expect(subjectIcon('   ', code: '   '), PhosphorIconsDuotone.bookOpen);
    });

    test('se décline dans les trois graisses', () {
      expect(subjectIcon('Physique', style: UniIconStyle.fill), PhosphorIconsFill.atom);
      expect(subjectIcon('Physique', style: UniIconStyle.bold), PhosphorIconsBold.atom);
      expect(subjectUniIcon('Chimie').fill, PhosphorIconsFill.flask);
    });
  });

  group('subjectColor', () {
    test('la couleur explicite gagne, avec ou sans dièse', () {
      expect(subjectColor('INF301', colorHex: '#7C3AED'), const Color(0xFF7C3AED));
      expect(subjectColor('INF301', colorHex: '7c3aed'), const Color(0xFF7C3AED));
    });

    test('sinon une couleur stable dérivée du code', () {
      final a = subjectColor('INF301');
      expect(a, subjectColor('INF301'));
      expect(a, subjectColor('INF301', colorHex: null));
      // Même palette que les cartes d'UE et l'emploi du temps.
      expect(a, Color(int.parse('FF${courseColorHex('INF301').substring(1)}', radix: 16)));
    });

    test('une couleur invalide est ignorée', () {
      expect(subjectColor('INF301', colorHex: 'rouge'), subjectColor('INF301'));
      expect(subjectColor('', colorHex: ''), isA<Color>());
    });
  });

  group('UniIcons', () {
    test('la table sémantique rend la graisse demandée', () {
      expect(UniIcons.dashboard(), PhosphorIconsDuotone.squaresFour);
      expect(UniIcons.dashboard(UniIconStyle.fill), PhosphorIconsFill.squaresFour);
      expect(UniIcons.dashboard(UniIconStyle.bold), PhosphorIconsBold.squaresFour);
    });
  });

  group('IconTile', () {
    Widget host(Widget child, {bool reduceMotion = true}) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(body: Center(child: child)),
        );

    testWidgets('respecte la taille demandée et porte l\'icône', (tester) async {
      await tester.pumpWidget(host(
        const IconTile(icon: PhosphorIconsDuotone.atom, color: AppColors.teal, size: IconTile.large),
      ));
      await tester.pumpAndSettle();
      final box = tester.getSize(find.byType(IconTile));
      expect(box, const Size(56, 56));
      expect(find.byIcon(PhosphorIconsDuotone.atom), findsOneWidget);
    });

    testWidgets('la variante douce n\'a ni dégradé ni ombre, la pleine a les deux', (tester) async {
      await tester.pumpWidget(host(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(
                key: Key('soft'),
                icon: PhosphorIconsDuotone.atom,
                color: AppColors.teal,
                variant: IconTileVariant.soft),
            IconTile(key: Key('filled'), icon: PhosphorIconsDuotone.atom, color: AppColors.teal),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      BoxDecoration decorationOf(String key) {
        final container = tester.widget<Container>(
          find.descendant(of: find.byKey(Key(key)), matching: find.byType(Container)).first,
        );
        return container.decoration! as BoxDecoration;
      }

      final soft = decorationOf('soft');
      expect(soft.gradient, isNull);
      expect(soft.boxShadow, isNull);
      expect(soft.color, AppColors.teal.withValues(alpha: 0.14));

      final filled = decorationOf('filled');
      expect(filled.gradient, isA<LinearGradient>());
      expect(filled.boxShadow, isNotEmpty);
    });

    testWidgets('sans animation quand « moins de mouvement » est actif', (tester) async {
      await tester.pumpWidget(host(
        const IconTile(icon: PhosphorIconsDuotone.atom, color: AppColors.teal, index: 5),
      ));
      // Aucun `TweenAnimationBuilder` ni `AnimatedScale` : rien à attendre.
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.byType(AnimatedScale), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('l\'apparition est finie et décalée par index', (tester) async {
      await tester.pumpWidget(host(
        const IconTile(icon: PhosphorIconsDuotone.atom, color: AppColors.teal, index: 3),
        reduceMotion: false,
      ));
      // À l'instant zéro, la tuile est encore invisible (décalage de 120 ms).
      await tester.pump(const Duration(milliseconds: 60));
      final early = tester.widget<Opacity>(
        find.descendant(of: find.byType(IconTile), matching: find.byType(Opacity)).first,
      );
      expect(early.opacity, 0);
      // Puis tout se pose : `pumpAndSettle` termine sans boucler.
      await tester.pumpAndSettle();
      final settled = tester.widget<Opacity>(
        find.descendant(of: find.byType(IconTile), matching: find.byType(Opacity)).first,
      );
      expect(settled.opacity, 1);
    });

    testWidgets('se rétracte à la pression puis revient', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        IconTile(icon: PhosphorIconsDuotone.atom, color: AppColors.teal, onTap: () => taps++),
        reduceMotion: false,
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.byType(IconTile)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.94);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      expect(taps, 1);
    });

    testWidgets('le libellé sémantique est annoncé une seule fois', (tester) async {
      await tester.pumpWidget(host(
        const IconTile(icon: PhosphorIconsDuotone.atom, color: AppColors.teal, semanticLabel: 'Physique'),
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Physique'), findsOneWidget);
    });
  });
}
