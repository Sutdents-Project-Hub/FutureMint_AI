import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
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

    final budget = BudgetHero(summary: summary);
    final coach = _CoachInsight(summary: summary);
    final goal = _GoalCard(profile: profile, summary: summary);
    final recent = _SectionCard(
      title: '近期紀錄',
      color: _softSurface(context, FutureMintTokens.paper),
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
    );
    final subscription = _SubscriptionOpportunity(
      comparison: controller.subscriptionComparison,
    );
    final disclosure = _SyntheticDisclosure(
      guest: controller.mode == AppMode.guest,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bento =
            constraints.maxWidth >= FutureMintTokens.dashboardBentoWidth;
        final gutter = FutureMintTokens.pageGutter(context);
        final content = bento
            ? Column(
                key: const Key('dashboard-bento-layout'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            budget,
                            const SizedBox(height: FutureMintTokens.space5),
                            coach,
                          ],
                        ),
                      ),
                      const SizedBox(width: FutureMintTokens.space5),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            goal,
                            const SizedBox(height: FutureMintTokens.space5),
                            subscription,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FutureMintTokens.space6),
                  recent,
                  const SizedBox(height: FutureMintTokens.space5),
                  disclosure,
                ],
              )
            : Column(
                key: const Key('dashboard-compact-layout'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  budget,
                  const SizedBox(height: FutureMintTokens.space5),
                  coach,
                  const SizedBox(height: FutureMintTokens.space5),
                  goal,
                  const SizedBox(height: FutureMintTokens.space5),
                  recent,
                  const SizedBox(height: FutureMintTokens.space5),
                  subscription,
                  const SizedBox(height: FutureMintTokens.space5),
                  disclosure,
                ],
              );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            FutureMintTokens.space5,
            gutter,
            FutureMintTokens.space7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeading(
                kicker: '今天的金錢節奏',
                title: profile.accountRole == AccountRole.parent
                    ? '陪孩子看懂選擇，不替他做決定'
                    : '嗨，今天也一起顧好每一塊錢',
                description: profile.accountRole == AccountRole.parent
                    ? '家長模式調整說明角度，不會讀取另一個帳號的交易。'
                    : '先看清楚，再做適合自己的選擇。',
                accent: FutureMintTokens.teal,
                trailing: FilledButton.icon(
                  onPressed: () => context.go('/capture'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('記一筆'),
                ),
              ),
              const SizedBox(height: FutureMintTokens.space6),
              if (controller.insights?.notices.isNotEmpty ?? false) ...[
                _NoticeStrip(notices: controller.insights!.notices),
                const SizedBox(height: FutureMintTokens.space5),
              ],
              content,
            ],
          ),
        );
      },
    );
  }
}

class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({required this.notices});

  final List<InsightNotice> notices;

  @override
  Widget build(BuildContext context) {
    final first = notices.first;
    return Material(
      color: _softSurface(context, FutureMintTokens.mintSoft),
      borderRadius: BorderRadius.circular(FutureMintTokens.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(FutureMintTokens.radiusMedium),
        onTap: () => context.go('/notifications'),
        child: Padding(
          padding: const EdgeInsets.all(FutureMintTokens.space4),
          child: Row(
            children: [
              Badge(
                label: Text('${notices.length}'),
                child: const Icon(Icons.notifications_active_outlined),
              ),
              const SizedBox(width: FutureMintTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      first.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.action,
    this.color,
  });
  final String title;
  final Widget child;
  final Widget? action;
  final Color? color;

  @override
  Widget build(BuildContext context) => SoftCard(
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            ?action,
          ],
        ),
        const SizedBox(height: FutureMintTokens.space4),
        child,
      ],
    ),
  );
}

class _CoachInsight extends StatelessWidget {
  const _CoachInsight({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => SoftCard(
    color: _softSurface(context, FutureMintTokens.lavenderSoft),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IconBadge(
          icon: Icons.lightbulb_outline_rounded,
          color: FutureMintTokens.coral,
        ),
        const SizedBox(width: FutureMintTokens.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '教練提醒',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: FutureMintTokens.space2),
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
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.profile, required this.summary});
  final UserProfile profile;
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: '成長目標',
    color: _softSurface(context, FutureMintTokens.mintSoft),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.goalName,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: FutureMintTokens.space3),
        LinearProgressIndicator(
          value: summary.goalProgress,
          minHeight: 9,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: FutureMintTokens.space3),
        Text(
          '已完成 ${(summary.goalProgress * 100).round()}% · 還差 ${formatTwd(summary.goalRemainingMinor)}',
        ),
        const SizedBox(height: FutureMintTokens.space1),
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
      color: _softSurface(context, FutureMintTokens.skySoft),
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
          const SizedBox(height: FutureMintTokens.space4),
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
  const _SyntheticDisclosure({required this.guest});
  final bool guest;
  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.all(FutureMintTokens.space4),
    radius: 16,
    borderWidth: 1,
    color: _softSurface(context, FutureMintTokens.mintSoft),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 20),
        const SizedBox(width: FutureMintTokens.space3),
        Expanded(
          child: Text(
            guest
                ? '這是訪客暫存資料；離開或重新整理後會清除，不會接觸真實帳戶或付款。'
                : '你的資料會依登入帳號保存；本產品仍不串接真實金融帳戶或付款。',
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
            ? _softSurface(context, FutureMintTokens.mintSoft)
            : _softSurface(context, FutureMintTokens.coralSoft),
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: SizedBox.square(
      dimension: 44,
      child: Icon(icon, color: FutureMintTokens.ink),
    ),
  );
}

Color _softSurface(BuildContext context, Color light) =>
    Theme.of(context).brightness == Brightness.dark
    ? FutureMintTokens.darkSurfaceRaised
    : light;

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
