// Sonde d'échange complet, exécutée SUR L'APPAREIL.
//
// La sonde `messaging_probe_test.dart` ne vérifie que `list` et `search`. Or
// c'est la chaîne entière qui est en jeu dans cette application : ouvrir une
// conversation, envoyer un texte, envoyer une pièce jointe, puis — le point
// qui a réellement été cassé — **que le destinataire puisse ouvrir cette pièce
// jointe**. Appwrite n'accorde au créateur d'un fichier que les permissions
// qu'il demande explicitement : sans l'identifiant du correspondant, la
// Function renvoyait une conversation sans `userId`, et le fichier partait
// lisible par son seul auteur. Le serveur répondait pourtant `ok:true`, ce qui
// suffisait à l'innocenter à tort.
//
// Deux comptes sont nécessaires : l'un envoie, l'autre relit. Les identifiants
// sont fournis au lancement, jamais écrits ici.
//
//   flutter test integration_test/messaging_roundtrip_test.dart -d <appareil> \
//     --dart-define=EMAIL_A=<compte A> --dart-define=PASSWORD_A=<mot de passe> \
//     --dart-define=EMAIL_B=<compte B> --dart-define=PASSWORD_B=<mot de passe>

import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:uniflow_mobile/data/appwrite_service.dart';
import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/repositories/messaging_repository.dart';

const _emailA = String.fromEnvironment('EMAIL_A');
const _passwordA = String.fromEnvironment('PASSWORD_A');
const _emailB = String.fromEnvironment('EMAIL_B');
const _passwordB = String.fromEnvironment('PASSWORD_B');

/// PNG 1×1 valide : le plus petit fichier dont Appwrite déduit un type MIME
/// `image/png`, ce qui exerce la branche « aperçu » et non la branche « carte ».
final _pngUnPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('un échange complet aboutit entre deux comptes', (tester) async {
    if (_emailA.isEmpty || _passwordA.isEmpty || _emailB.isEmpty || _passwordB.isEmpty) {
      fail(
        'Identifiants absents — relancer avec :\n'
        '  flutter test integration_test/messaging_roundtrip_test.dart -d <appareil> \\\n'
        '    --dart-define=EMAIL_A=<compte A> --dart-define=PASSWORD_A=<mot de passe> \\\n'
        '    --dart-define=EMAIL_B=<compte B> --dart-define=PASSWORD_B=<mot de passe>',
      );
    }

    await dotenv.load(fileName: '.env');

    // Une seule instance : la session est portée par le client. On travaille
    // donc en deux temps — A écrit, puis B relit — ce qui reproduit exactement
    // ce que font deux téléphones.
    final service = AppwriteService();
    final auth = AuthRepository(service);
    final messaging = MessagingRepository(service);

    // ---------- A : ouverture, texte, pièce jointe ----------
    await auth.login(_emailA, _passwordA);
    final compteA = await service.account.get();

    final contacts = await messaging.searchContacts('sondebeta');
    expect(contacts, isNotEmpty, reason: 'B doit être trouvable dans l\'annuaire');

    final conversation = await messaging.openByUsername('sondebeta');
    expect(conversation.id, isNotEmpty);
    // C'est ce champ qui autorise le fichier aux deux participants. Son absence
    // était le défaut de la Function non redéployée.
    expect(
      conversation.userId,
      isNotEmpty,
      reason: 'la conversation doit porter l\'identifiant du correspondant',
    );

    final horodatage = DateTime.now().toIso8601String();
    await messaging.sendMessage(conversation.id, 'Son texte $horodatage');

    final dossier = await getTemporaryDirectory();
    final chemin = '${dossier.path}/sonde-uniflow.png';
    await File(chemin).writeAsBytes(_pngUnPixel);

    final fileId = await messaging.uploadAttachment(
      conversationId: conversation.id,
      myUserId: compteA.$id,
      path: chemin,
      fileName: 'sonde-uniflow.png',
    );
    expect(fileId, isNotEmpty, reason: 'le téléversement doit rendre un identifiant');
    await messaging.sendMessage(conversation.id, '', fileId: fileId);

    // L'aperçu est ce que la bulle affiche : s'il échoue, l'image est un carré
    // vide, alors même que le fichier existe.
    final apercu = await messaging.attachmentPreview(fileId, width: 64);
    expect(apercu, isNotEmpty, reason: 'l\'aperçu de l\'image doit être lisible');

    // ---------- B : relecture, et surtout ouverture du fichier ----------
    await auth.login(_emailB, _passwordB);

    final boite = await messaging.getConversations();
    final fil = boite.firstWhere(
      (c) => c.id == conversation.id,
      orElse: () => throw StateError('B ne voit pas la conversation créée par A'),
    );

    final textes = fil.messages.map((m) => m.text).toList();
    expect(
      textes.any((t) => t.contains(horodatage)),
      isTrue,
      reason: 'le texte envoyé doit apparaître chez B',
    );

    // On cherche *ce* fichier et non « la première pièce jointe » : la
    // conversation survit d'une exécution à l'autre, et les pièces jointes des
    // essais précédents — dont les fichiers ont été supprimés du bucket —
    // seraient trouvées d'abord, faisant échouer la comparaison pour une raison
    // qui n'a rien à voir avec le code testé.
    final piece = fil.messages.firstWhere(
      (m) => m.fileId == fileId,
      orElse: () => throw StateError('la pièce jointe n\'apparaît pas chez B'),
    );
    expect(piece.kind, 'image', reason: 'un PNG doit être reconnu comme image');
    expect(piece.fileSize, _pngUnPixel.length);

    final octets = await messaging.downloadAttachment(piece.fileId);
    expect(
      octets.length,
      _pngUnPixel.length,
      reason: 'B doit pouvoir télécharger le fichier de A — c\'est le point qui '
          'échouait tant que la Function ne renvoyait pas `userId`',
    );

    await File(chemin).delete();
    // ignore: avoid_print
    print('SONDE aller-retour OK : conversation=${fil.id} piece=$fileId '
        'octets=${octets.length} messages=${fil.messages.length}');
  });
}
