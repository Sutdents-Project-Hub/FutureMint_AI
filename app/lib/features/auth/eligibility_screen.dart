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
  bool guardianAccepted = false;
  String? consentContext;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final status = session.eligibility?.status;
    final declaration = status == 'declaration-required';
    final inAppConsent =
        session.servicePolicy?.supportsInAppGuardianConsent == true;
    final currentConsentContext =
        '${session.account?.id}|$status|${session.servicePolicy?.signature}';
    if (consentContext != currentConsentContext) {
      guardianAccepted = false;
      consentContext = currentConsentContext;
    }
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
                              : '請監護人確認',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          declaration
                              ? '台灣服務最低年齡為 15 歲。15–17 歲需要監護人確認；帳號角色不代表監護人同意。'
                              : status == 'under-age'
                              ? '你可登出或刪除帳號；年齡聲明不能在 App 內任意變更。'
                              : inAppConsent
                              ? '請把裝置交給家長或法定代理人，在下方確認即可，不需要寄信。這是 App 內聲明，不是監護人身分驗證。'
                              : '服務正在更新監護人確認流程，請稍後重新整理。你仍可登出使用訪客模式，或查看、匯出及刪除自己的既有資料。',
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
                              initialValue:
                                  band ?? session.eligibility?.ageBand,
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
                            onPressed:
                                session.busy ||
                                    (band ?? session.eligibility?.ageBand) ==
                                        null
                                ? null
                                : () => session.declareAge(
                                    band ?? session.eligibility!.ageBand!,
                                  ),
                            child: const Text('確認年齡聲明'),
                          ),
                        ] else if (status != 'under-age') ...[
                          if (inAppConsent) ...[
                            const SizedBox(height: FutureMintTokens.space3),
                            const Text(
                              '同意孩子使用記帳與學習功能。家庭摘要分享與第三方 AI 會另外詢問，不會自動開啟；可隨時在孩子帳號的設定撤回同意。',
                            ),
                            const SizedBox(height: FutureMintTokens.space2),
                            CheckboxListTile(
                              key: const Key('guardian-in-app-consent'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: guardianAccepted,
                              onChanged: session.busy
                                  ? null
                                  : (value) => setState(
                                      () => guardianAccepted = value == true,
                                    ),
                              title: const Text(
                                '我是年滿 18 歲的家長或法定代理人，已閱讀隱私說明並同意孩子使用服務。',
                              ),
                            ),
                            const SizedBox(height: FutureMintTokens.space3),
                            FilledButton(
                              onPressed: session.busy || !guardianAccepted
                                  ? null
                                  : session.confirmGuardianInApp,
                              child: const Text('確認同意並繼續'),
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
