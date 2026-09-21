// `Databases.*Document` est marqué déprécié par le SDK Dart 26 au profit de
// `TablesDB.*Row` (Appwrite 1.8). Le schéma du projet est encore déclaré en
// collections/documents (`uniflow-we/scripts/appwrite-schema.mjs`) et la
// migration vers TablesDB se fera pour les trois clients en même temps ; on
// ignore la dépréciation ici, fichier par fichier, sans assouplir l'analyse
// globale.
// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/appwrite_provider.dart';
import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../models/user_role.dart';

/// Type de compte UniFlow (`users.accountType`).
///
/// `PLATFORM` est l'administrateur de la plateforme (`kernel@forge.codes`,
/// label `superadmin`) : il n'appartient à aucune université et voit tout. Il
/// n'est **jamais** proposé à l'inscription, ni à la connexion : on le lit
/// seulement. Une valeur inconnue ne fait pas planter le parseur : le web peut
/// ajouter un type avant que le mobile ne soit mis à jour.
enum UniFlowAccountType {
  university,
  personal,
  platform;

  String get wireValue => switch (this) {
        university => 'UNIVERSITY',
        personal => 'PERSONAL',
        platform => 'PLATFORM',
      };

  /// Types qu'un utilisateur peut choisir lui-même.
  static const List<UniFlowAccountType> selectable = [university, personal];

  static UniFlowAccountType? tryParse(Object? raw) {
    switch (raw?.toString().trim().toUpperCase()) {
      case 'UNIVERSITY':
        return university;
      case 'PERSONAL':
        return personal;
      case 'PLATFORM':
        return platform;
      default:
        return null;
    }
  }

  /// Comme [tryParse], avec un repli explicite sur `UNIVERSITY` : une valeur
  /// absente ou inconnue ne doit ni planter ni ouvrir l'espace personnel.
  static UniFlowAccountType parse(Object? raw, {UniFlowAccountType fallback = university}) => tryParse(raw) ?? fallback;
}

/// Forme d'un niveau académique (« L1 », « M2 », « D1 »…). Les niveaux
/// réellement ouverts viennent de `academic_programs.levels` de la filière
/// choisie : rien n'est figé ici.
final RegExp academicLevelPattern = RegExp(r'^[A-Z]\d$');

/// Page d'inscription du web, pour qui préfère s'inscrire depuis un navigateur
/// (`uniflow-we/src/App.tsx`, route `/register`).
const String webRegisterUrl = 'https://uniflow.kernelforge.codes/register';

/// Page où le lien de récupération de mot de passe envoyé par Appwrite ramène
/// l'utilisateur. Appwrite exige une URL d'une plateforme déclarée sur le
/// projet : c'est celle du web.
const String passwordResetUrl = 'https://uniflow.kernelforge.codes/reset-password';

/// Données saisies dans le formulaire d'inscription natif.
class RegistrationInput {
  final String email;
  final String password;
  final String name;
  final UniFlowAccountType accountType;
  final String university;

  /// Code de la faculté (`faculties.code`, « FS »…), enregistré dans
  /// `users.faculty` : l'administration d'une université gère sa faculté.
  final String faculty;
  final String program;
  final String? level;
  final String matricule;
  final String country;

  /// Niveaux ouverts par la filière choisie (`academic_programs.levels`) :
  /// la validation refuse un niveau que la filière n'offre pas.
  final List<String> availableLevels;

  const RegistrationInput({
    required this.email,
    required this.password,
    required this.name,
    required this.accountType,
    this.university = '',
    this.faculty = '',
    this.program = '',
    this.level,
    this.matricule = '',
    this.country = 'Cameroun',
    this.availableLevels = const [],
  });
}

