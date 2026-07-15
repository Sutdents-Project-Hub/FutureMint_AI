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
      child: SoftCard(
        key: const Key('dashboard-budget-hero'),
        color: dark ? FutureMintTokens.tealDark : FutureMintTokens.mint,
        radius: FutureMintTokens.radiusLarge,
        padding: const EdgeInsets.all(FutureMintTokens.space5),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
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
                    size: 64,
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
                  fontSize: 42,
                ),
              ),
              const SizedBox(height: FutureMintTokens.space5),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  key: const Key('dashboard-budget-progress'),
                  minHeight: 8,
                  value: ratio,
                  color: progressColor,
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
