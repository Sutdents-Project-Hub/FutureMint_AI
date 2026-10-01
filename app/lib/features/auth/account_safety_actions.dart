import 'package:flutter/material.dart';
import '../../state/session_controller.dart';
import '../../shared/public_links.dart';
import '../settings/help_sheets.dart';

Future<void> showSessionDeleteAccount(
  BuildContext context,
  SessionController session,
) async {
  final password = TextEditingController(),
      confirmation = TextEditingController();
  var busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('刪除帳號'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('帳號與目前資料庫中的個人資料將永久刪除。請輸入目前密碼及「刪除帳號」確認。'),
              TextField(
                controller: password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onChanged: (_) => update(() {}),
                decoration: const InputDecoration(labelText: '目前密碼'),
              ),
              TextField(
                controller: confirmation,
                onChanged: (_) => update(() {}),
                decoration: const InputDecoration(labelText: '輸入「刪除帳號」確認'),
              ),
              if (error != null) Text(error!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialog),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed:
                busy ||
                    password.text.isEmpty ||
                    confirmation.text.trim() != '刪除帳號'
                ? null
                : () async {
                    update(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await session.deleteAccount(password.text);
                      if (dialog.mounted) Navigator.pop(dialog);
                    } catch (_) {
                      if (dialog.mounted) {
                        update(() {
                          busy = false;
                          error = session.message;
                        });
                      }
                    }
                  },
            child: Text(busy ? '正在刪除…' : '永久刪除帳號'),
          ),
        ],
      ),
    ),
  );
  password.dispose();
  confirmation.dispose();
}

class AccountSafetyActions extends StatelessWidget {
  const AccountSafetyActions({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PrivacySupportLinks(),
      TextButton.icon(
        onPressed: () => showSupportBot(context),
        icon: const Icon(Icons.support_agent),
        label: const Text('使用說明與協助'),
      ),
      TextButton.icon(
        onPressed: session.busy ? null : session.logout,
        icon: const Icon(Icons.logout),
        label: const Text('登出'),
      ),
      TextButton.icon(
        onPressed: session.busy || !session.hasActiveToken
            ? null
            : () => showSessionDeleteAccount(context, session),
        icon: const Icon(Icons.delete_outline),
        label: const Text('刪除這個帳號'),
      ),
    ],
  );
}
