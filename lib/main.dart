import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/providers.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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
  }

  @override
  Widget build(BuildContext context) {
    // Tant que la session n'est pas résolue, on affiche un écran de garde :
    // router vers /login ici ferait clignoter la connexion pour un utilisateur
    // déjà authentifié.
    if (ref.watch(authStatusProvider) == AuthStatus.unknown) {
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
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text('UniFlow', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
