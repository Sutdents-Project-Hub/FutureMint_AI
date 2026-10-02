import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../export/export_plaintext.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/date_text.dart';
import '../../shared/money_text.dart';
import '../../shared/public_links.dart';
import '../../state/app_controller.dart';
import 'help_sheets.dart';

Future<void> showSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AppController>(),
        child: const _SettingsSheet(),
      ),
    );

Future<void> showAiConsentDisclosure(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => ChangeNotifierProvider.value(
    value: context.read<AppController>(),
    child: Consumer<AppController>(
      builder: (dialogContext, controller, _) => AlertDialog(
        key: const Key('ai-consent-disclosure'),
        title: const Text('啟用 AI 前的資料說明'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AiDisclosureSection(
                  title: '使用哪個 AI',
                  children: [
                    if (controller.servicePolicy != null) ...[
                      Text('第三方服務：${controller.servicePolicy!.aiDisplayName}。'),
                      Text(
                        '資料接收方：${controller.servicePolicy!.dataRecipients.join('、')}。',
                      ),
                    ] else
                      const Text('等待供應商資料載入。'),
                    if (controller.servicePolicy?.model != null) ...[
                      Text('請求模型：${controller.servicePolicy!.model}。'),
                      Text(
                        '模型 ID 不代表已驗證上游模型權重。',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: FutureMintTokens.space5),
                const _AiDisclosureSection(
                  title: '會傳送哪些資料',
                  children: [
                    Text('依使用的功能，後端會傳送你主動輸入的記帳文字、事件分類與是否設定目標等摘要，以及教練提問。'),
                    Text('AI 協助解析記帳與選擇金融教育主題；課程與教練回覆使用固定教育內容。'),
                    Text('請勿輸入帳號、聯絡方式或其他敏感資訊。'),
                  ],
                ),
                const SizedBox(height: FutureMintTokens.space5),
                _AiDisclosureSection(
                  title: '目前啟用狀態',
                  children: [
                    if (controller.servicePolicy == null ||
                        !controller.servicePolicy!.reviewed)
                      const Text('供應商資料暫時無法載入，請重新連線後再決定。'),
                    Text(
                      controller.servicePolicy?.dataTerms ??
                          '供應商、資料保留與處理地區等條件載入後，才可啟用第三方 AI。',
                    ),
                  ],
                ),
                const SizedBox(height: FutureMintTokens.space3),
                TextButtonTheme(
                  data: TextButtonThemeData(
                    style:
                        (Theme.of(dialogContext).textButtonTheme.style ??
                                const ButtonStyle())
                            .copyWith(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.only(right: 12),
                              ),
                              minimumSize: const WidgetStatePropertyAll(
                                Size(48, 48),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                  ),
                  child: const SizedBox(
                    key: Key('ai-disclosure-links'),
                    width: double.infinity,
                    child: PrivacySupportLinks(),
                  ),
                ),
                const SizedBox(height: FutureMintTokens.space5),
                const _AiDisclosureSection(
                  title: '你的選擇',
                  children: [
                    Text('不會傳送你的密碼。'),
                    Text(
                      '你可以拒絕，預算、紀錄、FutureSeed 與虛擬投資等非 AI 功能仍可使用；之後也可在設定隨時撤回。',
                    ),
                  ],
                ),
                if (controller.servicePolicy != null) ...[
                  const SizedBox(height: FutureMintTokens.space3),
                  ExpansionTile(
                    key: const Key('ai-disclosure-details'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: const Text('詳細資訊'),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '同意版本：${controller.servicePolicy!.aiPolicyVersion}',
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: FutureMintTokens.space3),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      controller.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('暫不啟用'),
          ),
          FilledButton(
            key: const Key('enable-ai-consent'),
            onPressed:
                controller.busy ||
                    !controller.canManageAiConsent ||
                    (controller.servicePolicy == null ||
                        !controller.servicePolicy!.reviewed)
                ? null
                : () async {
                    final enabled = await controller.updateAiConsent(true);
                    if (enabled && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
            child: const Text('同意並啟用'),
          ),
        ],
      ),
    ),
  ),
);

class _AiDisclosureSection extends StatelessWidget {
  const _AiDisclosureSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: FutureMintTokens.space2),
      DefaultTextStyle.merge(
        style: const TextStyle(height: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(height: FutureMintTokens.space2),
              children[index],
            ],
          ],
        ),
      ),
    ],
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  Future<void> _deleteAccount(
    BuildContext sheetContext,
    AppController controller,
  ) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    var deleting = false;
    String? actionError;
    await showDialog<void>(
      context: sheetContext,
      builder: (dialogContext) => _SettingsDialogBody(
        controllers: [password, confirmation],
        builder: (context, setDialogState) {
          final ready =
              password.text.isNotEmpty && confirmation.text.trim() == '刪除帳號';
          return AlertDialog(
            key: const Key('delete-account-dialog'),
            title: const Text('刪除帳號'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '此操作會立即刪除 FutureMint 目前資料庫中的帳號、預算、紀錄、課程、虛擬投資與家庭關聯，之後無法由 App 復原。正式服務仍須另行公布備份與第三方服務的保留、刪除期限。',
                    ),
                    const SizedBox(height: FutureMintTokens.space3),
                    TextField(
                      key: const Key('delete-account-password'),
                      controller: password,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: '目前密碼',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: FutureMintTokens.space3),
                    TextField(
                      key: const Key('delete-account-confirmation'),
                      controller: confirmation,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: '輸入「刪除帳號」確認',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (actionError != null) ...[
                      const SizedBox(height: FutureMintTokens.space2),
                      Text(
                        actionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: deleting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                key: const Key('confirm-delete-account'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: !ready || deleting || !controller.canDeleteAccount
                    ? null
                    : () async {
                        setDialogState(() {
                          deleting = true;
                          actionError = null;
                        });
                        final deleted = await controller.deleteAccount(
                          password.text,
                        );
                        if (!dialogContext.mounted) return;
                        if (deleted) {
                          Navigator.of(dialogContext).pop();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        } else {
                          setDialogState(() {
                            deleting = false;
                            actionError =
                                controller.errorMessage ??
                                '帳號尚未刪除，請確認目前密碼後再試一次。';
                          });
                        }
                      },
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(deleting ? '正在刪除…' : '永久刪除帳號'),
              ),
            ],
          );
        },
      ),
    );
  }

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
    final familyRoleLocked = controller.familyOverview != null;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SettingsDialogBody(
        controllers: [budget, goalName, goalTarget, goalSaved],
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('設定預算與目標'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxWidth < 360 ||
                          MediaQuery.textScalerOf(context).scale(1) >= 1.3;
                      if (compact) {
                        return Wrap(
                          spacing: FutureMintTokens.space2,
                          runSpacing: FutureMintTokens.space2,
                          children: [
                            ChoiceChip(
                              showCheckmark: false,
                              avatar: Icon(
                                accountRole == AccountRole.child
                                    ? Icons.check_circle_rounded
                                    : Icons.face_outlined,
                                size: 18,
                              ),
                              label: const Text('孩子'),
                              selected: accountRole == AccountRole.child,
                              onSelected: familyRoleLocked
                                  ? null
                                  : (_) => setDialogState(
                                      () => accountRole = AccountRole.child,
                                    ),
                            ),
                            ChoiceChip(
                              showCheckmark: false,
                              avatar: Icon(
                                accountRole == AccountRole.parent
                                    ? Icons.check_circle_rounded
                                    : Icons.family_restroom_outlined,
                                size: 18,
                              ),
                              label: const Text('家長'),
                              selected: accountRole == AccountRole.parent,
                              onSelected: familyRoleLocked
                                  ? null
                                  : (_) => setDialogState(
                                      () => accountRole = AccountRole.parent,
                                    ),
                            ),
                          ],
                        );
                      }
                      return SegmentedButton<AccountRole>(
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
                        onSelectionChanged: familyRoleLocked
                            ? null
                            : (value) => setDialogState(
                                () => accountRole = value.first,
                              ),
                      );
                    },
                  ),
                  if (familyRoleLocked) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('家庭關聯中的角色已鎖定；請先離開家庭再更換。'),
                    ),
                  ],
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
                      if (selected != null && dialogContext.mounted) {
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
              onPressed: saving || controller.busy
                  ? null
                  : () async {
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
                      setDialogState(() => saving = true);
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
                      if (!dialogContext.mounted) return;
                      if (didSave) {
                        Navigator.pop(dialogContext);
                      } else {
                        setDialogState(() => saving = false);
                      }
                    },
              child: Text(saving ? '正在儲存…' : '儲存設定'),
            ),
          ],
        ),
      ),
    );
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
                        titleTextStyle: Theme.of(context).textTheme.titleMedium,
                        leading: CircleAvatar(
                          radius: 24,
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
                      Wrap(
                        spacing: FutureMintTokens.space2,
                        runSpacing: FutureMintTokens.space1,
                        children: [
                          TextButton.icon(
                            onPressed: () => showAppWalkthrough(context),
                            icon: const Icon(Icons.route_outlined),
                            label: const Text('使用步驟介紹'),
                          ),
                          TextButton.icon(
                            onPressed: () => showSupportBot(context),
                            icon: const Icon(Icons.support_agent_rounded),
                            label: const Text('機器人服務諮詢'),
                          ),
                        ],
                      ),
                      const SizedBox(height: FutureMintTokens.space3),
                      if (!guest) ...[
                        if (!controller.canWrite)
                          const Text('目前為唯讀模式；既有資料可查看、匯出與刪除帳號。'),
                        if (controller.onViewEligibility != null)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              controller.onViewEligibility!();
                            },
                            child: const Text('查看年齡／監護人同意狀態'),
                          ),
                        const Divider(height: FutureMintTokens.space7),
                        Text(
                          'AI 使用同意',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: FutureMintTokens.space2),
                        Text(
                          controller.aiConsent.granted
                              ? '已啟用 ${controller.servicePolicy?.aiDisplayName ?? '第三方'} AI；你可隨時撤回。'
                              : '尚未啟用 AI；非 AI 功能仍可使用。',
                        ),
                        const SizedBox(height: FutureMintTokens.space2),
                        OutlinedButton.icon(
                          key: const Key('settings-ai-consent'),
                          onPressed: controller.busy
                              ? null
                              : () => showAiConsentDisclosure(context),
                          icon: Icon(
                            controller.aiConsent.granted
                                ? Icons.settings_suggest_outlined
                                : Icons.auto_awesome_outlined,
                          ),
                          label: Text(
                            controller.aiConsent.granted
                                ? '查看或撤回 AI 同意'
                                : '查看 AI 資料用途',
                          ),
                        ),
                        if (controller.aiConsent.granted) ...[
                          const SizedBox(height: FutureMintTokens.space2),
                          TextButton.icon(
                            key: const Key('revoke-ai-consent'),
                            onPressed:
                                controller.busy ||
                                    !controller.canManageAiConsent
                                ? null
                                : () => controller.revokeAiConsent(),
                            icon: const Icon(Icons.block_outlined),
                            label: const Text('撤回 AI 同意'),
                          ),
                        ],
                        const SizedBox(height: FutureMintTokens.space3),
                        const _FamilySection(),
                        const SizedBox(height: FutureMintTokens.space3),
                        const Divider(height: FutureMintTokens.space7),
                        if (controller.reminders?.supported == true)
                          SwitchListTile(
                            key: const Key('subscription-reminder-toggle'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('訂閱本機提醒'),
                            subtitle: const Text(
                              '續訂前一天 09:00（台灣時間）排程，實際送達受系統設定與省電限制影響；通知不含名稱或金額。',
                            ),
                            value: controller.reminders!.enabled,
                            onChanged: controller.busy
                                ? null
                                : controller.setRemindersEnabled,
                          ),
                        if (controller.reminders?.supported == true &&
                            controller.reminders!.permission == 'denied')
                          Padding(
                            key: Key('subscription-reminder-permission'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '通知權限已關閉。請在系統設定允許 FutureMint AI 通知，回到 App 後再啟用提醒；App 內仍可查看提醒。',
                                ),
                                TextButton.icon(
                                  key: const Key(
                                    'subscription-reminder-settings',
                                  ),
                                  onPressed: controller.busy
                                      ? null
                                      : controller.openReminderSettings,
                                  icon: const Icon(Icons.settings_outlined),
                                  label: const Text('開啟通知設定'),
                                ),
                              ],
                            ),
                          ),
                        if (controller.onGuardianWithdrawn != null)
                          TextButton(
                            onPressed: controller.busy
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialog) => AlertDialog(
                                        title: const Text('撤回監護人同意？'),
                                        content: const Text(
                                          '服務將停止寫入資料，並清除這台裝置的訂閱提醒。家庭分享與監護人同意是不同設定。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, false),
                                            child: const Text('取消'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(dialog, true),
                                            child: const Text('撤回'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await controller.onGuardianWithdrawn!();
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                            child: const Text('撤回監護人同意'),
                          ),
                        OutlinedButton.icon(
                          key: const Key('export-self'),
                          onPressed: controller.busy
                              ? null
                              : () async {
                                  final data = await controller.exportSelf();
                                  if (data == null || !context.mounted) return;
                                  final text = const JsonEncoder.withIndent(
                                    '  ',
                                  ).convert(data);
                                  await showDialog<void>(
                                    context: context,
                                    builder: (dialog) => AlertDialog(
                                      title: const Text('匯出自己的資料'),
                                      content: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 520,
                                          maxHeight: 420,
                                        ),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                '這是含個人紀錄的純文字 JSON。分享或儲存前請自行確認內容及存放位置。',
                                              ),
                                              SelectableText(text),
                                            ],
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog),
                                          child: const Text('關閉'),
                                        ),
                                        FilledButton(
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: text),
                                            );
                                          },
                                          child: const Text('複製 JSON'),
                                        ),
                                        if (kIsWeb)
                                          TextButton(
                                            onPressed: () => downloadJson(text),
                                            child: const Text('下載 JSON 檔案'),
                                          ),
                                        if (!kIsWeb &&
                                            defaultTargetPlatform ==
                                                TargetPlatform.iOS)
                                          TextButton(
                                            onPressed: () async {
                                              await const MethodChannel(
                                                'futuremint/subscription-reminders',
                                              ).invokeMethod<void>(
                                                'shareExport',
                                                {'text': text},
                                              );
                                            },
                                            child: const Text('分享／儲存檔案'),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('匯出我的資料（JSON）'),
                        ),
                        Text(
                          '帳號',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: FutureMintTokens.space2),
                        OutlinedButton.icon(
                          key: const Key('delete-account-action'),
                          onPressed:
                              controller.busy || !controller.canDeleteAccount
                              ? null
                              : () => _deleteAccount(context, controller),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('刪除帳號與資料'),
                        ),
                        const SizedBox(height: FutureMintTokens.space3),
                      ],
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
                                    ThemeMode.system,
                                    '系統',
                                    Icons.brightness_auto_outlined,
                                  ),
                                  (
                                    ThemeMode.light,
                                    '亮色',
                                    Icons.light_mode_outlined,
                                  ),
                                  (
                                    ThemeMode.dark,
                                    '深色',
                                    Icons.dark_mode_outlined,
                                  ),
                                ])
                                  ChoiceChip(
                                    showCheckmark: false,
                                    avatar: Icon(
                                      controller.themeMode == entry.$1
                                          ? Icons.check_circle_rounded
                                          : entry.$3,
                                      size: 18,
                                    ),
                                    label: Text(entry.$2),
                                    selected: controller.themeMode == entry.$1,
                                    onSelected: (_) =>
                                        controller.setThemeMode(entry.$1),
                                  ),
                              ],
                            );
                          }
                          return SegmentedButton<ThemeMode>(
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
                          );
                        },
                      ),
                      const Divider(height: FutureMintTokens.space7),
                      Text(
                        '資料與用途',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: FutureMintTokens.space2),
                      const Text(
                        'FutureMint AI 是金融教育決策教練。FutureSeed 是教育模擬，不是銀行或投資帳戶；不提供投資標的、報酬保證或真實金融交易。',
                      ),
                      const SizedBox(height: FutureMintTokens.space2),
                      const Text(
                        '請只記錄自己的預算與消費，不要輸入姓名、學校、帳號或卡號；系統無法自動辨識所有個資。啟用 AI 後，記帳文字會經後端送往同意頁揭露的第三方 AI 解析，原文不會寫入交易紀錄或一般日誌。資料的保存、刪除與第三方處理條件請閱讀隱私權政策；訪客資料不會儲存。',
                      ),
                      const SizedBox(height: FutureMintTokens.space2),
                      const PrivacySupportLinks(),
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

