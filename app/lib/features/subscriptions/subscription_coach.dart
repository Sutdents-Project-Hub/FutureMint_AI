import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../state/app_controller.dart';

class SubscriptionCoachScreen extends StatelessWidget {
  const SubscriptionCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final comparison = context.watch<AppController>().subscriptionComparison;
    final gutter = FutureMintTokens.pageGutter(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        FutureMintTokens.space4,
        gutter,
        FutureMintTokens.space7,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FutureMintTokens.contentReading,
          ),
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
                accent: FutureMintTokens.sky,
              ),
              const SizedBox(height: FutureMintTokens.space5),
              if (comparison == null)
                const SoftCard(
                  color: FutureMintTokens.skySoft,
                  child: Text('目前沒有可比較的訂閱情境。'),
                )
              else ...[
                SoftCard(
                  key: const Key('subscription-current-card'),
                  color: FutureMintTokens.ink,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: FutureMintTokens.paper),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              backgroundColor: FutureMintTokens.pink,
                              foregroundColor: FutureMintTokens.ink,
                              child: Icon(Icons.movie_outlined),
                            ),
                            const SizedBox(width: FutureMintTokens.space3),
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
                                  const Text('每月等效成本'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: FutureMintTokens.space4),
                        MoneyText(
                          comparison.currentMonthlyCostMinor,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: FutureMintTokens.paper),
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
    return SoftCard(
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : FutureMintTokens.paper,
      borderWidth: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 16),
              ),
              const SizedBox(width: FutureMintTokens.space2),
              Expanded(
                child: Text(
                  option.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Chip(label: Text(option.sourceType == 'synthetic' ? '合成方案' : '已知來源')),
          const SizedBox(height: FutureMintTokens.space4),
          Wrap(
            spacing: FutureMintTokens.space6,
            runSpacing: FutureMintTokens.space3,
            children: [
              _Metric(
                label: '你的每月負擔',
                value: formatTwd(option.userMonthlyCostMinor),
              ),
              _Metric(
                label: option.monthlySavingsMinor == null
                    ? '方案差額'
                    : option.monthlySavingsMinor! > 0
                    ? '每月可能少花'
                    : '每月可能多花',
                value: option.monthlySavingsMinor == null
                    ? '資格不符，不比較'
                    : formatTwd(option.monthlySavingsMinor!.abs()),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space4),
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
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: FutureMintTokens.space1),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
