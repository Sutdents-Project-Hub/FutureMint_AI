import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../data/demo_repository.dart';
import '../../shared/date_text.dart';
import '../../state/app_controller.dart';

Future<void> showSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppController>(),
        child: const _SettingsSheet(),
      ),
    );

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  Future<void> _editProfile(
    BuildContext context,
    AppController controller,
  ) async {
    final current = controller.profile;
    final budget = TextEditingController(
      text: (current?.monthlyBudgetMinor ?? 6000).toString(),
    );
    final goalName = TextEditingController(text: current?.goalName ?? '我的成長目標');
    final goalTarget = TextEditingController(
      text: (current?.goalTargetMinor ?? 12000).toString(),
    );
    final goalSaved = TextEditingController(
      text: (current?.goalSavedMinor ?? 0).toString(),
    );
    var goalDate =
        current?.goalDate ?? DateTime.now().add(const Duration(days: 90));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('設定預算與目標'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: budget,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '每月預算（元）'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalName,
                    decoration: const InputDecoration(labelText: '目標名稱'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalTarget,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '目標金額（元）'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalSaved,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '已累積（元）'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('目標日期'),
                    subtitle: Text(
                      '${goalDate.year}/${goalDate.month}/${goalDate.day}',
                    ),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final firstDate = dateOnly(DateTime.now());
                      final lastDate = dateOnly(
                        DateTime.now().add(const Duration(days: 3650)),
                      );
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: clampPickerDate(
                          goalDate,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        ),
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (selected != null) {
                        setDialogState(() => goalDate = selected);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final monthly = int.tryParse(budget.text.trim());
                final target = int.tryParse(goalTarget.text.trim());
                final savedAmount = int.tryParse(goalSaved.text.trim());
                if (monthly == null ||
                    monthly <= 0 ||
                    target == null ||
                    target <= 0 ||
                    savedAmount == null ||
                    savedAmount < 0 ||
                    goalName.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請填入有效的預算與目標資料。')),
                  );
                  return;
                }
                final didSave = await controller.updateProfile(
                  UserProfile(
                    userId: 'demo-user',
                    monthlyBudgetMinor: monthly,
                    weeklyBudgetMinor: current?.weeklyBudgetMinor,
                    goalName: goalName.text.trim(),
                    goalTargetMinor: target,
                    goalSavedMinor: savedAmount,
                    goalDate: goalDate,
                    preferredTone: current?.preferredTone ?? 'supportive',
                  ),
                );
                if (didSave && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('儲存設定'),
            ),
          ],
        ),
      ),
    );
    budget.dispose();
    goalName.dispose();
    goalTarget.dispose();
    goalSaved.dispose();
  }

  Future<void> _reset(BuildContext context, AppController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重設離線展示？'),
        content: const Text('這會刪除本機建立的合成紀錄，並還原固定展示故事。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認重設'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await controller.resetDemo();
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final offline = controller.mode == AppMode.offlineDemo;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '設定與服務狀態',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(
                      offline
                          ? Icons.offline_bolt_outlined
                          : Icons.cloud_done_outlined,
                    ),
                  ),
                  title: Text(offline ? '離線展示模式' : 'Connected 模式'),
                  subtitle: Text(
                    offline
                        ? '使用合成資料與離線解析；沒有連接銀行、支付或真實帳戶。'
                        : '透過 Functions API 存取展示資料；不會偷偷切換成離線結果。',
                  ),
                ),
                if (!offline) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            final repository = await DemoRepository.create();
                            await controller.switchRepository(
                              repository,
                              AppMode.offlineDemo,
                            );
                          },
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: const Text('明確切換到離線展示'),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: controller.busy
                      ? null
                      : () => _editProfile(context, controller),
                  icon: const Icon(Icons.savings_outlined),
                  label: Text(
                    controller.profile == null ? '建立預算與目標' : '編輯預算與目標',
                  ),
                ),
                const Divider(height: 36),
                Text(
                  '外觀',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('系統'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('亮色'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('深色'),
                    ),
                  ],
                  selected: {controller.themeMode},
                  onSelectionChanged: (value) =>
                      controller.setThemeMode(value.first),
                ),
                const Divider(height: 36),
                Text(
                  '資料與用途',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'FutureMint AI 是金融教育決策教練，不提供投資標的、報酬保證或真實金融交易。Demo 僅使用合成資料；請勿輸入姓名、學校、帳號或卡號。',
                ),
                if (offline) ...[
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _reset(context, controller),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('重設合成展示資料'),
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