class _FamilySection extends StatefulWidget {
  const _FamilySection();

  @override
  State<_FamilySection> createState() => _FamilySectionState();
}

class _FamilySectionState extends State<_FamilySection> {
  final _inviteController = TextEditingController();
  String? _actionError;
  String? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFamily(context.read<AppController>());
    });
  }

  Future<void> _loadFamily(AppController controller) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final loaded = await controller.loadFamily();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!loaded) {
        _loadError = controller.errorMessage ?? '暫時無法確認家庭關聯，請重新載入。';
      }
    });
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _createInvite(AppController controller) async {
    setState(() => _actionError = null);
    await controller.createFamilyInvite();
    if (mounted && controller.errorMessage != null) {
      setState(() => _actionError = controller.errorMessage);
    }
  }

  Future<void> _joinFamily(AppController controller) async {
    final code = _inviteController.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{24}$').hasMatch(code)) {
      setState(() => _actionError = '請貼上完整的 24 碼家長邀請碼，並保留英文大小寫。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('分享摘要給這個家庭？'),
        scrollable: true,
        content: const Text(
          '請先向家長確認邀請碼來源。加入後，這個家庭的家長帳號可查看你的預算、收支、訂閱與目標進度摘要，不會看到交易明細、原始輸入、Email 或投資訂單。\n\n你可隨時離開家庭停止分享。家庭關聯不會取代監護人同意，也不會啟用 AI。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-join-family'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('同意並加入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionError = null);
    await controller.joinFamily(code);
    if (mounted && controller.errorMessage != null) {
      setState(() => _actionError = controller.errorMessage);
    } else if (mounted && controller.familyOverview != null) {
      _inviteController.clear();
    }
  }

  Future<void> _updateInvite(
    AppController controller, {
    required bool revoke,
  }) async {
    setState(() => _actionError = null);
    if (revoke) {
      await controller.revokeFamilyInvite();
    } else {
      await controller.rotateFamilyInvite();
    }
    if (mounted && controller.errorMessage != null) {
      setState(() => _actionError = controller.errorMessage);
    }
  }

  Future<void> _leaveFamily(AppController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('離開家庭關聯？'),
        scrollable: true,
        content: Text(
          controller.profile?.accountRole == AccountRole.parent
              ? '將關閉這個家庭與邀請碼。你的個人帳號和紀錄會保留；之後可重新建立家庭。'
              : '家長將無法再查看你的摘要。你的個人帳號和紀錄會保留；再次加入需要有效邀請碼。監護人同意與 AI 設定維持原狀。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-leave-family'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('離開並停止分享'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionError = null);
    await controller.leaveFamily();
    if (mounted && controller.errorMessage != null) {
      setState(() => _actionError = controller.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final profile = controller.profile;
    final family = controller.familyOverview;
    final isParent = profile?.accountRole == AccountRole.parent;
    final parentHasChildren =
        isParent &&
        (family?.members.any((member) => member.role == AccountRole.child) ??
            false);
    return SoftCard(
      key: const Key('family-section'),
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurface
          : FutureMintTokens.lavenderSoft,
      borderWidth: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.family_restroom_outlined),
              const SizedBox(width: FutureMintTokens.space2),
              Expanded(
                child: Text(
                  '家庭共學關聯',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: FutureMintTokens.space2),
          const Text('預設採最少揭露：家長只能查看孩子的預算與趨勢摘要，不會看到交易明細、原始輸入、帳號 email 或投資訂單。'),
          const SizedBox(height: FutureMintTokens.space3),
          if (_loading)
            const Text('正在確認家庭關聯…')
          else if (_loadError != null) ...[
            Text(_loadError!),
            TextButton.icon(
              key: const Key('retry-family'),
              onPressed: controller.busy ? null : () => _loadFamily(controller),
              icon: const Icon(Icons.refresh),
              label: const Text('重新載入家庭'),
            ),
          ] else if (family == null && isParent) ...[
            const Text(
              '1. 建立邀請碼並交給孩子。\n2. 孩子使用自己的 Email 註冊，完成年齡／監護人確認與個人設定。\n3. 孩子在這裡輸入邀請碼，同意分享後即可查看摘要。\n\n家長不會在自己的帳號內代建孩子帳號；邀請碼不代表監護人同意。',
            ),
            const SizedBox(height: FutureMintTokens.space2),
            FilledButton.icon(
              key: const Key('create-family-invite'),
              onPressed: controller.busy || !controller.canWrite
                  ? null
                  : () => _createInvite(controller),
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('建立家庭邀請碼'),
            ),
          ] else if (family == null) ...[
            const Text('家庭分享可自由選擇。先向家長取得邀請碼；不加入也能使用自己的帳號。'),
            const SizedBox(height: FutureMintTokens.space2),
            TextField(
              key: const Key('family-invite-code'),
              controller: _inviteController,
              maxLength: 24,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '家長邀請碼',
                hintText: '貼上 24 碼邀請碼（區分大小寫）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: FutureMintTokens.space2),
            FilledButton.icon(
              key: const Key('join-family'),
              onPressed: controller.busy || !controller.canWrite
                  ? null
                  : () => _joinFamily(controller),
              icon: const Icon(Icons.link_outlined),
              label: const Text('加入家庭'),
            ),
          ] else ...[
            Text(
              '已連結 ${family.members.length} 個帳號',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: FutureMintTokens.space2),
            for (final member in family.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  member.role == AccountRole.parent
                      ? Icons.shield_outlined
                      : Icons.face_outlined,
                ),
                title: Text(member.label),
                subtitle: Text(
                  member.role == AccountRole.parent ? '家長權限' : '孩子權限',
                ),
              ),
            if (family.inviteCode != null) ...[
              const SizedBox(height: FutureMintTokens.space2),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '家長邀請碼',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        family.inviteCode!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '複製邀請碼',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: family.inviteCode!),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('邀請碼已複製。')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
              ),
            ],
            if (isParent) ...[
              const SizedBox(height: FutureMintTokens.space2),
              Text(
                family.inviteActive
                    ? '邀請碼有效至 ${family.inviteCodeExpiresAt?.toLocal().toString().substring(0, 16) ?? "到期時間未提供"}。只在建立或更新時顯示，請妥善分享。'
                    : '目前沒有有效邀請碼。',
              ),
              const SizedBox(height: FutureMintTokens.space2),
              OutlinedButton.icon(
                key: const Key('rotate-family-invite'),
                onPressed: controller.busy || !controller.canWrite
                    ? null
                    : () => _updateInvite(controller, revoke: false),
                icon: const Icon(Icons.refresh),
                label: const Text('產生新邀請碼'),
              ),
              if (family.inviteActive)
                TextButton.icon(
                  key: const Key('revoke-family-invite'),
                  onPressed: controller.busy
                      ? null
                      : () => _updateInvite(controller, revoke: true),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('停用邀請碼'),
                ),
            ],
            if (family.childSummaries.isNotEmpty) ...[
              const SizedBox(height: FutureMintTokens.space4),
              Text('孩子的本月摘要', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: FutureMintTokens.space2),
              for (final summary in family.childSummaries)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: FutureMintTokens.space2,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(FutureMintTokens.space3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            summary.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: FutureMintTokens.space1),
                          Text(
                            '可用 ${formatTwd(summary.availableMinor)} · 訂閱 ${formatTwd(summary.subscriptionMinor)}',
                          ),
                          Text(
                            '目標進度 ${(summary.goalProgress * 100).round()}% · ${summary.noticeCount} 個提醒',
                          ),
                          const SizedBox(height: FutureMintTokens.space1),
                          Text(summary.summary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: FutureMintTokens.space2),
            if (parentHasChildren) const Text('孩子仍在此家庭；請先由孩子帳號離開，家長才能關閉家庭。'),
            OutlinedButton.icon(
              key: const Key('leave-family'),
              onPressed: controller.busy || parentHasChildren
                  ? null
                  : () => _leaveFamily(controller),
              icon: const Icon(Icons.link_off_outlined),
              label: const Text('離開家庭關聯'),
            ),
          ],
          if (!_loading && _loadError == null && !controller.canWrite) ...[
            const SizedBox(height: FutureMintTokens.space2),
            const Text('唯讀模式仍可離開家庭或停用邀請碼；完成服務資格後才能新增分享。'),
          ],
          if (_actionError != null) ...[
            const SizedBox(height: FutureMintTokens.space2),
            Text(
              _actionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

// A dialog's popped Future resolves while its reverse transition is running.
// Release field controllers when the dialog subtree actually unmounts.
class _SettingsDialogBody extends StatefulWidget {
  const _SettingsDialogBody({required this.controllers, required this.builder});

  final List<TextEditingController> controllers;
  final StatefulWidgetBuilder builder;

  @override
  State<_SettingsDialogBody> createState() => _SettingsDialogBodyState();
}

class _SettingsDialogBodyState extends State<_SettingsDialogBody> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, setState);
}
