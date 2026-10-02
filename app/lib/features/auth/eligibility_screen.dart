import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../state/session_controller.dart';
import 'account_safety_actions.dart';

class EligibilityScreen extends StatefulWidget {
  const EligibilityScreen({super.key});
  @override
  State<EligibilityScreen> createState() => _EligibilityScreenState();
}

class _EligibilityScreenState extends State<EligibilityScreen> {
  String? band;
  final email = TextEditingController();
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final status = session.eligibility?.status;
    final declaration = status == 'declaration-required';
    final mailDisabled = session.servicePolicy?.mailEnabled == false;
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
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          declaration
                              ? '確認使用年齡'
                              : status == 'under-age'
                              ? '目前僅開放 15 歲以上使用'
                              : '等待監護人同意',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          declaration
                              ? '台灣服務最低年齡為 15 歲。15–17 歲需要監護人確認；帳號角色不代表監護人同意。'
                              : status == 'under-age'
                              ? '你可登出或刪除帳號；年齡聲明不能在 App 內任意變更。'
                              : mailDisabled
                              ? '目前未啟用監護人確認信，15–17 歲帳號仍須等待監護人同意，不能開始正式記帳。你可登出後先使用訪客模式；既有資料仍可查看、匯出或刪除。聯絡支援不會自動核准監護人身分。'
                              : '請輸入監護人電子郵件。監護人須由信件連結查看並確認，家庭邀請不會代替這一步。',
                        ),
                        if (declaration) ...[
                          const SizedBox(height: FutureMintTokens.space3),
                          Text(
                            '使用者年齡',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: FutureMintTokens.space2),
                          Semantics(
                            label: '使用者年齡',
                            child: DropdownButtonFormField<String>(
                              initialValue: band,
                              hint: const Text('請選擇年齡'),
                              decoration: const InputDecoration(
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'under-15',
                                  child: Text('未滿 15 歲'),
                                ),
                                DropdownMenuItem(
                                  value: '15-17',
                                  child: Text('15–17 歲'),
                                ),
                                DropdownMenuItem(
                                  value: '18-plus',
                                  child: Text('18 歲以上'),
                                ),
                              ],
                              onChanged: session.busy
                                  ? null
                                  : (v) => setState(() => band = v),
                            ),
                          ),
                          const SizedBox(height: FutureMintTokens.space3),
                          FilledButton(
                            onPressed: session.busy || band == null
                                ? null
                                : () => session.declareAge(band!),
                            child: const Text('確認年齡聲明'),
                          ),
                        ] else if (status != 'under-age') ...[
                          if (!mailDisabled) ...[
                            TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: '監護人電子郵件',
                              ),
                            ),
                            const SizedBox(height: FutureMintTokens.space3),
                            FilledButton(
                              onPressed: session.busy
                                  ? null
                                  : () => session.requestGuardian(email.text),
                              child: const Text('寄送／重寄同意信'),
                            ),
                          ],
                          const SizedBox(height: FutureMintTokens.space3),
                          OutlinedButton(
                            onPressed: session.busy
                                ? null
                                : session.refreshEligibility,
                            child: const Text('重新確認同意狀態'),
                          ),
                        ],
                        if (session.message != null)
                          Text(
                            session.message!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (session.notice != null) Text(session.notice!),
                        const SizedBox(height: 16),
                        if (session.account?.profileComplete == true)
                          OutlinedButton(
                            onPressed: session.busy
                                ? null
                                : session.enterReadOnly,
                            child: const Text('查看既有資料（唯讀）'),
                          ),
                      ],
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
