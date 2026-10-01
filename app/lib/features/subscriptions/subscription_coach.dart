import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../state/app_controller.dart';
import 'subscription_editor.dart';

class SubscriptionCoachScreen extends StatelessWidget {
  const SubscriptionCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final comparison = controller.subscriptionComparison;
    final gutter = FutureMintTokens.pageGutter(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        FutureMintTokens.space4,
        gutter,
        FutureMintTokens.space7,
      ),
      child: ResponsivePageCanvas(
        compactMaxWidth: FutureMintTokens.contentReading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('回首頁'),
              ),
            ),
            const SizedBox(height: FutureMintTokens.space2),
            const PageHeading(
              kicker: '訂閱教練',
              title: '訂閱不是只能留或退',
              description: '先換算每月真正負擔，再確認資格與使用方式。',
              accent: FutureMintTokens.skyInk,
            ),
            const SizedBox(height: FutureMintTokens.space5),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '目前每月訂閱承諾：${controller.subscriptions.monthlyCommitmentMinor} 元',
                  ),
                  const Text('實際付款另列於收支紀錄，避免重複扣除。'),
                  const SizedBox(height: 12),
                  if (controller.hasPendingSubscription) ...[
                    const Text('上一筆訂閱尚待確認。重試會使用原資料，避免重複建立。'),
                    FilledButton(
                      onPressed: controller.busy
                          ? null
                          : controller.retryPendingSubscription,
                      child: const Text('重試原訂閱'),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => showSubscriptionEditor(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('新增訂閱'),
                  ),
                  for (final item in controller.subscriptions.items.where(
                    (s) => s.active,
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.amountMinor} 元／${item.billingCycle == BillingCycle.yearly ? '年' : '月'}；下次 ${item.nextBillingDate.toIso8601String().split('T').first}',
                      ),
                      onTap: controller.busy
                          ? null
                          : () => showSubscriptionEditor(
                              context,
                              controller,
                              subscription: item,
                            ),
                      trailing: IconButton(
                        tooltip: '停用訂閱追蹤',
                        icon: const Icon(Icons.pause_circle_outline),
                        onPressed: controller.busy
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialog) => AlertDialog(
                                    title: const Text('停用訂閱追蹤？'),
                                    content: const Text(
                                      '既有付款會保留；未來提醒與每月承諾將停止。這不會取消服務供應商的訂閱。',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, false),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialog, true),
                                        child: const Text('停用'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await controller.deactivateSubscription(
                                    item.id,
                                  );
                                }
                              },
                      ),
                    ),
                  if (controller.subscriptions.legacyCandidates.isNotEmpty) ...[
                    const Divider(),
                    const Text('舊訂閱付款：如仍持續使用，可明確建立追蹤；歷史付款保留。'),
                    for (final payment
                        in controller.subscriptions.legacyCandidates)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(payment.merchant ?? '未命名訂閱付款'),
                        subtitle: Text(
                          '${payment.effectiveAmountMinor} 元（已發生）',
                        ),
                        trailing: TextButton(
                          onPressed: controller.busy
                              ? null
                              : () => showSubscriptionEditor(
                                  context,
                                  controller,
                                  legacy: payment,
                                ),
                          child: const Text('採用為訂閱'),
                        ),
                      ),
                  ],
                  if (controller.errorMessage != null)
                    Text(controller.errorMessage!),
                ],
              ),
            ),
            const SizedBox(height: FutureMintTokens.space4),
            if (comparison == null)
              const SoftCard(
                color: FutureMintTokens.skySoft,
                child: Text('目前沒有可比較的訂閱情境。'),
              )
            else ...[
              Container(
                key: const Key('subscription-current-card'),
                padding: FutureMintTokens.cardPadding(context),
                decoration: BoxDecoration(
                  color: FutureMintTokens.isDark(context)
                      ? FutureMintTokens.darkSurface
                      : FutureMintTokens.ink,
                  borderRadius: BorderRadius.circular(
                    FutureMintTokens.radiusLarge,
                  ),
                  border: Border.all(
                    color: FutureMintTokens.isDark(context)
                        ? FutureMintTokens.neonPurple.withValues(alpha: .35)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (FutureMintTokens.isDark(context))
                      BoxShadow(
                        color: FutureMintTokens.neonPurple.withValues(
                          alpha: .16,
                        ),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: FutureMintTokens.paper),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: FutureMintTokens.pink,
                        foregroundColor: FutureMintTokens.ink,
                        child: Icon(Icons.movie_outlined),
                      ),
                      const SizedBox(width: FutureMintTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '目前：${comparison.currentName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: FutureMintTokens.space1),
                            MoneyText(
                              comparison.currentMonthlyCostMinor,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: FutureMintTokens.paper,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              '每月等效成本',
                              style: TextStyle(
                                color: FutureMintTokens.paper.withValues(
                                  alpha: .78,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FutureMintTokens.space5),
              for (final entry in comparison.options.indexed) ...[
                _OptionCard(option: entry.$2, index: entry.$1),
                const SizedBox(height: FutureMintTokens.space4),
              ],
              SoftCard(
                padding: const EdgeInsets.all(FutureMintTokens.space4),
                radius: 16,
                borderWidth: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? FutureMintTokens.darkSurfaceRaised
                    : FutureMintTokens.coralSoft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded),
                    const SizedBox(width: FutureMintTokens.space3),
                    Expanded(child: Text(comparison.disclaimer)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.index});

  final SubscriptionOption option;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = index.isEven
        ? FutureMintTokens.sky
        : FutureMintTokens.lavender;
    final savings = option.monthlySavingsMinor;
    final savingsColor = savings == null
        ? null
        : savings > 0
        ? FutureMintTokens.positiveInk(context)
        : FutureMintTokens.dangerInk(context);
    return SoftCard(
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : FutureMintTokens.paper,
      borderWidth: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 12),
              ),
              const SizedBox(width: FutureMintTokens.space3),
              Expanded(
                child: Text(
                  option.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: FutureMintTokens.space2),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(option.sourceType == 'synthetic' ? '合成方案' : '已知來源'),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  label: '你的每月負擔',
                  value: formatTwd(option.userMonthlyCostMinor),
                ),
              ),
              const SizedBox(width: FutureMintTokens.space3),
              Expanded(
                child: _Metric(
                  label: savings == null
                      ? '方案差額'
                      : savings > 0
                      ? '每月可能少花'
                      : '每月可能多花',
                  value: savings == null
                      ? '資格不符，不比較'
                      : formatTwd(savings.abs()),
                  color: savingsColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space4),
          const Divider(height: 1),
          const SizedBox(height: FutureMintTokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                option.eligible
                    ? Icons.verified_outlined
                    : Icons.warning_amber_rounded,
                size: 20,
              ),
              const SizedBox(width: FutureMintTokens.space2),
              Expanded(child: Text(option.eligibilityMessage)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: FutureMintTokens.space1),
      Text(
        value,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}
