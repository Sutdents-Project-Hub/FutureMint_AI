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
      child: SizedBox(
        key: const Key('dashboard-budget-hero'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // outer card
            Container(
              padding: const EdgeInsets.all(FutureMintTokens.space5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: dark
                      ? [Color(0xFF12101A), Color(0xFF241B34)]
                      : [FutureMintTokens.mint, FutureMintTokens.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(FutureMintTokens.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: dark ? const Color(0xFF7B6BFF).withOpacity(.12) : Colors.black12,
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                // inner neon panel
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF241F34) : FutureMintTokens.paper,
                  borderRadius: BorderRadius.circular(FutureMintTokens.radiusLarge - 6),
                  border: Border.all(
                    color: dark ? FutureMintTokens.neonPurple.withOpacity(.28) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                padding: const EdgeInsets.all(FutureMintTokens.space5),
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
                          // placeholder for top-right blob is positioned separately
                          const SizedBox(width: 96),
                        ],
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: MoneyText(
                              summary.availableMinor,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: const Color(0xFF7CFF4D), // neon green
                                fontSize: 52,
                              ),
                            ),
                          ),
                          // yellow flower mascot from assets for pixel-accurate look
                          Image.asset(
                            'assets/images/mascot_yellow.png',
                            width: 110,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                      const SizedBox(height: FutureMintTokens.space4),
                      // neon progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 14,
                          color: dark ? const Color(0xFF101018) : FutureMintTokens.mint,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(color: progressTrackColor),
                              ),
                              FractionallySizedBox(
                                widthFactor: ratio,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [const Color(0xFF7CFF4D), const Color(0xFF4EFF6A)]),
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
              ),
            ),
            // purple blob positioned top-right (use provided image for pixel match)
            Positioned(
              right: -24,
              top: -40,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: FutureMintTokens.neonPurple.withOpacity(.35),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ],
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/blob_purple.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // small orange mascot bottom-right (asset)
            Positioned(
              right: -8,
              bottom: -12,
              child: Transform.translate(
                offset: const Offset(12, 12),
                child: Image.asset(
                  'assets/images/mascot_orange.png',
                  width: 68,
                  height: 68,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
