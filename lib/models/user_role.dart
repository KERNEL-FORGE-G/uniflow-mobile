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
  admin,

  /// Compte indépendant (`accountType = PERSONAL`) : il n'appartient à aucune
  /// université et ne voit que son espace personnel — matières, tâches,
  /// documents, agenda. Ce n'est pas un rôle universitaire, mais le traiter
  /// comme tel dans la table de navigation évite une seconde table pour
  /// décider de ce qu'il voit.
  personal;

  /// Libellé affiché, identique à celui du web.
  String get label => switch (this) {
        UniFlowRole.student => 'Étudiant',
        UniFlowRole.delegate => 'Délégué',
        UniFlowRole.teacher => 'Enseignant',
        UniFlowRole.admin => 'Administrateur',
        UniFlowRole.personal => 'Compte indépendant',
      };

  /// Valeur telle qu'elle est stockée dans `users.role` et dans les labels.
  String get wireValue => switch (this) {
        UniFlowRole.student => 'STUDENT',
        UniFlowRole.delegate => 'DELEGATE',
        UniFlowRole.teacher => 'TEACHER',
        UniFlowRole.admin => 'ADMIN',
        UniFlowRole.personal => 'PERSONAL',
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

  /// Vrai pour les rôles qui peuvent émettre un QR de présence.
  ///
  /// C'est la règle du service `/attendance-secure` (action `issue`) : la
  /// reprendre ici évite de proposer un bouton qui répondra `ROLE_DENIED`.
  bool get canIssueAttendance =>
      this == UniFlowRole.delegate || this == UniFlowRole.teacher || this == UniFlowRole.admin;

  /// Vrai pour les rôles qui émargent en scannant un QR (`scan`).
  bool get canScanAttendance => isLearner;

  /// Vrai pour un compte rattaché à une université.
  bool get isUniversity => this != UniFlowRole.personal;

  /// Rôle porté par les **labels Appwrite** du compte, source de vérité
  /// commune aux trois clients.
  ///
  /// Contrat : un label vaut le nom du rôle tel quel — `ADMIN`, `TEACHER`,
  /// `DELEGATE` — et l'absence de label de rôle signifie `STUDENT`. Appwrite
  /// n'admet que lettres et chiffres dans un label (`role:ADMIN` est refusé en
  /// 400), d'où cette forme nue. Le champ `users.role` du document n'est qu'un
  /// miroir d'affichage : il n'est lu ([fallbackRole]) que si les labels ne
  /// disent rien, pour les comptes créés avant la pose des labels.
  ///
  /// Insensible à la casse et tolérant aux labels inconnus (`superadmin`,
  /// libellés futurs) : un label imprévu ne doit pas faire chuter le compte au
  /// rang d'étudiant. Si plusieurs labels de rôle cohabitent, le plus élevé
  /// gagne : c'est le sens d'un cumul, et l'inverse rendrait un administrateur
  /// aussi étiqueté `TEACHER` incapable d'administrer.
  static UniFlowRole fromLabels(
    List<String> labels, {
    String? fallbackRole,
    String? accountType,
  }) {
    if ((accountType ?? '').trim().toUpperCase() == 'PERSONAL') {
      return UniFlowRole.personal;
    }
    UniFlowRole? found;
    for (final raw in labels) {
      final candidate = switch (raw.trim().toUpperCase()) {
        'ADMIN' => UniFlowRole.admin,
        'TEACHER' => UniFlowRole.teacher,
        'DELEGATE' => UniFlowRole.delegate,
        'STUDENT' => UniFlowRole.student,
        _ => null,
      };
      if (candidate == null) continue;
      if (found == null || candidate.index > found.index) found = candidate;
    }
    if (found != null) return found;
    if (fallbackRole != null && fallbackRole.trim().isNotEmpty) {
      return mapRole(fallbackRole);
    }
    return UniFlowRole.student;
  }
}

/// Vrai si les labels désignent l'administrateur de la plateforme.
///
/// Seul lui peut créer d'autres comptes `ADMIN` ; un administrateur
/// d'université crée enseignants, délégués et étudiants de sa propre
/// université.
bool isSuperAdmin(List<String> labels) => labels.any((label) => label.trim().toLowerCase() == 'superadmin');

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
    case 'PERSONAL':
    case 'INDEPENDANT':
      return UniFlowRole.personal;
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

  /// Rôles pour lesquels l'entrée occupe une place dans la barre du bas.
  ///
  /// Déclaré par rôle plutôt que par un booléen : la barre est un lieu fixe de
  /// six places au plus, et l'onglet « Enseignants » y a sa place pour
  /// l'administration mais pas pour un enseignant, qui y préfère ses cours.
  /// Un rôle qui figure ici sans figurer dans [roles] serait une incohérence :
  /// un test le vérifie.
  final Set<UniFlowRole> barRoles;

  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.roles,
    this.barRoles = const {},
  });

  bool allows(UniFlowRole role) => roles.contains(role);

  /// Vrai si l'entrée a sa place dans la barre du bas pour [role].
  bool inBarFor(UniFlowRole role) => barRoles.contains(role);
}

/// Rôles rattachés à une université.
const Set<UniFlowRole> universityRoles = {
  UniFlowRole.student,
  UniFlowRole.delegate,
  UniFlowRole.teacher,
  UniFlowRole.admin,
};

/// Tous les rôles, compte indépendant compris.
const Set<UniFlowRole> everyRole = {...universityRoles, UniFlowRole.personal};

