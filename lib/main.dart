import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/providers.dart';
import 'offline/background_sync.dart';
import 'offline/offline_providers.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'widgets/uni/uni_mascot.dart';
import 'widgets/uni/uni_scenes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bord à bord dès le premier rendu, comme Android 15 l'impose ; voir
  // AppSystemUi pour le style des barres.
  await AppSystemUi.appliquer();
  await dotenv.load(fileName: ".env");
  // Synchronisation périodique application fermée (Android). La contrainte
  // réseau est reposée par les Réglages quand « Wi-Fi seulement » change.
  await BackgroundSync.initialize();
  // Firebase Cloud Messaging : push en arrière-plan / app fermée.
  // L'init est en try-catch interne : un échec FCM ne bloque pas l'app.
  await FcmService.instance.initialize();
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
    ref.listenManual(academicSyncProvider, (_, __) {});
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
    // Tant que la session n'est pas résolue, on affiche un écran de garde : la
    // présentation qui suit propose « Continuer » (session ouverte) ou
    // « Commencer » (connexion), et ce libellé ne doit pas changer sous les
    // yeux de l'utilisateur. La présentation elle-même n'attend plus rien du
    // disque : elle revient à chaque lancement.
    final status = ref.watch(authStatusProvider);
    if (status == AuthStatus.unknown) {
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

/// Écran de garde — UniFlow Clean UI bleu+teal avec image de fond et mascotte Uni.
///
/// Fond dégradé bleu UniFlow → teal, illustration de bienvenue en
/// transparence, logo centré et indicateur de chargement discret.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.surBleu,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Fond dégradé bleu UniFlow → teal ─────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2D4FA8), Color(0xFF0D9488)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // ── Image de fond (illustration onboarding) — opacité réduite ──
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/onboarding/onboarding_2_univers.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            // ── Cercles décoratifs ────────────────────────────────────────
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // ── Contenu central ───────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mascotte Uni
                  const UniMascot(pose: UniPose.wave, size: 130),
                  const SizedBox(height: 20),
                  // Logo texte dans un conteneur verre
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'UniFlow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'La plateforme de ton campus',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  UniDots(color: Colors.white.withValues(alpha: 0.8)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
