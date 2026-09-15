import 'package:flutter/material.dart';

/// Rôle applicatif d'un compte UniFlow.
///
/// Les documents Appwrite portent le rôle en chaîne libre (`STUDENT`,
/// `DELEGATE`, `TEACHER`, `ADMIN`). Le reste de l'application manipule
/// l'énumération : une faute de frappe dans une comparaison de chaînes ne
/// produit pas d'erreur, elle produit un écran qui disparaît silencieusement.
/// Le web a la même énumération (`src/utils/userRole.tsx`), ce qui permet de
/// tenir les deux applications alignées.
enum UniFlowRole {
  student,
  delegate,
  teacher,
  admin;

  /// Libellé affiché, identique à celui du web.
  String get label => switch (this) {
        UniFlowRole.student => 'Étudiant',
        UniFlowRole.delegate => 'Délégué',
        UniFlowRole.teacher => 'Enseignant',
        UniFlowRole.admin => 'Administrateur',
      };

  /// Vrai pour les rôles qui encadrent : ils voient les annuaires complets.
  ///
  /// C'est le critère qui ouvre les listes d'étudiants et d'enseignants. Un
  /// étudiant n'a rien à faire dans l'annuaire complet de ses camarades.
  bool get isStaff => this == UniFlowRole.teacher || this == UniFlowRole.admin;

  /// Vrai pour les rôles qui suivent un cursus.
  bool get isLearner => this == UniFlowRole.student || this == UniFlowRole.delegate;

  /// Vrai pour un délégué : il gère les présences de sa promotion.
  bool get isDelegate => this == UniFlowRole.delegate;
}

/// Traduit le rôle stocké en base vers l'énumération.
///
/// Tolérant par construction : le web accepte aussi les formes françaises
/// (`ETUDIANT`, `DELEGUE`, `ENSEIGNANT`) parce que d'anciens documents en
/// portent. Une valeur inconnue retombe sur `student` — le rôle le plus
/// restreint — plutôt que de lever : un compte dont le rôle est illisible doit
/// voir le moins de choses possible, pas empêcher l'application de démarrer.
UniFlowRole mapRole(String? raw) {
  switch (raw?.trim().toUpperCase()) {
    case 'ETUDIANT':
    case 'STUDENT':
    case 'INDEPENDENT_STUDENT':
      return UniFlowRole.student;
    case 'DELEGUE':
    case 'DELEGATE':
      return UniFlowRole.delegate;
    case 'ENSEIGNANT':
    case 'TEACHER':
    case 'INDEPENDENT_TEACHER':
      return UniFlowRole.teacher;
    case 'ADMIN':
    case 'ADMINISTRATEUR':
      return UniFlowRole.admin;
    default:
      return UniFlowRole.student;
  }
}

/// Une destination de navigation, les rôles autorisés à l'atteindre, et sa
/// place éventuelle dans la barre du bas.
///
/// La table est unique et sert aux trois usages : composer la barre du bas,
/// composer la liste des accès secondaires, et refuser une URL atteinte
/// directement. Les séparer laisserait la porte ouverte à un écran masqué mais
/// accessible en tapant son adresse.
class NavDestination {
  final String path;
  final String label;

  /// Icône au repos, puis une fois l'onglet actif.
  final IconData icon;
  final IconData activeIcon;

  /// Rôles autorisés. Vide signifierait « personne » : aucune entrée ne doit
  /// l'être, un test le vérifie.
  final Set<UniFlowRole> roles;

  /// Vrai si l'entrée a sa place dans la barre du bas.
  ///
  /// Déclaré plutôt que déduit d'un `take(4)` : la barre est un lieu fixe de
  /// cinq places, et ce qui y figure est un choix d'ergonomie, pas un hasard
  /// d'ordre de déclaration.
  final bool inBottomBar;

  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.roles,
    this.inBottomBar = false,
  });

  bool allows(UniFlowRole role) => roles.contains(role);
}

