import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uniflow_mobile/main.dart';

void main() {
  testWidgets('shows login screen first', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: UniFlowApp()));
    await tester.pump();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
