import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';

import '../widget_test.dart';

void main() {
  testWidgets('opens the investment lab and completes a virtual buy', (
    tester,
  ) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未來').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('進入投資練習場'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('進入投資練習場'));
    await tester.pumpAndSettle();

    expect(find.text('用虛擬資金，練習真實的投資決策'), findsOneWidget);
    expect(
      find.byKey(const Key('investment-lab-portfolio-hero')),
      findsOneWidget,
    );
    expect(find.textContaining('內建教育快照'), findsOneWidget);
    expect(find.text('市場事件骰子'), findsOneWidget);
    expect(
      find.byKey(const Key('investment-lab-compact-layout')),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('確認虛擬買入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認虛擬買入'));
    await tester.pumpAndSettle();

    expect(controller.investmentLab?.orders, hasLength(1));
    expect(controller.investmentLab?.holdings.single.symbol, '0050');
    expect(controller.investmentLab?.holdings.single.quantity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the investment lab usable at 200% text scale', (
    tester,
  ) async {
    final controller = await createController();
    await controller.loadInvestmentLab();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未來').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('進入投資練習場'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('進入投資練習場'));
    await tester.pumpAndSettle();

    expect(find.text('虛擬總資產'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
