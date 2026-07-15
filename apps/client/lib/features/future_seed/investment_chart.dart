import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../design/tokens.dart';

class InvestmentScenarioChart extends StatelessWidget {
  const InvestmentScenarioChart({
    super.key,
    required this.scenarios,
    required this.selectedId,
    required this.onSelected,
  });

  final List<InvestmentScenario> scenarios;
  final InvestmentScenarioId selectedId;
  final ValueChanged<InvestmentScenarioId> onSelected;

  static const colors = [
    FutureMintTokens.teal,
    FutureMintTokens.sky,
    FutureMintTokens.coral,
  ];

  @override
  Widget build(BuildContext context) {
    final maxBalance = scenarios
        .expand((scenario) => scenario.yearlyPoints)
        .fold<int>(0, (value, point) => max(value, point.balanceMinor));
    final maxYears = scenarios.fold<int>(
      1,
      (value, scenario) => max(value, scenario.yearlyPoints.last.year),
    );
    return Semantics(
      label: '三種教育情境的資產變化曲線，可點選切換',
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxYears.toDouble(),
          minY: 0,
          maxY: max(100, maxBalance * 1.15).toDouble(),
          lineTouchData: LineTouchData(
            enabled: true,
            touchCallback: (event, response) {
              final spots = response?.lineBarSpots;
              if (!event.isInterestedForInteractions ||
                  spots == null ||
                  spots.isEmpty) {
                return;
              }
              onSelected(scenarios[spots.first.barIndex].id);
            },
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: max(100, maxBalance * 1.15) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
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
              axisNameWidget: const Text('年'),
              sideTitles: SideTitles(
                showTitles: true,
                interval: max(1, (maxYears / 5).ceil()).toDouble(),
                reservedSize: 28,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${value.toInt()}'),
                ),
              ),
            ),
          ),
          lineBarsData: [
            for (var index = 0; index < scenarios.length; index++)
              LineChartBarData(
                spots: [
                  for (final point in scenarios[index].yearlyPoints)
                    FlSpot(
                      point.year.toDouble(),
                      point.balanceMinor.toDouble(),
                    ),
                ],
                color: colors[index],
                barWidth: scenarios[index].id == selectedId ? 5 : 3,
                isCurved: true,
                dotData: FlDotData(show: scenarios[index].id == selectedId),
                belowBarData: BarAreaData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}
