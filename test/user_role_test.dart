// Tests des rôles et de la navigation.
//
// La table `navDestinations` sert à trois choses à la fois : composer la barre
// du bas, composer les accès secondaires, et refuser une adresse tapée
// directement. Ces tests verrouillent la cohérence des trois — une entrée
// masquée mais atteignable par URL ne restreindrait rien du tout.

import 'package:flutter_test/flutter_test.dart';

import 'package:uniflow_mobile/models/user_role.dart';

void main() {
  group('mapRole', () {
    test('reconnaît les rôles du schéma', () {
      expect(mapRole('STUDENT'), UniFlowRole.student);
      expect(mapRole('DELEGATE'), UniFlowRole.delegate);
      expect(mapRole('TEACHER'), UniFlowRole.teacher);
      expect(mapRole('ADMIN'), UniFlowRole.admin);
    });

    test('reconnaît les formes françaises des anciens documents', () {
      expect(mapRole('ETUDIANT'), UniFlowRole.student);
      expect(mapRole('DELEGUE'), UniFlowRole.delegate);
      expect(mapRole('ENSEIGNANT'), UniFlowRole.teacher);
      expect(mapRole('ADMINISTRATEUR'), UniFlowRole.admin);
    });

    test('tolère la casse et les espaces', () {
      expect(mapRole('  admin '), UniFlowRole.admin);
    });

    test('un rôle illisible retombe sur le plus restreint', () {
      // Un rôle inconnu doit voir le moins de choses possible, pas empêcher
      // l'application de démarrer.
      expect(mapRole('SUPER_ROOT'), UniFlowRole.student);
      expect(mapRole(''), UniFlowRole.student);
      expect(mapRole(null), UniFlowRole.student);
    });
  });

  group('UniFlowRole', () {
    test('l\'encadrement est enseignant ou administrateur', () {
      expect(UniFlowRole.teacher.isStaff, isTrue);
      expect(UniFlowRole.admin.isStaff, isTrue);
      expect(UniFlowRole.student.isStaff, isFalse);
      expect(UniFlowRole.delegate.isStaff, isFalse);
    });

    test('le cursus est étudiant ou délégué', () {
      expect(UniFlowRole.student.isLearner, isTrue);
      expect(UniFlowRole.delegate.isLearner, isTrue);
      expect(UniFlowRole.teacher.isLearner, isFalse);
      expect(UniFlowRole.admin.isLearner, isFalse);
    });

    test('seul le délégué gère les présences', () {
      expect(UniFlowRole.delegate.isDelegate, isTrue);
      expect(UniFlowRole.student.isDelegate, isFalse);
    });

    test('chaque rôle porte un libellé lisible', () {
      for (final role in UniFlowRole.values) {
        expect(role.label, isNotEmpty);
      }
    });
  });

  group('table de navigation', () {
    test('aucune entrée n\'est ouverte à personne', () {
      // Un ensemble de rôles vide rendrait l'écran définitivement inaccessible.
      for (final destination in navDestinations) {
        expect(destination.roles, isNotEmpty,
            reason: '${destination.path} n\'autorise aucun rôle');
      }
    });

    test('aucun chemin n\'est déclaré deux fois', () {
      final chemins = navDestinations.map((d) => d.path).toList();
      expect(chemins.toSet().length, chemins.length);
    });

    test('la barre du bas reste courte, Réglages en dernier', () {
      // Six au pire (étudiant, enseignant, administrateur) : c'est ce que la
      // table déclare aujourd'hui, et le balayage de mise en page vérifie que
      // six onglets tiennent à 320 px sans débordement. Une septième entrée
      // devrait repasser par ce test.
      for (final role in UniFlowRole.values) {
        final barre = bottomBarFor(role);
        expect(barre.length, lessThanOrEqualTo(6), reason: 'pour $role');
        expect(barre.last.path, '/settings', reason: 'pour $role');
      }
    });

    test('la barre du bas n\'est jamais vide', () {
      for (final role in UniFlowRole.values) {
        expect(bottomBarFor(role), isNotEmpty, reason: 'pour $role');
      }
    });

    test('aucun onglet n\'apparaît deux fois après le passage de Réglages', () {
      for (final role in UniFlowRole.values) {
        final chemins = bottomBarFor(role).map((d) => d.path).toList();
        expect(chemins.toSet().length, chemins.length, reason: 'pour $role');
      }
    });

    test('barre et accès secondaires ne se recouvrent pas', () {
      for (final role in UniFlowRole.values) {
        final barre = bottomBarFor(role).map((d) => d.path).toSet();
        for (final secondaire in overflowFor(role)) {
          expect(barre.contains(secondaire.path), isFalse,
              reason: '${secondaire.path} est dans les deux pour $role');
        }
      }
    });

    test('tout écran autorisé reste atteignable', () {
      // Barre du bas plus accès secondaires doivent couvrir exactement ce que
      // le rôle a le droit de voir : rien ne doit disparaître faute de place.
      for (final role in UniFlowRole.values) {
        final atteignables = {
          ...bottomBarFor(role).map((d) => d.path),
          ...overflowFor(role).map((d) => d.path),
        };
        expect(atteignables, destinationsFor(role).map((d) => d.path).toSet(),
            reason: 'pour $role');
      }
    });
  });

  group('canAccessPath', () {
    test('l\'étudiant n\'atteint pas l\'annuaire complet', () {
      // Masquer l'onglet ne suffit pas : l'adresse reste tapable.
      expect(canAccessPath(UniFlowRole.student, '/etudiants'), isFalse);
      expect(canAccessPath(UniFlowRole.student, '/enseignants'), isFalse);
    });

    test('l\'enseignant n\'atteint pas les présences par QR', () {
      expect(canAccessPath(UniFlowRole.teacher, '/presence'), isFalse);
      expect(canAccessPath(UniFlowRole.delegate, '/presence'), isTrue);
    });

    test('un sous-chemin suit la règle de son parent', () {
      expect(canAccessPath(UniFlowRole.student, '/etudiants/u1'), isFalse);
      expect(canAccessPath(UniFlowRole.admin, '/etudiants/u1'), isTrue);
      expect(canAccessPath(UniFlowRole.student, '/ues/ue1'), isTrue);
    });

    test('les chemins hors table sont laissés au routeur', () {
      // `/login` et `/acces-refuse` ne figurent pas dans la table : c'est le
      // routeur qui décide, sans quoi la page de refus se refuserait elle-même.
      expect(canAccessPath(UniFlowRole.student, '/login'), isTrue);
      expect(canAccessPath(UniFlowRole.student, '/acces-refuse'), isTrue);
    });

    test('l\'administrateur ne suit pas de cursus', () {
      // L'administrateur n'est pas un super-étudiant : il gère les inscriptions
      // mais n'a ni « Mes cours » ni les présences par QR, qui n'ont pas de sens
      // pour lui. C'est la même règle que la barre latérale du web.
      expect(canAccessPath(UniFlowRole.admin, '/ues'), isFalse);
      expect(canAccessPath(UniFlowRole.admin, '/presence'), isFalse);
      expect(canAccessPath(UniFlowRole.admin, '/inscriptions'), isTrue);
    });

    test('chaque rôle atteint ce que la table lui ouvre, et rien d\'autre', () {
      for (final role in UniFlowRole.values) {
        for (final destination in navDestinations) {
          expect(canAccessPath(role, destination.path), destination.allows(role),
              reason: '${destination.path} pour $role');
        }
      }
    });
  });
}
