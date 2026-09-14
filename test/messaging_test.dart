// Tests de la messagerie enrichie : validation du pseudo, lecture d'un message
// porteur d'une pièce jointe, et filtrage des événements temps réel.
//
// Ces trois fonctions décident sans réseau : le pseudo est normalisé avant
// l'appel, la pièce jointe est décrite par la Function, et l'alerte n'est
// déclenchée que sur une création de notification urgente. Une erreur ici se
// traduirait par un pseudo invalide accepté, un fichier invisible, ou une
// notification affichée pour le message de quelqu'un d'autre.

import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/repositories/messaging_repository.dart';
import 'package:uniflow_mobile/services/notification_service.dart';

void main() {
  group('normalizeUsername', () {
    test('accepte un pseudo simple et le met en minuscules', () {
      expect(normalizeUsername('Ravel'), 'ravel');
      expect(normalizeUsername('  ravel  '), 'ravel');
    });

    test('retire l\'arobase initiale', () {
      expect(normalizeUsername('@ravel'), 'ravel');
      expect(normalizeUsername('@Ravel.Nghomsi'), 'ravel.nghomsi');
    });

    test('accepte point, tiret et souligné à l\'intérieur', () {
      expect(normalizeUsername('ravel.nghomsi'), 'ravel.nghomsi');
      expect(normalizeUsername('ravel-nghomsi'), 'ravel-nghomsi');
      expect(normalizeUsername('ravel_nghomsi'), 'ravel_nghomsi');
      expect(normalizeUsername('ravel2'), 'ravel2');
    });

    test('refuse un pseudo trop court ou trop long', () {
      expect(normalizeUsername('ab'), isNull);
      expect(normalizeUsername('a'), isNull);
      expect(normalizeUsername('a' * 33), isNull);
      // 32 caractères restent acceptés : c'est la taille de l'attribut.
      expect(normalizeUsername('a' * 32), 'a' * 32);
    });

    test('refuse un pseudo qui ne commence pas par une lettre ou un chiffre', () {
      expect(normalizeUsername('.ravel'), isNull);
      expect(normalizeUsername('-ravel'), isNull);
      expect(normalizeUsername('_ravel'), isNull);
    });

    test('refuse un pseudo qui se termine par un séparateur', () {
      expect(normalizeUsername('ravel.'), isNull);
      expect(normalizeUsername('ravel-'), isNull);
      expect(normalizeUsername('ravel_'), isNull);
    });

    test('refuse espaces, accents et caractères spéciaux', () {
      expect(normalizeUsername('ravel nghomsi'), isNull);
      expect(normalizeUsername('ravel@uniflow'), isNull);
      expect(normalizeUsername('ravel!'), isNull);
      // Un accent ne se normalise pas tout seul : le pseudo reste en ASCII,
      // c'est un identifiant, pas un nom affiché.
      expect(normalizeUsername('ravelé'), isNull);
    });
  });

  group('ChatMessage', () {
    /// Charge utile telle que la produit `asMessage` côté Function.
    Map<String, dynamic> payload({Map<String, dynamic> extra = const {}}) => {
          'id': 'm1',
          'from': 'them',
          'text': 'Compte rendu',
          'time': '2026-09-14T17:00:59.246+00:00',
          'senderId': 'u2',
          ...extra,
        };

    test('un message de texte seul n\'a pas de pièce jointe', () {
      final message = ChatMessage.fromJson(payload());
      expect(message.hasAttachment, isFalse);
      expect(message.isImage, isFalse);
      expect(message.kind, 'text');
      expect(message.urgent, isFalse);
      expect(message.readableSize, '');
      expect(message.mine, isFalse);
    });

    test('lit les métadonnées d\'une pièce jointe', () {
      final message = ChatMessage.fromJson(payload(extra: {
        'fileId': 'f1',
        'fileName': 'rapport.pdf',
        'fileSize': 2 * 1024 * 1024,
        'fileType': 'application/pdf',
        'kind': 'file',
      }));
      expect(message.hasAttachment, isTrue);
      expect(message.fileName, 'rapport.pdf');
      expect(message.readableSize, '2.0 Mo');
      expect(message.isImage, isFalse);
    });

    test('une image est reconnue par son `kind`, pas par son extension', () {
      final message = ChatMessage.fromJson(payload(extra: {
        'fileId': 'f2',
        'fileName': 'photo.jpg',
        'fileSize': 900,
        'fileType': 'image/jpeg',
        'kind': 'image',
      }));
      expect(message.isImage, isTrue);
      expect(message.readableSize, '900 o');
    });

    test('une taille inconnue ne produit pas de libellé', () {
      // `fileSize` absent (document antérieur à l'ajout de l'attribut) : mieux
      // vaut ne rien afficher qu'un « 0 o » trompeur.
      final message = ChatMessage.fromJson(payload(extra: {'fileId': 'f3'}));
      expect(message.fileSize, 0);
      expect(message.readableSize, '');
    });

    test('l\'urgence est portée par le message', () {
      final message = ChatMessage.fromJson(payload(extra: {'urgent': true}));
      expect(message.urgent, isTrue);
    });

    test('`from: me` marque le message comme envoyé par l\'utilisateur', () {
      final message = ChatMessage.fromJson(payload(extra: {'from': 'me'}));
      expect(message.mine, isTrue);
    });
  });

  group('AppNotification', () {
    AppNotification build({String link = ''}) => AppNotification(
          id: 'n1',
          type: 'MESSAGE_URGENT',
          title: 'Message urgent de William',
          message: 'Compte rendu',
          isRead: false,
          link: link,
          time: '2026-09-14T17:00:59.374+00:00',
        );

    test('extrait l\'identifiant de conversation du lien', () {
      expect(
        build(link: '/messages?conversation=conv_abc').conversationId,
        'conv_abc',
      );
    });

    test('s\'arrête au premier paramètre suivant', () {
      expect(
        build(link: '/messages?conversation=conv_abc&onglet=fichiers')
            .conversationId,
        'conv_abc',
      );
    });

    test('renvoie une chaîne vide sans lien exploitable', () {
      expect(build().conversationId, '');
      expect(build(link: '/messages').conversationId, '');
    });
  });

  group('isUrgentNotificationFor', () {
    const me = 'user-me';
    final document = <String, dynamic>{
      'ownerId': me,
      'type': 'MESSAGE_URGENT',
    };
    const create = ['databases.uniflow.collections.notifications.documents.create'];

    test('accepte une création de notification urgente qui m\'appartient', () {
      expect(isUrgentNotificationFor(create, document, me), isTrue);
    });

    test('ignore une mise à jour : seule la création doit alerter', () {
      const update = ['databases.uniflow.collections.notifications.documents.update'];
      expect(isUrgentNotificationFor(update, document, me), isFalse);
    });

    test('ignore la notification d\'un autre utilisateur', () {
      // C'est le point critique : le canal Appwrite peut livrer des documents
      // que l'utilisateur n'a pas le droit de lire, et afficher l'alerte d'un
      // tiers serait une fuite d'information.
      expect(isUrgentNotificationFor(create, document, 'user-other'), isFalse);
    });

    test('ignore un type de notification non urgent', () {
      final autre = {...document, 'type': 'GRADE_PUBLISHED'};
      expect(isUrgentNotificationFor(create, autre, me), isFalse);
    });

    test('ne fait rien sans identifiant utilisateur', () {
      expect(isUrgentNotificationFor(create, document, ''), isFalse);
    });

    test('ignore un document sans `ownerId`', () {
      expect(isUrgentNotificationFor(create, {'type': 'MESSAGE_URGENT'}, me), isFalse);
    });
  });
}
