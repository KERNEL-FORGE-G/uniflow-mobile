// Contrat entre le mobile et l'unique Function `uniflow-api` d'Appwrite Cloud.
//
// Depuis la migration du 2026-09-20, les neuf anciennes Functions sont fondues
// en un routeur : c'est le champ `path` de l'exécution qui choisit le service.
// Tant que le mobile appelait `/functions/messaging/executions` sans `path`,
// le serveur répondait 404 et l'écran affichait « Messagerie indisponible »
// alors que le service tournait. Ces tests figent ce qui est envoyé.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/data/appwrite_service.dart';

void main() {
  group('routerExecutionParams', () {
    test('porte le chemin du service, la méthode et le corps JSON', () {
      final params = routerExecutionParams('/messaging', {'action': 'list'});
      expect(params['path'], '/messaging');
      expect(params['method'], 'POST');
      expect(params['async'], isFalse);
      expect(jsonDecode(params['body'] as String), {'action': 'list'});
    });

    test('déclare le corps en JSON, comme le web', () {
      // Sans cet en-tête, `req.bodyJson` reste vide côté Function ; les
      // services retombent sur `bodyText`, mais le web l'envoie et le contrat
      // doit être identique pour les trois clients.
      final params = routerExecutionParams('/messaging', const {});
      expect(params['headers'], {'content-type': 'application/json'});
    });

    test('normalise un chemin sans barre initiale ou avec barre finale', () {
      expect(routerExecutionParams('messaging', const {})['path'], '/messaging');
      expect(routerExecutionParams('/forum-reactions/', const {})['path'], '/forum-reactions');
      expect(routerExecutionParams('  /team-roster ', const {})['path'], '/team-roster');
    });

    test('ne confond pas la racine avec un chemin vide', () {
      expect(normalizeServicePath('/'), '/');
      expect(normalizeServicePath(''), '/');
    });

    test('sérialise les charges imbriquées sans les altérer', () {
      final params = routerExecutionParams('/attendance-secure', {
        'action': 'scan',
        'token': 'abc',
        'position': {'latitude': 3.86, 'longitude': 11.52, 'accuracy': 12},
      });
      final body = jsonDecode(params['body'] as String) as Map;
      expect(body['position'], {'latitude': 3.86, 'longitude': 11.52, 'accuracy': 12});
    });
  });

  group('decodeFunctionPayload sur une exécution Appwrite Cloud 2.2', () {
    // Document d'exécution tel que le renvoie Appwrite 2.2.0 : il porte
    // désormais `resourceType` et `resourceId`, ce qui ne change rien à la
    // lecture — seul `responseBody` nous intéresse.
    Map<String, dynamic> execution(String body, {int status = 200}) => {
          r'$id': 'exec1',
          'functionId': 'uniflow-api',
          'resourceType': 'functions',
          'resourceId': 'uniflow-api',
          'trigger': 'http',
          'status': status >= 400 ? 'failed' : 'completed',
          'requestMethod': 'POST',
          'requestPath': '/messaging',
          'responseStatusCode': status,
          'responseBody': body,
          'responseHeaders': const [],
          'logs': '',
          'errors': '',
          'duration': 0.3,
        };

    test('lit la charge utile d\'un succès', () {
      expect(decodeFunctionPayload(execution('{"ok":true,"conversations":[]}')),
          {'ok': true, 'conversations': <dynamic>[]});
    });

    test('lit aussi le corps d\'une exécution marquée en échec', () {
      // Appwrite marque l'exécution `failed` dès que la Function répond 4xx,
      // mais le corps porte le message à montrer à l'utilisateur.
      final payload = decodeFunctionPayload(
        execution('{"ok":false,"code":"ROLE_DENIED","message":"Refusé."}', status: 403),
      );
      expect(payload['ok'], isFalse);
      expect(payload['code'], 'ROLE_DENIED');
    });

    test('rend une map vide quand le routeur ne trouve pas le service', () {
      // Le routeur répond `{ok:false, code:'SERVICE_NOT_FOUND', services:[…]}`
      // en 404 ; c'est un JSON valide, il est rendu tel quel.
      final payload = decodeFunctionPayload(
        execution('{"ok":false,"code":"SERVICE_NOT_FOUND","services":["/messaging"]}', status: 404),
      );
      expect(payload['code'], 'SERVICE_NOT_FOUND');
      expect(decodeFunctionPayload(execution('')), isEmpty);
    });
  });

  group('valeurs par défaut du Cloud', () {
    test('la Function et le bucket portent les identifiants du schéma', () {
      // `uniflow-we/scripts/appwrite-schema.mjs` fait foi : un seul bucket
      // `uniflow_assets`, un seul routeur `uniflow-api`.
      expect(defaultApiFunctionId, 'uniflow-api');
      expect(defaultBucketId, 'uniflow_assets');
    });
  });
}
