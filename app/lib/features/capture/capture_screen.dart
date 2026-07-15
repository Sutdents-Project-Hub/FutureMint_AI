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

  @override
  void dispose() {
    inputController.dispose();
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
    await controller.parseCapture(text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final result = controller.captureResult;
    final saved = controller.lastSavedEvent;
    final drafts = result?.drafts ?? const [];
    final hasDrafts = drafts.isNotEmpty;
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
            maxWidth: FutureMintTokens.contentNarrow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeading(
                kicker: '快速記一筆',
                title: '用一句話，記下剛才發生的事',
                description: 'FutureMint 先整理成草稿，只有你按下確認後才會保存。',
                accent: FutureMintTokens.teal,
              ),
              const SizedBox(height: FutureMintTokens.space5),
              SoftCard(
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MoneyBuddy(
                          size: 56,
                          color: FutureMintTokens.sun,
                          shape: MoneyBuddyShape.spark,
                        ),
                        const SizedBox(width: FutureMintTokens.space3),
                        Expanded(
                          child: Text(
                            '把日常語句交給 AI 整理，金額與內容仍由你最後確認。',
                            style: Theme.of(context).textTheme.titleMedium,
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
                      onSubmitted: controller.busy
                          ? null
                          : (_) => _parse(controller),
                      decoration: const InputDecoration(
                        labelText: '收入、支出或訂閱',
                        alignLabelWithHint: true,
                        hintText: '例如：今天買珍奶 75 元',
                        helperText: '請勿輸入姓名、帳號、卡號或其他個人資料。',
                        helperMaxLines: 2,
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
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? FutureMintTokens.darkSurface
                                : entry.$2,
                            label: Text(entry.$1),
                            onPressed: controller.busy
                                ? null
                                : () => setState(
                                    () => inputController.text = entry.$1,
                                  ),
                          ),
                      ],
                    ),
                    const SizedBox(height: FutureMintTokens.space4),
                    FilledButton.icon(
                      onPressed: controller.busy
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
              ),
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
              ],
            ],
          ),
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
