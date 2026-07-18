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
    final foreground = const Color(0xFFF9F4FF);
    final ratio = summary.monthlyBudgetMinor == 0
        ? 0.0
        : (summary.availableMinor / summary.monthlyBudgetMinor).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label:
          '本月安心可用 ${summary.availableMinor} 元，預算剩餘百分之 ${(ratio * 100).round()}',
      child: SizedBox(
        width: double.infinity,
        key: const Key('dashboard-budget-hero'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 340),
              padding: const EdgeInsets.all(FutureMintTokens.space4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF121121), Color(0xFF261C3F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: FutureMintTokens.neonPurple.withOpacity(.35),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B6BFF).withOpacity(.12),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/hero_purple.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Image.asset(
                      'assets/images/clipboard_teal.jpg',
                      width: 58,
                      height: 58,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: 10,
                    child: Image.asset(
                      'assets/images/bars_purple.jpg',
                      width: 112,
                      height: 112,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -16,
                    child: Image.asset(
                      'assets/images/mascot_yellow.jpg',
                      width: 104,
                      height: 104,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: foreground),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: foreground,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '本月安心可用',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MoneyText(
                                      summary.availableMinor,
                                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        color: const Color(0xFF7CFF4D),
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        height: 1.02,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '月預算 ${formatTwd(summary.monthlyBudgetMinor)} · 已支出 ${formatTwd(summary.expenseMinor + summary.subscriptionMinor)}',
                                      style: const TextStyle(
                                        color: Color(0xFFF4ECFF),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Image.asset(
                                'assets/images/mascot_orange.jpg',
                                width: 70,
                                height: 70,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF191724),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      color: const Color(0xFF2B2542),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: ratio,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF7CFF4D), Color(0xFF4EFF6A)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: -10,
              top: -12,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/blob_purple.jpg',
                  width: 102,
                  height: 102,
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
