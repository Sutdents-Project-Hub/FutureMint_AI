import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../state/app_controller.dart';
import '../state/session_controller.dart';
import 'app_router.dart';

class FutureMintApp extends StatefulWidget {
  const FutureMintApp({super.key, this.controller, this.session})
    : assert(controller != null || session != null),
      assert(controller == null || session == null);

  final AppController? controller;
  final SessionController? session;

  @override
  State<FutureMintApp> createState() => _FutureMintAppState();
}

class _FutureMintAppState extends State<FutureMintApp> {
  late final router = createAppRouter();

  ThemeData get _light => FutureMintTheme.light();
  ThemeData get _dark => FutureMintTheme.dark();

  @override
  Widget build(BuildContext context) {
    final legacyController = widget.controller;
    if (legacyController != null) {
      return ChangeNotifierProvider.value(
        value: legacyController,
        child: Consumer<AppController>(
          builder: (context, controller, _) => MaterialApp.router(
            title: 'FutureMint AI',
            debugShowCheckedModeBanner: false,
            theme: _light,
            darkTheme: _dark,
            themeMode: controller.themeMode,
            routerConfig: router,
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: widget.session!,
      child: Consumer<SessionController>(
        builder: (context, session, _) {
          final home = switch (session.status) {
            SessionStatus.loading => const _LoadingScreen(),
            SessionStatus.signedOut => const AuthScreen(),
            SessionStatus.restorationFailed => _SessionRecoveryScreen(
              message: session.message,
              busy: session.busy,
              onRetry: session.start,
              onUseAnotherAccount: session.discardStoredSession,
            ),
            SessionStatus.onboarding => const OnboardingScreen(),
            SessionStatus.authenticated || SessionStatus.guest => null,
          };
          if (home != null) {
            return MaterialApp(
              title: 'FutureMint AI',
              debugShowCheckedModeBanner: false,
              theme: _light,
              darkTheme: _dark,
              home: home,
            );
          }
          final app = session.app!;
          return ChangeNotifierProvider.value(
            value: app,
            child: Consumer<AppController>(
              builder: (context, controller, _) => MaterialApp.router(
                title: 'FutureMint AI',
                debugShowCheckedModeBanner: false,
                theme: _light,
                darkTheme: _dark,
                themeMode: controller.themeMode,
                routerConfig: router,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _SessionRecoveryScreen extends StatelessWidget {
  const _SessionRecoveryScreen({
    required this.message,
    required this.busy,
    required this.onRetry,
    required this.onUseAnotherAccount,
  });

  final String? message;
  final bool busy;
  final Future<void> Function() onRetry;
  final Future<void> Function() onUseAnotherAccount;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  '暫時無法恢復登入',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  message ?? '請確認網路後再試一次；你的登入資訊仍保留在這台裝置。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: busy ? null : onRetry,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(busy ? '正在重試…' : '重新連線'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: busy ? null : onUseAnotherAccount,
                  child: const Text('改用其他帳號'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
