import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/providers.dart';
import 'offline/background_sync.dart';
import 'offline/offline_providers.dart';
import 'providers/onboarding_provider.dart';
import 'services/notification_service.dart';
import 'widgets/uni/uni_mascot.dart';
import 'widgets/uni/uni_scenes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // Synchronisation périodique application fermée (Android). La contrainte
  // réseau est reposée par les Réglages quand « Wi-Fi seulement » change.
  await BackgroundSync.initialize();
  // Une erreur de rendu non rattrapée affiche Uni qui s'excuse plutôt que le
  // rectangle rouge de Flutter — l'utilisateur comprend qu'il peut revenir en
  // arrière, et le détail reste lisible pour nous.
  ErrorWidget.builder = (details) => UniCrashScreen(details: details.exceptionAsString());
  runApp(const ProviderScope(child: UniFlowApp()));
}

class UniFlowApp extends ConsumerStatefulWidget {
  const UniFlowApp({super.key});

  @override
  ConsumerState<UniFlowApp> createState() => _UniFlowAppState();
}

class _UniFlowAppState extends ConsumerState<UniFlowApp> {
  @override
  void initState() {
    super.initState();
    // Résout la session Appwrite stockée sur l'appareil avant de choisir
    // entre l'écran de connexion et l'application.
    Future.microtask(() => ref.read(sessionBootstrapProvider.future));
    // Maintient la synchronisation active : elle se relance d'elle-même quand
    // l'état d'authentification change.
    ref.listenManual(gatewaySyncProvider, (_, __) {});
    // Ouvre l'écoute temps réel des messages urgents. Elle ne fait rien tant
    // qu'aucun compte n'est connecté, et se relance à chaque changement de
    // session — une socket laissée ouverte sur le compte précédent enverrait
    // les alertes du mauvais utilisateur.
    ref.listenManual(urgentNotificationsProvider, (_, __) {});
    // Hors ligne : le coordinateur écoute le réseau et le premier plan ; la
    // session chiffrée suit le profil pour redémarrer sans réseau.
    ref.read(syncCoordinatorProvider);
    ref.listenManual(currentUserProvider, (previous, next) {
      if (next == null) return;
      ref.read(sessionStoreProvider).save(next, now: DateTime.now()).catchError((_) {});
      if (previous?.id != next.id) {
        BackgroundSync.schedule(wifiOnly: ref.read(offlinePreferencesProvider).wifiOnly);
        ref.read(syncCoordinatorProvider).syncNow(reason: 'connexion');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tant que la session n'est pas résolue, on affiche un écran de garde :
    // router vers /login ici ferait clignoter la connexion pour un utilisateur
    // déjà authentifié. Même garde, sans session, tant que la préférence
    // « présentation déjà vue » n'est pas lue : sinon la connexion apparaissait
    // une fraction de seconde avant de céder la place à la présentation.
    final status = ref.watch(authStatusProvider);
    final onboardingPending = status == AuthStatus.signedOut && ref.watch(onboardingSeenProvider) == null;
    if (status == AuthStatus.unknown || onboardingPending) {
      return MaterialApp(
        title: 'UniFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _SplashScreen(),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'UniFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.teal,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Uni accueille pendant que la session locale se résout.
            UniMascot(pose: UniPose.wave, size: 150),
            SizedBox(height: 18),
            Text('UniFlow', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 14),
            UniDots(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
