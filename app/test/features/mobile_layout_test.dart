import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';

import '../widget_test.dart';

void main() {
  const pages = ['首頁', '紀錄', '記一筆', '學習', '未來'];
  const headings = [
    '今天的金錢節奏',
    '分析優先的金錢時間軸',
    '快速記一筆',
    '三分鐘微課',
    'FutureSeed 教育模擬',
  ];

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('phone destinations lay out without overflow '
          '(${theme.name}, ${scale}x text)', (tester) async {
        final controller = await createController();
        controller.setThemeMode(theme);
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(FutureMintApp(controller: controller));
        await tester.pumpAndSettle();

        // Labels are hidden at large text, so tap destinations by position.
        for (var index = 0; index < pages.length; index++) {
          await tester.tap(find.byType(NavigationDestination).at(index));
          await tester.pumpAndSettle();
          expect(find.text(headings[index]), findsOne, reason: pages[index]);
          expect(tester.takeException(), isNull, reason: pages[index]);
        }
        expect(find.byKey(const Key('mobile-navigation-shell')), findsOne);
      });
    }
  }

  testWidgets('light budget Hero keeps light text on the indigo surface', (
    tester,
  ) async {
    final controller = await createController();
    controller.setThemeMode(ThemeMode.light);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    final hero = tester.widget<Container>(
      find.byKey(const Key('dashboard-budget-hero')),
    );
    final decoration = hero.decoration! as BoxDecoration;
    expect(decoration.gradient, isNotNull);
    expect(decoration.color, isNull);
    expect(tester.takeException(), isNull);
  });
}
