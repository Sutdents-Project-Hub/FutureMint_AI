import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/features/subscriptions/subscription_editor.dart';
import 'package:futuremint_app/state/app_controller.dart';

import '../widget_test.dart' show createController;

Future<AppController> openEditor(WidgetTester tester) async {
  final controller = await createController();
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSubscriptionEditor(context, controller),
            child: const Text('Open subscription'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open subscription'));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> fillSubscription(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'NETFLIX QA');
  await tester.enterText(find.byType(TextFormField).at(1), '120');
  await tester.ensureVisible(find.text('確認儲存'));
}

Future<void> finishExit(WidgetTester tester) async {
  // Observe intermediate frames as well as the settled route. A popped sheet
  // remains mounted during its reverse transition.
  await tester.pump();
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(TextFormField), findsNothing);
}

void main() {
  for (final validateFirst in [false, true]) {
    testWidgets('subscription saves and exits with focused fields '
        '(validate first: $validateFirst)', (tester) async {
      final controller = await openEditor(tester);
      final originalEvents = controller.events.length;
      if (validateFirst) {
        await tester.ensureVisible(find.text('確認儲存'));
        await tester.tap(find.text('確認儲存'));
        await tester.pumpAndSettle();
        expect(find.text('請填入名稱。'), findsOneWidget);
        expect(find.text('請填入正確金額。'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await fillSubscription(tester);
      await tester.tap(find.text('確認儲存'));
      await finishExit(tester);
      final saved = controller.subscriptions.items.singleWhere(
        (item) => item.name == 'NETFLIX QA',
      );
      expect(saved.amountMinor, 120);
      expect(controller.events.length, originalEvents);
      // Reopening proves the editor still has working controller ownership.
      await tester.tap(find.text('Open subscription'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelling a focused sheet exits without saving', (
    tester,
  ) async {
    final controller = await openEditor(tester);
    final originalCount = controller.subscriptions.items.length;
    await fillSubscription(tester);
    Navigator.of(tester.element(find.byType(TextFormField).first)).pop();
    await finishExit(tester);
    expect(controller.subscriptions.items.length, originalCount);
  });
}