const Set<UniFlowRole> _learners = {UniFlowRole.student, UniFlowRole.delegate};
const Set<UniFlowRole> _learnersAndTeacher = {..._learners, UniFlowRole.teacher};
const Set<UniFlowRole> _staff = {UniFlowRole.teacher, UniFlowRole.admin};

/// Toutes les destinations de l'application connectée.
///
/// Reprise de `uniflow-we/src/data/navigation.ts`, qui fait foi : un écart
/// ferait apparaître sur mobile un écran que le web réserve à un autre rôle.
/// Le compte indépendant (`personal`) n'a aucun écran universitaire : il voit
/// son espace — matières, tâches, agenda, notes — et les écrans communs
/// (messagerie, forum, notifications, équipe, réglages).
const List<NavDestination> navDestinations = [
  NavDestination(
    path: '/accueil',
    label: 'Accueil',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    roles: everyRole,
    barRoles: everyRole,
  ),
  NavDestination(
    path: '/ues',
    label: 'Mes cours',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    roles: _learnersAndTeacher,
    barRoles: _learnersAndTeacher,
  ),
  NavDestination(
    path: '/emploi-du-temps',
    label: 'Emploi du temps',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    roles: {..._learnersAndTeacher, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/etudiants',
    label: 'Étudiants',
    icon: Icons.school_outlined,
    activeIcon: Icons.school,
    roles: _staff,
    barRoles: _staff,
  ),
  NavDestination(
    path: '/enseignants',
    label: 'Enseignants',
    icon: Icons.groups_2_outlined,
    activeIcon: Icons.groups_2,
    roles: _staff,
    barRoles: {UniFlowRole.admin},
  ),
  NavDestination(
    path: '/comptes',
    label: 'Comptes',
    icon: Icons.manage_accounts_outlined,
    activeIcon: Icons.manage_accounts,
    roles: {UniFlowRole.admin},
    barRoles: {UniFlowRole.admin},
  ),
  NavDestination(
    path: '/inscriptions',
    label: 'Inscriptions',
    icon: Icons.how_to_reg_outlined,
    activeIcon: Icons.how_to_reg,
    roles: {..._learners, UniFlowRole.admin},
  ),
  NavDestination(
    path: '/presence',
    label: 'Présence',
    icon: Icons.qr_code_scanner_outlined,
    activeIcon: Icons.qr_code_scanner,
    roles: _learnersAndTeacher,
    barRoles: _learners,
  ),
  NavDestination(
    path: '/notes',
    label: 'Notes',
    icon: Icons.grading_outlined,
    activeIcon: Icons.grading,
    roles: {..._learnersAndTeacher, UniFlowRole.personal},
    barRoles: {..._learnersAndTeacher, UniFlowRole.personal},
  ),
  NavDestination(
    path: '/devoirs',
    label: 'Devoirs',
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment,
    roles: _learnersAndTeacher,
  ),
  NavDestination(
    path: '/bibliotheque',
    label: 'Bibliothèque',
    icon: Icons.local_library_outlined,
    activeIcon: Icons.local_library,
    roles: universityRoles,
  ),
  NavDestination(
    path: '/matieres',
    label: 'Matières',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book,
    roles: {UniFlowRole.personal},
    barRoles: {UniFlowRole.personal},
  ),
  NavDestination(
    path: '/taches',
    label: 'Tâches',
    icon: Icons.task_alt_outlined,
    activeIcon: Icons.task_alt,
    roles: {UniFlowRole.personal},
    barRoles: {UniFlowRole.personal},
  ),
  NavDestination(
    path: '/agenda',
    label: 'Agenda',
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
    roles: {UniFlowRole.personal},
    barRoles: {UniFlowRole.personal},
  ),
  NavDestination(
    path: '/forum',
    label: 'Forum',
    icon: Icons.forum_outlined,
    activeIcon: Icons.forum,
    roles: everyRole,
  ),
  // Messagerie et notifications passent par le service `/messaging`, qui
  // refuse tout compte hors de l'annuaire académique (vérifié en direct le
  // 2026-09-20 : « La messagerie est réservée aux membres de l'annuaire… »).
  // Les proposer à un compte indépendant afficherait une erreur à chaque
  // ouverture.
  NavDestination(
    path: '/messages',
    label: 'Messages',
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    roles: universityRoles,
    barRoles: universityRoles,
  ),
  NavDestination(
    path: '/notifications',
    label: 'Notifications',
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
    roles: universityRoles,
  ),
  NavDestination(
    path: '/equipe',
    label: 'L\'Équipe KERNEL FORGE',
    icon: Icons.workspace_premium_outlined,
    activeIcon: Icons.workspace_premium,
    roles: everyRole,
  ),
  NavDestination(
    path: '/settings',
    label: 'Réglages',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    roles: everyRole,
    barRoles: everyRole,
  ),
];

/// Entrées visibles par [role], dans l'ordre de la table.
List<NavDestination> destinationsFor(UniFlowRole role) => navDestinations.where((d) => d.allows(role)).toList();

/// Les onglets de la barre du bas pour [role].
///
/// Toujours les Réglages en dernier : c'est le point de sortie de
/// l'application, il ne doit pas changer de place d'un rôle à l'autre.
List<NavDestination> bottomBarFor(UniFlowRole role) {
  final autorisees = destinationsFor(role);
  final fixe = autorisees.where((d) => d.inBarFor(role)).toList();
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
