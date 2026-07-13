import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../shared/money_text.dart';
import '../../state/app_controller.dart';

class SubscriptionCoachScreen extends StatelessWidget {
  const SubscriptionCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final comparison = context.watch<AppController>().subscriptionComparison;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
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
              Text(
                '訂閱不是只能留或退',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('先換算每月真正負擔，再確認資格與使用方式。'),
              const SizedBox(height: 24),
              if (comparison == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('目前沒有可比較的訂閱情境。'),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.movie_outlined)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('目前：${comparison.currentName}'),
                              const Text('每月等效成本'),
                            ],
                          ),
                        ),
                        MoneyText(
                          comparison.currentMonthlyCostMinor,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final option in comparison.options) ...[
                  _OptionCard(option: option),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded),
                      const SizedBox(width: 10),
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
  const _OptionCard({required this.option});
  final SubscriptionOption option;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Chip(
                label: Text(option.sourceType == 'synthetic' ? '合成方案' : '已知來源'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 12,
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
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                option.eligible
                    ? Icons.verified_outlined
                    : Icons.warning_amber_rounded,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(option.eligibilityMessage)),
            ],
          ),
        ],
      ),
    ),
  );
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
      const SizedBox(height: 3),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
