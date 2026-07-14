import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/features/capture/draft_editor.dart';

import '../widget_test.dart';

void main() {
  testWidgets('capture stays a draft until the user confirms it', (
    tester,
  ) async {
    final controller = await createController();
    final initialCount = controller.events.length;
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('記一筆').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capture-hero')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('capture-input')), '今天買珍奶 75');
    await tester.tap(find.text('幫我整理'));
    await tester.pumpAndSettle();

    expect(find.text('確認草稿'), findsOneWidget);
    expect(find.byKey(const Key('capture-draft-focus')), findsOneWidget);
    expect(find.textContaining('離線規則'), findsOneWidget);
    expect(find.bySemanticsLabel('AI 已整理草稿，尚未保存'), findsOneWidget);
    expect(controller.events.length, initialCount);

    await tester.ensureVisible(find.text('確認並記下'));
    await tester.tap(find.text('確認並記下'));
    await tester.pumpAndSettle();
    expect(controller.events.length, initialCount + 1);
  });

  testWidgets('capture remains usable on a narrow phone', (tester) async {
    final controller = await createController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('記一筆').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capture-input')), findsOneWidget);
    expect(find.text('今天買珍奶 75'), findsOneWidget);
    expect(find.text('打工薪水 1500'), findsOneWidget);
    expect(find.text('Netflix 390 四個人分'), findsOneWidget);
    expect(find.text('幫我整理'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subscription draft exposes date, cycle, and split arithmetic', (
    tester,
  ) async {
    final controller = await createController();
    await tester.pumpWidget(FutureMintApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('記一筆').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('capture-input')),
      'Netflix 390 四個人分',
    );
    await tester.tap(find.text('幫我整理'));
    await tester.pumpAndSettle();

    expect(find.text('交易類型'), findsOneWidget);
    expect(find.text('發生日期'), findsOneWidget);
    expect(find.text('計費週期'), findsOneWidget);
    expect(find.text('分帳人數'), findsOneWidget);
    expect(find.textContaining('NT\$ 98'), findsOneWidget);
  });

  testWidgets('defensively normalizes a contradictory AI draft', (
    tester,
  ) async {
    final draft = CaptureDraft(
      draftId: 'contradictory-ai',
      type: MoneyEventType.expense,
      amountMinor: 1500,
      currency: 'TWD',
      category: MoneyCategory.income,
      occurredAt: DateTime.parse('2026-07-13T12:00:00+08:00'),
      confidence: 0.8,
      missingFields: const [],
      needsConfirmation: true,
      source: CaptureSource.azureAi,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DraftEditor(draft: draft, busy: false, onConfirm: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('其他'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
