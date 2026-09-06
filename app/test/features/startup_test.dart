import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/main.dart';
import 'package:futuremint_app/state/session_controller.dart';

void main() {
  testWidgets(
    'startup failures render a retry action without exposing error details',
    (tester) async {
      var attempts = 0;
      Future<SessionController> failStartup() async {
        attempts++;
        throw StateError('private platform error detail');
      }

      await tester.pumpWidget(FutureMintBootstrap(sessionFactory: failStartup));
      await tester.pumpAndSettle();
      expect(find.textContaining('目前無法啟動 FutureMint'), findsOneWidget);
      expect(find.textContaining('private platform'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, '重新嘗試'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
