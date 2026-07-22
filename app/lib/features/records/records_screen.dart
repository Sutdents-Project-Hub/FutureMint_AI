import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../shared/date_text.dart';
import '../../state/app_controller.dart';
import '../dashboard/dashboard_screen.dart';
import 'analysis_widgets.dart';

enum _RecordFilter { all, expense, income, subscription }

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  _RecordFilter filter = _RecordFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final events =
        controller.events
            .where(
              (event) => switch (filter) {
                _RecordFilter.all => true,
                _RecordFilter.expense => event.type == MoneyEventType.expense,
                _RecordFilter.income => event.type == MoneyEventType.income,
                _RecordFilter.subscription =>
                  event.type == MoneyEventType.subscription,
              },
            )
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final gutter = FutureMintTokens.pageGutter(context);
    return RefreshIndicator(
      onRefresh: controller.refreshWithFeedback,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          gutter,
          FutureMintTokens.space5,
          gutter,
          FutureMintTokens.space7,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: FutureMintTokens.contentReading,
              ),
              child: Column(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _RecordsHeadingArtwork(),
                      const SizedBox(height: FutureMintTokens.space5),
                      if (controller.insights != null) ...[
                        // Soft glow behind the cashflow card.
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: FutureMintTokens.skyInk.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CashflowAnalysis(
                            insights: controller.insights!,
                          ),
                        ),
                        const SizedBox(height: FutureMintTokens.space6),
                      ],
                      Text(
                        '交易明細',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      LayoutBuilder(
                        builder: (context, filterConstraints) {
                          final compact =
                              filterConstraints.maxWidth < 440 ||
                              MediaQuery.textScalerOf(context).scale(1) >= 1.3;
                          if (compact) {
                            return Wrap(
                              spacing: FutureMintTokens.space2,
                              runSpacing: FutureMintTokens.space2,
                              children: [
                                for (final entry in const [
                                  (_RecordFilter.all, '全部'),
                                  (_RecordFilter.expense, '支出'),
                                  (_RecordFilter.income, '收入'),
                                  (_RecordFilter.subscription, '訂閱'),
                                ])
                                  ChoiceChip(
                                    label: Text(entry.$2),
                                    selected: filter == entry.$1,
                                    onSelected: (_) =>
                                        setState(() => filter = entry.$1),
                                  ),
                              ],
                            );
                          }
                          return SegmentedButton<_RecordFilter>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: _RecordFilter.all,
                                label: Text('全部'),
                              ),
                              ButtonSegment(
                                value: _RecordFilter.expense,
                                label: Text('支出'),
                              ),
                              ButtonSegment(
                                value: _RecordFilter.income,
                                label: Text('收入'),
                              ),
                              ButtonSegment(
                                value: _RecordFilter.subscription,
                                label: Text('訂閱'),
                              ),
                            ],
                            selected: {filter},
                            onSelectionChanged: (value) =>
                                setState(() => filter = value.first),
                          );
                        },
                      ),
                      const SizedBox(height: FutureMintTokens.space5),
                      const _RecordsListArtwork(),
                      const SizedBox(height: FutureMintTokens.space2),
                      SoftCard(
                        key: const Key('records-list-surface'),
                        borderWidth: 1,
                        padding: EdgeInsets.zero,
                        child: events.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(
                                  FutureMintTokens.space5,
                                ),
                                child: Center(child: Text('這個分類還沒有紀錄。')),
                              )
                            : Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < events.length;
                                    index++
                                  ) ...[
                                    _RecordRow(event: events[index]),
                                    if (index != events.length - 1)
                                      const Divider(height: 1),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsHeadingArtwork extends StatelessWidget {
  const _RecordsHeadingArtwork();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 520 ||
          MediaQuery.textScalerOf(context).scale(1) >= 1.3;
      const heading = PageHeading(
        kicker: '分析優先的金錢時間軸',
        title: '先看模式，再看每一筆',
        description: '收支、需要與想要會先整理成趨勢；下方仍保留所有確認紀錄。',
        accent: FutureMintTokens.skyInk,
      );
      final artwork = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/mascot_history_purple.png',
            width: compact ? 108 : 132,
            height: compact ? 108 : 132,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: FutureMintTokens.space1),
          Transform.rotate(
            angle: -0.15,
            child: Image.asset(
              'assets/images/icon_coins_gold.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ],
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: FutureMintTokens.space2),
            Align(alignment: Alignment.centerRight, child: artwork),
            const _RecordsSparkleStrip(),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: heading),
              const SizedBox(width: FutureMintTokens.space3),
              artwork,
            ],
          ),
          const _RecordsSparkleStrip(),
        ],
      );
    },
  );
}

