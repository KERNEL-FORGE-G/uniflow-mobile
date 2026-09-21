import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/widgets/uni/archlord_mascot.dart';
import 'package:uniflow_mobile/widgets/uni/mascot_dialogue.dart';
import 'package:uniflow_mobile/widgets/uni/uni_mascot.dart';

/// Une colonne de [width] px, contraintes lâches à l'intérieur : la scène
/// prend la largeur qu'elle veut, mais jamais plus que l'écran simulé.
Widget _wrap(Widget child, {bool reduceMotion = false, double width = 360}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: width, child: Center(child: child)))),
    ),
  );
}

const _lines = [
  DialogueLine.archlord('Première réplique du fondateur, assez longue pour occuper deux lignes en 360 px.'),
  DialogueLine.uni('Réponse d’Uni.'),
  DialogueLine.archlord('Dernière réplique.'),
];

/// Un paquet d'assets vide : simule l'image absente du binaire.
class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw FlutterError('asset absent : $key');
}

void main() {
  group('ArchlordPose', () {
    test('chaque pose pointe un asset WebP réellement présent', () {
      for (final pose in ArchlordPose.values) {
        expect(pose.asset, startsWith('assets/mascot/archlord_'));
        expect(pose.asset, endsWith('.webp'));
        expect(pose.ratio, greaterThan(0));
        expect(pose.alt, isNotEmpty);
        // Le repli couvre l'asset manquant à l'exécution ; ici on veut au
        // contraire savoir dès les tests qu'un fichier a été oublié.
        expect(File(pose.asset).existsSync(), isTrue, reason: '${pose.asset} manque');
      }
      expect(File(kArchlordUniFistbumpAsset).existsSync(), isTrue);
    });
  });

  group('ArchlordMascot', () {
    testWidgets('réserve la boîte au ratio de la pose et expose l’alt', (tester) async {
      await tester.pumpWidget(_wrap(const ArchlordMascot(pose: ArchlordPose.wave, size: 120)));
      await tester.pump(const Duration(milliseconds: 600));
      final box = tester.getSize(find.byType(Image));
      expect(box.height, 120);
      expect(box.width, closeTo(120 * ArchlordPose.wave.ratio, 0.5));
      expect(find.bySemanticsLabel(ArchlordPose.wave.alt), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la bulle s’affiche à côté du personnage sans déborder en 360 px', (tester) async {
      await tester.pumpWidget(_wrap(const ArchlordMascot(
        pose: ArchlordPose.explain,
        size: 110,
        bubble: Text('Tes données restent sur le téléphone, même un mois sans réseau.'),
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(UniBubble), findsOneWidget);
      expect(find.textContaining('un mois sans réseau'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quand il parle, la boucle tourne ; en mouvement réduit, elle se stabilise', (tester) async {
      await tester.pumpWidget(_wrap(const ArchlordMascot(pose: ArchlordPose.explain, talking: true)));
      await tester.pump(const Duration(milliseconds: 400));
      // Une boucle infinie a des frames planifiées en permanence.
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(_wrap(
        const ArchlordMascot(pose: ArchlordPose.explain, talking: true),
        reduceMotion: true,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('still coupe la boucle', (tester) async {
      await tester.pumpWidget(_wrap(const ArchlordMascot(pose: ArchlordPose.laptop, still: true)));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('sans asset, un repli s’affiche à la place du fichier manquant', (tester) async {
      await tester.pumpWidget(_wrap(DefaultAssetBundle(
        bundle: _EmptyBundle(),
        child: const ArchlordMascot(pose: ArchlordPose.wave, size: 100),
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la scène à deux réserve sa boîte et expose son alt', (tester) async {
      await tester.pumpWidget(_wrap(const ArchlordUniFistbump(size: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      final box = tester.getSize(find.byType(ArchlordUniFistbump));
      expect(box.height, 100);
      expect(box.width, closeTo(100 * kArchlordUniFistbumpRatio, 0.5));
      expect(find.bySemanticsLabel('Archlord et Uni se saluent du poing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MascotDialogue', () {
    testWidgets('affiche une réplique à la fois et avance au toucher', (tester) async {
      await tester.pumpWidget(_wrap(const MascotDialogue(lines: _lines, autoAdvance: false)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Première réplique'), findsOneWidget);
      expect(find.text('Réponse d’Uni.'), findsNothing);

      await tester.tap(find.byType(MascotDialogue));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Réponse d’Uni.'), findsOneWidget);
      expect(find.textContaining('Première réplique'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('avance seul après l’intervalle et boucle après la dernière', (tester) async {
      const interval = Duration(seconds: 1);
      await tester.pumpWidget(_wrap(const MascotDialogue(lines: _lines, interval: interval)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Première réplique'), findsOneWidget);

      // Chaque pas avance d'exactement un intervalle : le minuteur armé à la
      // réplique précédente tombe dans la fenêtre, et un seul.
      await tester.pump(interval);
      expect(find.text('Réponse d’Uni.'), findsOneWidget);

      await tester.pump(interval);
      expect(find.text('Dernière réplique.'), findsOneWidget);

      await tester.pump(interval);
      expect(find.textContaining('Première réplique'), findsOneWidget);
    });

    testWidgets('sans boucle, s’arrête sur la dernière réplique', (tester) async {
      await tester.pumpWidget(_wrap(const MascotDialogue(
        lines: _lines,
        loop: false,
        interval: Duration(milliseconds: 200),
      )));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('Dernière réplique.'), findsOneWidget);
    });

    testWidgets('le personnage qui parle est celui qui s’anime le plus', (tester) async {
      await tester.pumpWidget(_wrap(const MascotDialogue(lines: _lines, autoAdvance: false)));
      await tester.pump(const Duration(milliseconds: 300));
      var archlord = tester.widget<ArchlordMascot>(find.byType(ArchlordMascot));
      var uni = tester.widget<UniMascot>(find.byType(UniMascot));
      expect(archlord.talking, isTrue);
      expect(archlord.intensity, 1);
      expect(uni.intensity, lessThan(1));

      await tester.tap(find.byType(MascotDialogue));
      await tester.pump(const Duration(milliseconds: 300));
      archlord = tester.widget<ArchlordMascot>(find.byType(ArchlordMascot));
      uni = tester.widget<UniMascot>(find.byType(UniMascot));
      expect(archlord.talking, isFalse);
      expect(archlord.intensity, lessThan(1));
      expect(uni.intensity, 1);
    });

    testWidgets('en mouvement réduit, toutes les répliques sont visibles et rien ne bouge', (tester) async {
      await tester.pumpWidget(_wrap(const MascotDialogue(lines: _lines), reduceMotion: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Première réplique'), findsOneWidget);
      expect(find.text('Réponse d’Uni.'), findsOneWidget);
      expect(find.text('Dernière réplique.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('tient en $width px sans débordement, texte ×1.3', (tester) async {
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(width: width, child: const MascotDialogue(lines: _lines, autoAdvance: false)),
              ),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        for (var i = 0; i < _lines.length; i++) {
          await tester.tap(find.byType(MascotDialogue));
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
