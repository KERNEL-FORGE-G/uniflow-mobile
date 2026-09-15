// Le bouton « + » du forum ne faisait rien, et les « j'aime » étaient affichés
// sans être cliquables — avec, en prime, un nombre de commentaires écrit en dur
// alors qu'aucune collection de commentaires n'existe.
//
// En câblant la création, un défaut latent est apparu : `createPost` envoyait
// un attribut `tags` que la collection `forum_posts` ne déclare pas. Appwrite
// refuse alors le document entier. Le web connaissait déjà le problème et
// retirait `tags` avant d'écrire ; le mobile, non.
//
// `forumPostPayload` est pure : elle se teste sans réseau ni Appwrite.

import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/repositories/forum_repository.dart';
import 'package:uniflow_mobile/screens/forum.dart';

void main() {
  Map<String, dynamic> payload({String university = 'Université de Yaoundé I'}) => forumPostPayload(
        title: 'Un vrai gain de temps',
        content: 'Le module de notes est clair.',
        category: 'Retour d\'expérience',
        authorId: 'u1',
        authorName: 'Ravel',
        role: 'STUDENT',
        university: university,
      );

  group('forumPostPayload', () {
    test('n’écrit pas `tags`, absent du schéma', () {
      // C'est la correction : l'attribut n'existe pas, et sa présence faisait
      // échouer la création entière avec « Unknown attribute: tags ».
      expect(payload().containsKey('tags'), isFalse);
    });

    test('n’écrit que des attributs déclarés au schéma', () {
      // Relevé de `scripts/appwrite-schema.mjs`, collection `forum_posts`.
      const declares = {
        'authorId',
        'authorName',
        'role',
        'university',
        'title',
        'content',
        'category',
        'rating',
        'likes',
        'createdAt',
      };
      expect(payload().keys.toSet().difference(declares), isEmpty);
    });

    test('porte les champs requis par le schéma', () {
      final document = payload();
      for (final requis in ['authorId', 'authorName', 'role', 'title', 'content', 'category']) {
        expect(document[requis], isA<String>(), reason: '$requis doit être une chaîne');
        expect((document[requis] as String).isNotEmpty, isTrue, reason: '$requis est requis');
      }
    });

    test('part de zéro recommandation', () {
      // Le compteur est recalculé par la Function à partir des réactions
      // réelles ; une valeur fournie par le client serait un compteur truqué.
      expect(payload()['likes'], 0);
    });

    test('horodate la création, pour que le tri du forum fonctionne', () {
      expect(DateTime.tryParse(payload()['createdAt'] as String), isNotNull);
    });
  });

  group('forumCategories', () {
    test('reprend les catégories du web', () {
      // Elles étaient recopiées à la main dans la boîte de dialogue ; un écart
      // ferait apparaître dans le fil des catégories que le web ne filtre pas.
      expect(forumCategories, [
        'Retour d\'expérience',
        'Question',
        'Suggestion',
        'Support',
      ]);
    });
  });
}