class _RecordsListArtwork extends StatelessWidget {
  const _RecordsListArtwork();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      spacing: FutureMintTokens.space2,
      runSpacing: FutureMintTokens.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Transform.rotate(
          angle: -0.18,
          child: Image.asset(
            'assets/images/icon_coins_gold.png',
            width: 54,
            height: 54,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        Image.asset(
          'assets/images/mascot_history_green.png',
          width: 152,
          height: 152,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        Transform.rotate(
          angle: 0.1,
          child: Image.asset(
            'assets/images/icon_moneybag_gold.png',
            width: 74,
            height: 74,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        Transform.rotate(
          angle: 0.25,
          child: Image.asset(
            'assets/images/icon_bill_gold.png',
            width: 54,
            height: 54,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ],
    ),
  );
}

class _RecordsSparkleStrip extends StatelessWidget {
  const _RecordsSparkleStrip();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.only(top: FutureMintTokens.space1),
      child: Wrap(
        spacing: FutureMintTokens.space2,
        children: const [
          Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white54),
          Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white38),
          Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white54),
        ],
      ),
    ),
  );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.event});
  final MoneyEvent event;

  @override
  Widget build(BuildContext context) {
    final income = event.type == MoneyEventType.income;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FutureMintTokens.space4,
        vertical: FutureMintTokens.space2,
      ),
      leading: CircleAvatar(
        backgroundColor: income
            ? FutureMintTokens.mintSoft
            : event.type == MoneyEventType.subscription
            ? FutureMintTokens.lavenderSoft
            : FutureMintTokens.coralSoft,
        foregroundColor: FutureMintTokens.ink,
        child: Icon(_categoryIcon(event)),
      ),
      title: Text(
        event.merchant ?? categoryLabel(event.category),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${categoryLabel(event.category)}${event.spendingIntent == null ? '' : ' · ${_intentLabel(event.spendingIntent!)}'} · ${formatTaipeiDateTime(event.occurredAt, includeYear: true)}${event.split == null ? '' : ' · ${event.split!.participants} 人分帳'}',
      ),
      trailing: MoneyText(
        income ? event.effectiveAmountMinor : -event.effectiveAmountMinor,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: income ? FutureMintTokens.teal : null,
        ),
      ),
    );
  }
}

String _intentLabel(SpendingIntent intent) => switch (intent) {
  SpendingIntent.need => '需要',
  SpendingIntent.want => '想要',
  SpendingIntent.uncertain => '不確定',
};

IconData _categoryIcon(MoneyEvent event) {
  if (event.type == MoneyEventType.income) return Icons.payments_rounded;
  if (event.type == MoneyEventType.subscription) {
    return Icons.autorenew_rounded;
  }
  final label = categoryLabel(event.category);
  if (label.contains('娛樂') || label.contains('遊戲')) {
    return Icons.sports_esports_rounded;
  }
  if (label.contains('餐飲') || label.contains('飲') || label.contains('食')) {
    return Icons.local_cafe_rounded;
  }
  if (label.contains('交通')) return Icons.directions_bus_filled_rounded;
  if (label.contains('購物')) return Icons.shopping_bag_rounded;
  if (label.contains('醫療') || label.contains('健康')) {
    return Icons.favorite_rounded;
  }
  if (label.contains('教育') || label.contains('學')) {
    return Icons.school_rounded;
  }
  return Icons.remove_rounded;
}
