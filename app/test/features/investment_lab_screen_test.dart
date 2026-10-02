import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/app/future_mint_app.dart';
import 'package:futuremint_app/core/models.dart';
import 'package:futuremint_app/data/demo_repository.dart';
import 'package:futuremint_app/features/future_seed/investment_lab_screen.dart';
import 'package:provider/provider.dart';

import '../widget_test.dart';

class ChangingQuoteRepository extends GuestRepository {
  ChangingQuoteRepository(this.profile) : super.transient();
  final UserProfile profile;

  @override
  Future<UserProfile> getProfile() async => profile;
  bool fail = false;
  VirtualInvestmentOrder? saved;

  @override
  Future<InvestmentLab> getInvestmentLab() async {
    final base = await super.getInvestmentLab();
    final current = saved;
    final quotes = base.market.quotes
        .map(
          (quote) => MarketQuote.fromJson({
            ...quote.toJson(),
            'price': quote.symbol == '0050'
                ? (current == null ? 104.4 : 112.9)
                : quote.price,
            'asOf': current == null ? '2026-07-14' : '2026-10-01',
            'source': current == null ? 'educational-snapshot' : 'twse-openapi',
          }),
        )
        .toList();
    return InvestmentLab(
      startingCashMinor: base.startingCashMinor,
      cashMinor: base.cashMinor,
      marketValueMinor: base.marketValueMinor,
      totalAssetMinor: base.totalAssetMinor,
      gainLossMinor: base.gainLossMinor,
      returnPercent: base.returnPercent,
      diversificationScore: base.diversificationScore,
      learningSummary: base.learningSummary,
      holdings: base.holdings,
      orders: current == null ? [] : [current],
      market: MarketSnapshot(
        quotes: quotes,
        fetchedAt: base.market.fetchedAt,
        source: quotes.first.source,
        sourceLabel: 'Synthetic market',
        sourceUrl: base.market.sourceUrl,
        isFallback: current == null,
        disclaimer: base.market.disclaimer,
      ),
      disclaimer: base.disclaimer,
    );
  }

  @override
  Future<InvestmentLab> placeInvestmentOrder({
    required String symbol,
    required InvestmentOrderSide side,
    required int quantity,
    required String idempotencyKey,
  }) async {
    if (fail) throw const FormatException('合成測試：訂單未保存。');
    saved ??= VirtualInvestmentOrder(
      id: 'server-order-1',
      symbol: symbol,
      name: 'Synthetic ETF',
      side: side,
      quantity: quantity,
      unitPrice: 112.9,
      totalMinor: (112.9 * quantity).round(),
      quoteAsOf: DateTime(2026, 10, 1),
      quoteSource: MarketQuoteSource.twseOpenapi,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime(2026, 10, 2),
    );
    return getInvestmentLab();
  }
}

void main() {
  testWidgets(
    'shows server execution when the displayed quote changes and does not misreport failures',
    (tester) async {
      final controller = await createController();
      final repository = ChangingQuoteRepository(controller.profile!);
      controller.repository = repository;
      await controller.loadInvestmentLab();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: Scaffold(body: InvestmentLabScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.investmentLab!.market.quotes.first.price, 104.4);
      expect(find.textContaining('畫面金額為預估；送出時以伺服器'), findsOneWidget);
      await tester.ensureVisible(find.text('確認虛擬買入'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認虛擬買入'));
      await tester.pumpAndSettle();
      final result = find.byKey(const Key('investment-lab-order-result'));
      expect(result, findsOneWidget);
      expect(
        find.descendant(of: result, matching: find.textContaining('行情已更新')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: result,
          matching: find.textContaining('單價 NT\$112.90'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: result,
          matching: find.textContaining('資料日 2026-10-01'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // A repeated response containing only a known order must not announce a
      // second successful execution.
      await tester.ensureVisible(find.text('確認虛擬買入'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認虛擬買入'));
      await tester.pumpAndSettle();
      expect(result, findsNothing);

      repository.fail = true;
      await tester.tap(find.text('確認虛擬買入'));
      await tester.pumpAndSettle();
      expect(controller.errorMessage, '合成測試：訂單未保存。');
      expect(result, findsNothing);
      expect(controller.investmentLab!.orders, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

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

    expect(find.text('用虛擬資金練習投資決策'), findsOneWidget);
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
