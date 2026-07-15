import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/date_text.dart';
import '../../state/app_controller.dart';
import 'help_sheets.dart';

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
    var accountRole = current?.accountRole ?? AccountRole.child;
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
                  SegmentedButton<AccountRole>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AccountRole.child,
                        icon: Icon(Icons.face_outlined),
                        label: Text('孩子'),
                      ),
                      ButtonSegment(
                        value: AccountRole.parent,
                        icon: Icon(Icons.family_restroom_outlined),
                        label: Text('家長'),
                      ),
                    ],
                    selected: {accountRole},
                    onSelectionChanged: (value) =>
                        setDialogState(() => accountRole = value.first),
                  ),
                  const SizedBox(height: 12),
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
                    userId: current?.userId ?? 'guest-user',
                    accountRole: accountRole,
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final guest = controller.mode == AppMode.guest;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          FutureMintTokens.space5,
          FutureMintTokens.space1,
          FutureMintTokens.space5,
          FutureMintTokens.space5 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeading(
                  kicker: '控制中心',
                  title: '設定與服務狀態',
                  accent: FutureMintTokens.teal,
                ),
                const SizedBox(height: FutureMintTokens.space5),
                SoftCard(
                  key: const Key('settings-grouped-surface'),
                  borderWidth: 1,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FutureMintTokens.darkSurfaceRaised
                      : FutureMintTokens.paper,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: FutureMintTokens.sky,
                          foregroundColor: FutureMintTokens.ink,
                          child: Icon(
                            guest
                                ? Icons.visibility_outlined
                                : Icons.verified_user_outlined,
                          ),
                        ),
                        title: Text(guest ? '訪客暫存模式' : '已登入帳號'),
                        subtitle: Text(
                          guest
                              ? '訪客資料只留在這次使用期間；離開、重新整理或切換帳號後會清除。'
                              : '${controller.accountEmail ?? '目前帳號'} 的預算、紀錄與課程會分開保存。',
                        ),
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      FilledButton.icon(
                        onPressed: controller.busy
                            ? null
                            : () => _editProfile(context, controller),
                        icon: const Icon(Icons.savings_outlined),
                        label: Text(
                          controller.profile == null ? '建立預算與目標' : '編輯預算與目標',
                        ),
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      OutlinedButton.icon(
                        onPressed: () => showAppWalkthrough(context),
                        icon: const Icon(Icons.route_outlined),
                        label: const Text('使用步驟介紹'),
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      OutlinedButton.icon(
                        onPressed: () => showSupportBot(context),
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('機器人服務諮詢'),
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      OutlinedButton.icon(
                        onPressed: controller.busy || controller.onExit == null
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                await controller.onExit!();
                              },
                        icon: Icon(
                          guest
                              ? Icons.exit_to_app_rounded
                              : Icons.logout_rounded,
                        ),
                        label: Text(guest ? '結束訪客模式' : '登出'),
                      ),
                      const Divider(height: FutureMintTokens.space7),
                      Text(
                        '外觀',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
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
                      const Divider(height: FutureMintTokens.space7),
                      Text(
                        '資料與用途',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: FutureMintTokens.space2),
                      const Text(
                        'FutureMint AI 是金融教育決策教練，不提供投資標的、報酬保證或真實金融交易。請勿輸入姓名、學校、帳號或卡號；訪客資料不會儲存。',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
