import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../state/app_controller.dart';

class InvestmentLabScreen extends StatefulWidget {
  const InvestmentLabScreen({super.key});

  @override
  State<InvestmentLabScreen> createState() => _InvestmentLabScreenState();
}

class _InvestmentLabScreenState extends State<InvestmentLabScreen> {
  final quantityController = TextEditingController(text: '1');
  String selectedSymbol = '0050';
  InvestmentOrderSide side = InvestmentOrderSide.buy;
  String? quantityError;
  bool requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (requested) return;
    requested = true;
    final controller = context.read<AppController>();
    if (controller.investmentLab == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.loadInvestmentLab();
      });
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  int? get quantity => int.tryParse(quantityController.text.trim());

  Future<void> _submitOrder(AppController controller, MarketQuote quote) async {
    final value = quantity;
    if (value == null || value < 1 || value > 1000) {
      setState(() => quantityError = '請輸入 1 到 1000 之間的整數。');
      return;
    }
    setState(() => quantityError = null);
    await controller.placeInvestmentOrder(
      symbol: quote.symbol,
      side: side,
      quantity: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final lab = controller.investmentLab;
    final gutter = FutureMintTokens.pageGutter(context);
    return SingleChildScrollView(
      key: const Key('investment-lab-scroll'),
      padding: EdgeInsets.fromLTRB(
        gutter,
        FutureMintTokens.space5,
        gutter,
        FutureMintTokens.space7,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FutureMintTokens.contentCanvas,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeading(
                kicker: 'FutureSeed 投資練習場',
                title: '用虛擬資金，練習真實的投資決策',
                description: '使用盤後行情練習買賣、配置與面對波動；不連券商、不使用真錢，也不提供選股建議。',
                accent: FutureMintTokens.teal,
                trailing: TextButton.icon(
                  onPressed: () => context.go('/future-seed'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('回到長期比較'),
                ),
              ),
              const SizedBox(height: FutureMintTokens.space5),
              if (lab == null)
                _LoadingState(
                  busy: controller.busy,
                  onRetry: controller.busy
                      ? null
                      : controller.loadInvestmentLab,
                )
              else ...[
                _PortfolioHero(lab: lab),
                const SizedBox(height: FutureMintTokens.space3),
                _MarketSourceStrip(market: lab.market),
                const SizedBox(height: FutureMintTokens.space5),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final selected = lab.market.quotes.firstWhere(
                      (quote) => quote.symbol == selectedSymbol,
                      orElse: () => lab.market.quotes.first,
                    );
                    final market = _MarketList(
                      quotes: lab.market.quotes,
                      selectedSymbol: selected.symbol,
                      onSelected: controller.busy
                          ? null
                          : (symbol) => setState(() => selectedSymbol = symbol),
                    );
                    final order = _OrderPanel(
                      lab: lab,
                      quote: selected,
                      side: side,
                      quantityController: quantityController,
                      quantityError: quantityError,
                      busy: controller.busy,
                      onSideChanged: (value) => setState(() => side = value),
                      onQuantityChanged: () => setState(() {
                        quantityError = null;
                      }),
                      onSubmit: () => _submitOrder(controller, selected),
                    );
                    if (constraints.maxWidth >= 820) {
                      return Row(
                        key: const Key('investment-lab-wide-layout'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: market),
                          const SizedBox(width: FutureMintTokens.space5),
                          SizedBox(width: 340, child: order),
                        ],
                      );
                    }
                    return Column(
                      key: const Key('investment-lab-compact-layout'),
                      children: [
                        market,
                        const SizedBox(height: FutureMintTokens.space4),
                        order,
                      ],
                    );
                  },
                ),
                const SizedBox(height: FutureMintTokens.space5),
                _HoldingsSection(lab: lab),
                const SizedBox(height: FutureMintTokens.space5),
                _PracticeEventCard(
                  event: controller.practiceDiceEvent,
                  reply: controller.coachReply,
                  busy: controller.busy,
                  onRoll: controller.rollInvestmentDice,
                  onAsk: controller.practiceDiceEvent == null
                      ? null
                      : () => controller.askCoach(
                          topic: 'risk',
                          question: controller.practiceDiceEvent!.coachQuestion,
                        ),
                ),
                const SizedBox(height: FutureMintTokens.space5),
                _OrderHistory(orders: lab.orders),
                const SizedBox(height: FutureMintTokens.space4),
                Text(
                  lab.disclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.busy, required this.onRetry});

  final bool busy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      children: [
        if (busy)
          const CircularProgressIndicator()
        else
          const Icon(Icons.cloud_off_outlined, size: 44),
        const SizedBox(height: FutureMintTokens.space4),
        Text(
          busy ? '正在取得盤後行情與虛擬帳戶…' : '目前無法載入投資練習場。',
          textAlign: TextAlign.center,
        ),
        if (!busy) ...[
          const SizedBox(height: FutureMintTokens.space4),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新載入'),
          ),
        ],
      ],
    ),
  );
}