/// Document `users` à créer pour une inscription, identique à celui qu'écrit
/// le web (`uniflow-we/src/lib/appwrite.ts#createAccount`).
///
/// Le rôle est **toujours** `STUDENT` pour un compte universitaire : le
/// formulaire ne propose aucun choix de rôle, et les rôles supérieurs ne se
/// donnent que par labels, posés côté serveur par l'administration. Un client
/// qui écrirait `ADMIN` ici n'obtiendrait de toute façon aucun droit, puisque
/// les services lisent les labels — mais l'afficher tromperait l'utilisateur.
///
/// Fonction pure, testée : c'est le contrat entre le mobile et le schéma.
Map<String, dynamic> registrationProfileDocument(
  RegistrationInput input, {
  required String email,
  required String name,
}) {
  final university = input.accountType == UniFlowAccountType.university;
  return {
    'email': email,
    'name': name,
    'accountType': input.accountType.wireValue,
    // `users.role` est une énumération STUDENT|DELEGATE|TEACHER|ADMIN : un
    // compte indépendant y porte aussi STUDENT, c'est `accountType` qui le
    // distingue.
    'role': 'STUDENT',
    // `university` porte le NOM de l'université et `program` le CODE de la
    // filière (celui de `academic_courses.program`) : c'est sur ce couple
    // program + level que se filtrent cours, emploi du temps et annuaire.
    'university': university ? input.university.trim() : '',
    'faculty': university ? input.faculty.trim().toUpperCase() : '',
    'program': university ? input.program.trim().toUpperCase() : '',
    if (university && input.level != null && academicLevelPattern.hasMatch(input.level!.trim().toUpperCase()))
      'level': input.level!.trim().toUpperCase(),
    'country': input.country.trim().isEmpty ? 'Cameroun' : input.country.trim(),
  };
}

/// Message d'erreur si la confirmation ne reprend pas le mot de passe, ou
/// `null`. Vérifié après [validateRegistration] : un mot de passe trop court
/// se signale avant sa confirmation.
String? passwordConfirmationError(String password, String confirmation) {
  if (confirmation.isEmpty) return 'Confirmez votre mot de passe.';
  if (password != confirmation) return 'Les deux mots de passe ne correspondent pas.';
  return null;
}

/// Message d'erreur du formulaire d'inscription, ou `null` s'il est valide.
///
/// Appliqué avant l'appel réseau pour un retour immédiat ; l'unicité de
/// l'adresse, elle, ne peut venir que du serveur (409).
String? validateRegistration(RegistrationInput input) {
  if (input.name.trim().length < 2) return 'Indiquez votre nom complet.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input.email.trim())) {
    return 'Adresse e-mail invalide.';
  }
  // Appwrite refuse les mots de passe de moins de 8 caractères (400) : autant
  // le dire avant d'envoyer.
  if (input.password.length < 8) return 'Le mot de passe doit faire au moins 8 caractères.';
  if (input.accountType == UniFlowAccountType.university) {
    if (input.university.trim().isEmpty) return 'Indiquez votre université.';
    if (input.program.trim().isEmpty) return 'Indiquez votre filière.';
    final level = input.level?.trim().toUpperCase() ?? '';
    if (level.isEmpty || !academicLevelPattern.hasMatch(level)) return 'Choisissez votre niveau.';
    if (input.availableLevels.isNotEmpty && !input.availableLevels.contains(level)) {
      return 'Le niveau $level n\'est pas ouvert dans cette filière.';
    }
  }
  return null;
}

class AuthRepository {
  final AppwriteService _service;
  AuthRepository(this._service);

  Account get _account => _service.account;
  Databases get _databases => _service.databases;

