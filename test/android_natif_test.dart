// Contrat des ressources Android natives : manifeste, écran de lancement,
// raccourcis. Ce que Flutter ne compile pas et que `flutter test` ne voit
// jamais tourner — un écran de lancement ou un raccourci cassé ne se découvre
// qu'en installant l'APK. Ces tests lisent les fichiers de `android/` et les
// confrontent aux constantes Dart qu'ils doivent refléter.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/router/app_router.dart';
import 'package:uniflow_mobile/services/notification_service.dart';
import 'package:uniflow_mobile/theme/app_theme.dart';

void main() {
  final racine = Directory.current.path;
  final res = '$racine/android/app/src/main/res';
  final manifeste = File('$racine/android/app/src/main/AndroidManifest.xml').readAsStringSync();

  group('Manifeste', () {
    test('le libellé du lanceur est la marque, avec ses majuscules', () {
      expect(manifeste, contains('android:label="UniFlow"'));
      expect(manifeste, isNot(contains('android:label="uniflow"')));
    });

    test('le retour prédictif est activé et aucun écran ne bloque le retour système', () {
      expect(manifeste, contains('android:enableOnBackInvokedCallback="true"'));
      // Un PopScope à canPop:false désactive l'animation de retour prédictif
      // sur son écran ; il faudrait alors le justifier ici.
      final bloqueurs = <String>[];
      for (final entite in Directory('$racine/lib').listSync(recursive: true)) {
        if (entite is! File || !entite.path.endsWith('.dart')) continue;
        final source = entite.readAsStringSync();
        if (source.contains('WillPopScope') || source.contains('canPop: false')) {
          bloqueurs.add(entite.path);
        }
      }
      expect(bloqueurs, isEmpty);
    });

    test('les permissions déclarées ont toutes un usage dans lib/', () {
      // Une permission déclarée sans code qui s'en sert fait peur à la
      // boutique et à l'utilisateur pour rien. Chaque entrée cite le fichier
      // qui la justifie ; retirer l'usage, c'est retirer la permission.
      const usages = {
        'android.permission.CAMERA': 'MobileScanner',
        'android.permission.ACCESS_FINE_LOCATION': 'Geolocator.getCurrentPosition',
        'android.permission.ACCESS_COARSE_LOCATION': 'Geolocator.getCurrentPosition',
        'android.permission.POST_NOTIFICATIONS': 'requestNotificationsPermission',
        'android.permission.VIBRATE': 'vibrationPattern',
        'android.permission.INTERNET': 'Client()',
      };
      final permissions =
          RegExp(r'<uses-permission android:name="([^"]+)"').allMatches(manifeste).map((m) => m.group(1)!).toSet();
      expect(permissions, usages.keys.toSet(), reason: 'permission ajoutée ou retirée sans mettre ce test à jour');

      final sources = Directory('$racine/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      for (final entree in usages.entries) {
        expect(sources, contains(entree.value),
            reason: '${entree.key} n\'a plus d\'usage (${entree.value} introuvable)');
      }
    });
  });

  group('Écran de lancement', () {
    test('le bleu Android est exactement AppColors.primaryBlue', () {
      // L'écran de lancement s'efface au premier rendu Flutter ; si les deux
      // fonds diffèrent, chaque démarrage fait un saut de couleur.
      final couleurs = File('$res/values/colors.xml').readAsStringSync();
      final hex = RegExp(r'<color name="uniflow_bleu_marque">#([0-9A-Fa-f]{6})</color>').firstMatch(couleurs)?.group(1);
      expect(hex, isNotNull, reason: 'uniflow_bleu_marque absente de values/colors.xml');
      final android = Color(0xFF000000 | int.parse(hex!, radix: 16));
      expect(android, AppColors.primaryBlue);
    });

    test('Android 12+ : fond de marque et icône adaptative', () {
      final v31 = File('$res/values-v31/styles.xml').readAsStringSync();
      expect(v31, contains('<style name="LaunchTheme"'));
      expect(v31, contains('name="android:windowSplashScreenBackground">@color/uniflow_bleu_marque<'));
      // L'icône adaptative, pas le PNG pré-rendu : un bitmap est étiré sur les
      // 288dp du conteneur puis rogné au disque de 192dp.
      expect(v31, contains('name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher<'));
    });

    test('Android < 12 : fond de marque et disque de l\'écusson par densité', () {
      final fond = File('$res/drawable/launch_background.xml').readAsStringSync();
      expect(fond, contains('@color/uniflow_bleu_marque'));
      expect(fond, contains('@drawable/splash_ecusson'));
      expect(
        File('$res/drawable-v21/launch_background.xml').existsSync(),
        isFalse,
        reason: 'minSdk 24 : la variante v21 remplacerait silencieusement le fichier de base',
      );
      for (final densite in const {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}.entries) {
        final fichier = File('$res/drawable-${densite.key}/splash_ecusson.png');
        expect(fichier.existsSync(), isTrue, reason: '${fichier.path} est absent');
        final octets = fichier.readAsBytesSync();
        final largeur = (octets[16] << 24) | (octets[17] << 16) | (octets[18] << 8) | octets[19];
        expect(largeur, (192 * densite.value).round(), reason: 'le disque doit faire 192dp');
      }
    });

    test('aucun LaunchTheme de nuit ne masque l\'écran de lancement système', () {
      // « night » prime sur « v31 » : un LaunchTheme dans values-night aurait
      // remplacé, en mode sombre, les attributs de values-v31.
      final nuit = File('$res/values-night/styles.xml').readAsStringSync();
      expect(nuit, isNot(contains('<style name="LaunchTheme"')));
      expect(nuit, contains('<style name="NormalTheme"'));
    });
  });

  group('Notifications', () {
    test('l\'icône de barre d\'état est un drawable dédié, présent par densité', () {
      // `@mipmap/ic_launcher` en couleurs donnait un carré gris : Android ne
      // garde que l'alpha. Le drawable référencé doit exister, sinon le greffon
      // lève à l'initialisation et plus aucune alerte n'est affichée.
      expect(notificationIcon, startsWith('@drawable/'));
      final nom = notificationIcon.substring('@drawable/'.length);
      for (final densite in const ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(File('$res/drawable-$densite/$nom.png').existsSync(), isTrue, reason: '$nom absent en $densite');
      }
    });
  });

  group('Release', () {
    final gradle = File('$racine/android/app/build.gradle.kts').readAsStringSync();

    test('la release est réduite par R8, avec les règles du dépôt', () {
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
      expect(gradle, contains('"proguard-rules.pro"'));
      expect(File('$racine/android/app/proguard-rules.pro').existsSync(), isTrue);
    });

    test('la signature vient de key.properties, jamais versionné, sans clé dans le dépôt', () {
      expect(gradle, contains('rootProject.file("key.properties")'));
      // Sans le fichier, on retombe sur la clé de debug : la compilation reste
      // vérifiable sur un poste sans secret.
      expect(gradle, contains('signingConfigs.getByName(if (signatureRelease) "release" else "debug")'));
      final ignore = File('$racine/android/.gitignore').readAsStringSync().split('\n').map((l) => l.trim());
      expect(ignore, containsAll(['key.properties', '**/*.keystore', '**/*.jks']));
      final suivis = Process.runSync('git', ['ls-files'], workingDirectory: racine).stdout as String;
      final secrets = suivis.split('\n').where(
            (f) => f.endsWith('key.properties') || f.endsWith('.jks') || f.endsWith('.keystore'),
          );
      expect(secrets, isEmpty, reason: 'un keystore ou ses mots de passe sont suivis par Git');
    });

    test('la réduction des ressources conserve l\'icône de notification désignée depuis Dart', () {
      // Référencée par une chaîne Dart, elle est invisible au réducteur, qui
      // la retirerait de l'APK : le système refuserait alors la notification.
      final keep = File('$res/raw/keep.xml').readAsStringSync();
      final conserves = RegExp(r'tools:keep="([^"]+)"').firstMatch(keep)?.group(1)?.split(',').map((s) => s.trim());
      expect(conserves, isNotNull, reason: 'res/raw/keep.xml sans attribut tools:keep');
      expect(conserves, contains(notificationIcon));
    });

    test('le .env embarqué ne contient que des identifiants publics', () {
      // Flutter déclare .env comme asset : il est lisible en clair dans l'APK.
      // Une clé d'API Appwrite y a déjà figuré ; ce test empêche son retour.
      final lignes =
          File('$racine/.env').readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('#'));
      const publics = {
        'APPWRITE_ENDPOINT',
        'APPWRITE_PROJECT_ID',
        'APPWRITE_DATABASE_ID',
        'APPWRITE_STORAGE_BUCKET_ID',
        'APPWRITE_AVATAR_BUCKET_ID',
        'APPWRITE_CHAT_FILES_BUCKET_ID',
        'APPWRITE_API_FUNCTION_ID',
      };
      for (final ligne in lignes) {
        final nom = ligne.split('=').first;
        final valeur = ligne.substring(nom.length + 1);
        expect(publics, contains(nom),
            reason: '$nom : variable inconnue dans .env, à justifier ici si elle est publique');
        expect(nom, isNot(matches(RegExp(r'KEY|SECRET|TOKEN|PASSWORD'))));
        // Une clé d'API Appwrite fait plus de 200 caractères hexadécimaux.
        expect(valeur.length, lessThan(80), reason: '$nom a une valeur de la taille d\'un secret');
      }
    });
  });

  group('launchLocationFromLink', () {
    test('ramène les deux écritures du schéma uniflow à la même route', () {
      // Trois barres : chemin. Deux barres : Uri y voit un hôte et un chemin
      // vide, que go_router n'apparierait à rien.
      expect(launchLocationFromLink(Uri.parse('uniflow:///emploi-du-temps')), '/emploi-du-temps');
      expect(launchLocationFromLink(Uri.parse('uniflow://emploi-du-temps')), '/emploi-du-temps');
      expect(launchLocationFromLink(Uri.parse('uniflow://messages/conv_1')), '/messages/conv_1');
    });

    test('conserve la requête et ignore les segments vides', () {
      expect(launchLocationFromLink(Uri.parse('uniflow:///register?type=personal')), '/register?type=personal');
      expect(launchLocationFromLink(Uri.parse('uniflow:///messages/')), '/messages');
      expect(launchLocationFromLink(Uri.parse('uniflow://')), '/');
    });

    test('laisse passer une adresse interne, et ne prend pas un hôte http pour une route', () {
      expect(launchLocationFromLink(Uri.parse('/accueil')), isNull);
      expect(launchLocationFromLink(Uri.parse('/messages/conv_1?x=1')), isNull);
      expect(launchLocationFromLink(Uri.parse('https://uniflow.app/notes')), '/notes');
    });

    test('après normalisation, la redirection ne boucle pas', () {
      // Le redirect renvoie l'adresse interne ; celle-ci, sans schéma, doit
      // rendre null au tour suivant — sinon go_router s'arrête sur une boucle.
      final interne = launchLocationFromLink(Uri.parse('uniflow:///notifications'))!;
      expect(launchLocationFromLink(Uri.parse(interne)), isNull);
    });
  });

  group('Raccourcis du lanceur', () {
    final fichier = File('$res/xml/shortcuts.xml');

    test('sont déclarés dans le manifeste', () {
      expect(fichier.existsSync(), isTrue, reason: '${fichier.path} est absent');
      expect(manifeste, contains('android:name="android.app.shortcuts"'));
      expect(manifeste, contains('android:resource="@xml/shortcuts"'));
    });

    test('chaque raccourci ouvre une adresse connue du routeur, via le schéma uniflow', () {
      final xml = fichier.readAsStringSync();
      final liens = RegExp(r'android:data="([^"]+)"').allMatches(xml).map((m) => m.group(1)!).toList();
      expect(liens, hasLength(3), reason: 'Emploi du temps, Messages, Notifications');
      for (final lien in liens) {
        final uri = Uri.parse(lien);
        expect(uri.scheme, 'uniflow', reason: '$lien : seul le schéma uniflow est reçu par le routeur');
        final chemin = launchLocationFromLink(uri);
        expect(chemin, isNotNull);
        expect(chemin, startsWith('/'));
        expect(routePaths, contains(chemin), reason: '$lien ne mène à aucune route déclarée');
      }
      // Les trois raccourcis ne visent pas la même page.
      expect(liens.toSet(), hasLength(3));
    });

    test('portent des libellés courts et longs, et une icône monochrome', () {
      final xml = fichier.readAsStringSync();
      expect(RegExp(r'<shortcut\b').allMatches(xml), hasLength(3));
      expect(xml, contains('android:shortcutShortLabel="@string/'));
      expect(xml, contains('android:shortcutLongLabel="@string/'));
      expect(xml, contains('android:icon="@drawable/ic_shortcut_'));
      // Les intents visent l'activité Flutter, avec l'action VIEW que
      // l'embedding transforme en route initiale.
      expect(xml, contains('android:targetClass="com.uniflow.kernelforge.MainActivity"'));
      expect(xml, isNot(contains('android:action="android.intent.action.MAIN"')));
    });
  });
}
