import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/providers/providers.dart';
import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/repositories/reference_repository.dart';
import 'package:uniflow_mobile/screens/register.dart';

import 'layout_test_support.dart';

/// Le formulaire d'inscription est le contrat entre le mobile et le schéma :
/// un compte universitaire naît STUDENT, sans valeur codée en dur, et la
/// chaîne université → faculté → filière → niveau vient de la base.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  RegistrationInput universitaire({String? level, List<String> levels = const ['L1', 'L2', 'L3']}) => RegistrationInput(
        email: 'etu@test.cm',
        password: 'motdepasse',
        name: 'Étu Test',
        accountType: UniFlowAccountType.university,
        university: 'Université de Test',
        program: 'test',
        level: level,
        availableLevels: levels,
      );

  group('parseLevels', () {
    test('lit la chaîne du schéma dans l\'ordre, sans doublon ni espace', () {
      expect(parseLevels('L1,L2,L3'), ['L1', 'L2', 'L3']);
      expect(parseLevels(' m1 ; M2,M2 '), ['M1', 'M2']);
      expect(parseLevels(null), isEmpty);
      expect(parseLevels(''), isEmpty);
    });
  });

  group('registrationProfileDocument', () {
    test('un compte universitaire est toujours STUDENT, avec le code filière en majuscules', () {
      final doc = registrationProfileDocument(universitaire(level: 'L2'), email: 'etu@test.cm', name: 'Étu Test');
      expect(doc['role'], 'STUDENT');
      expect(doc['accountType'], 'UNIVERSITY');
      expect(doc['university'], 'Université de Test');
      expect(doc['program'], 'TEST');
      expect(doc['level'], 'L2');
    });

    test('aucune université ni filière par défaut : ce que l\'utilisateur n\'a pas choisi reste vide', () {
      final doc = registrationProfileDocument(
        const RegistrationInput(
            email: 'a@b.cm', password: 'motdepasse', name: 'A B', accountType: UniFlowAccountType.university),
        email: 'a@b.cm',
        name: 'A B',
      );
      expect(doc['university'], '');
      expect(doc['program'], '');
      expect(doc.containsKey('level'), isFalse);
    });

    test('un compte indépendant ne porte aucun rattachement académique', () {
      final doc = registrationProfileDocument(
        const RegistrationInput(
            email: 'a@b.cm', password: 'motdepasse', name: 'A B', accountType: UniFlowAccountType.personal),
        email: 'a@b.cm',
        name: 'A B',
      );
      expect(doc['accountType'], 'PERSONAL');
      expect(doc['role'], 'STUDENT');
      expect(doc['university'], '');
      expect(doc['program'], '');
    });
  });

  group('welcomeMessage', () {
    UniFlowUser u(String type, {String name = 'Nina Ateba', String role = 'STUDENT'}) =>
        UniFlowUser(id: 'x', email: 'n@t.cm', name: name, accountType: type, role: role, program: 'ICT4D', level: 'L2');

    test('salue par le prénom et adapte le mot au type de compte', () {
      expect(welcomeMessage(u('PERSONAL')), 'Bienvenue sur UniFlow, Nina. Votre espace personnel est prêt.');
      expect(welcomeMessage(u('UNIVERSITY')), startsWith('Bienvenue sur UniFlow, Nina. Votre filière'));
      expect(welcomeMessage(u('UNIVERSITY', name: '  ')), startsWith('Bienvenue sur UniFlow. '));
    });

    test('prévient quand les cours de la filière ne sont pas encore publiés', () {
      expect(welcomeMessage(u('UNIVERSITY'), pendingCourses: true), contains('pas encore publiés'));
      // Un espace personnel n'a pas de cours de filière : l'avertissement ne le concerne pas.
      expect(welcomeMessage(u('PERSONAL'), pendingCourses: true), isNot(contains('publiés')));
    });
  });

  group('validateRegistration', () {
    test('accepte un niveau ouvert par la filière et refuse les autres', () {
      expect(validateRegistration(universitaire(level: 'L3')), isNull);
      expect(validateRegistration(universitaire(level: 'M1')), contains('M1'));
      expect(validateRegistration(universitaire(level: 'M1', levels: ['M1', 'M2'])), isNull);
      expect(validateRegistration(universitaire()), 'Choisissez votre niveau.');
    });

    test('exige l\'université et la filière pour un compte universitaire seulement', () {
      const sansFiliere = RegistrationInput(
        email: 'a@b.cm',
        password: 'motdepasse',
        name: 'A B',
        accountType: UniFlowAccountType.university,
        university: 'U',
      );
      expect(validateRegistration(sansFiliere), 'Indiquez votre filière.');
      const personnel = RegistrationInput(
          email: 'a@b.cm', password: 'motdepasse', name: 'A B', accountType: UniFlowAccountType.personal);
      expect(validateRegistration(personnel), isNull);
    });

    test('mot de passe court et adresse invalide sont refusés avant le réseau', () {
      expect(validateRegistration(universitaire(level: 'L1').copyWithPassword('court')), contains('8 caractères'));
      const mauvaisEmail = RegistrationInput(
          email: 'pas-une-adresse', password: 'motdepasse', name: 'A B', accountType: UniFlowAccountType.personal);
      expect(validateRegistration(mauvaisEmail), 'Adresse e-mail invalide.');
    });
  });

  group('RegisterScreen', () {
    testWidgets('enchaîne université → faculté → filière → niveau depuis les listes de la base', (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(const RegisterScreen()));
      await tester.pumpAndSettle();

      // Rien n'est proposé tant que l'université n'est pas choisie.
      expect(find.text('Choisissez d\'abord une université.'), findsNWidgets(2));
      expect(find.text('L1'), findsNothing);
      // Et aucun choix de rôle n'existe dans le formulaire.
      expect(find.textContaining('Rôle'), findsNothing);
      expect(find.textContaining('Enseignant'), findsNothing);

      await tester.ensureVisible(find.byType(DropdownButtonFormField<University>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<University>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Université de Test Numéro Un (UT1)').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<Faculty>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<Faculty>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Faculté des Sciences et Technologies Appliquées').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<AcademicProgram>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<AcademicProgram>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('(TEST)').last);
      await tester.pumpAndSettle();

      // Les niveaux sont ceux de la filière (« L1,L2,L3 »), pas une liste figée.
      expect(find.text('L1'), findsOneWidget);
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('L3'), findsOneWidget);
      expect(find.text('M1'), findsNothing);
      await tester.ensureVisible(find.text('L2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('L2'));
      await tester.pumpAndSettle();
    });

    testWidgets('après l\'inscription, on entre directement dans l\'application avec un mot de bienvenue',
        (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final depot = _InscriptionFactice(
        UniFlowUser(id: 'u9', email: 'nina@test.cm', name: 'Nina Ateba', accountType: 'PERSONAL', role: 'STUDENT'),
      );
      late ProviderContainer container;
      await tester.pumpWidget(host(
        Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const RegisterScreen(initialType: UniFlowAccountType.personal);
        }),
        overrides: [authRepositoryProvider.overrideWithValue(depot)],
      ));
      await tester.pumpAndSettle();
      expect(container.read(authStatusProvider), AuthStatus.unknown);

      await tester.enterText(find.widgetWithText(TextField, 'Nom complet'), 'Nina Ateba');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'nina@test.cm');
      await tester.enterText(find.widgetWithText(TextField, 'Mot de passe (8 caractères minimum)'), 'motdepasse');
      await tester.enterText(find.widgetWithText(TextField, 'Confirmer le mot de passe'), 'motdepasse');
      await tester.ensureVisible(find.text('Créer mon espace personnel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer mon espace personnel'));
      await tester.pumpAndSettle();

      // Plus d'écran intermédiaire à valider : l'état bascule, le routeur
      // mènera au tableau de bord, et le mot de bienvenue s'affiche par-dessus.
      expect(depot.inscriptions, 1);
      expect(container.read(authStatusProvider), AuthStatus.signedIn);
      expect(container.read(currentUserProvider)?.name, 'Nina Ateba');
      expect(find.text('Entrer dans l\'application'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Bienvenue sur UniFlow, Nina'), findsOneWidget);
    });

    testWidgets('un compte indépendant n\'a pas de rattachement académique', (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(const RegisterScreen(initialType: UniFlowAccountType.personal)));
      await tester.pumpAndSettle();
      expect(find.text('Rattachement académique'), findsNothing);
      expect(find.byType(DropdownButtonFormField<University>), findsNothing);
      expect(find.text('Créer mon espace personnel'), findsOneWidget);
    });
  });
}

