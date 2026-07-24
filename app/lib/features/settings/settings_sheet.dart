import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/date_text.dart';
import '../../shared/money_text.dart';
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
    final familyRoleLocked = controller.familyOverview != null;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('設定預算與目標'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                              avatar: const Icon(Icons.face_outlined, size: 18),
                              label: const Text('孩子'),
                              selected: accountRole == AccountRole.child,
                              onSelected: familyRoleLocked
                                  ? null
                                  : (_) => setDialogState(
                                      () => accountRole = AccountRole.child,
                                    ),
                            ),
                            ChoiceChip(
                              avatar: const Icon(
                                Icons.family_restroom_outlined,
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
                      if (!guest) ...[
                        const _FamilySection(),
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
                                    avatar: Icon(entry.$3, size: 18),
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
                        '決賽版本僅使用合成資料。使用量界 AI 模式時，輸入會經後端送往 AI provider 解析；原文不會寫入交易紀錄或一般 log。請勿輸入姓名、學校、帳號或卡號；訪客資料不會儲存。',
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

class _FamilySection extends StatefulWidget {
  const _FamilySection();

  @override
  State<_FamilySection> createState() => _FamilySectionState();
}

class _FamilySectionState extends State<_FamilySection> {
  final _inviteController = TextEditingController();
  String? _actionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppController>().loadFamily();
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
    final code = _inviteController.text.trim().toUpperCase();
    if (code.length != 8) {
      setState(() => _actionError = '請輸入 8 碼家長邀請碼。');
      return;
    }
    setState(() => _actionError = null);
    await controller.joinFamily(code);
    if (mounted && controller.errorMessage != null) {
      setState(() => _actionError = controller.errorMessage);
    }
  }

  Future<void> _leaveFamily(AppController controller) async {
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
          if (family == null && isParent) ...[
            const Text('建立邀請碼，讓孩子帳號加入這個家庭。'),
            const SizedBox(height: FutureMintTokens.space2),
            FilledButton.icon(
              key: const Key('create-family-invite'),
              onPressed: controller.busy
                  ? null
                  : () => _createInvite(controller),
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('建立家庭邀請碼'),
            ),
          ] else if (family == null) ...[
            TextField(
              key: const Key('family-invite-code'),
              controller: _inviteController,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '家長邀請碼',
                hintText: '輸入 8 碼英數字',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: FutureMintTokens.space2),
            FilledButton.icon(
              key: const Key('join-family'),
              onPressed: controller.busy ? null : () => _joinFamily(controller),
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
            OutlinedButton.icon(
              key: const Key('leave-family'),
              onPressed: controller.busy
                  ? null
                  : () => _leaveFamily(controller),
              icon: const Icon(Icons.link_off_outlined),
              label: const Text('離開家庭關聯'),
            ),
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
