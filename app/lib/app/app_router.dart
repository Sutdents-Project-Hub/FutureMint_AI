import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/capture/capture_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/future_seed/future_seed_screen.dart';
import '../features/future_seed/investment_lab_screen.dart';
import '../features/learning/learning_screen.dart';
import '../features/notifications/notification_center_screen.dart';
import '../features/records/records_screen.dart';
import '../features/subscriptions/subscription_coach.dart';
import 'app_shell.dart';

GoRouter createAppRouter() => GoRouter(
  initialLocation: '/',
  errorPageBuilder: (context, state) => _instantPage(
    state,
    Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_outlined, size: 48),
            const SizedBox(height: 16),
            const Text('找不到這個頁面'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('回到首頁'),
            ),
          ],
        ),
      ),
    ),
  ),
  routes: [
    ShellRoute(
      pageBuilder: (context, state, child) =>
          _instantPage(state, AppShell(location: state.uri.path, child: child)),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (_, state) =>
              _instantPage(state, const DashboardScreen()),
        ),
        GoRoute(
          path: '/records',
          pageBuilder: (_, state) => _instantPage(state, const RecordsScreen()),
        ),
        GoRoute(
          path: '/capture',
          pageBuilder: (_, state) => _instantPage(state, const CaptureScreen()),
        ),
        GoRoute(
          path: '/learning',
          pageBuilder: (_, state) =>
              _instantPage(state, const LearningScreen()),
        ),
        GoRoute(
          path: '/notifications',
          pageBuilder: (_, state) =>
              _instantPage(state, const NotificationCenterScreen()),
        ),
        GoRoute(
          path: '/future-seed',
          pageBuilder: (_, state) =>
              _instantPage(state, const FutureSeedScreen()),
        ),
        GoRoute(
          path: '/future-seed/investment-lab',   
          pageBuilder: (_, state) =>
              _instantPage(state, const InvestmentLabScreen()),
        ),
        GoRoute(
          path: '/subscriptions',
          pageBuilder: (_, state) =>
              _instantPage(state, const SubscriptionCoachScreen()),
        ),
      ],
    ),
  ],
);

NoTransitionPage<void> _instantPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);
