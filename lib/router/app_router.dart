import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../providers/onboarding_provider.dart';
import '../providers/providers.dart';
import '../models/user_role.dart';
import '../widgets/app_shell.dart';
import '../screens/login.dart';
import '../screens/onboarding.dart';
import '../screens/register.dart';
import '../screens/forgot_password.dart';
import '../repositories/auth_repository.dart';
import 'shell_pages.dart';

/// Adresses accessibles sans session. Une fois connecté, elles ramènent à
/// l'accueil : revenir sur l'inscription avec une session ouverte ferait
/// échouer `account.create`.
const Set<String> publicPaths = {onboardingPath, '/login', '/register', '/mot-de-passe-oublie'};

/// Présentation du premier lancement, avant la connexion.
const String onboardingPath = '/bienvenue';

/// Requête portée par `/bienvenue` : l'adresse à ouvrir une fois la
/// présentation terminée, pour qu'un lien externe ou un raccourci du lanceur
/// reçu au démarrage à froid ne se perde pas derrière l'onboarding.
const String onboardingNextParam = 'suite';

/// Où envoyer quelqu'un qui n'a pas de session : la présentation tant qu'elle
/// n'a pas été parcourue dans ce processus (elle revient à chaque lancement,
/// décision du propriétaire du 2026-09-21), la connexion ensuite. Les autres
/// adresses publiques (inscription, mot de passe oublié) restent atteignables.
String signedOutDestination({required bool onboardingSeen, required String location}) {
  if (!onboardingSeen) return location == onboardingPath ? location : onboardingPath;
  if (location == onboardingPath) return '/login';
  return publicPaths.contains(location) ? location : '/login';
}

/// Où envoyer quelqu'un dont la session est ouverte : la présentation d'abord,
/// tant qu'elle n'a pas été parcourue dans ce processus, avec l'adresse visée
/// en requête `suite` si elle mérite d'être conservée ; ensuite l'accueil pour
/// les adresses publiques, sinon l'adresse demandée (la règle des rôles
/// s'applique après). `requested` est l'URI complète (chemin + requête).
String signedInDestination({required bool onboardingSeen, required String location, required String requested}) {
  if (!onboardingSeen) {
    if (location == onboardingPath) return location;
    final worthKeeping = !publicPaths.contains(location) && location != '/accueil';
    return worthKeeping ? '$onboardingPath?$onboardingNextParam=${Uri.encodeComponent(requested)}' : onboardingPath;
  }
  return publicPaths.contains(location) ? '/accueil' : location;
}

