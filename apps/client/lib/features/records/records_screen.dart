import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../shared/date_text.dart';
import '../../state/app_controller.dart';
import '../dashboard/dashboard_screen.dart';

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeading(
                    kicker: '金錢時間軸',
                    title: '每一筆，都看得懂',
                    description: '這裡只顯示你確認保存的合成紀錄。下拉可重新整理。',
                    accent: FutureMintTokens.sky,
                  ),
                  const SizedBox(height: FutureMintTokens.space5),
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
                  SoftCard(
                    key: const Key('records-list-surface'),
                    borderWidth: 1,
                    padding: EdgeInsets.zero,
                    child: events.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(FutureMintTokens.space5),
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
            ),
          ),
        ],
      ),
    );
  }
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
            : FutureMintTokens.skySoft,
        foregroundColor: FutureMintTokens.ink,
        child: Icon(
          income
              ? Icons.add_rounded
              : event.type == MoneyEventType.subscription
              ? Icons.autorenew_rounded
              : Icons.remove_rounded,
        ),
      ),
      title: Text(
        event.merchant ?? categoryLabel(event.category),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${categoryLabel(event.category)} · ${formatTaipeiDateTime(event.occurredAt, includeYear: true)}${event.split == null ? '' : ' · ${event.split!.participants} 人分帳'}',
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
