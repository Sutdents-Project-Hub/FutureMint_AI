import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/date_text.dart';
import '../dashboard/dashboard_screen.dart';

class DraftEditor extends StatefulWidget {
  const DraftEditor({
    super.key,
    required this.draft,
    required this.busy,
    required this.onConfirm,
  });

  final CaptureDraft draft;
  final bool busy;
  final ValueChanged<CaptureDraft> onConfirm;

  @override
  State<DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<DraftEditor> {
  late final amountController = TextEditingController(
    text: widget.draft.amountMinor?.toString() ?? '',
  );
  late final merchantController = TextEditingController(
    text: widget.draft.merchant ?? '',
  );
  late MoneyEventType eventType = widget.draft.type;
  late MoneyCategory category = _normalizedCategory(
    widget.draft.type,
    widget.draft.category,
  );
  late DateTime occurredAt = widget.draft.occurredAt;
  late BillingCycle billingCycle =
      widget.draft.recurrence?.billingCycle ?? BillingCycle.monthly;
  late DateTime? nextBillingAt = widget.draft.recurrence?.nextBillingAt;
  late SpendingIntent spendingIntent =
      widget.draft.spendingIntent ?? SpendingIntent.uncertain;
  late bool splitEnabled = widget.draft.split != null;
  late int participants = widget.draft.split?.participants ?? 2;

  List<MoneyCategory> get availableCategories => switch (eventType) {
    MoneyEventType.income => const [MoneyCategory.income],
    MoneyEventType.subscription => const [MoneyCategory.subscription],
    MoneyEventType.expense =>
      MoneyCategory.values
          .where(
            (item) =>
                item != MoneyCategory.income &&
                item != MoneyCategory.subscription,
          )
          .toList(),
  };

  int? get parsedAmount =>
      int.tryParse(amountController.text.replaceAll(',', '').trim());

  @override
  void dispose() {
    amountController.dispose();
    merchantController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(
      amountController.text.replaceAll(',', '').trim(),
    );
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入大於 0 的整數金額。')));
      return;
    }
    widget.onConfirm(
      widget.draft.copyWith(
        amountMinor: amount,
        merchant: merchantController.text.trim().isEmpty
            ? null
            : merchantController.text.trim(),
        clearMerchant: merchantController.text.trim().isEmpty,
        category: category,
        type: eventType,
        occurredAt: occurredAt,
        recurrence: eventType == MoneyEventType.subscription
            ? RecurrenceDetails(
                billingCycle: billingCycle,
                nextBillingAt: nextBillingAt,
              )
            : null,
        clearRecurrence: eventType != MoneyEventType.subscription,
        split: splitEnabled
            ? SplitDetails(
                participants: participants,
                userShareMinor: (amount / participants).round(),
              )
            : null,
        clearSplit: !splitEnabled,
        spendingIntent: spendingIntent,
      ),
    );
  }

