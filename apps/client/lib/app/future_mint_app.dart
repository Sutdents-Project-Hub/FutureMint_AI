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