class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({required this.lab});

  final InvestmentLab lab;

  @override
  Widget build(BuildContext context) {
    final positive = lab.gainLossMinor >= 0;
    return SoftCard(
      key: const Key('investment-lab-portfolio-hero'),
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : FutureMintTokens.mintSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '虛擬總資產',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            formatTwd(lab.totalAssetMinor),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            '${positive ? '+' : ''}${formatTwd(lab.gainLossMinor)} '
            '(${positive ? '+' : ''}${lab.returnPercent.toStringAsFixed(2)}%)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: positive
                  ? FutureMintTokens.positive
                  : FutureMintTokens.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: FutureMintTokens.space5),
          Wrap(
            spacing: FutureMintTokens.space5,
            runSpacing: FutureMintTokens.space3,
            children: [
              _HeroMetric(label: '虛擬現金', value: formatTwd(lab.cashMinor)),
              _HeroMetric(
                label: '持有市值',
                value: formatTwd(lab.marketValueMinor),
              ),
              _HeroMetric(
                label: '起始練習金',
                value: formatTwd(lab.startingCashMinor),
              ),
              _HeroMetric(
                label: '分散練習分數',
                value: '${lab.diversificationScore} / 100',
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space4),
          Text(lab.learningSummary),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: FutureMintTokens.space1),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _MarketSourceStrip extends StatelessWidget {
  const _MarketSourceStrip({required this.market});

  final MarketSnapshot market;

  @override
  Widget build(BuildContext context) {
    final asOf = market.quotes.isEmpty
        ? '無資料日'
        : market.quotes.first.asOf.toIso8601String().split('T').first;
    return Semantics(
      label: '${market.sourceLabel}，資料日 $asOf',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FutureMintTokens.space4,
          vertical: FutureMintTokens.space3,
        ),
        decoration: BoxDecoration(
          color: market.isFallback
              ? FutureMintTokens.sunSoft
              : FutureMintTokens.skySoft,
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusSmall),
        ),
        child: Wrap(
          spacing: FutureMintTokens.space2,
          runSpacing: FutureMintTokens.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              market.isFallback
                  ? Icons.info_outline_rounded
                  : Icons.schedule_rounded,
              size: 20,
              color: FutureMintTokens.ink,
            ),
            Text(
              '${market.sourceLabel} · 資料日 $asOf',
              style: const TextStyle(
                color: FutureMintTokens.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              market.isFallback ? '目前為備援快照' : '盤後資料，非即時',
              style: const TextStyle(color: FutureMintTokens.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketList extends StatelessWidget {
  const _MarketList({
    required this.quotes,
    required this.selectedSymbol,
    required this.onSelected,
  });

  final List<MarketQuote> quotes;
  final String selectedSymbol;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) => SoftCard(
    key: const Key('investment-lab-market-list'),
    borderWidth: 1,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: FutureMintTokens.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('市場觀察範例', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: FutureMintTokens.space1),
              Text(
                '依產業多樣性選出的教學範例，不代表推薦或排名。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        for (var index = 0; index < quotes.length; index++) ...[
          if (index > 0)
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          _QuoteRow(
            quote: quotes[index],
            selected: quotes[index].symbol == selectedSymbol,
            onTap: onSelected == null
                ? null
                : () => onSelected!(quotes[index].symbol),
          ),
        ],
      ],
    ),
  );
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.quote,
    required this.selected,
    required this.onTap,
  });

  final MarketQuote quote;
  final bool selected;
  final VoidCallback? onTap;

  String _price(double value) =>
      'NT\$${NumberFormat('#,##0.00', 'zh_TW').format(value)}';

  @override
  Widget build(BuildContext context) {
    final changeColor = quote.change >= 0
        ? FutureMintTokens.positive
        : FutureMintTokens.danger;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${quote.symbol} ${quote.name}，盤後價 ${_price(quote.price)}',
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(FutureMintTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (MediaQuery.textScalerOf(context).scale(1) >= 1.5)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check_circle_rounded, size: 20),
                            const SizedBox(width: FutureMintTokens.space2),
                          ],
                          Expanded(
                            child: Text(
                              '${quote.symbol}  ${quote.name}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: FutureMintTokens.space2),
                      Text(
                        _price(quote.price),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: FutureMintTokens.space3,
                    runSpacing: FutureMintTokens.space2,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check_circle_rounded, size: 20),
                            const SizedBox(width: FutureMintTokens.space2),
                          ],
                          Text(
                            '${quote.symbol}  ${quote.name}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Text(
                        _price(quote.price),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  ),
                const SizedBox(height: FutureMintTokens.space2),
                Wrap(
                  spacing: FutureMintTokens.space3,
                  runSpacing: FutureMintTokens.space1,
                  children: [
                    Text(quote.sector),
                    Text(
                      '${quote.change >= 0 ? '+' : ''}${quote.change.toStringAsFixed(2)} '
                      '(${quote.changePercent.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        color: changeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.lab,
    required this.quote,
    required this.side,
    required this.quantityController,
    required this.quantityError,
    required this.busy,
    required this.onSideChanged,
    required this.onQuantityChanged,
    required this.onSubmit,
  });

  final InvestmentLab lab;
  final MarketQuote quote;
  final InvestmentOrderSide side;
  final TextEditingController quantityController;
  final String? quantityError;
  final bool busy;
  final ValueChanged<InvestmentOrderSide> onSideChanged;
  final VoidCallback onQuantityChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final quantity = int.tryParse(quantityController.text) ?? 0;
    final estimate = (quote.price * quantity).round();
    final owned = lab.holdings
        .where((holding) => holding.symbol == quote.symbol)
        .fold<int>(0, (sum, holding) => sum + holding.quantity);
    return SoftCard(
      key: const Key('investment-lab-order-panel'),
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : FutureMintTokens.skySoft,
      borderWidth: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('虛擬下單', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: FutureMintTokens.space2),
          Text('${quote.symbol} ${quote.name} · ${quote.sector}'),
          const SizedBox(height: FutureMintTokens.space4),
          if (MediaQuery.textScalerOf(context).scale(1) >= 1.5)
            Wrap(
              spacing: FutureMintTokens.space2,
              runSpacing: FutureMintTokens.space2,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.add_chart_rounded),
                  label: const Text('買入'),
                  selected: side == InvestmentOrderSide.buy,
                  onSelected: busy
                      ? null
                      : (_) => onSideChanged(InvestmentOrderSide.buy),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.sell_outlined),
                  label: const Text('賣出'),
                  selected: side == InvestmentOrderSide.sell,
                  onSelected: busy
                      ? null
                      : (_) => onSideChanged(InvestmentOrderSide.sell),
                ),
              ],
            )
          else
            SegmentedButton<InvestmentOrderSide>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: InvestmentOrderSide.buy,
                  icon: Icon(Icons.add_chart_rounded),
                  label: Text('買入'),
                ),
                ButtonSegment(
                  value: InvestmentOrderSide.sell,
                  icon: Icon(Icons.sell_outlined),
                  label: Text('賣出'),
                ),
              ],
              selected: {side},
              onSelectionChanged: busy
                  ? null
                  : (values) => onSideChanged(values.first),
            ),
          const SizedBox(height: FutureMintTokens.space4),
          Text('數量', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: FutureMintTokens.space2),
          Row(
            children: [
              IconButton.outlined(
                tooltip: '減少一股',
                onPressed: busy
                    ? null
                    : () {
                        final current =
                            int.tryParse(quantityController.text) ?? 1;
                        quantityController.text = maxInt(
                          1,
                          current - 1,
                        ).toString();
                        onQuantityChanged();
                      },
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: FutureMintTokens.space2),
              Expanded(
                child: TextField(
                  controller: quantityController,
                  enabled: !busy,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onQuantityChanged(),
                  decoration: const InputDecoration(labelText: '虛擬股數'),
                ),
              ),
              const SizedBox(width: FutureMintTokens.space2),
              IconButton.outlined(
                tooltip: '增加一股',
                onPressed: busy
                    ? null
                    : () {
                        final current =
                            int.tryParse(quantityController.text) ?? 0;
                        quantityController.text = (current + 1).toString();
                        onQuantityChanged();
                      },
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (quantityError != null) ...[
            const SizedBox(height: FutureMintTokens.space2),
            Text(
              quantityError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: FutureMintTokens.space4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: FutureMintTokens.space3,
            runSpacing: FutureMintTokens.space2,
            children: [
              Text(side == InvestmentOrderSide.buy ? '預估使用' : '預估收回'),
              Text(
                formatTwd(estimate),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            side == InvestmentOrderSide.buy
                ? '可用虛擬現金 ${formatTwd(lab.cashMinor)}'
                : '目前持有 $owned 股',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: FutureMintTokens.space4),
          FilledButton.icon(
            onPressed: busy ? null : onSubmit,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    side == InvestmentOrderSide.buy
                        ? Icons.add_chart_rounded
                        : Icons.sell_outlined,
                  ),
            label: Text(side == InvestmentOrderSide.buy ? '確認虛擬買入' : '確認虛擬賣出'),
          ),
          const SizedBox(height: FutureMintTokens.space3),
          Text(
            '成交價採畫面所示盤後價；本練習未計入費用與稅。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

int maxInt(int first, int second) => first > second ? first : second;

class _HoldingsSection extends StatelessWidget {
  const _HoldingsSection({required this.lab});

  final InvestmentLab lab;

  @override
  Widget build(BuildContext context) => SoftCard(
    key: const Key('investment-lab-holdings'),
    borderWidth: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('持有與配置', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: FutureMintTokens.space2),
        Text(lab.learningSummary),
        const SizedBox(height: FutureMintTokens.space4),
        if (lab.holdings.isEmpty)
          const Text('目前還沒有虛擬持股。先觀察價格與標的類型，再決定第一筆練習。')
        else
          for (var index = 0; index < lab.holdings.length; index++) ...[
            if (index > 0) const SizedBox(height: FutureMintTokens.space4),
            _HoldingRow(holding: lab.holdings[index]),
          ],
      ],
    ),
  );
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding});

  final VirtualHolding holding;

  @override
  Widget build(BuildContext context) {
    final positive = holding.gainLossMinor >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: FutureMintTokens.space3,
          runSpacing: FutureMintTokens.space2,
          children: [
            Text(
              '${holding.symbol} ${holding.name} · ${holding.quantity} 股',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${formatTwd(holding.marketValueMinor)} · '
              '${positive ? '+' : ''}${formatTwd(holding.gainLossMinor)}',
              style: TextStyle(
                color: positive
                    ? FutureMintTokens.positive
                    : FutureMintTokens.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space2),
        LinearProgressIndicator(
          value: (holding.allocationPercent / 100).clamp(0, 1),
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
        ),
        const SizedBox(height: FutureMintTokens.space1),
        Text(
          '配置 ${holding.allocationPercent.toStringAsFixed(1)}% · '
          '平均成本 NT\$${holding.averageCost.toStringAsFixed(2)} · '
          '盤後價 NT\$${holding.currentPrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PracticeEventCard extends StatelessWidget {
  const _PracticeEventCard({
    required this.event,
    required this.reply,
    required this.busy,
    required this.onRoll,
    required this.onAsk,
  });

  final PracticeDiceEvent? event;
  final CoachReply? reply;
  final bool busy;
  final VoidCallback onRoll;
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) => SoftCard(
    key: const Key('investment-lab-dice'),
    color: Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.lavenderSoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('市場事件骰子', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: FutureMintTokens.space1),
                const Text('抽一張情境卡，練習面對市場與生活中的不確定。'),
              ],
            );
            final button = FilledButton.tonalIcon(
              onPressed: busy ? null : onRoll,
              icon: const Icon(Icons.casino_outlined),
              label: Text(event == null ? '擲骰子' : '再擲一次'),
            );
            if (constraints.maxWidth < 600 ||
                MediaQuery.textScalerOf(context).scale(1) >= 1.5) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: FutureMintTokens.space3),
                  Align(alignment: Alignment.centerLeft, child: button),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                const SizedBox(width: FutureMintTokens.space4),
                button,
              ],
            );
          },
        ),
        if (event != null) ...[
          const SizedBox(height: FutureMintTokens.space5),
          Text(
            event!.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(event!.situation),
          const SizedBox(height: FutureMintTokens.space3),
          Text(
            '本次練習：${event!.practicePrompt}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: FutureMintTokens.space4),
          OutlinedButton.icon(
            onPressed: busy ? null : onAsk,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('請 AI 陪讀員解釋'),
          ),
          if (reply != null) ...[
            const SizedBox(height: FutureMintTokens.space4),
            Container(
              padding: const EdgeInsets.all(FutureMintTokens.space4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  FutureMintTokens.radiusSmall,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 陪讀員',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: FutureMintTokens.space2),
                  Text(reply!.answer),
                  const SizedBox(height: FutureMintTokens.space2),
                  Text(
                    reply!.takeaway,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: FutureMintTokens.space3),
          Text(event!.disclaimer, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}

class _OrderHistory extends StatelessWidget {
  const _OrderHistory({required this.orders});

  final List<VirtualInvestmentOrder> orders;

  @override
  Widget build(BuildContext context) => SoftCard(
    key: const Key('investment-lab-order-history'),
    borderWidth: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('練習紀錄', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: FutureMintTokens.space4),
        if (orders.isEmpty)
          const Text('完成第一筆虛擬買賣後，這裡會保留價格、數量與資料日期。')
        else
          for (var index = 0; index < orders.length; index++) ...[
            if (index > 0) const Divider(height: FutureMintTokens.space5),
            _OrderRow(order: orders[index]),
          ],
      ],
    ),
  );
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final VirtualInvestmentOrder order;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: FutureMintTokens.space3,
    runSpacing: FutureMintTokens.space2,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${order.side == InvestmentOrderSide.buy ? '買入' : '賣出'} '
            '${order.symbol} ${order.name}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${order.quantity} 股 · 單價 NT\$${order.unitPrice.toStringAsFixed(2)} · '
            '資料日 ${order.quoteAsOf.toIso8601String().split('T').first}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      Text(
        formatTwd(order.totalMinor),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ],
  );
}
