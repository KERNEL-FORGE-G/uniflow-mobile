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

import 'dart:io';

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

void main() {
  final racine = Directory.current.path;

  group('Icônes de lancement Android', () {
    test('chaque densité porte une icône héritée carrée, non vide', () {
      for (final entree in _densites.entries) {
        final fichier = File(
          '$racine/android/app/src/main/res/mipmap-${entree.key}/ic_launcher.png',
        );
        final taille = _taillePng(fichier);
        expect(
          taille,
          isNotNull,
          reason: '${fichier.path} est absent ou tronqué',
        );
        expect(
          [taille!.width, taille.height],
          [entree.value, entree.value],
          reason: 'ic_launcher.png de ${entree.key} n\'est pas au bon format',
        );
      }
    });

    test('chaque densité porte une couche avant, à l\'échelle 108dp', () {
      // La couche avant d'une icône adaptative est un carré de 108dp ; le
      // script y place l'écusson à 60 % pour respecter la zone sûre, mais le
      // fichier lui-même doit couvrir les 108dp, sinon le lanceur le rogne.
      for (final entree in _densites.entries) {
        final fichier = File(
          '$racine/android/app/src/main/res/mipmap-${entree.key}'
          '/ic_launcher_foreground.png',
        );
        final taille = _taillePng(fichier);
        expect(taille, isNotNull, reason: '${fichier.path} est absent');
        final attendu = (entree.value / 48 * 108).round();
        expect(
          [taille!.width, taille.height],
          [attendu, attendu],
          reason:
              'la couche avant de ${entree.key} doit faire ${attendu}px '
              '(108dp) pour que le lanceur la masque sans rogner l\'écusson',
        );
      }
    });

    test('l\'icône adaptative référence un fond et une couche avant', () {
      final xml = File(
        '$racine/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      expect(xml.existsSync(), isTrue, reason: '${xml.path} est absent');
      final contenu = xml.readAsStringSync();
      expect(contenu, contains('@color/ic_launcher_background'));
      expect(contenu, contains('@mipmap/ic_launcher_foreground'));
    });

    test('le fond adaptatif est le bleu de marque du web', () {
      final xml = File(
        '$racine/android/app/src/main/res/values/ic_launcher_background.xml',
      );
      expect(xml.existsSync(), isTrue, reason: '${xml.path} est absent');
      // Relevé dans uniflow-we : c'est la couleur de marque, pas un choix local.
      expect(xml.readAsStringSync(), contains('#1e3a8a'));
    });

    test('le manifeste pointe bien vers @mipmap/ic_launcher', () {
      // Avec `flutter_launcher_icons` configuré sur `launcher_icon`, le
      // manifeste et les fichiers ne disaient plus la même chose.
      final manifeste = File(
        '$racine/android/app/src/main/AndroidManifest.xml',
      );
      expect(
        manifeste.readAsStringSync(),
        contains('android:icon="@mipmap/ic_launcher"'),
      );
    });

    test('un seul mécanisme possède les icônes', () {
      // On lit le pubspec *hors commentaires* : le fichier explique justement
      // pourquoi l'outil a été retiré, et citer son nom dans une explication ne
      // doit pas être pris pour une déclaration.
      final declarations = File('$racine/pubspec.yaml')
          .readAsLinesSync()
          .map((ligne) {
            final sansCommentaire = ligne.trimLeft().startsWith('#')
                ? ''
                : ligne.replaceAll(RegExp(r'\s+#.*$'), '');
            return sansCommentaire;
          })
          .join('\n');
      expect(
        declarations,
        isNot(contains('flutter_launcher_icons')),
        reason:
            'les icônes sont produites par tools/generer-icones-uniflow.py ; '
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