/// Toutes les destinations de l'application connectée.
///
/// Reprise de `uniflow-we/src/data/navigation.ts`, qui fait foi : un écart
/// ferait apparaître sur mobile un écran que le web réserve à un autre rôle.
const List<NavDestination> navDestinations = [
  NavDestination(
    path: '/accueil',
    label: 'Accueil',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    inBottomBar: true,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/ues',
    label: 'Mes cours',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    inBottomBar: true,
    roles: {UniFlowRole.student, UniFlowRole.delegate},
  ),
  NavDestination(
    path: '/etudiants',
    label: 'Étudiants',
    icon: Icons.school_outlined,
    activeIcon: Icons.school,
    inBottomBar: true,
    roles: {UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/enseignants',
    label: 'Enseignants',
    icon: Icons.groups_2_outlined,
    activeIcon: Icons.groups_2,
    inBottomBar: true,
    roles: {UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/inscriptions',
    label: 'Inscriptions',
    icon: Icons.how_to_reg_outlined,
    activeIcon: Icons.how_to_reg,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/presence',
    label: 'Présence',
    icon: Icons.qr_code_scanner_outlined,
    activeIcon: Icons.qr_code_scanner,
    inBottomBar: true,
    roles: {UniFlowRole.student, UniFlowRole.delegate},
  ),
  NavDestination(
    path: '/notes',
    label: 'Notes',
    icon: Icons.grading_outlined,
    activeIcon: Icons.grading,
    inBottomBar: true,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/devoirs',
    label: 'Devoirs',
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher},
  ),
  NavDestination(
    path: '/bibliotheque',
    label: 'Bibliothèque',
    icon: Icons.local_library_outlined,
    activeIcon: Icons.local_library,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher},
  ),
  NavDestination(
    path: '/forum',
    label: 'Forum',
    icon: Icons.forum_outlined,
    activeIcon: Icons.forum,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/messages',
    label: 'Messages',
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    inBottomBar: true,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/notifications',
    label: 'Notifications',
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/sentinelle',
    label: 'Sentinelle IoT',
    icon: Icons.sensors_outlined,
    activeIcon: Icons.sensors,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/equipe',
    label: 'L\'Équipe KERNEL FORGE',
    icon: Icons.workspace_premium_outlined,
    activeIcon: Icons.workspace_premium,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/settings',
    label: 'Réglages',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    inBottomBar: true,
    roles: {UniFlowRole.student, UniFlowRole.delegate, UniFlowRole.teacher, UniFlowRole.admin},
  ),
];

/// Entrées visibles par [role], dans l'ordre de la table.
List<NavDestination> destinationsFor(UniFlowRole role) =>
    navDestinations.where((d) => d.allows(role)).toList();

/// Les onglets de la barre du bas pour [role].
///
/// Toujours les Réglages en dernier : c'est le point de sortie de
/// l'application, il ne doit pas changer de place d'un rôle à l'autre.
List<NavDestination> bottomBarFor(UniFlowRole role) {
  final autorisees = destinationsFor(role);
  final fixe = autorisees.where((d) => d.inBottomBar).toList();
  final reglages = fixe.where((d) => d.path == '/settings');
  final autres = fixe.where((d) => d.path != '/settings');
  return [...autres, ...reglages];
}

/// Toutes les entrées autorisées qui ne tiennent pas dans la barre du bas.
///
/// Elles restent atteignables depuis l'accueil : aucun écran autorisé ne doit
/// devenir inaccessible faute de place dans la barre.
List<NavDestination> overflowFor(UniFlowRole role) {
  final barre = bottomBarFor(role).map((d) => d.path).toSet();
  return destinationsFor(role).where((d) => !barre.contains(d.path)).toList();
}

/// Vrai si [role] a le droit d'atteindre [location].
///
/// Les sous-chemins héritent de leur parent : `/etudiants/u1` suit la règle de
/// `/etudiants`. Les chemins hors table — `/login`, ou une URL inconnue — sont
/// laissés au routeur, qui a ses propres règles.
bool canAccessPath(UniFlowRole role, String location) {
  NavDestination? destination;
  for (final candidate in navDestinations) {
    if (location == candidate.path || location.startsWith('${candidate.path}/')) {
      // Le préfixe le plus long gagne : `/ues` ne doit pas décider pour
      // `/ues/ue1` si une entrée plus précise existait un jour.
      if (destination == null || candidate.path.length > destination.path.length) {
        destination = candidate;
      }
    }
  }
  if (destination == null) return true;
  return destination.allows(role);
}
