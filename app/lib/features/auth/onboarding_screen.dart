import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../state/session_controller.dart';
import 'account_safety_actions.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _monthlyBudget = TextEditingController();
  final _goalName = TextEditingController();
  final _goalTarget = TextEditingController();
  var _goalDate = DateTime.now().add(const Duration(days: 90));
  var _accountRole = AccountRole.child;

  @override
  void dispose() {
    _monthlyBudget.dispose();
    _goalName.dispose();
    _goalTarget.dispose();
    super.dispose();
  }

  Future<void> _save(SessionController session) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final account = session.account;
    if (account == null) return;
    await session.completeOnboarding(
      UserProfile(
        userId: account.id,
        accountRole: _accountRole,
        monthlyBudgetMinor: int.parse(_monthlyBudget.text.trim()),
        goalName: _goalName.text.trim(),
        goalTargetMinor: int.parse(_goalTarget.text.trim()),
        goalSavedMinor: 0,
        goalDate: _goalDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(FutureMintTokens.pageGutter(context)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeading(
                    kicker: '第一步',
                    title: '先設定一個做得到的目標',
                    description: '這些資料只會存到你的帳號，之後也能在設定裡修改。',
                    accent: FutureMintTokens.teal,
                  ),
                  const SizedBox(height: FutureMintTokens.space5),
                  SoftCard(
                    color: theme.brightness == Brightness.dark
                        ? FutureMintTokens.darkSurfaceRaised
                        : FutureMintTokens.lavenderSoft,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('使用角色', style: theme.textTheme.titleMedium),
                          const SizedBox(height: FutureMintTokens.space2),
                          const Text('角色只調整內容與說明角度，不會開放查看另一個帳號的明細。'),
                          const SizedBox(height: FutureMintTokens.space3),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact =
                                  constraints.maxWidth < 400 ||
                                  MediaQuery.textScalerOf(context).scale(1) >=
                                      1.3;
                              if (compact) {
                                return Wrap(
                                  spacing: FutureMintTokens.space2,
                                  runSpacing: FutureMintTokens.space2,
                                  children: [
                                    ChoiceChip(
                                      showCheckmark: false,
                                      avatar: Icon(
                                        _accountRole == AccountRole.child
                                            ? Icons.check_circle_rounded
                                            : Icons.face_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('孩子使用'),
                                      selected:
                                          _accountRole == AccountRole.child,
                                      onSelected: (_) => setState(
                                        () => _accountRole = AccountRole.child,
                                      ),
                                    ),
                                    ChoiceChip(
                                      showCheckmark: false,
                                      avatar: Icon(
                                        _accountRole == AccountRole.parent
                                            ? Icons.check_circle_rounded
                                            : Icons.family_restroom_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('家長陪伴'),
                                      selected:
                                          _accountRole == AccountRole.parent,
                                      onSelected: (_) => setState(
                                        () => _accountRole = AccountRole.parent,
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
                                    label: Text('孩子使用'),
                                  ),
                                  ButtonSegment(
                                    value: AccountRole.parent,
                                    icon: Icon(Icons.family_restroom_outlined),
                                    label: Text('家長陪伴'),
                                  ),
                                ],
                                selected: {_accountRole},
                                onSelectionChanged: (value) =>
                                    setState(() => _accountRole = value.first),
                              );
                            },
                          ),
                          const SizedBox(height: FutureMintTokens.space5),
                          Text('預算與目標', style: theme.textTheme.titleMedium),
                          const SizedBox(height: FutureMintTokens.space3),
                          TextFormField(
                            controller: _monthlyBudget,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '每月可安排的預算（元）',
                            ),
                            validator: (value) =>
                                (int.tryParse(value?.trim() ?? '') ?? 0) > 0
                                ? null
                                : '請填入大於 0 的金額。',
                          ),
                          const SizedBox(height: FutureMintTokens.space4),
                          TextFormField(
                            controller: _goalName,
                            decoration: const InputDecoration(
                              labelText: '想累積的目標',
                            ),
                            validator: (value) =>
                                (value?.trim().isNotEmpty ?? false)
                                ? null
                                : '請為這個目標取一個名稱。',
                          ),
                          const SizedBox(height: FutureMintTokens.space4),
                          TextFormField(
                            controller: _goalTarget,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '目標金額（元）',
                            ),
                            validator: (value) =>
                                (int.tryParse(value?.trim() ?? '') ?? 0) > 0
                                ? null
                                : '請填入大於 0 的目標金額。',
                          ),
                          const SizedBox(height: FutureMintTokens.space4),
                          Semantics(
                            button: true,
                            label:
                                '希望完成的日期，${_goalDate.year}年${_goalDate.month}月${_goalDate.day}日',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                FutureMintTokens.radiusSmall,
                              ),
                              onTap: () async {
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: _goalDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 3650),
                                  ),
                                );
                                if (selected != null && mounted) {
                                  setState(() => _goalDate = selected);
                                }
                              },
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: FutureMintTokens.controlHeight,
                                ),
                                child: InputDecorator(
                                  isEmpty: false,
                                  decoration: const InputDecoration(
                                    labelText: '希望完成的日期',
                                    suffixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  child: Text(
                                    '${_goalDate.year}/${_goalDate.month}/${_goalDate.day}',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (session.message != null)
                            Text(
                              session.message!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          const SizedBox(height: FutureMintTokens.space5),
                          FilledButton.icon(
                            onPressed: session.busy
                                ? null
                                : () => _save(session),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(session.busy ? '正在儲存…' : '儲存並開始使用'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FutureMintTokens.space4),
                  AccountSafetyActions(session: session),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
