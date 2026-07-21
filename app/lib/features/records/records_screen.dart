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
              // Outer stack: page content Column plus a handful of
              // decorative sparkles scattered behind it. The Column is the
              // only non-positioned child, so it determines the Stack's
              // size; the sparkles are Positioned siblings, not nested in
              // their own Stack (that caused an unbounded-height crash).
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Purple mascot floats above the heading, spilling
                      // outside the top-right corner (target design). A
                      // gold coin accent floats nearby for decoration.
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const PageHeading(
                            kicker: '分析優先的金錢時間軸',
                            title: '先看模式，再看每一筆',
                            description: '收支、需要與想要會先整理成趨勢；下方仍保留所有確認紀錄。',
                            accent: FutureMintTokens.skyInk,
                          ),
                          Positioned(
                            top: -18,
                            right: -8,
                            child: IgnorePointer(
                              child: Image.asset(
                                'assets/images/mascot_history_purple.png',
                                width: 96,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 20,
                            right: 90,
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: -0.15,
                                child: Image.asset(
                                  'assets/images/icon_coins_gold.png',
                                  width: 32,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: FutureMintTokens.space5),
                      if (controller.insights != null) ...[
                        // Soft glow behind the cashflow card.
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: FutureMintTokens.skyInk.withOpacity(
                                  0.35,
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
                      SegmentedButton<_RecordFilter>(
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
                      ),
                      const SizedBox(height: FutureMintTokens.space5),
                      // Records list card. Green mascot (2x size) sits high
                      // beside the doubled moneybag icon, with coins and a
                      // bill scattered around it, all spilling outside the
                      // card's top-right corner (target design).
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SoftCard(
                            key: const Key('records-list-surface'),
                            borderWidth: 1,
                            padding: EdgeInsets.zero,
                            child: events.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(
                                      FutureMintTokens.space5,
                                    ),
                                    child: Center(
                                      child: Text('這個分類還沒有紀錄。'),
                                    ),
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
                          // Moneybag, doubled in size.
                          Positioned(
                            right: -20,
                            top: -44,
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: 0.1,
                                child: Image.asset(
                                  'assets/images/icon_moneybag_gold.png',
                                  width: 80,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          // Green mascot, moved further up, doubled in size.
                          Positioned(
                            right: 40,
                            top: -150,
                            child: IgnorePointer(
                              child: Image.asset(
                                'assets/images/mascot_history_green.png',
                                width: 192,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 190,
                            top: -80,
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: -0.18,
                                child: Image.asset(
                                  'assets/images/icon_coins_gold.png',
                                  width: 68,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -70,
                            top: -60,
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: 0.25,
                                child: Image.asset(
                                  'assets/images/icon_bill_gold.png',
                                  width: 68,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    left: 12,
                    top: 40,
                    child: const IgnorePointer(
                      child: _Sparkle(size: 16, opacity: .55),
                    ),
                  ),
                  Positioned(
                    right: 60,
                    top: 10,
                    child: const IgnorePointer(
                      child: _Sparkle(size: 12, opacity: .4),
                    ),
                  ),
                  Positioned(
                    left: 90,
                    top: 260,
                    child: const IgnorePointer(
                      child: _Sparkle(size: 14, opacity: .35),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    top: 340,
                    child: const IgnorePointer(
                      child: _Sparkle(size: 18, opacity: .5),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    top: 560,
                    child: const IgnorePointer(
                      child: _Sparkle(size: 14, opacity: .4),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 640,
                    child: const IgnorePointer(
                      child: _Sparkle(size: 20, opacity: .45),
                    ),
                  ),
                  Positioned(
                    left: 60,
                    top: 780,
                    child: const IgnorePointer(
                      child: _Sparkle(size: 12, opacity: .35),
                    ),
                  ),
                  Positioned(
                    right: 90,
                    top: 860,
                    child: const IgnorePointer(
                      child: _Sparkle(size: 16, opacity: .4),
                    ),
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

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.auto_awesome_rounded,
    size: size,
    color: Colors.white.withOpacity(opacity),
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
