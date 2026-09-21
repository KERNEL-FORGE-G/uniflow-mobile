import 'dart:async';
import 'dart:io';

import 'package:appwrite/appwrite.dart';

import '../repositories/messaging_repository.dart';

/// Ce que l'on montre d'une erreur : une phrase lisible pour l'utilisateur,
/// et un code technique court pour nous.
///
/// Le code n'était pas affiché avant : la messagerie s'est cassée en montrant
/// « Bad state: No element » sans dire d'où cela venait, et chaque panne a
/// coûté une session de diagnostic. Le type et le code suffisent à trancher
/// entre un refus du serveur, une Function absente et une panne réseau.
class ErrorText {
  final String detail;
  final String code;

  const ErrorText(this.detail, this.code);
}

ErrorText describeError(Object error) {
  switch (error) {
    case MessagingException e:
      return ErrorText(e.message, e.code.isEmpty ? 'MESSAGING' : e.code);
    case AppwriteException e:
      final code = [
        'APPWRITE',
        if (e.code != null) '${e.code}',
        if (e.type != null && e.type!.isNotEmpty) e.type!,
      ].join(' ');
      return ErrorText(e.message ?? 'Le serveur a refusé la demande.', code);
    case HandshakeException _:
    case TlsException _:
      return const ErrorText('La connexion sécurisée au serveur a échoué.', 'TLS');
    case SocketException _:
      return const ErrorText('Impossible de joindre le serveur. Vérifie ta connexion.', 'RÉSEAU');
    case TimeoutException _:
      return const ErrorText('Le serveur met trop de temps à répondre.', 'DÉLAI');
    case FormatException _:
      return const ErrorText('La réponse du serveur n’a pas la forme attendue.', 'FORMAT');
  }
  // Les exceptions du projet renvoient leur message dans `toString()` ; les
  // autres arrivent préfixées du nom de classe (« Exception: … »).
  var detail = error.toString().trim();
  final colon = detail.indexOf(': ');
  if (colon > 0 && RegExp(r'^\w*(Exception|Error)$').hasMatch(detail.substring(0, colon))) {
    detail = detail.substring(colon + 2).trim();
  }
  if (detail.isEmpty) detail = 'Une erreur inattendue est survenue.';
  return ErrorText(detail, error.runtimeType.toString());
}