  Future<void> _pickDate() async {
    final taipei = toTaipeiTime(occurredAt);
    final firstDate = DateTime(2020);
    final lastDate = dateOnly(DateTime.now().add(const Duration(days: 366)));
    final selected = await showDatePicker(
      context: context,
      initialDate: clampPickerDate(
        taipei,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected == null || !mounted) return;
    final month = selected.month.toString().padLeft(2, '0');
    final day = selected.day.toString().padLeft(2, '0');
    setState(() {
      occurredAt = DateTime.parse(
        '${selected.year}-$month-${day}T12:00:00+08:00',
      );
    });
  }

  Future<void> _pickNextBillingDate() async {
    final current = nextBillingAt == null
        ? toTaipeiTime(occurredAt).add(const Duration(days: 30))
        : toTaipeiTime(nextBillingAt!);
    final firstDate = dateOnly(DateTime.now());
    final lastDate = dateOnly(DateTime.now().add(const Duration(days: 3660)));
    final selected = await showDatePicker(
      context: context,
      initialDate: clampPickerDate(
        current,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected == null || !mounted) return;
    final month = selected.month.toString().padLeft(2, '0');
    final day = selected.day.toString().padLeft(2, '0');
    setState(() {
      nextBillingAt = DateTime.parse(
        '${selected.year}-$month-${day}T12:00:00+08:00',
      );
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'AI 已整理草稿，尚未保存',
    child: SoftCard(
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : FutureMintTokens.paper,
      borderWidth: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: FutureMintTokens.space3,
            runSpacing: FutureMintTokens.space2,
            children: [
              Text('確認草稿', style: Theme.of(context).textTheme.titleLarge),
              Chip(
                avatar: const Icon(Icons.rule_rounded, size: 16),
                label: Text(
                  widget.draft.source == CaptureSource.liangjieAi
                      ? '量界智算 AI 解析'
                      : '離線規則解析',
                ),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            '解析不會自動存檔，請確認內容後再記下。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            '你可以修改每個欄位。確認後會依你的版本更新分析；這次修正不會自動拿去訓練 AI。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            '解析信心 ${(widget.draft.confidence * 100).round()}%'
            '${widget.draft.missingFields.isEmpty ? '' : ' · 待補：${widget.draft.missingFields.map(_missingFieldLabel).join('、')}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: FutureMintTokens.space5),
          Text('交易基本資料', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: FutureMintTokens.space3),
          TextField(
            controller: amountController,
            enabled: !widget.busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '金額（新台幣）',
              prefixText: 'NT\$ ',
              helperText: '只輸入整數，例如 75',
            ),
            onChanged: widget.busy ? null : (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: merchantController,
            enabled: !widget.busy,
            decoration: const InputDecoration(
              labelText: '項目名稱（可選）',
              hintText: '例如：珍奶',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<MoneyEventType>(
            initialValue: eventType,
            decoration: const InputDecoration(labelText: '交易類型'),
            items: [
              for (final item in MoneyEventType.values)
                DropdownMenuItem(
                  value: item,
                  child: Text(_eventTypeLabel(item)),
                ),
            ],
            onChanged: widget.busy
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      eventType = value;
                      category = switch (value) {
                        MoneyEventType.income => MoneyCategory.income,
                        MoneyEventType.subscription =>
                          MoneyCategory.subscription,
                        MoneyEventType.expense =>
                          category == MoneyCategory.income ||
                                  category == MoneyCategory.subscription
                              ? MoneyCategory.other
                              : category,
                      };
                      if (value == MoneyEventType.income) splitEnabled = false;
                    });
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<MoneyCategory>(
            key: ValueKey(eventType),
            initialValue: category,
            decoration: const InputDecoration(labelText: '分類'),
            items: [
              for (final item in availableCategories)
                DropdownMenuItem(value: item, child: Text(categoryLabel(item))),
            ],
            onChanged: widget.busy
                ? null
                : (value) {
                    if (value != null) setState(() => category = value);
                  },
          ),
          const SizedBox(height: 16),
          ListTile(
            key: const Key('draft-date'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('發生日期'),
            subtitle: Text(formatTaipeiDateTime(occurredAt, includeYear: true)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: widget.busy ? null : _pickDate,
          ),
          if (eventType == MoneyEventType.subscription) ...[
            const SizedBox(height: FutureMintTokens.space5),
            Text('訂閱設定', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: FutureMintTokens.space3),
            DropdownButtonFormField<BillingCycle>(
              initialValue: billingCycle,
              decoration: const InputDecoration(labelText: '計費週期'),
              items: const [
                DropdownMenuItem(
                  value: BillingCycle.monthly,
                  child: Text('月繳'),
                ),
                DropdownMenuItem(value: BillingCycle.yearly, child: Text('年繳')),
              ],
              onChanged: widget.busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => billingCycle = value);
                    },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('下次扣款日（可選）'),
              subtitle: Text(
                nextBillingAt == null
                    ? '未提供'
                    : formatTaipeiDateTime(nextBillingAt!, includeYear: true),
              ),
              trailing: nextBillingAt == null
                  ? const Icon(Icons.calendar_month_outlined)
                  : IconButton(
                      tooltip: '清除下次扣款日',
                      onPressed: widget.busy
                          ? null
                          : () => setState(() => nextBillingAt = null),
                      icon: const Icon(Icons.clear_rounded),
                    ),
              onTap: widget.busy ? null : _pickNextBillingDate,
            ),
          ],
          if (eventType != MoneyEventType.income) ...[
            const SizedBox(height: FutureMintTokens.space5),
            Text('AI 需要／想要建議', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: FutureMintTokens.space2),
            Text(
              widget.draft.intentReason ?? 'AI 無法確定當時情境，最後由你決定。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: FutureMintTokens.space3),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 440 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.3;
                if (compact) {
                  return Wrap(
                    spacing: FutureMintTokens.space2,
                    runSpacing: FutureMintTokens.space2,
                    children: [
                      for (final entry in const [
                        (
                          SpendingIntent.need,
                          '需要',
                          Icons.check_circle_outline_rounded,
                        ),
                        (
                          SpendingIntent.want,
                          '想要',
                          Icons.favorite_border_rounded,
                        ),
                        (
                          SpendingIntent.uncertain,
                          '不確定',
                          Icons.help_outline_rounded,
                        ),
                      ])
                        ChoiceChip(
                          avatar: Icon(entry.$3, size: 18),
                          label: Text(entry.$2),
                          selected: spendingIntent == entry.$1,
                          onSelected: widget.busy
                              ? null
                              : (_) =>
                                    setState(() => spendingIntent = entry.$1),
                        ),
                    ],
                  );
                }
                return SegmentedButton<SpendingIntent>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: SpendingIntent.need,
                      icon: Icon(Icons.check_circle_outline_rounded),
                      label: Text('需要'),
                    ),
                    ButtonSegment(
                      value: SpendingIntent.want,
                      icon: Icon(Icons.favorite_border_rounded),
                      label: Text('想要'),
                    ),
                    ButtonSegment(
                      value: SpendingIntent.uncertain,
                      icon: Icon(Icons.help_outline_rounded),
                      label: Text('不確定'),
                    ),
                  ],
                  selected: {spendingIntent},
                  onSelectionChanged: widget.busy
                      ? null
                      : (value) => setState(() => spendingIntent = value.first),
                );
              },
            ),
            const SizedBox(height: FutureMintTokens.space5),
            Text('分帳設定', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: FutureMintTokens.space2),
            SwitchListTile(
              key: const Key('split-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('這筆需要分帳'),
              subtitle: const Text('系統會以確定性算式重算你的負擔'),
              value: splitEnabled,
              onChanged: widget.busy
                  ? null
                  : (value) => setState(() => splitEnabled = value),
            ),
            if (splitEnabled) ...[
              DropdownButtonFormField<int>(
                initialValue: participants,
                decoration: const InputDecoration(labelText: '分帳人數'),
                items: [
                  for (var count = 2; count <= 20; count += 1)
                    DropdownMenuItem(value: count, child: Text('$count 人')),
                ],
                onChanged: widget.busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => participants = value);
                      },
              ),
              const SizedBox(height: 8),
              Text(
                parsedAmount == null || parsedAmount! <= 0
                    ? '輸入金額後會顯示每人負擔。'
                    : '你的負擔約為 NT\$ ${(parsedAmount! / participants).round()}',
              ),
            ],
          ],
          const SizedBox(height: FutureMintTokens.space5),
          FilledButton.icon(
            onPressed: widget.busy ? null : _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('確認並記下'),
          ),
        ],
      ),
    ),
  );
}

String _eventTypeLabel(MoneyEventType type) => switch (type) {
  MoneyEventType.income => '收入',
  MoneyEventType.expense => '支出',
  MoneyEventType.subscription => '訂閱',
};

MoneyCategory _normalizedCategory(
  MoneyEventType type,
  MoneyCategory category,
) => switch (type) {
  MoneyEventType.income => MoneyCategory.income,
  MoneyEventType.subscription => MoneyCategory.subscription,
  MoneyEventType.expense =>
    category == MoneyCategory.income || category == MoneyCategory.subscription
        ? MoneyCategory.other
        : category,
};

String _missingFieldLabel(String field) => switch (field) {
  'amountMinor' => '金額',
  'occurredAt' => '日期',
  'recurrence' => '計費週期',
  'split' => '分帳',
  _ => '其他內容',
};
