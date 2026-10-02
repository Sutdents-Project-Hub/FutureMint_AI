import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../state/app_controller.dart';
import 'draft_editor.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _draftKey = GlobalKey();

  @override
  void dispose() {
    inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _parse(AppController controller) async {
    if (controller.busy) return;
    final text = inputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先輸入一筆收入、支出或訂閱。')));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.parseCapture(text);
    _showDraft();
  }

  void _showDraft() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final draftContext = _draftKey.currentContext;
      if (draftContext != null) {
        Scrollable.ensureVisible(draftContext, alignment: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final result = controller.captureResult;
    final saved = controller.lastSavedEvent;
    final drafts = result?.drafts ?? const [];
    final hasDrafts = drafts.isNotEmpty;
    final gutter = FutureMintTokens.pageGutter(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    const heading = PageHeading(
      kicker: '快速記一筆',
      title: '用一句話記下收支',
      description: 'FutureMint 先整理成草稿，只有你按下確認後才會保存。',
      accent: FutureMintTokens.teal,
    );
    final headingArtwork = Image.asset(
      'assets/images/mascot_note_star.png',
      width: 72,
      height: 72,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    final inputCard = SoftCard(
      key: const Key('capture-hero'),
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : hasDrafts
          ? FutureMintTokens.paper
          : FutureMintTokens.mintSoft,
      borderWidth: hasDrafts ? 1 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The helper mascot shares the intro row; once drafts exist
          // it gets smaller so emphasis moves to the first draft.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '把日常語句交給 AI 整理，金額與內容仍由你最後確認。',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: FutureMintTokens.space3),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: FutureMintTokens.sun.withValues(
                        alpha: hasDrafts ? .18 : .34,
                      ),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/mascot_note_helper.png',
                  width: hasDrafts ? 72 : 96,
                  height: hasDrafts ? 72 : 96,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space4),
          TextField(
            key: const Key('capture-input'),
            controller: inputController,
            enabled: !controller.busy,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textInputAction: TextInputAction.done,
            onSubmitted: controller.busy ? null : (_) => _parse(controller),
            decoration: const InputDecoration(
              labelText: '收入、支出或訂閱',
              alignLabelWithHint: true,
              hintText: '例如：今天買珍奶 75 元',
              helperText: '請勿輸入姓名、帳號、卡號或其他個人資料。',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: FutureMintTokens.space3),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const [
                ('今天買珍奶 75', FutureMintTokens.coralSoft),
                ('打工薪水 1500', FutureMintTokens.mintSoft),
                ('Netflix 390 四個人分', FutureMintTokens.lavenderSoft),
              ])
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? FutureMintTokens.darkSurface
                      : entry.$2,
                  label: Text(entry.$1),
                  onPressed: controller.busy
                      ? null
                      : () => setState(() => inputController.text = entry.$1),
                ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space4),
          OutlinedButton.icon(
            key: const Key('manual-capture'),
            onPressed: controller.busy
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    controller.startManualCapture();
                    _showDraft();
                  },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('手動記一筆'),
          ),
          const SizedBox(height: FutureMintTokens.space2),
          FilledButton.icon(
            onPressed: controller.busy || !controller.isAiEnabled
                ? null
                : () => _parse(controller),
            icon: controller.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_rounded),
            label: Text(controller.busy ? '正在整理…' : '幫我整理'),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        gutter,
        FutureMintTokens.space5,
        gutter,
        FutureMintTokens.space7,
      ),
      child: ResponsivePageCanvas(
        compactMaxWidth: FutureMintTokens.contentNarrow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (largeText) ...[
              heading,
              Align(alignment: Alignment.centerRight, child: headingArtwork),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: heading),
                  const SizedBox(width: FutureMintTokens.space2),
                  headingArtwork,
                ],
              ),
            const SizedBox(height: FutureMintTokens.space5),
            if (!hasDrafts) inputCard,
            if (controller.errorMessage != null) ...[
              const SizedBox(height: FutureMintTokens.space4),
              _StatusMessage(
                icon: Icons.error_outline,
                message: controller.errorMessage!,
                error: true,
              ),
            ],
            if (saved != null && result == null) ...[
              const SizedBox(height: FutureMintTokens.space4),
              const _StatusMessage(
                icon: Icons.check_circle_outline_rounded,
                message: '已安全記下，首頁預算與紀錄也更新了。',
              ),
            ],
            if (result?.rejectedReason != null) ...[
              const SizedBox(height: FutureMintTokens.space4),
              _StatusMessage(
                icon: Icons.do_not_disturb_alt_rounded,
                message: result!.rejectedReason!,
              ),
            ],
            if (result?.clarificationQuestion != null) ...[
              const SizedBox(height: FutureMintTokens.space4),
              _StatusMessage(
                icon: Icons.help_outline_rounded,
                message: result!.clarificationQuestion!,
              ),
            ],
            for (var index = 0; index < drafts.length; index++) ...[
              const SizedBox(height: FutureMintTokens.space5),
              KeyedSubtree(
                key: index == 0
                    ? const Key('capture-draft-focus')
                    : ValueKey('capture-draft-$index'),
                child: KeyedSubtree(
                  key: index == 0 ? _draftKey : null,
                  child: DraftEditor(
                    key: ValueKey(drafts[index].draftId),
                    draft: drafts[index],
                    busy: controller.busy,
                    onConfirm: (draft) async {
                      await controller.saveDraft(draft);
                      if (mounted && controller.captureResult == null) {
                        inputController.clear();
                      }
                    },
                  ),
                ),
              ),
            ],
            if (hasDrafts) ...[
              const SizedBox(height: FutureMintTokens.space5),
              Text('再記一筆', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: FutureMintTokens.space3),
              inputCard,
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    this.error = false,
  });
  final IconData icon;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.all(FutureMintTokens.space4),
    radius: 16,
    borderWidth: 1,
    color: error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.mintSoft,
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: FutureMintTokens.space3),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
