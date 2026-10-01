import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../shared/date_text.dart';
import '../../state/app_controller.dart';
import '../capture/draft_editor.dart';
import '../dashboard/dashboard_screen.dart';
import 'analysis_widgets.dart';

enum _RecordFilter { all, expense, income, subscription }

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  _RecordFilter filter = _RecordFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final events =
        controller.events
            .where(
              (event) => switch (filter) {
                _RecordFilter.all => true,
                _RecordFilter.expense => event.type == MoneyEventType.expense,
                _RecordFilter.income => event.type == MoneyEventType.income,
                _RecordFilter.subscription =>
                  event.type == MoneyEventType.subscription,
              },
            )
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final gutter = FutureMintTokens.pageGutter(context);
    return RefreshIndicator(
      onRefresh: controller.refreshWithFeedback,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          gutter,
          FutureMintTokens.space5,
          gutter,
          FutureMintTokens.space7,
        ),
        children: [
          ResponsivePageCanvas(
            compactMaxWidth: FutureMintTokens.contentReading,
            child: Column(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _RecordsHeadingArtwork(),
                    const SizedBox(height: FutureMintTokens.space5),
                    if (controller.insights != null) ...[
                      // Soft brand glow behind the analysis in the dark theme.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            if (FutureMintTokens.isDark(context))
                              BoxShadow(
                                color: FutureMintTokens.neonPurple.withValues(
                                  alpha: .14,
                                ),
                                blurRadius: 36,
                              ),
                          ],
                        ),
                        child: CashflowAnalysis(insights: controller.insights!),
                      ),
                      const SizedBox(height: FutureMintTokens.space6),
                    ],
                    Text('交易明細', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: FutureMintTokens.space3),
                    LayoutBuilder(
                      builder: (context, filterConstraints) {
                        final compact =
                            filterConstraints.maxWidth < 440 ||
                            MediaQuery.textScalerOf(context).scale(1) >= 1.3;
                        if (compact) {
                          return Wrap(
                            spacing: FutureMintTokens.space2,
                            runSpacing: FutureMintTokens.space2,
                            children: [
                              for (final entry in const [
                                (_RecordFilter.all, '全部'),
                                (_RecordFilter.expense, '支出'),
                                (_RecordFilter.income, '收入'),
                                (_RecordFilter.subscription, '訂閱'),
                              ])
                                ChoiceChip(
                                  label: Text(entry.$2),
                                  selected: filter == entry.$1,
                                  onSelected: (_) =>
                                      setState(() => filter = entry.$1),
                                ),
                            ],
                          );
                        }
                        return SegmentedButton<_RecordFilter>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _RecordFilter.all,
                              label: Text('全部'),
                            ),
                            ButtonSegment(
                              value: _RecordFilter.expense,
                              label: Text('支出'),
                            ),
                            ButtonSegment(
                              value: _RecordFilter.income,
                              label: Text('收入'),
                            ),
                            ButtonSegment(
                              value: _RecordFilter.subscription,
                              label: Text('訂閱'),
                            ),
                          ],
                          selected: {filter},
                          onSelectionChanged: (value) =>
                              setState(() => filter = value.first),
                        );
                      },
                    ),
                    const SizedBox(height: FutureMintTokens.space4),
                    SoftCard(
                      key: const Key('records-list-surface'),
                      borderWidth: 1,
                      padding: EdgeInsets.zero,
                      child: events.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(FutureMintTokens.space5),
                              child: Center(child: Text('這個分類還沒有紀錄。')),
                            )
                          : Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < events.length;
                                  index++
                                ) ...[
                                  _RecordRow(event: events[index]),
                                  if (index != events.length - 1)
                                    const Divider(height: 1),
                                ],
                              ],
                            ),
                    ),
                    if (controller.nextEventsCursor != null)
                      TextButton.icon(
                        key: const Key('load-more-records'),
                        onPressed: controller.busy
                            ? null
                            : controller.loadMoreEvents,
                        icon: const Icon(Icons.expand_more),
                        label: Text(controller.busy ? '載入中…' : '載入更多紀錄'),
                      ),
                    // The illustration band closes the list as a card footer,
                    // so filters lead straight into the transactions.
                    const SizedBox(height: FutureMintTokens.space4),
                    const _RecordsListArtwork(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsHeadingArtwork extends StatelessWidget {
  const _RecordsHeadingArtwork();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
      final compact = constraints.maxWidth < 520 || largeText;
      const heading = PageHeading(
        kicker: '分析優先的金錢時間軸',
        title: '先看模式，再看每一筆',
        description: '收支、需要與想要會先整理成趨勢；下方仍保留所有確認紀錄。',
        accent: FutureMintTokens.skyInk,
      );
      if (compact && !largeText) {
        // Phone: mascot and coins share a column beside the heading.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: heading),
            const SizedBox(width: FutureMintTokens.space2),
            SizedBox(
              width: 100,
              height: 112,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Image.asset(
                      'assets/images/mascot_history_purple.png',
                      width: 92,
                      height: 92,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Transform.rotate(
                      angle: -0.15,
                      child: Image.asset(
                        'assets/images/icon_coins_gold.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }
      final artwork = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/mascot_history_purple.png',
            width: compact ? 108 : 132,
            height: compact ? 108 : 132,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: FutureMintTokens.space1),
          Transform.rotate(
            angle: -0.15,
            child: Image.asset(
              'assets/images/icon_coins_gold.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ],
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: FutureMintTokens.space2),
            Align(alignment: Alignment.centerRight, child: artwork),
            const _RecordsSparkleStrip(),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: heading),
              const SizedBox(width: FutureMintTokens.space3),
              artwork,
            ],
          ),
          const _RecordsSparkleStrip(),
        ],
      );
    },
  );
}