  /// Ouvre la session. `accountTypeHint` est le choix fait sur l'écran de
  /// connexion : il n'est enregistré que si le compte n'a encore aucun type
  /// (ni dans `users.accountType`, ni dans ses préférences), comme sur le web.
  /// Un compte déjà typé garde son type quoi que l'utilisateur ait coché.
  Future<void> login(String email, String password, {UniFlowAccountType? accountTypeHint}) async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
    await _account.createEmailPasswordSession(
      email: email.trim(),
      password: password,
    );
    if (accountTypeHint == null) return;
    try {
      final account = await _account.get();
      if (UniFlowAccountType.tryParse(account.prefs.data['uniflowAccountType']) != null) return;
      final docs = await _databases.listDocuments(
        databaseId: _service.databaseId,
        collectionId: 'users',
        queries: [Query.equal('email', account.email), Query.limit(1)],
      );
      final typed =
          docs.documents.isNotEmpty && UniFlowAccountType.tryParse(docs.documents.first.data['accountType']) != null;
      if (!typed) await _persistAccountTypePreference(accountTypeHint);
    } catch (_) {
      // L'indication est un confort, pas une condition de connexion.
    }
  }

  Future<void> logout() async {
    await _account.deleteSession(sessionId: 'current');
  }

  /// Crée le compte, ouvre la session, écrit la préférence de type et le
  /// document `users`, puis — pour un compte universitaire — demande le
  /// raccordement académique. C'est, étape pour étape, la séquence du web.
  ///
  /// Le compte reste créé si le raccordement échoue : le message le dit, et
  /// l'utilisateur pourra relancer l'inscription universitaire depuis sa
  /// session. Le détruire silencieusement lui ferait perdre son adresse.
  Future<UniFlowUser> register(RegistrationInput input) async {
    final invalid = validateRegistration(input);
    if (invalid != null) throw AuthException(invalid);

    // Appwrite refuse `account.create` si une session est encore ouverte :
    // la fermeture doit précéder la création.
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}

    try {
      await _account.create(
        userId: ID.unique(),
        email: input.email.trim(),
        password: input.password,
        name: input.name.trim(),
      );
    } on AppwriteException catch (error) {
      throw AuthException(_registrationMessage(error));
    }

    await _account.createEmailPasswordSession(
      email: input.email.trim(),
      password: input.password,
    );
    await _persistAccountTypePreference(input.accountType);
    final account = await _account.get();

    final document = registrationProfileDocument(
      input,
      email: account.email,
      name: account.name,
    );
    try {
      await _databases.createDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: account.$id,
        data: document,
        permissions: [
          Permission.read(Role.user(account.$id)),
          Permission.update(Role.user(account.$id)),
          Permission.delete(Role.user(account.$id)),
        ],
      );
    } on AppwriteException catch (error) {
      // 409 : le document existe déjà (inscription reprise après une coupure).
      if (error.code != 409) {
        throw AuthException('Compte créé, mais le profil UniFlow n\'a pas pu être enregistré (code ${error.code}).');
      }
    }

    if (input.accountType == UniFlowAccountType.university) {
      // Le raccordement ne conditionne plus l'inscription : compte et session
      // existent, et l'échec courant — cours de la filière pas encore publiés —
      // se rattrape à la connexion suivante (`retryAcademicProvisioning`).
      // Avant, l'étudiant lisait « Compte créé, mais… » devant le formulaire.
      try {
        await provisionAcademicRegistration(matricule: input.matricule);
      } on AuthException catch (error) {
        debugPrint('Raccordement académique différé : ${error.message}');
        _academicProvisioningPending = true;
      }
    }

    final user = await getCurrentUser();
    if (user == null) {
      throw AuthException('Compte créé, mais la session n\'a pas pu être relue. Connectez-vous.');
    }
    return user;
  }

  /// Vrai tant qu'un raccordement académique reste à rejouer dans ce processus.
  bool _academicProvisioningPending = false;

  /// Rattache l'étudiant connecté à l'annuaire et aux cours de sa filière
  /// (service `/academic-registration`, action `provision`). Renvoie `false`
  /// quand le serveur signale que les cours de la filière ne sont pas encore
  /// publiés (`coursesReady: false`) : l'appel est à rejouer plus tard.
  Future<bool> provisionAcademicRegistration({String matricule = ''}) async {
    Map<String, dynamic> data;
    try {
      data = await _service.callService('/academic-registration', {
        'action': 'provision',
        'matricule': matricule.trim(),
      });
    } catch (error) {
      throw AuthException('Le raccordement académique a échoué ($error).');
    }
    if (data['ok'] != true) {
      throw AuthException(
        (data['message'] as String?) ?? 'Le raccordement académique a été refusé.',
      );
    }
    return data['coursesReady'] != false;
  }

  /// Rejoue le raccordement d'un apprenant universitaire à la connexion, si
  /// celui de l'inscription n'a pas abouti. Idempotent côté serveur (annuaire
  /// et inscriptions existants conservés). Ne lève jamais : c'est un
  /// rattrapage, pas une condition d'accès.
  Future<void> retryAcademicProvisioning(UniFlowUser user) async {
    if (!user.isUniversity || user.isPlatform) return;
    if (!const {'STUDENT', 'DELEGATE'}.contains(user.role.toUpperCase())) return;
    if ((user.program ?? '').isEmpty || (user.level ?? '').isEmpty) return;
    try {
      _academicProvisioningPending = !await provisionAcademicRegistration();
    } on AuthException catch (error) {
      debugPrint('Raccordement académique toujours différé : ${error.message}');
    }
  }

  bool get academicProvisioningPending => _academicProvisioningPending;

  /// Envoie l'e-mail de réinitialisation du mot de passe.
  Future<void> sendPasswordRecovery(String email) async {
    try {
      await _account.createRecovery(email: email.trim(), url: passwordResetUrl);
    } on AppwriteException catch (error) {
      throw AuthException(switch (error.code) {
        404 => 'Aucun compte ne porte cette adresse.',
        429 => 'Trop de demandes : réessayez dans quelques minutes.',
        _ => 'L\'envoi a échoué (code ${error.code}).',
      });
    }
  }

  Future<void> _persistAccountTypePreference(UniFlowAccountType type) async {
    try {
      final account = await _account.get();
      await _account.updatePrefs(prefs: {
        ...account.prefs.data,
        'uniflowAccountType': type.wireValue,
      });
    } catch (_) {
      // La préférence accélère les sessions futures ; la connexion reste
      // valide si sa mise à jour échoue.
    }
  }

  /// Profil de l'utilisateur connecté, ou `null` sans session.
  ///
  /// Le rôle est calculé depuis les **labels** du compte, source de vérité
  /// commune aux trois clients ; `users.role` ne sert que de repli si les
  /// labels sont vides. Le type de compte vient des préférences
  /// (`uniflowAccountType`, écrites à l'inscription) puis du document.
  ///
  /// Un document `users` absent (404) n'invalide pas la session : le compte
  /// existe, son profil est simplement incomplet — le web fait de même.
  Future<UniFlowUser?> getCurrentUser() async {
    try {
      return await getCurrentUserStrict();
    } catch (_) {
      return null;
    }
  }

  /// Comme [getCurrentUser], mais distingue « pas de session » (`null`, le
  /// serveur a répondu 401) de « serveur injoignable » (exception).
  ///
  /// Le démarrage hors ligne en dépend : confondre les deux déconnectait
  /// l'utilisateur dès que le réseau manquait, alors que sa session est
  /// peut-être parfaitement valide.
  Future<UniFlowUser?> getCurrentUserStrict() async {
    final models.User account;
    try {
      account = await _account.get();
    } on AppwriteException catch (error) {
      if (error.code == 401 || error.code == 403) return null;
      rethrow;
    }

    Map<String, dynamic> data = const {};
    try {
      final doc = await _databases.getDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: account.$id,
      );
      data = doc.data;
    } on AppwriteException catch (error) {
      // 404 : profil incomplet, la session reste valide. 401 : la session est
      // tombée entre les deux appels. Le reste (réseau) remonte.
      if (error.code == 401 || error.code == 403) return null;
      if (error.code != 404) rethrow;
    }

    // Le document fait foi (il porte `PLATFORM` pour l'admin de la
    // plateforme) ; la préférence n'est qu'un indice laissé à la connexion.
    final hintedType = UniFlowAccountType.tryParse(account.prefs.data['uniflowAccountType']);
    final accountType =
        UniFlowAccountType.parse(data['accountType'], fallback: hintedType ?? UniFlowAccountType.university);
    final role = UniFlowRole.fromLabels(
      account.labels,
      fallbackRole: data['role']?.toString(),
      accountType: accountType.wireValue,
    );

    return UniFlowUser(
      id: account.$id,
      email: account.email,
      name: account.name,
      accountType: accountType.wireValue,
      role: role.wireValue,
      labels: List<String>.from(account.labels),
      university: data['university'],
      faculty: data['faculty'],
      program: data['program'],
      level: data['level'],
      country: data['country'],
      username: data['username'],
      avatarFileId: data['avatarFileId'],
    );
  }

  /// Relit uniquement le document de profil, sans repasser par le compte.
  ///
  /// Utilisé après un changement de photo : le compte Appwrite n'a pas bougé,
  /// seul le document `users` a été mis à jour.
  Future<UniFlowUser?> refreshProfile() => getCurrentUser();

  /// Change le pseudo du compte connecté et renvoie le profil à jour.
  ///
  /// Le pseudo est l'adresse de la messagerie : il doit être unique. Cette
  /// unicité est garantie par un index unique côté Appwrite, qui répond 409 —
  /// c'est donc le serveur qui tranche, et non une vérification préalable qui
  /// laisserait passer deux inscriptions simultanées.
  Future<UniFlowUser> updateUsername(String userId, String username) async {
    try {
      await _databases.updateDocument(
        databaseId: _service.databaseId,
        collectionId: 'users',
        documentId: userId,
        data: {'username': username},
      );
    } on AppwriteException catch (error) {
      throw AuthException(_usernameMessage(error, username));
    }

    final profile = await getCurrentUser();
    if (profile == null) {
      throw AuthException('Pseudo enregistré, mais le profil n\'a pas pu être relu.');
    }
    return profile;
  }

  String _usernameMessage(AppwriteException error, String username) {
    switch (error.code) {
      case 409:
        return 'Le pseudo « $username » est déjà pris. Choisissez-en un autre.';
      case 401:
        return 'Session expirée. Reconnectez-vous pour changer de pseudo.';
      case 403:
        return 'Ce compte n\'est pas autorisé à modifier son profil.';
      case 400:
        // Appwrite refuse un document qui viole le format d'un attribut ; le
        // seul cas atteignable ici est le pseudo, déjà validé côté client.
        return 'Ce pseudo n\'est pas accepté par Appwrite.';
      default:
        return 'Le changement de pseudo a échoué (code ${error.code}).';
    }
  }

  String _registrationMessage(AppwriteException error) {
    switch (error.code) {
      case 409:
        return 'Un compte existe déjà avec cette adresse. Connectez-vous ou réinitialisez votre mot de passe.';
      case 400:
        return 'Adresse ou mot de passe refusé par Appwrite : ${error.message ?? 'vérifiez la saisie.'}';
      case 429:
        return 'Trop de tentatives : réessayez dans quelques minutes.';
      default:
        return 'La création du compte a échoué (code ${error.code}).';
    }
  }
}

