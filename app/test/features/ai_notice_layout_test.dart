import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/core/models.dart';

import '../widget_test.dart';

void main() {
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('AI notice remains readable and opens disclosure '
          '(${theme.name}, ${scale}x text)', (tester) async {
        final controller = await createController(mode: AppMode.authenticated);
        controller.setThemeMode(theme);
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(FutureMintApp(controller: controller));
        await tester.pumpAndSettle();
        final notice = tester.getRect(
          find.byKey(const Key('ai-consent-notice')),
        );
        final action = find.widgetWithText(TextButton, '查看資料用途');
        final actionRect = tester.getRect(action);
        expect(actionRect.height, greaterThanOrEqualTo(48));
        expect(notice.contains(actionRect.topLeft), isTrue);
        expect(notice.contains(actionRect.bottomRight), isTrue);
        expect(find.text('手動功能照常使用'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('啟用 AI 前的資料說明'), findsOneWidget);
        await tester.ensureVisible(find.text('暫不啟用'));
        await tester.tap(find.text('暫不啟用'));
        await tester.pumpAndSettle();
        expect(controller.aiConsent.granted, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
