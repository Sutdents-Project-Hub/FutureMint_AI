import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../state/session_controller.dart';

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  Future<void> _deleteAccount(
    BuildContext context,
    SessionController session,
  ) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    var deleting = false;
    String? actionError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final ready =
              password.text.isNotEmpty && confirmation.text.trim() == '刪除帳號';
          return AlertDialog(
            title: const Text('刪除帳號'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('尚未驗證的帳號也可以刪除。此操作會刪除目前資料庫中的帳號與資料，之後無法由 App 復原。'),
                    const SizedBox(height: FutureMintTokens.space3),
                    TextField(
                      controller: password,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.password],
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: '目前密碼',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: FutureMintTokens.space3),
                    TextField(
                      controller: confirmation,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: '輸入「刪除帳號」確認',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (actionError != null) ...[
                      const SizedBox(height: FutureMintTokens.space2),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          actionError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
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
                onPressed: deleting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: !ready || deleting
                    ? null
                    : () async {
                        setDialogState(() {
                          deleting = true;
                          actionError = null;
                        });
                        try {
                          await session.deleteAccount(password.text);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              deleting = false;
                              actionError = session.message ?? '帳號尚未刪除，請再試一次。';
                            });
                          }
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
    password.dispose();
    confirmation.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final email = session.account?.email ?? '你的電子郵件';
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(FutureMintTokens.pageGutter(context)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SoftCard(
                color: theme.brightness == Brightness.dark
                    ? FutureMintTokens.darkSurfaceRaised
                    : FutureMintTokens.lavenderSoft,
                borderWidth: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_unread_outlined, size: 48),
                    const SizedBox(height: FutureMintTokens.space4),
                    Text(
                      '請先驗證你的電子郵件',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: FutureMintTokens.space2),
                    Text(
                      '請查看 $email 的驗證信。若未收到，可重新寄送；完成信件中的步驟後，回到 App 按「我已完成驗證」。',
                      textAlign: TextAlign.center,
                    ),
                    if (session.message != null) ...[
                      const SizedBox(height: FutureMintTokens.space3),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          session.message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    if (session.notice != null) ...[
                      const SizedBox(height: FutureMintTokens.space3),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          session.notice!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: FutureMintTokens.space5),
                    FilledButton.icon(
                      onPressed: session.busy
                          ? null
                          : session.refreshEmailVerification,
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(session.busy ? '正在確認…' : '我已完成驗證'),
                    ),
                    const SizedBox(height: FutureMintTokens.space3),
                    OutlinedButton.icon(
                      onPressed: session.busy
                          ? null
                          : session.requestEmailVerification,
                      icon: const Icon(Icons.forward_to_inbox_outlined),
                      label: const Text('重新寄驗證信'),
                    ),
                    const SizedBox(height: FutureMintTokens.space3),
                    TextButton.icon(
                      onPressed: session.busy ? null : session.logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('改用其他帳號登入'),
                    ),
                    TextButton.icon(
                      onPressed: session.busy
                          ? null
                          : () => _deleteAccount(context, session),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('刪除這個帳號'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
