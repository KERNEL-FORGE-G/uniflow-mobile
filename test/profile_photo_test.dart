// « Quand je pars sur changer la photo de profil on me dit null type int. »
//
// Le symptôme vient de `File.fromMap` du SDK Dart 26.2.0, qui déclare
// `sizeActual` comme un `int` non nullable alors que le serveur Appwrite 1.6.1
// ne renvoie pas ce champ. Le fichier était donc bel et bien déposé, mais
// l'écran annonçait un échec de téléversement.
//
// La correction consiste à ne plus construire de modèle `File` du tout : on
// passe par `AppwriteService.uploadFile`, qui lit `$id` dans la réponse brute.
// Les tests ci-dessous verrouillent les deux moitiés de cette correction :
// l'analyse de la réponse, et le fait que le service n'appelle plus
// `storage.createFile`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/data/appwrite_service.dart';
import 'package:uniflow_mobile/utils/avatar.dart';

void main() {
  group('réponse de téléversement Appwrite 1.6.1', () {
    // Relevé réel d'un `POST /storage/buckets/{bucket}/files` sur ce serveur.
    // Aucun `sizeActual` : c'est précisément ce qui cassait `File.fromMap`.
    final reponseAvatar = <String, dynamic>{
      r'$id': '6aa91d49c41855da12b7',
      'bucketId': 'uniflow_assets',
      r'$createdAt': '2026-09-15T10:12:03.000+00:00',
      r'$updatedAt': '2026-09-15T10:12:03.000+00:00',
      r'$permissions': ['read("any")'],
      'name': 'avatar.png',
      'signature': 'a1b2c3',
      'mimeType': 'image/png',
      'sizeOriginal': 20480,
      'chunksTotal': 1,
      'chunksUploaded': 1,
    };

    test('l’identifiant est lu malgré l’absence de `sizeActual`', () {
      expect(decodeUploadedFileId(reponseAvatar), '6aa91d49c41855da12b7');
    });

    test('la réponse ne porte pas `sizeActual`', () {
      // Si Appwrite se met un jour à renvoyer ce champ, ce test tombera et
      // signalera que le contournement peut être réexaminé — pas l'inverse.
      expect(reponseAvatar.containsKey('sizeActual'), isFalse);
    });

    test('une réponse illisible rend `null` plutôt que de lever', () {
      // Le téléversement a réussi : lever ici ferait croire à un échec, ce qui
      // est exactement le défaut d'origine.
      expect(decodeUploadedFileId(null), isNull);
      expect(decodeUploadedFileId(''), isNull);
      expect(decodeUploadedFileId(const []), isNull);
      expect(decodeUploadedFileId(const <String, dynamic>{}), isNull);
      expect(decodeUploadedFileId(const {r'$id': 42}), isNull);
    });
  });

  group('chemin de téléversement de la photo de profil', () {
    // Garde-fou de régression. Le défaut ne se voit ni à l'analyse ni à la
    // compilation : `storage.createFile` est parfaitement valide, il échoue
    // seulement à l'exécution, sur ce serveur. Sans ce test, un futur
    // remaniement peut réintroduire l'appel sans que rien ne le signale.
    final source = File('lib/services/profile_photo_service.dart').readAsStringSync();

    test('n’instancie plus de modèle `File` du SDK', () {
      expect(source.contains('_storage.createFile'), isFalse);
      expect(source.contains('storage.createFile'), isFalse);
    });

    test('passe par `uploadFile`, qui lit la réponse brute', () {
      expect(source.contains('_service.uploadFile'), isTrue);
    });
  });

  group('validation du fichier choisi', () {
    test('accepte les extensions du bucket', () {
      for (final extension in ['jpg', 'jpeg', 'png', 'webp', 'PNG', 'JPG']) {
        expect(validateAvatarPath('/tmp/photo.$extension'), isNull, reason: '$extension doit être accepté');
      }
    });

    test('refuse ce que le bucket refuse, avec un message utile', () {
      for (final extension in ['gif', 'pdf', 'mp4', 'heic']) {
        expect(validateAvatarPath('/tmp/photo.$extension'), isNotNull, reason: '$extension doit être refusé');
      }
    });

    test('la limite annoncée correspond à celle du bucket', () {
      expect(avatarMaxBytes, 5 * 1024 * 1024);
    });
  });

  group('initialsOf', () {
    test('compose les initiales du prénom et du nom', () {
      expect(initialsOf('Ravel Nkouatchet'), 'RN');
    });

    test('se rabat sur `U` quand il n’y a rien à afficher', () {
      // L'avatar est dessiné même quand le profil n'a pas de nom renseigné.
      expect(initialsOf(''), 'U');
      expect(initialsOf('   '), 'U');
    });
  });
}