/// Message lisible pour une erreur de connexion.
///
/// Le SDK rend un texte anglais (« Invalid credentials ») et un code : on
/// traduit les cas courants, et on garde le code pour le diagnostic.
String loginErrorMessage(Object error) {
  if (error is AuthException) return error.message;
  if (error is AppwriteException) {
    return switch (error.code) {
      401 => 'Adresse ou mot de passe incorrect.',
      429 => 'Trop de tentatives : réessayez dans quelques minutes.',
      _ => 'Connexion refusée par Appwrite (code ${error.code}).',
    };
  }
  return 'Serveur injoignable : vérifiez votre connexion. ($error)';
}

/// Erreur destinée à l'utilisateur, portant un texte déjà rédigé.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Pseudo normalisé, ou `null` s'il est inutilisable.
///
/// La règle est volontairement stricte : le pseudo sert d'adresse de
/// messagerie, donc de minuscules sans espace ni accent, comme un identifiant.
/// Elle est appliquée avant l'appel réseau pour donner un retour immédiat ;
/// l'unicité, elle, ne peut venir que du serveur.
String? normalizeUsername(String raw) {
  final cleaned = raw.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
  if (cleaned.length < 3) return null;
  if (cleaned.length > 32) return null;
  if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(cleaned)) return null;
  if (cleaned.endsWith('.') || cleaned.endsWith('-') || cleaned.endsWith('_')) {
    return null;
  }
  return cleaned;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return AuthRepository(service);
});

/// Mot de bienvenue affiché à l'arrivée sur le tableau de bord après
/// l'inscription. Il remplace l'ancien écran « Entrer dans l'application » :
/// un étudiant dont les cours ne sont pas encore publiés est prévenu ici.
String welcomeMessage(UniFlowUser user, {bool pendingCourses = false}) {
  final prenom = user.name.trim().split(RegExp(r'\s+')).first;
  final salut = prenom.isEmpty ? 'Bienvenue sur UniFlow' : 'Bienvenue sur UniFlow, $prenom';
  if (user.isPersonal) return '$salut. Votre espace personnel est prêt.';
  if (pendingCourses) {
    return '$salut. Les cours de votre filière ne sont pas encore publiés : vous y serez inscrit automatiquement.';
  }
  return '$salut. Votre filière et votre niveau déterminent vos cours, votre emploi du temps et votre annuaire.';
}
