import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../state/app_controller.dart';
import 'investment_chart.dart';

class FutureSeedScreen extends StatefulWidget {
  const FutureSeedScreen({super.key});

  @override
  State<FutureSeedScreen> createState() => _FutureSeedScreenState();
}

class _FutureSeedScreenState extends State<FutureSeedScreen> {
  double initial = 4200;
  double monthly = 500;
  double years = 5;
  InvestmentScenarioId selectedId = InvestmentScenarioId.balanced;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final simulation = controller.investmentSimulation;
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
                kicker: 'FutureSeed 教育模擬',
                title: '讓省下來的錢，遇見時間、紀律與風險',
                description: '比較三條合成路徑的成長與下跌，再用 AI 陪讀員看懂現象。這不是報酬預測。',
                accent: FutureMintTokens.teal,
              ),
              const SizedBox(height: FutureMintTokens.space5),
              SoftCard(
                key: const Key('investment-lab-entry'),
                color: Theme.of(context).brightness == Brightness.dark
                    ? FutureMintTokens.darkSurfaceRaised
                    : FutureMintTokens.lavenderSoft,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: FutureMintTokens.space5,
                  runSpacing: FutureMintTokens.space4,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '想實際練習虛擬買賣？',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: FutureMintTokens.space2),
                          const Text('進入投資練習場，使用證交所盤後行情、虛擬資金與市場事件骰子練習配置與風險。'),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          context.go('/future-seed/investment-lab'),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('進入投資練習場'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FutureMintTokens.space5),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 860 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.5;
                  final controls = _Controls(
                    initial: initial,
                    monthly: monthly,
                    years: years,
                    onInitial: controller.busy
                        ? null
                        : (value) => setState(() => initial = value),
                    onMonthly: controller.busy
                        ? null
                        : (value) => setState(() => monthly = value),
                    onYears: controller.busy
                        ? null
                        : (value) => setState(() => years = value),
                    onPreset: controller.busy
                        ? null
                        : (nextInitial, nextMonthly, nextYears) => setState(() {
                            initial = nextInitial;
                            monthly = nextMonthly;
                            years = nextYears;
                          }),
                    onRun: controller.busy
                        ? null
                        : () async {
                            await controller.runInvestmentSimulation(
                              initialAmountMinor: initial.round(),
                              monthlyContributionMinor: monthly.round(),
                              years: years.round(),
                            );
                          },
                  );
                  final results = _SimulationResults(
                    simulation: simulation,
                    selectedId: selectedId,
                    coachReply: controller.coachReply,
                    busy: controller.busy,
                    onSelected: (value) => setState(() => selectedId = value),
                    onAsk: (topic, question, style) => controller.askCoach(
                      topic: topic,
                      question: question,
                      style: style,
                      scenarioId: selectedId,
                    ),
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 320, child: controls),
                        const SizedBox(width: FutureMintTokens.space5),
                        Expanded(child: results),
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
    required this.initial,
    required this.monthly,
    required this.years,
    required this.onInitial,
    required this.onMonthly,
    required this.onYears,
    required this.onRun,
    required this.onPreset,
  });

  final double initial;
  final double monthly;
  final double years;
  final ValueChanged<double>? onInitial;
  final ValueChanged<double>? onMonthly;
  final ValueChanged<double>? onYears;
  final VoidCallback? onRun;
  final void Function(double initial, double monthly, double years)? onPreset;

  @override
  Widget build(BuildContext context) => SoftCard(
    key: const Key('future-seed-controls'),
    borderWidth: 1,
    color: Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.lavenderSoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('你的教育情境', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: FutureMintTokens.space4),
        _SliderField(
          label: '已經省下來',
          valueLabel: formatTwd(initial.round()),
          value: initial,
          min: 0,
          max: 20000,
          step: 500,
          onChanged: onInitial,
        ),
        _SliderField(
          label: '每月持續投入',
          valueLabel: formatTwd(monthly.round()),
          value: monthly,
          min: 100,
          max: 5000,
          step: 100,
          onChanged: onMonthly,
        ),
        _SliderField(
          label: '持續期間',
          valueLabel: '${years.round()} 年',
          value: years,
          min: 1,
          max: 20,
          step: 1,
          onChanged: onYears,
        ),
        const SizedBox(height: FutureMintTokens.space2),
        FilledButton.icon(
          onPressed: onRun,
          icon: const Icon(Icons.show_chart_rounded),
          label: const Text('開始教育試算'),
        ),
        const SizedBox(height: FutureMintTokens.space3),
        Text('快速套用一個情境', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: FutureMintTokens.space2),
        Wrap(
          spacing: FutureMintTokens.space2,
          runSpacing: FutureMintTokens.space2,
          children: [
            ActionChip(
              label: const Text('從零開始'),
              onPressed: onPreset == null ? null : () => onPreset!(0, 300, 3),
            ),
            ActionChip(
              label: const Text('穩定累積'),
              onPressed: onPreset == null
                  ? null
                  : () => onPreset!(4200, 500, 5),
            ),
            ActionChip(
              label: const Text('長期目標'),
              onPressed: onPreset == null ? null : () => onPreset!(0, 1000, 10),
            ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space3),
        Text(
          '不使用真實股票、不下單，也不預測市場。',
          style: Theme.of(context).textTheme.bodySmall,
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
    required this.step,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double>? onChanged;

  double _snap(double nextValue) => (nextValue / step).round() * step;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FutureMintTokens.space4),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            trackShape: const RoundedRectSliderTrackShape(),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.32),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            label: valueLabel,
            semanticFormatterCallback: (_) => '$label，$valueLabel',
            onChanged: onChanged == null
                ? null
                : (nextValue) => onChanged!(_snap(nextValue)),
          ),
        ),
      ],
    ),
  );
}

