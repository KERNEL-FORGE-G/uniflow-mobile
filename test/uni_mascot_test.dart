import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/widgets/uni/uni_assistant.dart';
import 'package:uniflow_mobile/widgets/uni/uni_mascot.dart';
import 'package:uniflow_mobile/widgets/uni/uni_scenes.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  group('UniPose', () {
    test('chaque pose pointe un asset WebP embarqué', () {
      for (final pose in UniPose.values) {
        expect(pose.asset, startsWith('assets/mascot/uni_'));
        expect(pose.asset, endsWith('.webp'));
        expect(pose.ratio, greaterThan(0));
        expect(pose.alt, isNotEmpty);
      }
    });
  });

  group('UniMascot', () {
    testWidgets('réserve la boîte au ratio de la pose et expose l’alt', (tester) async {
      await tester.pumpWidget(_wrap(const UniMascot(pose: UniPose.sorry, size: 100)));
      await tester.pump(const Duration(milliseconds: 600));
      final box = tester.getSize(find.byType(Image));
      expect(box.height, 100);
      expect(box.width, closeTo(100 * UniPose.sorry.ratio, 0.5));
      expect(find.bySemanticsLabel(UniPose.sorry.alt), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la bulle s’affiche à côté du personnage', (tester) async {
      await tester.pumpWidget(_wrap(
        const UniMascot(pose: UniPose.wave, size: 80, bubble: Text('Bonjour !')),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Bonjour !'), findsOneWidget);
      expect(find.byType(UniBubble), findsOneWidget);
    });

    testWidgets('sans mouvement demandé par le système, aucune boucle ne tourne', (tester) async {
      await tester.pumpWidget(_wrap(
        const UniMascot(pose: UniPose.celebrate, size: 80),
        reduceMotion: true,
      ));
      // Avec une animation infinie, pumpAndSettle expirerait ; ici elle doit
      // se stabiliser, preuve que la boucle et les confettis sont coupés.
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('intensity 0 immobilise Uni sans couper l’entrée ni la bulle', (tester) async {
      await tester.pumpWidget(_wrap(
        const UniMascot(pose: UniPose.wave, size: 80, intensity: 0, bubble: Text('Chut.')),
      ));
      // Un ticker qui tournerait pour une amplitude nulle empêcherait ceci.
      await tester.pumpAndSettle();
      expect(find.text('Chut.'), findsOneWidget);
      expect(find.bySemanticsLabel(UniPose.wave.alt), findsOneWidget);
    });
  });

  group('UniScenes', () {
    testWidgets('UniLoading montre Uni qui réfléchit et le libellé', (tester) async {
      await tester.pumpWidget(_wrap(const UniLoading(label: 'Chargement…')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Chargement…'), findsOneWidget);
      expect(find.byType(UniDots), findsOneWidget);
      expect(find.bySemanticsLabel(UniPose.thinking.alt), findsOneWidget);
    });

    testWidgets('UniOops porte titre, message et action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(UniOops(
        title: 'Rien trouvé',
        message: 'Essayez autre chose.',
        pose: UniPose.search,
        action: FilledButton(onPressed: () => tapped = true, child: const Text('Réessayer')),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rien trouvé'), findsOneWidget);
      expect(find.text('Essayez autre chose.'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(tapped, isTrue);
    });

    testWidgets('UniCrashScreen s’affiche sans thème ni provider', (tester) async {
      await tester.pumpWidget(const UniCrashScreen(details: 'Boom'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Oups'), findsOneWidget);
      expect(find.text('Boom'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UniPeek n’apparaît qu’une fois par identifiant', (tester) async {
      UniPeek.shown.clear();
      await tester.pumpWidget(_wrap(const SizedBox(
        width: 300,
        height: 400,
        child: Stack(children: [UniPeek(id: 'test', message: 'Coucou', delay: Duration(milliseconds: 10))]),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));
      expect(UniPeek.shown, contains('test'));
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.offset, Offset.zero);

      // Une seconde instance (nouvel élément) avec le même identifiant reste cachée.
      await tester.pumpWidget(_wrap(const SizedBox(
        width: 300,
        height: 400,
        child: Stack(children: [UniPeek(key: ValueKey('bis'), id: 'test', message: 'Coucou', delay: Duration(milliseconds: 10))]),
      )));
      await tester.pump(const Duration(milliseconds: 100));
      final again = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(again.offset, isNot(Offset.zero));
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('UniPeek : dans une fenêtre étroite, la bulle se replie au lieu de déborder', (tester) async {
      // Symptôme corrigé : en 420 px avec la barre latérale, la bulle
      // (260 px) plus Uni (96 px) dépassaient de 55 px à droite — un
      // « RenderFlex overflowed » à chaque premier lancement.
      UniPeek.shown.clear();
      const host = ValueKey('hote-etroit');
      await tester.pumpWidget(_wrap(const SizedBox(
        key: host,
        width: 300,
        height: 400,
        child: Stack(children: [
          UniPeek(
            id: 'etroit',
            message: 'Salut ! Je suis Uni. Une question sur tes cours ou l’appli ? Touche-moi.',
            delay: Duration(milliseconds: 10),
          ),
        ]),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      final cadre = tester.getRect(find.byKey(host));
      final uni = tester.getRect(find.byType(UniMascot));
      final bulle = tester.getRect(find.byType(UniBubble));
      expect(uni.right, lessThanOrEqualTo(cadre.right + 0.5));
      expect(bulle.left, greaterThanOrEqualTo(cadre.left - 0.5));
      expect(bulle.width, lessThan(260));
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('UniMarkdownLite', () {
    testWidgets('rend paragraphes, puces et gras sans HTML', (tester) async {
      await tester.pumpWidget(_wrap(const UniMarkdownLite(
        'Voici **deux** cours :\n* Algo\n- Réseaux\n\nBonne journée.',
        baseStyle: TextStyle(fontSize: 14),
      )));
      expect(find.textContaining('Algo'), findsOneWidget);
      expect(find.textContaining('Réseaux'), findsOneWidget);
      expect(find.textContaining('Bonne journée.'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
    });
  });
}