/// Adresse interne visée par un lien externe (`uniflow:///emploi-du-temps`,
/// `uniflow://messages/abc?x=1`), ou `null` si `uri` est déjà une adresse
/// interne (sans schéma).
///
/// Les raccourcis statiques du lanceur (`res/xml/shortcuts.xml`) lancent
/// l'activité avec une action VIEW et une donnée `uniflow:///…` ; l'embedding
/// Android transmet cette URI complète comme route initiale (démarrage à
/// froid) ou la pousse au routeur (application déjà ouverte). go_router
/// n'apparie que le chemin : la forme `uniflow://emploi-du-temps` (hôte, chemin
/// vide) ne correspondrait à rien et finirait sur « Page introuvable ». On
/// ramène donc les deux formes à `/emploi-du-temps`, requête comprise, et la
/// redirection habituelle (session, rôle) s'applique ensuite.
String? launchLocationFromLink(Uri uri) {
  if (uri.scheme.isEmpty) return null;
  final segments = [
    // Dans `uniflow://messages`, « messages » est un hôte pour Uri mais une
    // route pour nous ; dans un lien http, l'hôte est un serveur.
    if (uri.scheme == 'uniflow' && uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((segment) => segment.isNotEmpty),
  ];
  final path = '/${segments.join('/')}';
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

/// Chemins de toutes les routes déclarées, pour que les liens externes
/// (raccourcis, notifications) puissent être vérifiés contre le routeur.
Set<String> get routePaths {
  final paths = <String>{};
  void visit(List<RouteBase> routes) {
    for (final route in routes) {
      if (route is GoRoute) paths.add(route.path);
      visit(route.routes);
    }
  }

  visit(_appRoutes());
  return paths;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter ne suit pas nativement les providers Riverpod : ce notifier lui
  // sert de signal pour réévaluer le redirect quand la session change.
  final sessionChanged = ValueNotifier<int>(0);
  ref.listen(authStatusProvider, (_, __) => sessionChanged.value++);
  // Le rôle change sans que l'état d'authentification bouge — un administrateur
  // qui corrige le rôle d'un compte pendant que celui-ci est ouvert. Sans cette
  // écoute, le routeur garderait la décision prise au démarrage.
  ref.listen(currentUserProvider, (_, __) => sessionChanged.value++);
  // « Passer », « Commencer » ou « Continuer » sur la présentation : l'état
  // bascule, et /bienvenue doit aussitôt céder la place à la suite.
  ref.listen(onboardingSeenProvider, (_, __) => sessionChanged.value++);
  ref.onDispose(sessionChanged.dispose);

  return GoRouter(
    initialLocation: '/accueil',
    refreshListenable: sessionChanged,
    // À chaque lancement, la présentation passe d'abord, session ou pas. Puis,
    // tant qu'aucun compte n'est connecté, tout ramène à /login ; une fois
    // connecté, les adresses publiques renvoient vers l'accueil.
    //
    // La seconde règle est celle des rôles : une adresse que le rôle n'a pas le
    // droit d'atteindre ramène à l'accueil, avec un message. Masquer un onglet
    // ne suffit pas — l'adresse reste tapable, et un écran d'administration
    // atteignable par URL n'est pas restreint du tout.
    redirect: (context, state) {
      // Lien externe (raccourci du lanceur) : on le ramène à l'adresse interne
      // équivalente, et cette redirection repasse ici sans schéma.
      final external = launchLocationFromLink(state.uri);
      if (external != null) return external;

      final signedIn = ref.read(authStatusProvider) == AuthStatus.signedIn;
      final onboardingSeen = ref.read(onboardingSeenProvider);
      final location = state.matchedLocation;
      if (!signedIn) {
        final target = signedOutDestination(onboardingSeen: onboardingSeen, location: location);
        return target == location ? null : target;
      }
      final target = signedInDestination(
        onboardingSeen: onboardingSeen,
        location: location,
        requested: state.uri.toString(),
      );
      if (target != location) return target;

      final role = ref.read(currentRoleProvider);
      if (!canAccessPath(role, location)) {
        return '/acces-refuse?depuis=${Uri.encodeComponent(location)}';
      }
      return null;
    },
    routes: _appRoutes(),
    errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('Page introuvable'))),
  );
});

List<RouteBase> _appRoutes() => [
      // Présentation → connexion en fondu : un glissement latéral laisserait
      // croire qu'on peut revenir en arrière alors que l'état « vu » est posé.
      GoRoute(
        path: onboardingPath,
        pageBuilder: (_, s) => _fadePage(s, OnboardingScreen(next: s.uri.queryParameters[onboardingNextParam])),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => _fadePage(s, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        builder: (_, s) => RegisterScreen(
          initialType: UniFlowAccountType.tryParse(s.uri.queryParameters['type']) ?? UniFlowAccountType.university,
        ),
      ),
      GoRoute(path: '/mot-de-passe-oublie', builder: (_, __) => const ForgotPasswordScreen()),
      // Les pages connectées viennent de `shell_pages.dart` : la même table
      // dit à `AppShell` où accrocher le bouton d'Uni sur chaque page.
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          for (final page in shellPages) GoRoute(path: page.path, builder: (_, s) => page.builder(PageArgs.of(s))),
        ],
      ),
    ];

/// Durée du fondu entre la présentation et la connexion.
const Duration kAuthFadeDuration = Duration(milliseconds: 320);

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: kAuthFadeDuration,
    reverseTransitionDuration: kAuthFadeDuration,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    ),
  );
}
