import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniflow_mobile/offline/local_database.dart';
import 'package:uniflow_mobile/offline/offline_providers.dart';
import 'package:uniflow_mobile/providers/onboarding_provider.dart';
import 'package:uniflow_mobile/providers/providers.dart';
import 'package:uniflow_mobile/router/app_router.dart';
import 'package:uniflow_mobile/screens/dashboard.dart';
import 'package:uniflow_mobile/screens/login.dart';
import 'package:uniflow_mobile/screens/onboarding.dart';
import 'package:uniflow_mobile/screens/schedule.dart';
import 'package:uniflow_mobile/theme/app_theme.dart';
import 'package:uniflow_mobile/widgets/uni/mascot_dialogue.dart';
import 'package:uniflow_mobile/widgets/uni/uni_mascot.dart';

import 'layout_test_support.dart';

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

/// Monte l'application entière derrière son routeur, comme au démarrage à
/// froid, avec l'état de session voulu et les providers réseau neutralisés.
Future<GoRouter> _launchApp(WidgetTester tester, {required AuthStatus status}) async {
  late GoRouter router;
  await tester.pumpWidget(ProviderScope(
    overrides: [...neutralOverrides(), authStatusProvider.overrideWith((ref) => status)],
    child: Consumer(
      builder: (context, ref, _) {
        router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          // Comme `host` : les mascottes en boucle empêcheraient de se poser.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        );
      },
    ),
  ));
  await _settleRoute(tester);
  return router;
}

/// Laisse passer la redirection et le fondu entre deux pages du routeur.
Future<void> _settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(kAuthFadeDuration + const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Parcourt les pages jusqu'à la dernière (sans animation : le routeur de test
/// déclare `disableAnimations`).
Future<void> _goToLastPage(WidgetTester tester) async {
  for (var i = 1; i < onboardingPages.length; i++) {
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late LocalDatabase db;
  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  group('OnboardingController', () {
    test('l’état « vu » ne vit qu’en mémoire : un nouveau processus repart à « pas vue »', () async {
      final container = ProviderContainer(overrides: [localDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);

      // Aucune lecture disque : la décision est connue dès la première image.
      expect(container.read(onboardingSeenProvider), isFalse);

      await container.read(onboardingSeenProvider.notifier).markSeen();
      expect(container.read(onboardingSeenProvider), isTrue);
      // La trace informative reste écrite…
      expect(await db.preference(onboardingSeenKey), '1');

      // …mais un second contrôleur (nouveau démarrage) ne la relit pas : la
      // présentation revient à chaque lancement.
      final again = ProviderContainer(overrides: [localDatabaseProvider.overrideWithValue(db)]);
      addTearDown(again.dispose);
      expect(again.read(onboardingSeenProvider), isFalse);
    });
  });

  group('signedOutDestination', () {
    test('pas encore vue dans ce processus → présentation, quelle que soit l’adresse demandée', () {
      expect(signedOutDestination(onboardingSeen: false, location: '/accueil'), onboardingPath);
      expect(signedOutDestination(onboardingSeen: false, location: '/login'), onboardingPath);
      expect(signedOutDestination(onboardingSeen: false, location: onboardingPath), onboardingPath);
    });

    test('vue → connexion ; les adresses publiques restent atteignables', () {
      expect(signedOutDestination(onboardingSeen: true, location: '/accueil'), '/login');
      expect(signedOutDestination(onboardingSeen: true, location: onboardingPath), '/login');
      expect(signedOutDestination(onboardingSeen: true, location: '/register'), '/register');
      expect(signedOutDestination(onboardingSeen: true, location: '/mot-de-passe-oublie'), '/mot-de-passe-oublie');
    });
  });

  group('signedInDestination', () {
    test('pas encore vue → présentation d’abord, même avec une session ouverte', () {
      expect(
        signedInDestination(onboardingSeen: false, location: '/accueil', requested: '/accueil'),
        onboardingPath,
      );
      expect(
        signedInDestination(onboardingSeen: false, location: '/login', requested: '/login'),
        onboardingPath,
      );
      // Déjà sur la présentation : on y reste (pas de boucle de redirection).
      expect(
        signedInDestination(onboardingSeen: false, location: onboardingPath, requested: onboardingPath),
        onboardingPath,
      );
    });

    test('pas encore vue → un lien externe est conservé en requête « suite »', () {
      expect(
        signedInDestination(onboardingSeen: false, location: '/messages/abc', requested: '/messages/abc?x=1'),
        '$onboardingPath?$onboardingNextParam=${Uri.encodeComponent('/messages/abc?x=1')}',
      );
    });

    test('vue → les adresses publiques ramènent à l’accueil, les autres passent', () {
      expect(
          signedInDestination(onboardingSeen: true, location: onboardingPath, requested: onboardingPath), '/accueil');
      expect(signedInDestination(onboardingSeen: true, location: '/login', requested: '/login'), '/accueil');
      expect(signedInDestination(onboardingSeen: true, location: '/notes', requested: '/notes'), '/notes');
    });
  });

  group('démarrage à froid', () {
    testWidgets('connecté : présentation d’abord, « Continuer » mène au tableau de bord, sans retour', (tester) async {
      tester.view.physicalSize = const Size(411, 731);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = await _launchApp(tester, status: AuthStatus.signedIn);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);

      await _goToLastPage(tester);
      // Session ouverte : le dernier bouton dit « Continuer », pas « Commencer ».
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.text('Commencer'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await _settleRoute(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      // Revenir sur /bienvenue dans la même session ne rejoue rien.
      router.go(onboardingPath);
      await _settleRoute(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('connecté : un lien reçu au lancement survit à la présentation', (tester) async {
      tester.view.physicalSize = const Size(411, 731);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = await _launchApp(tester, status: AuthStatus.signedIn);
      // Le raccourci du lanceur arrive pendant que la présentation est affichée.
      router.go('/emploi-du-temps');
      await _settleRoute(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await _settleRoute(tester);
      expect(find.byType(ScheduleScreen), findsOneWidget);
    });

    testWidgets('déconnecté : présentation d’abord, « Passer » mène à la connexion, sans retour', (tester) async {
      tester.view.physicalSize = const Size(411, 731);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final router = await _launchApp(tester, status: AuthStatus.signedOut);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await _settleRoute(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      router.go(onboardingPath);
      await _settleRoute(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('déconnecté : la dernière page dit « Commencer » et mène à la connexion', (tester) async {
      tester.view.physicalSize = const Size(411, 731);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _launchApp(tester, status: AuthStatus.signedOut);
      await _goToLastPage(tester);
      expect(find.text('Commencer'), findsOneWidget);
      expect(find.text('Continuer'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await _settleRoute(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('OnboardingScreen', () {
    testWidgets('quatre pages : Suivant enchaîne, Commencer termine et laisse une trace', (tester) async {
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

    testWidgets('Passer termine tout de suite et laisse une trace', (tester) async {
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
