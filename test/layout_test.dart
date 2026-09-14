// Test de mise en page.
//
// Il ne vérifie pas des valeurs mais **l'absence de débordement** : chaque écran
// est peint à plusieurs largeurs, et Flutter échoue le test dès qu'un `Row` ou
// une `Column` ne rentre pas dans la place disponible (« A RenderFlex
// overflowed by N pixels »).
//
// C'est ce test qui aurait attrapé le débordement observé en usage réel : les
// écrans étaient corrects sur une largeur de téléphone courante, mais
// débordaient de quelques pixels sur une fenêtre plus étroite ou avec une police
// agrandie.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:uniflow_mobile/screens/assignments.dart';
import 'package:uniflow_mobile/screens/dashboard.dart';
import 'package:uniflow_mobile/screens/enrollments.dart';
import 'package:uniflow_mobile/screens/grades.dart';
import 'package:uniflow_mobile/screens/help.dart';
import 'package:uniflow_mobile/screens/library.dart';
import 'package:uniflow_mobile/screens/login.dart';
import 'package:uniflow_mobile/screens/presence.dart';
import 'package:uniflow_mobile/screens/sentinelle.dart';
import 'package:uniflow_mobile/screens/settings.dart';
import 'package:uniflow_mobile/screens/students_list.dart';
import 'package:uniflow_mobile/screens/teachers_list.dart';
import 'package:uniflow_mobile/screens/teams.dart';
import 'package:uniflow_mobile/screens/ues_list.dart';

import 'layout_test_support.dart';

/// Largeurs balayées : d'un petit téléphone (320) à une fenêtre de bureau
/// étroite, en passant par les tailles Android courantes.
const List<Size> _sizes = [
  Size(320, 568), // petit téléphone
  Size(360, 640), // Android courant
  Size(411, 731), // Pixel
  Size(600, 900), // tablette portrait
  Size(900, 700), // fenêtre redimensionnée / paysage
];

/// Le texte est agrandi sur l'un des passages : un utilisateur qui règle la
/// taille de police du système ne doit pas faire déborder les écrans.
const List<double> _textScales = [1.0, 1.3];

void main() {
  // `google_fonts` tente de télécharger Inter au premier rendu ; en test il n'y
  // a pas de réseau, et l'échec produirait une erreur sans rapport avec ce que
  // l'on vérifie ici.
  GoogleFonts.config.allowRuntimeFetching = false;

  /// Les écrans testés, avec leur nom pour le message d'échec.
  final screens = <String, Widget>{
    'Login': const LoginScreen(),
    'Dashboard': const DashboardScreen(),
    'Étudiants': const StudentsListScreen(),
    'Enseignants': const TeachersListScreen(),
    'UEs': const UEsListScreen(),
    'Inscriptions': const EnrollmentsScreen(),
    'Présence': const PresenceScreen(),
    'Notes': const GradesScreen(),
    'Devoirs': const AssignmentsScreen(),
    'Bibliothèque': const LibraryScreen(),
    'Équipe': const TeamsScreen(),
    'Aide': const HelpScreen(),
    'Sentinelle': const SentinelleScreen(),
    'Réglages': const SettingsScreen(),
  };

  for (final entry in screens.entries) {
    for (final size in _sizes) {
      for (final scale in _textScales) {
        testWidgets(
          '${entry.key} ne déborde pas en ${size.width.toInt()}×${size.height.toInt()} '
          '(texte ×$scale)',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
                child: host(entry.value),
              ),
            );
            // Deux passes : la première construit l'arbre, la seconde peint —
            // c'est à la peinture que Flutter signale un débordement.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