class _SimulationResults extends StatelessWidget {
  const _SimulationResults({
    required this.simulation,
    required this.selectedId,
    required this.coachReply,
    required this.busy,
    required this.onSelected,
    required this.onAsk,
  });

  final InvestmentSimulation? simulation;
  final InvestmentScenarioId selectedId;
  final CoachReply? coachReply;
  final bool busy;
  final ValueChanged<InvestmentScenarioId> onSelected;
  final void Function(String topic, String question, String style) onAsk;

  @override
  Widget build(BuildContext context) {
    if (simulation == null) {
      return const SoftCard(
        key: Key('future-seed-empty-state'),
        child: Column(
          children: [
            MoneyBuddy(
              size: 72,
              color: FutureMintTokens.sky,
              shape: MoneyBuddyShape.blob,
              excludeSemantics: true,
            ),
            SizedBox(height: FutureMintTokens.space4),
            Text('調整省下的金額與時間，開始比較三條教育路徑。', textAlign: TextAlign.center),
          ],
        ),
      );
    }
    final selected = simulation!.scenarios.firstWhere(
      (scenario) => scenario.id == selectedId,
      orElse: () => simulation!.scenarios.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          borderWidth: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('時間與風險曲線', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: FutureMintTokens.space2),
              const Text('點曲線或下方名稱切換情境。'),
              const SizedBox(height: FutureMintTokens.space4),
              SizedBox(
                height: 280,
                child: InvestmentScenarioChart(
                  scenarios: simulation!.scenarios,
                  selectedId: selected.id,
                  onSelected: onSelected,
                ),
              ),
              const SizedBox(height: FutureMintTokens.space3),
              SegmentedButton<InvestmentScenarioId>(
                showSelectedIcon: false,
                segments: [
                  for (final scenario in simulation!.scenarios)
                    ButtonSegment(
                      value: scenario.id,
                      label: Text(scenario.title),
                    ),
                ],
                selected: {selected.id},
                onSelectionChanged: (value) => onSelected(value.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: FutureMintTokens.space4),
        _ScenarioDetails(scenario: selected),
        const SizedBox(height: FutureMintTokens.space4),
        _AiReadingCompanion(reply: coachReply, busy: busy, onAsk: onAsk),
        const SizedBox(height: FutureMintTokens.space3),
        Text(
          simulation!.disclaimer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ScenarioDetails extends StatelessWidget {
  const _ScenarioDetails({required this.scenario});

  final InvestmentScenario scenario;

  @override
  Widget build(BuildContext context) {
    final events = scenario.yearlyPoints
        .where((point) => point.eventLabel != null)
        .toList();
    return SoftCard(
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : FutureMintTokens.mintSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: FutureMintTokens.space3,
            runSpacing: FutureMintTokens.space2,
            children: [
              Text(
                scenario.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Chip(
                label: Text(
                  '${scenario.assumedAnnualRatePercent}% · ${scenario.riskLabel}',
                ),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(scenario.description),
          const SizedBox(height: FutureMintTokens.space4),
          Wrap(
            spacing: FutureMintTokens.space6,
            runSpacing: FutureMintTokens.space3,
            children: [
              _Metric(label: '投入本金', value: formatTwd(scenario.principalMinor)),
              _Metric(label: '假設成長', value: formatTwd(scenario.growthMinor)),
              _Metric(
                label: '期末可能金額',
                value: formatTwd(scenario.endingBalanceMinor),
              ),
              _Metric(label: '最大回落', value: '${scenario.maxDrawdownPercent}%'),
            ],
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(height: FutureMintTokens.space4),
            for (final point in events)
              Padding(
                padding: const EdgeInsets.only(bottom: FutureMintTokens.space2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.south_east_rounded, size: 20),
                    const SizedBox(width: FutureMintTokens.space2),
                    Expanded(
                      child: Text('第 ${point.year} 年：${point.eventLabel}'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: FutureMintTokens.space1),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}

class _AiReadingCompanion extends StatefulWidget {
  const _AiReadingCompanion({
    required this.reply,
    required this.busy,
    required this.onAsk,
  });

  final CoachReply? reply;
  final bool busy;
  final void Function(String topic, String question, String style) onAsk;

  @override
  State<_AiReadingCompanion> createState() => _AiReadingCompanionState();
}

class _AiReadingCompanionState extends State<_AiReadingCompanion> {
  final _questionController = TextEditingController();
  String _topic = 'risk';
  String _style = 'example';

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _ask() {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;
    widget.onAsk(_topic, question, _style);
  }

  @override
  Widget build(BuildContext context) => SoftCard(
    color: Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.lavenderSoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_outlined),
            const SizedBox(width: FutureMintTokens.space2),
            Expanded(
              child: Text(
                'AI 陪讀員',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space3),
        Wrap(
          spacing: FutureMintTokens.space2,
          runSpacing: FutureMintTokens.space2,
          children: [
            ActionChip(
              label: const Text('為什麼中間掉下去？'),
              onPressed: widget.busy
                  ? null
                  : () {
                      _topic = 'risk';
                      _questionController.text = '為什麼這條線中間掉下去了？';
                      _ask();
                    },
            ),
            ActionChip(
              label: const Text('什麼是分散風險？'),
              onPressed: widget.busy
                  ? null
                  : () {
                      _topic = 'risk';
                      _questionController.text = '什麼是分散風險？';
                      _ask();
                    },
            ),
            ActionChip(
              label: const Text('複利怎麼發生？'),
              onPressed: widget.busy
                  ? null
                  : () {
                      _topic = 'compound';
                      _questionController.text = '複利怎麼發生？';
                      _ask();
                    },
            ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space3),
        Text('也可以直接問：', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: FutureMintTokens.space2),
        Wrap(
          spacing: FutureMintTokens.space2,
          runSpacing: FutureMintTokens.space2,
          children: [
            for (final entry in const {
              'risk': '波動與 ETF',
              'compound': '複利與存錢',
              'general': '我的情境',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _topic == entry.key,
                onSelected: (_) => setState(() => _topic = entry.key),
              ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space3),
        TextField(
          key: const Key('future-seed-coach-question'),
          controller: _questionController,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '自由輸入問題',
            hintText: '例如：如果中間下跌，我應該觀察什麼？',
            helperText: '內容只用於教育解釋，不會產生買賣指令。',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: FutureMintTokens.space2),
        Wrap(
          spacing: FutureMintTokens.space2,
          runSpacing: FutureMintTokens.space2,
          children: [
            for (final entry in const {
              'brief': '一句話重點',
              'example': '生活例子',
              'steps': '一步一步',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _style == entry.key,
                onSelected: (_) => setState(() => _style = entry.key),
              ),
          ],
        ),
        const SizedBox(height: FutureMintTokens.space3),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _questionController,
          builder: (context, value, _) => FilledButton.icon(
            key: const Key('ask-future-seed-coach'),
            onPressed: widget.busy || value.text.trim().isEmpty ? null : _ask,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('請教 AI'),
          ),
        ),
        if (widget.busy) ...[
          const SizedBox(height: FutureMintTokens.space3),
          const LinearProgressIndicator(),
        ],
        if (widget.reply != null) ...[
          const SizedBox(height: FutureMintTokens.space4),
          Text(widget.reply!.answer, key: const Key('future-seed-coach-reply')),
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            '記住：${widget.reply!.takeaway}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Wrap(
            spacing: FutureMintTokens.space2,
            runSpacing: FutureMintTokens.space2,
            children: [
              for (final suggestion in widget.reply!.suggestions)
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () =>
                      setState(() => _questionController.text = suggestion),
                ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            widget.reply!.disclaimer,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}
