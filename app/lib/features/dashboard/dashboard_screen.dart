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

        // The shell already shows a persistent guest banner and the
        // disclosure card closes the page, so the header starts with content.
        final pageColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DashboardHeader(
              parent: profile.accountRole == AccountRole.parent,
              onCapture: () => context.go('/capture'),
            ),
            SizedBox(
              height: bento ? FutureMintTokens.space6 : FutureMintTokens.space5,
            ),
            if (controller.insights?.notices.isNotEmpty ?? false) ...[
              _NoticeStrip(notices: controller.insights!.notices),
              const SizedBox(height: FutureMintTokens.space5),
            ],
            content,
          ],
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            FutureMintTokens.space5,
            gutter,
            FutureMintTokens.space7,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: _BackgroundSparkles(compact: !bento),
                ),
              ),
              pageColumn,
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.parent, required this.onCapture});

  final bool parent;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final title = parent ? '陪孩子看懂選擇，不替他做決定' : '嗨，今天也一起顧好每一塊錢';
    final description = parent ? '家長模式調整說明角度，不會讀取另一個帳號的交易。' : '先看清楚，再做適合自己的選擇。';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 620 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.3;
        if (!compact) {
          return PageHeading(
            kicker: '今天的金錢節奏',
            title: title,
            description: description,
            accent: FutureMintTokens.teal,
            trailing: _DashboardHeaderActions(onCapture: onCapture),
          );
        }
        // Phone: the mascot takes its own column beside the greeting, so the
        // budget Hero reaches the first screen instead of a separate art row.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeading(
                    kicker: '今天的金錢節奏',
                    title: title,
                    description: description,
                    accent: FutureMintTokens.teal,
                  ),
                  const SizedBox(height: FutureMintTokens.space4),
                  FilledButton.icon(
                    onPressed: onCapture,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('記一筆'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FutureMintTokens.space2),
            const _BlobArtwork(size: 112),
          ],
        );
      },
    );
  }
}

class _BlobArtwork extends StatelessWidget {
  const _BlobArtwork({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(size * .06),
            child: Image.asset(
              'assets/images/blob_purple.png',
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: size * .08,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: size * .2,
            color: const Color(0xFF7CFF4D).withValues(alpha: .9),
          ),
        ),
        Positioned(
          right: 0,
          bottom: size * .02,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: size * .16,
            color: FutureMintTokens.neonPurple.withValues(alpha: .85),
          ),
        ),
      ],
    ),
  );
}

class _BackgroundSparkles extends StatelessWidget {
  const _BackgroundSparkles({this.compact = false});

  final bool compact;

  static const _stars = <_StarSpec>[
    _StarSpec(1, 97, 50, -23),
    _StarSpec(1, 340, 50, -49),
    _StarSpec(-1, 776, 44, -32),
    _StarSpec(-1, 889, 26, -27),
    _StarSpec(-1, 465, 44, -40),
    _StarSpec(-1, 872, 50, -46),
    _StarSpec(1, 572, 26, -18),
    _StarSpec(1, 144, 56, -43),
    _StarSpec(-1, 803, 56, -44),
  ];

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final star in _stars)
        // Phone gutters are only 16dp: shrink the stars so they stay in the
        // gutter instead of being cut by the screen edge or covering text.
        Positioned(
          left: star.side < 0 ? (compact ? -14 : star.depth) : null,
          right: star.side > 0 ? (compact ? -14 : star.depth) : null,
          top: star.top,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: compact
                ? (star.size * .26).clamp(8, 13).toDouble()
                : star.size,
            color: compact ? Colors.white30 : Colors.white24,
          ),
        ),
    ],
  );
}

class _StarSpec {
  const _StarSpec(this.side, this.top, this.size, this.depth);
  final int side;
  final double top;
  final double size;
  final double depth;
}

