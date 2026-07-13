import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../../../shared/money_text.dart';

class BudgetHero extends StatelessWidget {
  const BudgetHero({super.key, required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = summary.monthlyBudgetMinor == 0
        ? 0.0
        : (summary.availableMinor / summary.monthlyBudgetMinor).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label:
          '本月安心可用 ${summary.availableMinor} 元，預算剩餘百分之 ${(ratio * 100).round()}',
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primary.withValues(alpha: .78)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: .18),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onPrimary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: scheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '本月安心可用',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MoneyText(
                summary.availableMinor,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: scheme.onPrimary,
                  fontSize: 42,
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: ratio,
                  color: scheme.onPrimary,
                  backgroundColor: scheme.onPrimary.withValues(alpha: .25),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '月預算 ${formatTwd(summary.monthlyBudgetMinor)} · 已支出 ${formatTwd(summary.expenseMinor + summary.subscriptionMinor)}',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: .88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
