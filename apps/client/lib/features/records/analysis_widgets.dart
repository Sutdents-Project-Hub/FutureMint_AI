import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';

class CashflowAnalysis extends StatelessWidget {
  const CashflowAnalysis({super.key, required this.insights});

  final FinancialInsights insights;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SoftCard(
        key: const Key('cashflow-analysis-chart'),
        borderWidth: 1,
        color: Theme.of(context).brightness == Brightness.dark
            ? FutureMintTokens.darkSurfaceRaised
            : FutureMintTokens.paper,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: FutureMintTokens.space3,
              runSpacing: FutureMintTokens.space2,
              children: [
                Text('近六個月收支', style: Theme.of(context).textTheme.titleLarge),
                const Wrap(
                  spacing: FutureMintTokens.space3,
                  children: [
                    _Legend(color: FutureMintTokens.teal, label: '收入'),
                    _Legend(color: FutureMintTokens.coral, label: '支出＋訂閱'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: FutureMintTokens.space4),
            SizedBox(
              height: 220,
              child: _CashflowChart(points: insights.monthlyCashflow),
            ),
            const SizedBox(height: FutureMintTokens.space3),
            Text(insights.summary),
          ],
        ),
      ),
      const SizedBox(height: FutureMintTokens.space4),
      SoftCard(
        borderWidth: 1,
        color: Theme.of(context).brightness == Brightness.dark
            ? FutureMintTokens.darkSurfaceRaised
            : FutureMintTokens.skySoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('本月選擇分析', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: FutureMintTokens.space4),
            _IntentBar(
              label: '需要',
              amount: insights.needMinor,
              total:
                  insights.needMinor +
                  insights.wantMinor +
                  insights.uncertainMinor,
              color: FutureMintTokens.teal,
            ),
            _IntentBar(
              label: '想要',
              amount: insights.wantMinor,
              total:
                  insights.needMinor +
                  insights.wantMinor +
                  insights.uncertainMinor,
              color: FutureMintTokens.coral,
            ),
            _IntentBar(
              label: '不確定',
              amount: insights.uncertainMinor,
              total:
                  insights.needMinor +
                  insights.wantMinor +
                  insights.uncertainMinor,
              color: FutureMintTokens.sun,
            ),
            const SizedBox(height: FutureMintTokens.space2),
            Text(
              '這是協助回想情境的分類，不是對孩子消費的評分。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

class _CashflowChart extends StatelessWidget {
  const _CashflowChart({required this.points});

  final List<MonthlyCashflowPoint> points;

  @override
  Widget build(BuildContext context) {
    final largest = points.fold<int>(0, (value, point) {
      return max(
        value,
        max(point.incomeMinor, point.expenseMinor + point.subscriptionMinor),
      );
    });
    final maxY = max(100, largest * 1.2).toDouble();
    return Semantics(
      label: '近六個月收入與支出長條圖',
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: true),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(points[index].month.substring(5)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var index = 0; index < points.length; index++)
              BarChartGroupData(
                x: index,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: points[index].incomeMinor.toDouble(),
                    color: FutureMintTokens.teal,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                  BarChartRodData(
                    toY:
                        (points[index].expenseMinor +
                                points[index].subscriptionMinor)
                            .toDouble(),
                    color: FutureMintTokens.coral,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

class _IntentBar extends StatelessWidget {
  const _IntentBar({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
  });

  final String label;
  final int amount;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FutureMintTokens.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            MoneyText(
              amount,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space1),
        LinearProgressIndicator(
          value: total == 0 ? 0 : amount / total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: color,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
        ),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
