import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../../../design/tokens.dart';
import '../../../shared/money_text.dart';

class BudgetHero extends StatelessWidget {
  const BudgetHero({super.key, required this.summary});

  final DashboardSummary summary;

  static const _neonGreen = Color(0xFF7CFF4D);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ratio = summary.monthlyBudgetMinor == 0
        ? 0.0
        : (summary.availableMinor / summary.monthlyBudgetMinor).clamp(0.0, 1.0);
    // Light mode uses the indigo Hero surface from MASTER.md, so both themes
    // keep light foreground text on a dark, high-contrast budget card.
    final foreground = dark
        ? theme.colorScheme.onSurface
        : FutureMintTokens.paper;
    return Semantics(
      container: true,
      label:
          '本月安心可用 ${summary.availableMinor} 元，預算剩餘百分之 ${(ratio * 100).round()}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
          final compact = constraints.maxWidth < 580 || largeText;
          final phoneRow = compact && !largeText;
          final artwork = SizedBox(
            width: phoneRow ? 112 : (compact ? 158 : 180),
            height: phoneRow ? 112 : (compact ? 140 : 164),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/images/mascot_yellow.png',
                    key: const Key('dashboard-mascot'),
                    width: phoneRow ? 100 : (compact ? 130 : 154),
                    height: phoneRow ? 100 : (compact ? 130 : 154),
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                Positioned(
                  left: phoneRow ? 0 : (compact ? 12 : 18),
                  top: phoneRow ? 6 : (compact ? 48 : 54),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: phoneRow ? 18 : (compact ? 23 : 28),
                    color: FutureMintTokens.neonPurple.withValues(alpha: .8),
                  ),
                ),
                if (!phoneRow)
                  Positioned(
                    right: compact ? 112 : 126,
                    bottom: compact ? 18 : 26,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: compact ? 20 : 24,
                      color: _neonGreen.withValues(alpha: .85),
                    ),
                  ),
              ],
            ),
          );
          final label = Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: foreground),
              const SizedBox(width: FutureMintTokens.space2),
              Flexible(
                child: Text(
                  '本月安心可用',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );
          final remaining = Text(
            '預算還剩 ${(ratio * 100).round()}%',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground.withValues(alpha: .82),
              fontWeight: FontWeight.w600,
            ),
          );
          Widget amount(double size) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              summary.availableMinor,
              style: theme.textTheme.displaySmall?.copyWith(
                color: _neonGreen,
                fontSize: size,
              ),
            ),
          );
          final Widget top;
          if (phoneRow) {
            top = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label,
                      const SizedBox(height: FutureMintTokens.space3),
                      amount(40),
                      const SizedBox(height: FutureMintTokens.space1),
                      remaining,
                    ],
                  ),
                ),
                artwork,
              ],
            );
          } else if (compact) {
            top = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: FutureMintTokens.space3),
                amount(44),
                const SizedBox(height: FutureMintTokens.space2),
                Align(alignment: Alignment.centerRight, child: artwork),
              ],
            );
          } else {
            top = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: FutureMintTokens.space3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: amount(52)),
                    artwork,
                  ],
                ),
              ],
            );
          }
          return Container(
            key: const Key('dashboard-budget-hero'),
            padding: FutureMintTokens.cardPadding(context),
            decoration: BoxDecoration(
              color: dark ? FutureMintTokens.darkSurface : null,
              gradient: dark
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FutureMintTokens.teal,
                        FutureMintTokens.tealDark,
                      ],
                    ),
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
                      : FutureMintTokens.teal.withValues(alpha: .28),
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
                  top,
                  SizedBox(
                    height: phoneRow
                        ? FutureMintTokens.space4
                        : FutureMintTokens.space3,
                  ),
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
                                  : Colors.white.withValues(alpha: .18),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_neonGreen, Color(0xFF4EFF6A)],
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
