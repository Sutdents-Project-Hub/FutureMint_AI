import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../../../design/tokens.dart';
import '../../../shared/money_text.dart';

class BudgetHero extends StatelessWidget {
  const BudgetHero({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ratio = summary.monthlyBudgetMinor == 0
        ? 0.0
        : (summary.availableMinor / summary.monthlyBudgetMinor).clamp(0.0, 1.0);
    final foreground = dark
        ? theme.colorScheme.onSurface
        : FutureMintTokens.paper;
    return Semantics(
      container: true,
      label:
          '本月安心可用 ${summary.availableMinor} 元，預算剩餘百分之 ${(ratio * 100).round()}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 580 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.3;
          final artwork = SizedBox(
            width: compact ? 158 : 180,
            height: compact ? 140 : 164,
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/images/mascot_yellow.png',
                    key: const Key('dashboard-mascot'),
                    width: compact ? 130 : 154,
                    height: compact ? 130 : 154,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                Positioned(
                  left: compact ? 12 : 18,
                  top: compact ? 48 : 54,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: compact ? 23 : 28,
                    color: FutureMintTokens.neonPurple.withValues(alpha: .8),
                  ),
                ),
                Positioned(
                  right: compact ? 112 : 126,
                  bottom: compact ? 18 : 26,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: compact ? 20 : 24,
                    color: const Color(0xFF7CFF4D).withValues(alpha: .85),
                  ),
                ),
              ],
            ),
          );
          return Container(
            key: const Key('dashboard-budget-hero'),
            padding: FutureMintTokens.cardPadding(context),
            decoration: BoxDecoration(
              color: dark
                  ? FutureMintTokens.darkSurface
                  : FutureMintTokens.paper,
              borderRadius: BorderRadius.circular(FutureMintTokens.radiusLarge),
              border: Border.all(
                color: dark
                    ? FutureMintTokens.neonPurple.withValues(alpha: .35)
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: dark
                      ? FutureMintTokens.neonPurple.withValues(alpha: .18)
                      : Colors.black12,
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: foreground,
                      ),
                      const SizedBox(width: FutureMintTokens.space2),
                      Text(
                        '本月安心可用',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FutureMintTokens.space3),
                  if (compact) ...[
                    MoneyText(
                      summary.availableMinor,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: const Color(0xFF7CFF4D),
                        fontSize: 44,
                      ),
                    ),
                    const SizedBox(height: FutureMintTokens.space2),
                    Align(alignment: Alignment.centerRight, child: artwork),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: MoneyText(
                            summary.availableMinor,
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: const Color(0xFF7CFF4D),
                              fontSize: 52,
                            ),
                          ),
                        ),
                        artwork,
                      ],
                    ),
                  const SizedBox(height: FutureMintTokens.space3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      key: const Key('dashboard-budget-progress'),
                      height: 14,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: dark
                                  ? FutureMintTokens.darkSurfaceRaised
                                  : FutureMintTokens.tealDark,
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF7CFF4D),
                                    Color(0xFF4EFF6A),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
          );
        },
      ),
    );
  }
}