extension on RegistrationInput {
  RegistrationInput copyWithPassword(String value) => RegistrationInput(
        email: email,
        password: value,
        name: name,
        accountType: accountType,
        university: university,
        program: program,
        level: level,
        availableLevels: availableLevels,
      );
}

/// Dépôt factice : l'inscription réussit sans réseau et rend l'utilisateur donné.
class _InscriptionFactice implements AuthRepository {
  _InscriptionFactice(this.resultat);
  final UniFlowUser resultat;
  int inscriptions = 0;

  @override
  Future<UniFlowUser> register(RegistrationInput input) async {
    inscriptions++;
    return resultat;
  }

  @override
  bool get academicProvisioningPending => false;
  @override
  Future<UniFlowUser?> getCurrentUser() async => resultat;
  @override
  Future<UniFlowUser?> getCurrentUserStrict() async => resultat;
  @override
  Future<UniFlowUser?> refreshProfile() async => resultat;
  @override
  Future<void> login(String email, String password, {UniFlowAccountType? accountTypeHint}) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<bool> provisionAcademicRegistration({String matricule = ''}) async => true;
  @override
  Future<void> retryAcademicProvisioning(UniFlowUser user) async {}
  @override
  Future<void> sendPasswordRecovery(String email) async {}
  @override
  Future<UniFlowUser> updateUsername(String userId, String username) async => resultat;
}
