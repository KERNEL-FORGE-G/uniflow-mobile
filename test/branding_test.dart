// Garde-fou sur l'identité visuelle.
//
// Deux pièges se sont déjà refermés ici, et ce test existe pour qu'ils ne se
// referment pas :
//
// 1. **Deux mécanismes se disputaient les icônes.** `pubspec.yaml` déclarait
//    `flutter_launcher_icons` avec `android: "launcher_icon"` — alors que le
//    manifeste et `res/mipmap-*/` disent `ic_launcher` — et `ios: true` alors
//    qu'il n'existe aucun dossier `ios/` dans ce dépôt. Lancer l'outil aurait
//    créé un jeu d'icônes parallèle, jamais référencé par le manifeste : le
//    logo affiché aurait dépendu de la densité, sans que rien ne le signale.
//    Les icônes sont donc produites par `tools/generer-icones-uniflow.py`, seul
//    propriétaire — et ce test interdit qu'un second revienne.
//
// 2. **Le logo d'origine était livré sur fond blanc opaque.** Un carré blanc
//    plein dans un en-tête bleu foncé. Les logos de `assets/brand/` sont
//    transparents ; ce test vérifie qu'aucun écran ne retombe sur l'ancien
//    fichier, qui a été supprimé.
//
// 3. **L'icône adaptative posait l'écusson sur un aplat bleu marine `#1e3a8a`
//    — la couleur de la toque.** À 48 dp la toque disparaissait dans le fond et
//    il ne restait qu'un demi-« U » turquoise. Le fond est désormais une tuile
//    claire (PNG par densité) ; ce test lit le pixel central du fond et refuse
//    qu'il redevienne sombre. Il vérifie aussi que l'icône de barre d'état est
//    une silhouette blanche : Android ne garde que son alpha, une icône en
//    couleurs y devient un carré gris.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dimensions lues dans l'en-tête PNG (IHDR), sans dépendance à un décodeur :
/// le fichier est peut-être présent mais vide ou tronqué, et c'est justement ce
/// que l'on veut détecter.
({int width, int height})? _taillePng(File fichier) {
  if (!fichier.existsSync()) return null;
  final octets = fichier.readAsBytesSync();
  if (octets.length < 24) return null;
  final vue = ByteData.sublistView(Uint8List.fromList(octets));
  return (width: vue.getUint32(16), height: vue.getUint32(20));
}

