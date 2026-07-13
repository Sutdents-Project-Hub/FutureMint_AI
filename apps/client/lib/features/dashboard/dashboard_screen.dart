import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/tokens.dart';
import '../../shared/async_panel.dart';
import '../../shared/date_text.dart';
import '../../shared/money_text.dart';
import '../../state/app_controller.dart';
import 'widgets/budget_hero.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return AsyncPanel(
      busy: controller.busy && !controller.initialized,
      errorMessage: controller.initialized ? null : controller.errorMessage,
      onRetry: controller.initialize,
      child: _DashboardContent(controller: controller),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.dashboard;
    final profile = controller.profile;
    if (summary == null || profile == null) return const SizedBox.shrink();
    final wide =
        MediaQuery.sizeOf(context).width >= FutureMintTokens.wideBreakpoint;

    final primary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BudgetHero(summary: summary),
        const SizedBox(height: 20),
        _CoachInsight(summary: summary),
        const SizedBox(height: 20),
        _SectionCard(
          title: '近期紀錄',
          action: TextButton(
            onPressed: () => context.go('/records'),
            child: const Text('查看全部'),
          ),
          child: Column(
            children: [
              for (final event in summary.recentEvents.take(4))
                _RecentEventTile(event: event),
            ],
          ),
        ),
      ],
    );

    final secondary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoalCard(profile: profile, summary: summary),
        const SizedBox(height: 20),
        _SubscriptionOpportunity(comparison: controller.subscriptionComparison),
        const SizedBox(height: 20),
        _SyntheticDisclosure(offline: controller.mode == AppMode.offlineDemo),
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 36 : 20, 24, wide ? 36 : 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '嗨，今天也一起顧好每一塊錢',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '先看清楚，再做適合自己的選擇。',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => context.go('/capture'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('記一筆'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: primary),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: secondary),
              ],
            )
          else ...[
            primary,
            const SizedBox(height: 20),
            secondary,
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _CoachInsight extends StatelessWidget {
  const _CoachInsight({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(
      context,
    ).colorScheme.secondaryContainer.withValues(alpha: .65),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '教練提醒',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.availableMinor >= 0
                      ? '現在還有 ${formatTwd(summary.availableMinor)} 可以安排。先把想花的和需要花的分開，會更容易守住目標。'
                      : '本月超出預算 ${formatTwd(-summary.availableMinor)}。先暫停一項可延後支出，不需要責怪自己。',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.profile, required this.summary});
  final UserProfile profile;
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: '成長目標',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.goalName,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: summary.goalProgress,
          minHeight: 9,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 10),
        Text(
          '已完成 ${(summary.goalProgress * 100).round()}% · 還差 ${formatTwd(summary.goalRemainingMinor)}',
        ),
        const SizedBox(height: 4),
        Text(
          '預計 ${profile.goalDate.year} 年 ${profile.goalDate.month} 月 ${profile.goalDate.day} 日前完成',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _SubscriptionOpportunity extends StatelessWidget {
  const _SubscriptionOpportunity({required this.comparison});
  final SubscriptionComparison? comparison;

  @override
  Widget build(BuildContext context) {
    final best = comparison?.options
        .where((item) => item.eligible && (item.monthlySavingsMinor ?? 0) > 0)
        .firstOrNull;
    return _SectionCard(
      title: '訂閱小檢查',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comparison == null
                ? '先記下固定訂閱，FutureMint 才能一起比較。'
                : best == null
                ? '目前的每月負擔已不高於合成比較方案，不需為了更換而更換。'
                : '合成情境中，「${best.name}」每月可能少 ${formatTwd(best.monthlySavingsMinor ?? 0)}。',
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => context.go('/subscriptions'),
            icon: const Icon(Icons.compare_arrows_rounded),
            label: const Text('比較方案'),
          ),
        ],
      ),
    );
  }
}

class _SyntheticDisclosure extends StatelessWidget {
  const _SyntheticDisclosure({required this.offline});
  final bool offline;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            offline
                ? '目前使用固定合成資料與離線規則，不會接觸真實帳戶或付款。'
                : '目前連接展示 API；本產品仍不串接真實金融帳戶或付款。',
          ),
        ),
      ],
    ),
  );
}

class _RecentEventTile extends StatelessWidget {
  const _RecentEventTile({required this.event});
  final MoneyEvent event;

  @override
  Widget build(BuildContext context) {
    final income = event.type == MoneyEventType.income;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: income
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          income ? Icons.south_west_rounded : Icons.north_east_rounded,
        ),
      ),
      title: Text(event.merchant ?? categoryLabel(event.category)),
      subtitle: Text(formatTaipeiDateTime(event.occurredAt)),
      trailing: MoneyText(
        income ? event.effectiveAmountMinor : -event.effectiveAmountMinor,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: income
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

String categoryLabel(MoneyCategory category) => switch (category) {
  MoneyCategory.food => '餐飲',
  MoneyCategory.transport => '交通',
  MoneyCategory.entertainment => '娛樂',
  MoneyCategory.education => '學習',
  MoneyCategory.shopping => '購物',
  MoneyCategory.income => '收入',
  MoneyCategory.subscription => '訂閱',
  MoneyCategory.other => '其他',
};
