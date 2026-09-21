// Le bouton d'Uni ne recouvre aucune commande, sur aucune page.
//
// Constat du propriétaire (2026-09-21) : posé au même endroit partout, le
// bouton flottant d'Uni cachait le bouton « Nouvelle conversation » de la
// messagerie et le bouton d'envoi d'une conversation. Chaque page déclare
// désormais ce qu'elle pose en bas de l'écran (`shell_pages.dart`) et la
// coquille en déduit où accrocher Uni.
//
// Ce test rend la déclaration obligatoire de fait : il monte **chaque page de
// la table**, pour **chaque rôle** (le même écran change de contenu selon le
// rôle) et à deux largeurs de téléphone, puis vérifie que le rectangle d'Uni
// ne croise aucune commande — d'abord les commandes fixes (boutons flottants,
// composeurs, barres du bas), puis les commandes des listes une fois celles-ci
// déroulées jusqu'au bout. Une page ajoutée avec un bouton flottant sans
// déclaration échoue ici avant d'atteindre un téléphone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:uniflow_mobile/models/user_role.dart';
import 'package:uniflow_mobile/router/shell_pages.dart';
import 'package:uniflow_mobile/theme/app_theme.dart';
import 'package:uniflow_mobile/widgets/app_shell.dart';
import 'package:uniflow_mobile/widgets/uni/uni_assistant.dart';

import 'layout_test_support.dart';

/// Deux largeurs de téléphone : c'est sur la plus étroite qu'un bouton
/// flottant étendu et Uni se disputent le plus la place.
const List<Size> _sizes = [Size(360, 640), Size(411, 731)];

