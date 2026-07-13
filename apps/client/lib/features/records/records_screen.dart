import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
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

    return RefreshIndicator(
      onRefresh: controller.refreshWithFeedback,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每一筆，都看得懂',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '這裡只顯示你確認保存的合成紀錄。下拉可重新整理。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                ],
              ),
            ),
          ),
          if (events.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('這個分類還沒有紀錄。')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
              sliver: SliverList.separated(
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _RecordCard(event: events[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.event});
  final MoneyEvent event;

  @override
  Widget build(BuildContext context) {
    final income = event.type == MoneyEventType.income;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
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
            fontWeight: FontWeight.w800,
            color: income ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}
