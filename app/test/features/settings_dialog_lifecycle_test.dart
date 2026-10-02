import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/features/settings/settings_sheet.dart';
import 'package:futuremint_app/state/app_controller.dart';
import 'package:provider/provider.dart';

import '../widget_test.dart' show createController;

Future<AppController> openSettings(WidgetTester tester, ThemeMode theme) async {
  final controller = await createController(
    mode: AppMode.authenticated,
    onDeleteAccount: (_) async =>
        throw const FormatException('測試密碼錯誤，未刪除任何帳號。'),
  );
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        themeMode: theme,
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsSheet(context),
              child: const Text('Settings'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> dismissDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, '取消').last);
  await finishDialogExit(tester);
}

Future<void> finishDialogExit(WidgetTester tester) async {
  await tester.pump();
  expect(tester.takeException(), isNull);
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(AlertDialog), findsNothing);
}

void main() {
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final save in [true, false]) {
      testWidgets(
        'budget dialog focused fields ${save ? 'save' : 'cancel'} (${theme.name})',
        (tester) async {
          final controller = await openSettings(tester, theme);
          final original = controller.profile!.monthlyBudgetMinor;
          await tester.ensureVisible(find.text('編輯預算與目標'));
          await tester.tap(find.text('編輯預算與目標'));
          await tester.pumpAndSettle();
          final fields = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          );
          await tester.enterText(fields.first, '3500');
          await tester.enterText(fields.last, '600');
          if (save) {
            await tester.tap(find.text('儲存設定'));
            await finishDialogExit(tester);
            expect(controller.profile!.monthlyBudgetMinor, 3500);
            expect(controller.profile!.goalSavedMinor, 600);
          } else {
            await dismissDialog(tester);
            expect(controller.profile!.monthlyBudgetMinor, original);
          }
        },
      );
    }
    for (final invalidAttempt in [false, true]) {
      testWidgets(
        'delete dialog cancels focused fields after invalid attempt $invalidAttempt (${theme.name})',
        (tester) async {
          final controller = await openSettings(tester, theme);
          await tester.ensureVisible(find.text('刪除帳號與資料'));
          await tester.tap(find.text('刪除帳號與資料'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('delete-account-password')),
            'invalid-synthetic-password',
          );
          if (invalidAttempt) {
            await tester.enterText(
              find.byKey(const Key('delete-account-confirmation')),
              '刪除帳號',
            );
            await tester.pump();
            await tester.tap(find.byKey(const Key('confirm-delete-account')));
            await tester.pumpAndSettle();
            expect(find.text('測試密碼錯誤，未刪除任何帳號。'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await dismissDialog(tester);
          expect(controller.profile, isNotNull);
        },
      );
    }
  }
}
