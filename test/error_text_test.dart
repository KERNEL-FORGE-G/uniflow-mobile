import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/repositories/messaging_repository.dart';
import 'package:uniflow_mobile/utils/error_text.dart';
import 'package:uniflow_mobile/widgets/common.dart';
import 'package:uniflow_mobile/widgets/uni/uni_mascot.dart';

void main() {
  group('describeError', () {
    test('une exception du projet garde son message et expose son code', () {
      final text = describeError(MessagingException('Function absente', code: 'FUNCTION_NOT_FOUND'));
      expect(text.detail, 'Function absente');
      expect(text.code, 'FUNCTION_NOT_FOUND');
      expect(describeError(MessagingException('sans code')).code, 'MESSAGING');
    });

    test('une AppwriteException montre le code HTTP et le type', () {
      final text = describeError(AppwriteException('Accès refusé', 401, 'general_unauthorized_scope'));
      expect(text.detail, 'Accès refusé');
      expect(text.code, 'APPWRITE 401 general_unauthorized_scope');
    });

    test('les pannes réseau ont une phrase lisible plutôt que la trace brute', () {
      expect(describeError(const SocketException('Connection refused')).code, 'RÉSEAU');
      expect(describeError(const HandshakeException('bad cert')).code, 'TLS');
      expect(describeError(const SocketException('x')).detail, isNot(contains('SocketException')));
    });

    test('« Bad state: No element » reste lisible et signe StateError', () {
      // C'est exactement ce que la messagerie affichait sans dire d'où cela
      // venait : le code technique doit maintenant l'accompagner.
      final text = describeError(StateError('No element'));
      expect(text.detail, 'Bad state: No element');
      expect(text.code, 'StateError');
    });

    test('le préfixe « Exception: » est retiré du texte affiché', () {
      final text = describeError(Exception('boom'));
      expect(text.detail, 'boom');
      expect(text.code, isNotEmpty);
    });
  });

  group('LoadErrorView', () {
    testWidgets('Uni s’excuse, le message, le code et Réessayer sont là', (tester) async {
      var retried = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LoadErrorView(
            title: 'Messagerie indisponible',
            error: MessagingException('Le serveur ne répond pas', code: 'TIMEOUT'),
            onRetry: () => retried++,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Messagerie indisponible'), findsOneWidget);
      expect(find.text('Le serveur ne répond pas'), findsOneWidget);
      expect(find.text('TIMEOUT'), findsOneWidget);
      expect(find.bySemanticsLabel(UniPose.sorry.alt), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      expect(retried, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tient en 320 px avec un long message, texte ×1.3', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 568,
              child: LoadErrorView(
                title: 'L\'emploi du temps n\'a pas pu être chargé',
                error: AppwriteException(
                  'The current user is not authorized to perform the requested action on this resource.',
                  401,
                  'general_unauthorized_scope',
                ),
                onRetry: () {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  });
}
