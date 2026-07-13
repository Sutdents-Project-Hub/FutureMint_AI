import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '用一句話，記下剛才發生的事',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'FutureMint 先整理成草稿，只有你按下確認後才會保存。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('capture-input'),
                        controller: inputController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _parse(controller),
                        decoration: const InputDecoration(
                          labelText: '收入、支出或訂閱',
                          alignLabelWithHint: true,
                          hintText: '例如：今天買珍奶 75 元',
                          helperText: '請勿輸入姓名、帳號、卡號或其他個人資料。',
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final sample in const [
                            '今天買珍奶 75',
                            '打工薪水 1500',
                            'Netflix 390 四個人分',
                          ])
                            ActionChip(
                              label: Text(sample),
                              onPressed: () =>
                                  setState(() => inputController.text = sample),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: controller.busy
                            ? null
                            : () => _parse(controller),
                        icon: controller.busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_fix_high_rounded),
                        label: Text(controller.busy ? '正在整理…' : '幫我整理'),
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 16),
                _StatusMessage(
                  icon: Icons.error_outline,
                  message: controller.errorMessage!,
                  error: true,
                ),
              ],
              if (saved != null && result == null) ...[
                const SizedBox(height: 16),
                const _StatusMessage(
                  icon: Icons.check_circle_outline_rounded,
                  message: '已安全記下，首頁預算與紀錄也更新了。',
                ),
              ],
              if (result?.rejectedReason != null) ...[
                const SizedBox(height: 16),
                _StatusMessage(
                  icon: Icons.do_not_disturb_alt_rounded,
                  message: result!.rejectedReason!,
                ),
              ],
              if (result?.clarificationQuestion != null) ...[
                const SizedBox(height: 16),
                _StatusMessage(
                  icon: Icons.help_outline_rounded,
                  message: result!.clarificationQuestion!,
                ),
              ],
              for (final draft in result?.drafts ?? const []) ...[
                const SizedBox(height: 20),
                DraftEditor(
                  key: ValueKey(draft.draftId),
                  draft: draft,
                  busy: controller.busy,
                  onConfirm: controller.saveDraft,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
