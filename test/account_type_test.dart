import 'package:flutter_test/flutter_test.dart';
import 'package:uniflow_mobile/models/appwrite_models.dart';
import 'package:uniflow_mobile/models/user_role.dart';
import 'package:uniflow_mobile/repositories/auth_repository.dart';
import 'package:uniflow_mobile/repositories/reference_repository.dart';

/// `users.accountType` vaut désormais UNIVERSITY | PERSONAL | PLATFORM
/// (schéma du 2026-09-20). Le parseur ne doit planter ni sur PLATFORM ni sur
/// une valeur imprévue, et PLATFORM ne doit jamais ouvrir l'espace personnel.
void main() {
  group('UniFlowAccountType', () {
    test('lit les trois valeurs, sans casse', () {
      expect(UniFlowAccountType.tryParse('UNIVERSITY'), UniFlowAccountType.university);
      expect(UniFlowAccountType.tryParse('personal'), UniFlowAccountType.personal);
      expect(UniFlowAccountType.tryParse(' Platform '), UniFlowAccountType.platform);
      expect(UniFlowAccountType.platform.wireValue, 'PLATFORM');
    });

    test('valeur inconnue ou absente : repli explicite, pas d\'exception', () {
      expect(UniFlowAccountType.tryParse('ENTREPRISE'), isNull);
      expect(UniFlowAccountType.tryParse(null), isNull);
      expect(UniFlowAccountType.parse('ENTREPRISE'), UniFlowAccountType.university);
      expect(UniFlowAccountType.parse(null, fallback: UniFlowAccountType.personal), UniFlowAccountType.personal);
      expect(UniFlowAccountType.parse(42), UniFlowAccountType.university);
    });

    test('seuls UNIVERSITY et PERSONAL sont proposés à l\'utilisateur', () {
      expect(UniFlowAccountType.selectable, isNot(contains(UniFlowAccountType.platform)));
    });
  });

  group('compte PLATFORM', () {
    final kernel = UniFlowUser(
      id: 'k',
      email: 'kernel@forge.codes',
      name: 'Kernel Forge',
      accountType: 'PLATFORM',
      role: 'ADMIN',
      labels: const ['ADMIN', 'superadmin'],
    );

    test('n\'est ni personnel ni sans rôle : ADMIN par ses labels', () {
      expect(kernel.isPlatform, isTrue);
      expect(kernel.isPersonal, isFalse);
      expect(kernel.isSuperAdmin, isTrue);
      expect(UniFlowRole.fromLabels(kernel.labels, accountType: 'PLATFORM'), UniFlowRole.admin);
    });

    test('n\'a accès à aucun écran personnel, mais à tous les écrans universitaires', () {
      final role = UniFlowRole.fromLabels(kernel.labels, accountType: kernel.accountType);
      expect(canAccessPath(role, '/matieres'), isFalse);
      expect(canAccessPath(role, '/comptes'), isTrue);
      expect(canAccessPath(role, '/emploi-du-temps'), isTrue);
    });
  });

  group('inscription universitaire', () {
    test('enregistre la faculté et le code court de la filière, rôle STUDENT', () {
      final doc = registrationProfileDocument(
        const RegistrationInput(
          email: 'e@t.cm',
          password: 'motdepasse',
          name: 'Étudiante',
          accountType: UniFlowAccountType.university,
          university: 'Université de Yaoundé I',
          faculty: 'fs',
          program: 'phy',
          level: 'M1',
          availableLevels: ['L1', 'L2', 'L3', 'M1'],
        ),
        email: 'e@t.cm',
        name: 'Étudiante',
      );
      expect(doc['faculty'], 'FS');
      expect(doc['program'], 'PHY');
      expect(doc['level'], 'M1');
      expect(doc['role'], 'STUDENT');
      expect(doc['accountType'], 'UNIVERSITY');
    });
  });

  group('resolveUniversity', () {
    const uy1 = University(code: 'UY1', name: 'Université de Yaoundé I', shortName: 'UY1');
    const ud = University(code: 'UD', name: 'Université de Douala', shortName: 'UDla');

    test('retrouve l\'université par nom, sigle ou code, sans casse', () {
      expect(resolveUniversity([uy1, ud], 'université de yaoundé i'), uy1);
      expect(resolveUniversity([uy1, ud], 'UDla'), ud);
      expect(resolveUniversity([uy1, ud], 'ud'), ud);
      expect(resolveUniversity([uy1, ud], 'Inconnue'), isNull);
      expect(resolveUniversity([uy1, ud], ''), isNull);
    });
  });
}