class _DashboardHeaderActions extends StatelessWidget {
  const _DashboardHeaderActions({required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: FutureMintTokens.space3,
    runSpacing: FutureMintTokens.space2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const _BlobArtwork(size: 156),
      FilledButton.icon(
        onPressed: onCapture,
        icon: const Icon(Icons.add_rounded),
        label: const Text('記一筆'),
      ),
    ],
  );
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
                offset: const Offset(2, -2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: FutureMintTokens.sun.withValues(
                      alpha: FutureMintTokens.isDark(context) ? .18 : .45,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: FutureMintTokens.isDark(context)
                          ? FutureMintTokens.sun
                          : FutureMintTokens.ink,
                    ),
                  ),
                ),
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
  Widget build(BuildContext context) => NeonCard(
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (action != null) ...[
              const SizedBox(width: FutureMintTokens.space3),
              action!,
            ],
          ],
        ),
        const SizedBox(height: FutureMintTokens.space3),
        child,
      ],
    ),
  );
}

class _CoachInsight extends StatelessWidget {
  const _CoachInsight({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => NeonCard(
    color: _softSurface(context, FutureMintTokens.lavenderSoft),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
        final compact = constraints.maxWidth < 520 || largeText;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _IconBadge(
                  icon: Icons.lightbulb_outline_rounded,
                  color: FutureMintTokens.coral,
                ),
                const SizedBox(width: FutureMintTokens.space3),
                Expanded(
                  child: Text(
                    '教練提醒',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FutureMintTokens.space2),
            Text(
              summary.availableMinor >= 0
                  ? '現在還有 ${formatTwd(summary.availableMinor)} 可以安排。先把想花的和需要花的分開，會更容易守住目標。'
                  : '本月超出預算 ${formatTwd(-summary.availableMinor)}。先暫停一項可延後支出，不需要責怪自己。',
            ),
          ],
        );
        final mascot = Image.asset(
          'assets/images/mascot_orange.png',
          width: compact ? 96 : 136,
          height: compact ? 96 : 136,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        );
        if (compact && !largeText) {
          // Phone: the coach mascot sits in its own column next to the tip.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: FutureMintTokens.space2),
              mascot,
            ],
          );
        }
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy,
              const SizedBox(height: FutureMintTokens.space2),
              Align(alignment: Alignment.centerRight, child: mascot),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            const SizedBox(width: FutureMintTokens.space3),
            mascot,
          ],
        );
      },
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
    action: Image.asset(
      'assets/images/bars_purple.png',
      width: _phone(context) ? 64 : 84,
      height: _phone(context) ? 64 : 84,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
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
      action: Image.asset(
        'assets/images/clipboard_teal.png',
        width: _phone(context) ? 60 : 76,
        height: _phone(context) ? 60 : 76,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
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
  Widget build(BuildContext context) => NeonCard(
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
    final color = categoryColor(event.category);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: FutureMintTokens.space2,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .18),
        child: Icon(categoryIcon(event.category), color: color, size: 20),
      ),
      title: Text(event.merchant ?? categoryLabel(event.category)),
      subtitle: Text(formatTaipeiDateTime(event.occurredAt)),
      trailing: MoneyText(
        income ? event.effectiveAmountMinor : -event.effectiveAmountMinor,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: income
              ? FutureMintTokens.brandInk(context)
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

bool _phone(BuildContext context) =>
    MediaQuery.sizeOf(context).width < FutureMintTokens.railBreakpoint;

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

IconData categoryIcon(MoneyCategory category) => switch (category) {
  MoneyCategory.food => Icons.restaurant_rounded,
  MoneyCategory.transport => Icons.directions_car_filled_rounded,
  MoneyCategory.entertainment => Icons.sports_esports_rounded,
  MoneyCategory.education => Icons.school_rounded,
  MoneyCategory.shopping => Icons.shopping_bag_rounded,
  MoneyCategory.income => Icons.south_west_rounded,
  MoneyCategory.subscription => Icons.subscriptions_rounded,
  MoneyCategory.other => Icons.receipt_long_rounded,
};

Color categoryColor(MoneyCategory category) => switch (category) {
  MoneyCategory.food => const Color(0xFFFFA36C),
  MoneyCategory.transport => const Color(0xFF6CC2FF),
  MoneyCategory.entertainment => const Color(0xFFB98CFF),
  MoneyCategory.education => const Color(0xFF7CE0C6),
  MoneyCategory.shopping => const Color(0xFFFFD36C),
  MoneyCategory.income => const Color(0xFF7CFF4D),
  MoneyCategory.subscription => const Color(0xFFFF8CC6),
  MoneyCategory.other => const Color(0xFFB9C2CC),
};