class _RecordsListArtwork extends StatelessWidget {
  const _RecordsListArtwork();

  @override
  Widget build(BuildContext context) {
    final phone =
        MediaQuery.sizeOf(context).width < FutureMintTokens.railBreakpoint;
    final scale = phone ? .72 : 1.0;
    Widget art(String name, double size, [double angle = 0]) =>
        Transform.rotate(
          angle: angle,
          child: Image.asset(
            'assets/images/$name.png',
            width: size * scale,
            height: size * scale,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        );
    return Align(
      alignment: phone ? Alignment.center : Alignment.centerRight,
      child: Wrap(
        spacing: FutureMintTokens.space2,
        runSpacing: FutureMintTokens.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          art('icon_coins_gold', 54, -0.18),
          art('mascot_history_green', 152),
          art('icon_moneybag_gold', 74, 0.1),
          art('icon_bill_gold', 54, 0.25),
        ],
      ),
    );
  }
}

class _RecordsSparkleStrip extends StatelessWidget {
  const _RecordsSparkleStrip();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.only(top: FutureMintTokens.space1),
      child: Wrap(
        spacing: FutureMintTokens.space2,
        children: const [
          Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white54),
          Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white38),
          Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white54),
        ],
      ),
    ),
  );
}

enum _RecordAction { edit, delete }

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.event});
  final MoneyEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = FutureMintTokens.isDark(context);
    final income = event.type == MoneyEventType.income;
    final title = event.merchant ?? categoryLabel(event.category);
    final accent = income
        ? FutureMintTokens.mint
        : event.type == MoneyEventType.subscription
        ? FutureMintTokens.lavender
        : FutureMintTokens.coral;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    final titleText = Text(
      title,
      maxLines: largeText ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
    final amountText = MoneyText(
      income ? event.effectiveAmountMinor : -event.effectiveAmountMinor,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: income ? FutureMintTokens.brandInk(context) : null,
      ),
    );
    final meta = [
      categoryLabel(event.category),
      if (event.spendingIntent != null) _intentLabel(event.spendingIntent!),
      if (event.split != null) '${event.split!.participants} 人分帳',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FutureMintTokens.space4,
        FutureMintTokens.space3,
        FutureMintTokens.space1,
        FutureMintTokens.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: dark
                ? accent.withValues(alpha: .22)
                : income
                ? FutureMintTokens.mintSoft
                : event.type == MoneyEventType.subscription
                ? FutureMintTokens.lavenderSoft
                : FutureMintTokens.coralSoft,
            foregroundColor: dark
                ? Color.lerp(accent, Colors.white, .35)
                : FutureMintTokens.ink,
            child: Icon(_categoryIcon(event), size: 22),
          ),
          const SizedBox(width: FutureMintTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large text stacks the amount under the title instead of
                // squeezing both into one line.
                if (largeText) ...[
                  titleText,
                  amountText,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: titleText),
                      const SizedBox(width: FutureMintTokens.space2),
                      amountText,
                    ],
                  ),
                const SizedBox(height: FutureMintTokens.space1),
                Text(
                  meta,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatTaipeiDateTime(event.occurredAt, includeYear: true),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<_RecordAction>(
            tooltip: '交易操作：$title',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) => switch (action) {
              _RecordAction.edit => _showEditEventSheet(context, event),
              _RecordAction.delete => _showDeleteEventDialog(context, event),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _RecordAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('編輯'),
                ),
              ),
              PopupMenuItem(
                value: _RecordAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('刪除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

CaptureDraft _draftFromEvent(MoneyEvent event) => CaptureDraft(
  draftId: 'edit-${event.id}',
  type: event.type,
  amountMinor: event.amountMinor,
  currency: event.currency,
  category: event.category,
  merchant: event.merchant,
  occurredAt: event.occurredAt,
  recurrence: event.recurrence,
  subscriptionId: event.subscriptionId,
  split: event.split,
  spendingIntent: event.spendingIntent,
  intentReason: event.intentReason,
  confidence: 1,
  missingFields: const [],
  needsConfirmation: true,
  source: event.source ?? CaptureSource.manual,
);

Future<void> _showEditEventSheet(BuildContext context, MoneyEvent event) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppController>(),
        child: _EventEditorSheet(event: event),
      ),
    );

