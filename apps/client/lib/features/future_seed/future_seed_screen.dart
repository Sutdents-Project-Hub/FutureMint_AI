import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../state/app_controller.dart';

class FutureSeedScreen extends StatefulWidget {
  const FutureSeedScreen({super.key});

  @override
  State<FutureSeedScreen> createState() => _FutureSeedScreenState();
}

class _FutureSeedScreenState extends State<FutureSeedScreen> {
  double monthly = 500;
  double years = 5;
  double rate = 3;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final preview = controller.futureSeedPreview;
    final gutter = FutureMintTokens.pageGutter(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        FutureMintTokens.space5,
        gutter,
        FutureMintTokens.space7,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FutureMintTokens.contentCanvas,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeading(
                kicker: 'FutureSeed 教育試算',
                title: '讓小小的累積，長出未來',
                description: '調整假設，看看本金和可能成長的差別。這不是報酬預測。',
                accent: FutureMintTokens.sun,
              ),
              const SizedBox(height: FutureMintTokens.space5),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 820 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.5;
                  final controls = _Controls(
                    monthly: monthly,
                    years: years,
                    rate: rate,
                    onMonthly: (value) => setState(() => monthly = value),
                    onYears: (value) => setState(() => years = value),
                    onRate: (value) => setState(() => rate = value),
                    onPreview: controller.busy
                        ? null
                        : () => controller.previewFutureSeed(
                            monthlyContributionMinor: monthly.round(),
                            years: years.round(),
                            annualRatePercent: rate,
                          ),
                  );
                  final results = _Results(preview: preview);
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: controls),
                        const SizedBox(width: FutureMintTokens.space5),
                        Expanded(flex: 6, child: results),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      controls,
                      const SizedBox(height: FutureMintTokens.space5),
                      results,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.monthly,
    required this.years,
    required this.rate,
    required this.onMonthly,
    required this.onYears,
    required this.onRate,
    required this.onPreview,
  });
  final double monthly;
  final double years;
  final double rate;
  final ValueChanged<double> onMonthly;
  final ValueChanged<double> onYears;
  final ValueChanged<double> onRate;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) => SoftCard(
    key: const Key('future-seed-controls'),
    color: Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.sunSoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('你的假設', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: FutureMintTokens.space5),
        _SliderField(
          label: '每月累積',
          valueLabel: formatTwd(monthly.round()),
          value: monthly,
          min: 100,
          max: 5000,
          divisions: 49,
          onChanged: onMonthly,
        ),
        _SliderField(
          label: '持續期間',
          valueLabel: '${years.round()} 年',
          value: years,
          min: 1,
          max: 20,
          divisions: 19,
          onChanged: onYears,
        ),
        _SliderField(
          label: '假設年化率',
          valueLabel: '${rate.toStringAsFixed(1)}%',
          value: rate,
          min: 0,
          max: 8,
          divisions: 16,
          onChanged: onRate,
        ),
        const SizedBox(height: FutureMintTokens.space3),
        FilledButton.icon(
          onPressed: onPreview,
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('開始教育試算'),
        ),
      ],
    ),
  );
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FutureMintTokens.space4),
    child: Column(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: FutureMintTokens.space3,
          runSpacing: FutureMintTokens.space1,
          children: [
            Text(label),
            Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results({required this.preview});
  final FutureSeedPreview? preview;

  @override
  Widget build(BuildContext context) {
    if (preview == null) {
      return SoftCard(
        key: const Key('future-seed-empty-state'),
        color: Theme.of(context).brightness == Brightness.dark
            ? FutureMintTokens.darkSurfaceRaised
            : FutureMintTokens.skySoft,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyBuddy(
              size: 72,
              color: FutureMintTokens.sky,
              shape: MoneyBuddyShape.blob,
              excludeSemantics: true,
            ),
            SizedBox(height: FutureMintTokens.space4),
            Text('調整條件，看看累積的可能樣貌。', textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return SoftCard(
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : FutureMintTokens.mintSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('試算結果', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: FutureMintTokens.space4),
          Wrap(
            spacing: FutureMintTokens.space6,
            runSpacing: 16,
            children: [
              _ResultMetric(label: '投入本金', amount: preview!.principalMinor),
              _ResultMetric(label: '假設成長', amount: preview!.growthMinor),
              _ResultMetric(
                label: '期末可能金額',
                amount: preview!.endingBalanceMinor,
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space5),
          Text(
            '每年累積',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: FutureMintTokens.space3),
          for (final point in preview!.yearlyPoints)
            _YearBar(point: point, max: preview!.endingBalanceMinor),
          const SizedBox(height: 16),
          Text(
            preview!.disclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });
  final String label;
  final int amount;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: FutureMintTokens.space1),
      MoneyText(
        amount,
        style:
            (emphasized
                    ? Theme.of(context).textTheme.headlineSmall
                    : Theme.of(context).textTheme.titleLarge)
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasized
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
      ),
    ],
  );
}

class _YearBar extends StatelessWidget {
  const _YearBar({required this.point, required this.max});
  final FutureSeedYearPoint point;
  final int max;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FutureMintTokens.space2),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow =
            constraints.maxWidth < 420 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        final progress = ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: point.balanceMinor / max,
            minHeight: FutureMintTokens.space2,
            color: Theme.of(context).brightness == Brightness.dark
                ? FutureMintTokens.lavender
                : FutureMintTokens.teal,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? FutureMintTokens.darkSurface
                : FutureMintTokens.paper,
          ),
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: FutureMintTokens.space3,
                runSpacing: FutureMintTokens.space1,
                children: [
                  Text('${point.year} 年'),
                  Text(formatTwd(point.balanceMinor)),
                ],
              ),
              const SizedBox(height: FutureMintTokens.space2),
              progress,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 48, child: Text('${point.year} 年')),
            Expanded(child: progress),
            const SizedBox(width: FutureMintTokens.space3),
            SizedBox(
              width: 112,
              child: Text(
                formatTwd(point.balanceMinor),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      },
    ),
  );
}
