import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../../../design/soft_components.dart';
import '../../../design/tokens.dart';
import '../../../shared/money_text.dart';

class BudgetHero extends StatelessWidget {
  const BudgetHero({super.key, required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark
        ? theme.colorScheme.onSurface
        : FutureMintTokens.paper;
    final progressColor = dark
        ? theme.colorScheme.onSurface
        : FutureMintTokens.paper;
    final progressTrackColor = dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.tealDark;
    final ratio = summary.monthlyBudgetMinor == 0
        ? 0.0
        : (summary.availableMinor / summary.monthlyBudgetMinor).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label:
          '本月安心可用 ${summary.availableMinor} 元，預算剩餘百分之 ${(ratio * 100).round()}',
      child: Container(
        key: const Key('dashboard-budget-hero'),
        padding: const EdgeInsets.all(FutureMintTokens.space5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? [Color(0xFF1C1630), Color(0xFF2B1E45)]
                : [FutureMintTokens.mint, FutureMintTokens.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusLarge),
          border: Border.all(
            color: dark ? const Color(0xFF7B6BFF).withOpacity(.22) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            if (dark)
              BoxShadow(
                color: const Color(0xFF7B6BFF).withOpacity(.12),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: foreground,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '本月安心可用',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const MoneyBuddy(
                    key: Key('dashboard-mascot'),
                    size: 80,
                    color: FutureMintTokens.sun,
                    shape: MoneyBuddyShape.flower,
                  ),
                ],
              ),
              const SizedBox(height: FutureMintTokens.space3),
              MoneyText(
                summary.availableMinor,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: foreground,
                  fontSize: 48,
                ),
              ),
              const SizedBox(height: FutureMintTokens.space4),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  key: const Key('dashboard-budget-progress'),
                  minHeight: 12,
                  value: ratio,
                  color: dark ? const Color(0xFF9B8CFF) : FutureMintTokens.paper,
                  backgroundColor: progressTrackColor,
                ),
              ),
              const SizedBox(height: FutureMintTokens.space3),
              Text(
                '月預算 ${formatTwd(summary.monthlyBudgetMinor)} · 已支出 ${formatTwd(summary.expenseMinor + summary.subscriptionMinor)}',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