class _EventEditorSheet extends StatelessWidget {
  const _EventEditorSheet({required this.event});
  final MoneyEvent event;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          FutureMintTokens.space5,
          FutureMintTokens.space1,
          FutureMintTokens.space5,
          FutureMintTokens.space6 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DraftEditor(
                  draft: _draftFromEvent(event),
                  editing: true,
                  busy: controller.busy,
                  onConfirm: (draft) async {
                    final saved = await controller.updateMoneyEvent(
                      event.id,
                      draft,
                    );
                    if (saved && context.mounted) Navigator.pop(context);
                  },
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: FutureMintTokens.space3),
                  Text(
                    controller.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showDeleteEventDialog(
  BuildContext context,
  MoneyEvent event,
) async {
  final controller = context.read<AppController>();
  var deleting = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('刪除這筆紀錄？'),
        content: Text(
          '確定刪除「${event.merchant ?? categoryLabel(event.category)}」${formatTwd(event.effectiveAmountMinor)}？此動作無法復原，預算與分析會重新整理。',
        ),
        actions: [
          TextButton(
            onPressed: deleting ? null : () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: deleting
                ? null
                : () async {
                    setDialogState(() {
                      deleting = true;
                      error = null;
                    });
                    final deleted = await controller.deleteMoneyEvent(event.id);
                    if (!context.mounted) return;
                    if (deleted) {
                      Navigator.pop(dialogContext);
                      return;
                    }
                    setDialogState(() {
                      deleting = false;
                      error = controller.errorMessage;
                    });
                  },
            icon: deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(deleting ? '正在刪除…' : '確認刪除'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: FutureMintTokens.space2),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}

String _intentLabel(SpendingIntent intent) => switch (intent) {
  SpendingIntent.need => '需要',
  SpendingIntent.want => '想要',
  SpendingIntent.uncertain => '不確定',
};

IconData _categoryIcon(MoneyEvent event) {
  if (event.type == MoneyEventType.income) return Icons.payments_rounded;
  if (event.type == MoneyEventType.subscription) {
    return Icons.autorenew_rounded;
  }
  final label = categoryLabel(event.category);
  if (label.contains('娛樂') || label.contains('遊戲')) {
    return Icons.sports_esports_rounded;
  }
  if (label.contains('餐飲') || label.contains('飲') || label.contains('食')) {
    return Icons.local_cafe_rounded;
  }
  if (label.contains('交通')) return Icons.directions_bus_filled_rounded;
  if (label.contains('購物')) return Icons.shopping_bag_rounded;
  if (label.contains('醫療') || label.contains('健康')) {
    return Icons.favorite_rounded;
  }
  if (label.contains('教育') || label.contains('學')) {
    return Icons.school_rounded;
  }
  return Icons.remove_rounded;
}
