// L'écran Bibliothèque affichait « Téléchargement bientôt disponible » alors
// que la ressource était déjà dans le bucket `uniflow_assets` et lisible : le
// bouton ne faisait rien. Il télécharge désormais réellement, puis confie le
// fichier au système — ce qui suppose d'en écrire une copie locale, donc d'en
// bâtir un nom de fichier sûr à partir d'un titre venu de la base.
//
// `libraryFileName` est pure : elle se teste sans réseau, sans Appwrite et sans
// système de fichiers.

import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/repositories/academic_repository.dart';

void main() {
  group('libraryFileName', () {
    test('conserve un titre ordinaire', () {
      expect(
        libraryFileName('Introduction aux réseaux', 'abc123'),
        'uniflow_abc123_Introduction aux réseaux',
      );
    });

    test('neutralise la barre oblique qui créerait un dossier', () {
      // Sans cela, `File('…/uniflow_x_Chapitre 1/2.pdf')` échoue : le dossier
      // intermédiaire n'existe pas.
      final nom = libraryFileName('Chapitre 1/2', 'abc123');
      expect(nom, isNot(contains('/')));
      expect(nom, 'uniflow_abc123_Chapitre 1_2');
    });

    test('neutralise les caractères interdits par les systèmes de fichiers', () {
      for (final titre in ['a\\b', 'a:b', 'a*b', 'a?b', 'a"b', 'a<b>c', 'a|b']) {
        final nom = libraryFileName(titre, 'abc123');
        expect(
          RegExp(r'^[\w\s.-]+$').hasMatch(nom.substring('uniflow_abc123_'.length)),
          isTrue,
          reason: '« $titre » donne « $nom », qui contient encore un caractère interdit',
        );
      }
    });

    test('supprime les retours à la ligne et les espaces de bord', () {
      expect(libraryFileName('  Réseaux\n', 'x1'), 'uniflow_x1_Réseaux');
    });

    test('retombe sur un nom neutre quand le titre ne laisse rien', () {
      expect(libraryFileName('///', 'x1'), 'uniflow_x1_ressource');
      expect(libraryFileName('', 'x1'), 'uniflow_x1_ressource');
      expect(libraryFileName('   ', 'x1'), 'uniflow_x1_ressource');
    });

    test('préfixe par l’identifiant, pour que deux titres proches ne se heurtent pas', () {
      expect(libraryFileName('Cours', 'aaa'), isNot(libraryFileName('Cours', 'bbb')));
    });
  });
}