/// Côté attendu d'une icône de lanceur, par densité (48dp × facteur).
const Map<String, int> _densites = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// Pixels RGBA d'un PNG, décodé par le moteur : c'est ce que verra Android.
///
/// Alpha « droit » (non prémultiplié) : avec `rawRgba`, un pixel blanc à demi
/// transparent se lit gris, et le test croirait le glyphe coloré.
Future<({int width, int height, Uint8List rgba})> _pixels(File fichier) async {
  final codec = await ui.instantiateImageCodec(fichier.readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final donnees = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  return (width: image.width, height: image.height, rgba: donnees!.buffer.asUint8List());
}

void main() {
  final racine = Directory.current.path;
  final res = '$racine/android/app/src/main/res';

  group('Icônes de lancement Android', () {
    test('chaque densité porte une icône héritée et une icône ronde, carrées, non vides', () {
      for (final entree in _densites.entries) {
        for (final nom in ['ic_launcher.png', 'ic_launcher_round.png']) {
          final fichier = File('$res/mipmap-${entree.key}/$nom');
          final taille = _taillePng(fichier);
          expect(taille, isNotNull, reason: '${fichier.path} est absent ou tronqué');
          expect(
            [taille!.width, taille.height],
            [entree.value, entree.value],
            reason: '$nom de ${entree.key} n\'est pas au bon format',
          );
        }
      }
    });

    test('chaque densité porte les trois couches adaptatives, à l\'échelle 108dp', () {
      // Les couches d'une icône adaptative sont des carrés de 108dp ; le script
      // y place l'écusson dans la zone sûre, mais le fichier lui-même doit
      // couvrir les 108dp, sinon le lanceur le rogne.
      for (final entree in _densites.entries) {
        final attendu = (entree.value / 48 * 108).round();
        for (final nom in [
          'ic_launcher_foreground.png',
          'ic_launcher_background.png',
          'ic_launcher_monochrome.png',
        ]) {
          final fichier = File('$res/mipmap-${entree.key}/$nom');
          final taille = _taillePng(fichier);
          expect(taille, isNotNull, reason: '${fichier.path} est absent');
          expect(
            [taille!.width, taille.height],
            [attendu, attendu],
            reason: '$nom de ${entree.key} doit faire ${attendu}px (108dp) '
                'pour que le lanceur le masque sans rogner l\'écusson',
          );
        }
      }
    });

    test('les deux icônes adaptatives référencent fond, couche avant et monochrome', () {
      for (final nom in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
        final xml = File('$res/mipmap-anydpi-v26/$nom');
        expect(xml.existsSync(), isTrue, reason: '${xml.path} est absent');
        final contenu = xml.readAsStringSync();
        expect(contenu, contains('@mipmap/ic_launcher_background'));
        expect(contenu, contains('@mipmap/ic_launcher_foreground'));
        // Sans couche <monochrome>, Android 13+ affiche l'icône en gris uni
        // quand l'utilisateur active les icônes thématiques.
        expect(contenu, contains('<monochrome android:drawable="@mipmap/ic_launcher_monochrome"'));
      }
      expect(
        File('$res/values/ic_launcher_background.xml').existsSync(),
        isFalse,
        reason: 'l\'ancien fond uni bleu marine ne doit pas survivre à côté du PNG : '
            'deux mécanismes se disputeraient le fond',
      );
    });

    test('le fond adaptatif est clair derrière la toque', () async {
      // Symptôme corrigé : sur l'aplat `#1e3a8a`, la toque — de la même
      // couleur — disparaissait, et l'icône se réduisait à un demi-« U ».
      TestWidgetsFlutterBinding.ensureInitialized();
      final fond = await _pixels(File('$res/mipmap-mdpi/ic_launcher_background.png'));
      final centre = (fond.height ~/ 2) * fond.width + fond.width ~/ 2;
      final r = fond.rgba[centre * 4], g = fond.rgba[centre * 4 + 1], b = fond.rgba[centre * 4 + 2];
      final luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
      expect(luminance, greaterThan(0.85), reason: 'le fond derrière l\'écusson doit rester clair (lu : $r,$g,$b)');
      expect(fond.rgba[centre * 4 + 3], 255, reason: 'la couche de fond doit être opaque');
    });

    test('la couche monochrome est une silhouette blanche dans la zone sûre', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final mono = await _pixels(File('$res/mipmap-mdpi/ic_launcher_monochrome.png'));
      var opaques = 0;
      for (var i = 0; i < mono.rgba.length; i += 4) {
        if (mono.rgba[i + 3] == 0) continue;
        opaques++;
        expect([mono.rgba[i], mono.rgba[i + 1], mono.rgba[i + 2]], [255, 255, 255],
            reason: 'le système teinte le glyphe par son alpha : tout pixel visible doit être blanc');
        // Zone sûre : disque de 66dp au centre des 108dp.
        final x = (i ~/ 4) % mono.width, y = (i ~/ 4) ~/ mono.width;
        final dx = x - (mono.width - 1) / 2, dy = y - (mono.height - 1) / 2;
        expect(dx * dx + dy * dy, lessThanOrEqualTo(33.5 * 33.5),
            reason: 'un pixel du glyphe sort de la zone sûre ($x,$y) : le lanceur le rognerait');
      }
      expect(opaques, greaterThan(200), reason: 'la couche monochrome est vide');
    });

    test('l\'icône de barre d\'état est une silhouette blanche de 24dp par densité', () async {
      // Android ne garde que l'alpha d'une icône de notification et la teinte
      // lui-même ; une icône en couleurs (l'ancien `@mipmap/ic_launcher`)
      // devient un carré gris dans la barre d'état.
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final entree in _densites.entries) {
        final fichier = File('$res/drawable-${entree.key}/ic_stat_uniflow.png');
        expect(fichier.existsSync(), isTrue, reason: '${fichier.path} est absent');
        final glyphe = await _pixels(fichier);
        final attendu = (entree.value / 48 * 24).round();
        expect([glyphe.width, glyphe.height], [attendu, attendu]);
        var visibles = 0;
        for (var i = 0; i < glyphe.rgba.length; i += 4) {
          if (glyphe.rgba[i + 3] == 0) continue;
          visibles++;
          expect([glyphe.rgba[i], glyphe.rgba[i + 1], glyphe.rgba[i + 2]], [255, 255, 255],
              reason: 'pixel coloré dans ${fichier.path}');
        }
        expect(visibles, greaterThan(attendu * attendu ~/ 10), reason: '${fichier.path} est vide');
      }
    });

    test('le manifeste pointe vers @mipmap/ic_launcher et son icône ronde', () {
      // Avec `flutter_launcher_icons` configuré sur `launcher_icon`, le
      // manifeste et les fichiers ne disaient plus la même chose.
      final manifeste = File('$racine/android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifeste, contains('android:icon="@mipmap/ic_launcher"'));
      expect(manifeste, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    });

    test('la planche de l\'icône retenue est versionnée dans docs/design', () {
      // C'est la seule trace visuelle du choix « tuile claire » : sans elle, la
      // prochaine session repart de l'aplat marine ou refait la comparaison.
      final planche = File('$racine/docs/design/icone-android.png');
      expect(_taillePng(planche), isNotNull, reason: '${planche.path} est absente');
    });

    test('un seul mécanisme possède les icônes', () {
      // On lit le pubspec *hors commentaires* : le fichier explique justement
      // pourquoi l'outil a été retiré, et citer son nom dans une explication ne
      // doit pas être pris pour une déclaration.
      final declarations = File('$racine/pubspec.yaml').readAsLinesSync().map((ligne) {
        final sansCommentaire = ligne.trimLeft().startsWith('#') ? '' : ligne.replaceAll(RegExp(r'\s+#.*$'), '');
        return sansCommentaire;
      }).join('\n');
      expect(
        declarations,
        isNot(contains('flutter_launcher_icons')),
        reason: 'les icônes sont produites par tools/generer-icones-uniflow.py ; '
            'une seconde configuration créerait un jeu parallèle',
      );
      expect(
        File('$racine/tools/generer-icones-uniflow.py').existsSync(),
        isTrue,
        reason: 'le générateur d\'icônes a disparu',
      );
    });
  });

  group('Logos de marque', () {
    test('les logos transparents sont présents et déclarés', () {
      for (final nom in [
        'uniflow_marque.png',
        'uniflow_logo_horizontal.png',
      ]) {
        final fichier = File('$racine/assets/brand/$nom');
        expect(fichier.existsSync(), isTrue, reason: '${fichier.path} absent');
        final taille = _taillePng(fichier);
        expect(taille!.width, greaterThan(0));
      }
      expect(
        File('$racine/pubspec.yaml').readAsStringSync(),
        contains('assets/brand/'),
        reason: 'sans cette déclaration, Image.asset échoue au premier écran',
      );
    });

    test('les logos sont réellement embarqués dans le bundle', () async {
      // Vérifier le fichier sur le disque ne suffit pas : un chemin mal écrit
      // ou une déclaration `assets:` oubliée dans le pubspec ne se voit ni à
      // l'analyse ni à la compilation. À l'exécution, `Image.asset` bascule
      // alors silencieusement sur son `errorBuilder` — l'écran affiche
      // l'icône de repli au lieu du logo, sans la moindre erreur.
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final nom in [
        'uniflow_marque.png',
        'uniflow_logo_horizontal.png',
      ]) {
        final donnees = await rootBundle.load('assets/brand/$nom');
        expect(
          donnees.lengthInBytes,
          greaterThan(1000),
          reason: 'assets/brand/$nom est vide ou absent du bundle',
        );
      }
    });

    test('aucun écran ne référence l\'ancien logo sur fond blanc', () {
      // Ce fichier avait un fond blanc opaque : dans un en-tête bleu foncé, il
      // posait une tuile blanche. Il a été supprimé, et un écran qui le
      // référencerait encore afficherait l'icône de repli au lieu du logo.
      final references = <String>[];
      for (final entite in Directory('$racine/lib').listSync(recursive: true)) {
        if (entite is! File || !entite.path.endsWith('.dart')) continue;
        if (entite.readAsStringSync().contains('assets/logo.png')) {
          references.add(entite.path);
        }
      }
      expect(references, isEmpty);
      expect(
        File('$racine/assets/logo.png').existsSync(),
        isFalse,
        reason: 'l\'ancien logo ne doit pas rester : il alourdit l\'APK',
      );
    });
  });
}
