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
    final progressTrackColor = dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.tealDark;
    final ratio = summary.monthlyBudgetMinor == 0
        ? 0.0
        : (summary.availableMinor / summary.monthlyBudgetMinor).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label:
          '本月安心可用 ${summary.availableMinor} 元,預算剩餘百分之 ${(ratio * 100).round()}',
      child: Padding(
        padding: const EdgeInsets.only(top: 56, right: 8),
        child: Stack(
          clipBehavior: Clip.none,
          key: const Key('dashboard-budget-hero'),
          children: [
            Container(
              padding: const EdgeInsets.all(FutureMintTokens.space5),
              decoration: BoxDecoration(
                color: dark
                    ? FutureMintTokens.darkSurface
                    : FutureMintTokens.paper,
                borderRadius: BorderRadius.circular(
                  FutureMintTokens.radiusLarge,
                ),
                border: Border.all(
                  color: dark
                      ? FutureMintTokens.neonPurple.withOpacity(.35)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: dark
                        ? FutureMintTokens.neonPurple.withOpacity(.18)
                        : Colors.black12,
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: dark ? theme.colorScheme.onSurface : foreground,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: dark ? theme.colorScheme.onSurface : foreground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '本月安心可用',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: dark ? theme.colorScheme.onSurface : foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: FutureMintTokens.space3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: MoneyText(
                            summary.availableMinor,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: const Color(0xFF7CFF4D),
                                  fontSize: 52,
                                ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-220, 0),
                          child: Image.asset(
                            'assets/images/mascot_yellow.png',
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: FutureMintTokens.space4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 14,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(color: progressTrackColor),
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
                        color: dark ? theme.colorScheme.onSurface : foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -220,
              top: -340,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/blob_purple.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // sparkle decorations around purple blob (enlarged)
            Positioned(
              right: -40,
              top: -330,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 46,
                  color: const Color(0xFF7CFF4D).withOpacity(.9),
                ),
              ),
            ),
            Positioned(
              right: -300,
              top: -290,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 34,
                  color: FutureMintTokens.neonPurple.withOpacity(.9),
                ),
              ),
            ),
            Positioned(
              right: -120,
              top: -160,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: const Color(0xFF7CFF4D).withOpacity(.85),
                ),
              ),
            ),
            Positioned(
              right: -330,
              top: -150,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 24,
                  color: FutureMintTokens.neonPurple.withOpacity(.7),
                ),
              ),
            ),
            // sparkles near yellow blob
            Positioned(
              right: 100,
              top: 145,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 30,
                  color: const Color(0xFF7CFF4D).withOpacity(.85),
                ),
              ),
            ),
            Positioned(
              right: 210,
              top: 110,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 27,
                  color: FutureMintTokens.neonPurple.withOpacity(.75),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -100,
              child: Image.asset(
                'assets/images/mascot_orange.png',
                width: 130,
                height: 130,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