/// Les commandes qu'Uni ne doit pas recouvrir. Les tuiles de liste (`InkWell`,
/// `ListTile`) n'y sont pas : elles restent atteignables par le reste de leur
/// surface, et les lister ferait échouer toute page dont la liste finit sous
/// le bouton.
final List<Type> _controlTypes = [
  FloatingActionButton,
  IconButton,
  TextField,
  FilledButton,
  ElevatedButton,
  OutlinedButton,
  TextButton,
  Switch,
  Checkbox,
];

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('table des pages', () {
    test('reconnaît une adresse concrète, paramètres compris', () {
      expect(shellPageFor('/messages')!.path, '/messages');
      expect(shellPageFor('/messages/abc123')!.path, '/messages/:id');
      expect(shellPageFor('/acces-refuse?depuis=%2Fcomptes')!.path, '/acces-refuse');
      expect(shellPageFor('/inconnue'), isNull);
      expect(shellPageFor('/messages/'), isNull, reason: 'un segment vide ne vaut pas un identifiant');
    });

    test('la conversation efface Uni, la messagerie le perche au-dessus du bouton', () {
      expect(bottomEdgeAt('/messages/abc', UniFlowRole.student), BottomEdge.composer);
      expect(bottomEdgeAt('/messages', UniFlowRole.student), BottomEdge.fab);
      expect(bottomEdgeAt('/accueil', UniFlowRole.student), BottomEdge.free);
      // Même adresse, deux métiers : seul l'enseignant publie depuis un bouton.
      expect(bottomEdgeAt('/devoirs', UniFlowRole.teacher), BottomEdge.fab);
      expect(bottomEdgeAt('/devoirs', UniFlowRole.student), BottomEdge.free);
      expect(bottomEdgeAt('/nulle-part', UniFlowRole.student), BottomEdge.free);
    });

    test('chaque motif produit une adresse d\'exemple qui se reconnaît elle-même', () {
      for (final page in shellPages) {
        expect(page.matches(page.samplePath), isTrue, reason: page.path);
        expect(page.samplePath.contains(':'), isFalse, reason: '${page.path} : paramètre d\'exemple manquant');
      }
    });

    test('l\'ancrage suit le bord déclaré', () {
      expect(uniDockFor(BottomEdge.free), UniDock.right);
      expect(uniDockFor(BottomEdge.fab), UniDock.left);
      expect(uniDockFor(BottomEdge.composer), UniDock.hidden);
      // Un bouton flottant Material (56 pt à 16 pt du bord droit) : Uni doit
      // finir à sa gauche, sans le toucher, même sur un petit écran.
      expect(UniDock.left.leftIn(320) + UniLauncher.size, lessThan(320 - 16 - 56));
      expect(UniDock.right.leftIn(320), 320 - UniDock.edgeInset - UniLauncher.size);
    });

    test('la marge basse des listes couvre Uni et un bouton flottant', () {
      expect(uniClearance, greaterThanOrEqualTo(UniDock.bottomInset + UniLauncher.size + 8));
      expect(uniClearance, greaterThanOrEqualTo(16 + 56 + 8));
      expect(AppInsets.pageList.bottom, uniClearance);
    });
  });

  for (final page in shellPages) {
    for (final role in UniFlowRole.values) {
      for (final size in _sizes) {
        testWidgets(
          'Uni ne recouvre aucune commande sur ${page.samplePath} (${role.label}, ${size.width.toInt()} pt)',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(_hostShell(page, role));
            // Deux passes : la première construit, la seconde laisse les
            // providers neutralisés livrer leurs valeurs et peint.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.takeException(), isNull);

            final launcher = find.byType(UniLauncher);
            if (page.bottomEdgeFor(role) == BottomEdge.composer) {
              expect(launcher, findsNothing, reason: 'un composeur occupe tout le bord inférieur');
              return;
            }
            expect(launcher, findsOneWidget);
            final uniRect = tester.getRect(launcher);
            expect(uniRect.bottom, lessThanOrEqualTo(size.height), reason: 'le bouton doit rester dans l\'écran');

            // 1. Commandes fixes : celles qui ne défilent pas.
            expect(_controlsUnder(tester, uniRect, includeScrolling: false), isEmpty,
                reason: 'une commande fixe est sous Uni ; déclarer le bord inférieur de la page dans shell_pages.dart');

            // 2. Commandes des listes, une fois chaque liste déroulée au bout :
            // c'est là que la dernière ligne se retrouve sous le bouton si la
            // liste n'a pas de marge basse.
            for (final scrollable in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
              if (scrollable.position.axis != Axis.vertical || !scrollable.position.hasContentDimensions) continue;
              scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expect(_controlsUnder(tester, uniRect, includeScrolling: true), isEmpty,
                reason: 'une commande de liste finit sous Uni ; donner à la liste une marge basse (uniClearance)');
          },
        );
      }
    }
  }
}

/// La coquille entière autour de [page], comme en production : c'est elle qui
/// place Uni, il faut donc la monter plutôt que l'écran seul.
Widget _hostShell(ShellPage page, UniFlowRole role) {
  return ProviderScope(
    overrides: neutralOverrides(connectedUser: userWithRole(role)),
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: AppShell(location: page.samplePath, child: page.builder(page.sampleArgs)),
    ),
  );
}

/// Les commandes dont le rectangle croise [uniRect], décrites pour le message
/// d'échec. Sans [includeScrolling], celles qui vivent dans un `Scrollable`
/// sont ignorées : elles ne sont pas encore à leur place définitive.
List<String> _controlsUnder(WidgetTester tester, Rect uniRect, {required bool includeScrolling}) {
  final found = <String>[];
  for (final type in _controlTypes) {
    for (final element in find.byType(type).evaluate()) {
      // La pastille d'Uni contient ses propres widgets ; ils ne comptent pas.
      if (find
          .ancestor(of: find.byElementPredicate((e) => e == element), matching: find.byType(UniLauncher))
          .evaluate()
          .isNotEmpty) {
        continue;
      }
      if (!includeScrolling &&
          find
              .ancestor(of: find.byElementPredicate((e) => e == element), matching: find.byType(Scrollable))
              .evaluate()
              .isNotEmpty) {
        continue;
      }
      final box = element.renderObject;
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.overlaps(uniRect)) {
        found.add('$type à ${rect.toString()} (Uni : $uniRect)');
      }
    }
  }
  return found;
}
