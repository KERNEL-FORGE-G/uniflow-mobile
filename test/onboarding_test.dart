import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniflow_mobile/offline/local_database.dart';
import 'package:uniflow_mobile/offline/offline_providers.dart';
import 'package:uniflow_mobile/providers/onboarding_provider.dart';
import 'package:uniflow_mobile/router/app_router.dart';
import 'package:uniflow_mobile/screens/onboarding.dart';
import 'package:uniflow_mobile/theme/app_theme.dart';
import 'package:uniflow_mobile/widgets/uni/mascot_dialogue.dart';
import 'package:uniflow_mobile/widgets/uni/uni_mascot.dart';

Future<void> _settleAfterNext(WidgetTester tester) async {
  // Un ticker démarre à sa première image : le premier `pump()` lance le
  // glissement, le second l'achève (380 ms), sans `pumpAndSettle` que les
  // mascottes en boucle n'atteindraient jamais.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _host(Widget child, {required LocalDatabase db, Size? size, double textScale = 1}) {
  return ProviderScope(
    overrides: [localDatabaseProvider.overrideWithValue(db)],
    child: MediaQuery(
      data: MediaQueryData(size: size ?? const Size(360, 640), textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(theme: AppTheme.light, home: child),
    ),
  );
}

/// La préférence se lit dans SQLite, donc de façon asynchrone : on attend que
/// le contrôleur ait tranché (`null` = pas encore lu).
Future<bool> _loaded(ProviderContainer container) async {
  for (var i = 0; i < 200; i++) {
    final value = container.read(onboardingSeenProvider);
    if (value != null) return value;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('la préférence de présentation n’a jamais été lue');
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late LocalDatabase db;
  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  group('OnboardingController', () {
    test('première ouverture : pas encore vue ; markSeen persiste dans la base locale', () async {
      final container = ProviderContainer(overrides: [localDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);

      expect(await _loaded(container), isFalse);

      await container.read(onboardingSeenProvider.notifier).markSeen();
      expect(container.read(onboardingSeenProvider), isTrue);
      expect(await db.preference(onboardingSeenKey), '1');

      // Un second contrôleur (nouveau démarrage) relit la préférence.
      final again = ProviderContainer(overrides: [localDatabaseProvider.overrideWithValue(db)]);
      addTearDown(again.dispose);
      expect(await _loaded(again), isTrue);

      await again.read(onboardingSeenProvider.notifier).reset();
      expect(again.read(onboardingSeenProvider), isFalse);
      expect(await db.preference(onboardingSeenKey), '0');
    });
  });

  group('signedOutDestination', () {
    test('jamais vue → présentation, quelle que soit l’adresse demandée', () {
      expect(signedOutDestination(onboardingSeen: false, location: '/accueil'), onboardingPath);
      expect(signedOutDestination(onboardingSeen: false, location: '/login'), onboardingPath);
      expect(signedOutDestination(onboardingSeen: false, location: onboardingPath), onboardingPath);
    });

    test('déjà vue → connexion ; les adresses publiques restent atteignables', () {
      expect(signedOutDestination(onboardingSeen: true, location: '/accueil'), '/login');
      expect(signedOutDestination(onboardingSeen: true, location: onboardingPath), '/login');
      expect(signedOutDestination(onboardingSeen: true, location: '/register'), '/register');
      expect(signedOutDestination(onboardingSeen: true, location: '/mot-de-passe-oublie'), '/mot-de-passe-oublie');
    });

    test('préférence pas encore lue → on ne bloque pas la connexion', () {
      expect(signedOutDestination(onboardingSeen: null, location: '/accueil'), '/login');
    });
  });

  group('OnboardingScreen', () {
    testWidgets('quatre pages : Suivant enchaîne, Commencer termine et mémorise', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_host(OnboardingScreen(onFinished: () => finished++), db: db));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(onboardingPages.first.title), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);
      // Uni accompagne chaque page de fonctionnalité d'une bulle courte.
      expect(find.text(onboardingPages.first.uniSays), findsOneWidget);

      for (var i = 1; i < onboardingPages.length; i++) {
        await tester.tap(find.byKey(const ValueKey('onboarding-next')));
        await _settleAfterNext(tester);
        expect(find.text(onboardingPages[i].title), findsOneWidget, reason: 'page $i');
      }

      // Dernière page : Archlord et Uni dialoguent, le bouton devient Commencer.
      expect(find.byType(MascotDialogue), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);
      expect(find.text('Suivant'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(finished, 1);
      expect(await db.preference(onboardingSeenKey), '1');
    });

    testWidgets('Passer termine tout de suite et mémorise', (tester) async {
      var finished = 0;
      await tester.pumpWidget(_host(OnboardingScreen(onFinished: () => finished++), db: db));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(finished, 1);
      expect(await db.preference(onboardingSeenKey), '1');
    });

    testWidgets('l’indicateur élargit le point de la page courante', (tester) async {
      await tester.pumpWidget(_host(const OnboardingScreen(onFinished: _noop), db: db));
      await tester.pump(const Duration(milliseconds: 100));

      // La boîte mesurée inclut l'écart entre les points.
      const active = PageDots.activeWidth + 2 * PageDots.gap;
      const idle = PageDots.dotSize + 2 * PageDots.gap;
      expect(tester.getSize(find.byKey(const ValueKey('dot-0'))).width, active);
      expect(tester.getSize(find.byKey(const ValueKey('dot-1'))).width, idle);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await _settleAfterNext(tester);
      // Le point s'élargit en 260 ms après le changement de page.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(find.byKey(const ValueKey('dot-1'))).width, active);
      expect(tester.getSize(find.byKey(const ValueKey('dot-0'))).width, idle);
      expect(find.bySemanticsLabel('Page 2 sur ${onboardingPages.length}'), findsOneWidget);
    });

    testWidgets('en mouvement réduit, les pages changent sans animation', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [localDatabaseProvider.overrideWithValue(db)],
        child: const MediaQuery(
          data: MediaQueryData(size: Size(360, 640), disableAnimations: true),
          child: MaterialApp(home: OnboardingScreen(onFinished: _noop)),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump();
      expect(find.text(onboardingPages[1].title), findsOneWidget);
    });

    for (final size in const [Size(320, 568), Size(360, 640), Size(411, 731)]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('aucune page ne déborde en ${size.width.toInt()}×${size.height.toInt()} (texte ×$scale)',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_host(
            const OnboardingScreen(onFinished: _noop),
            db: db,
            size: size,
            textScale: scale,
          ));
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull, reason: 'page 0');

          for (var i = 1; i < onboardingPages.length; i++) {
            await tester.tap(find.byKey(const ValueKey('onboarding-next')));
            await _settleAfterNext(tester);
            expect(tester.takeException(), isNull, reason: 'page $i');
          }
          // Le dialogue de la dernière page change de réplique : chacune doit
          // tenir aussi.
          for (var i = 0; i < onboardingDialogue.length; i++) {
            await tester.tap(find.byType(MascotDialogue));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull, reason: 'réplique $i');
          }
          expect(find.byType(UniMascot), findsWidgets);
        });
      }
    }
  });
}

void _noop() {}
