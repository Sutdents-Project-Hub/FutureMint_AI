import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/capture/capture_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/future_seed/future_seed_screen.dart';
import '../features/learning/learning_screen.dart';
import '../features/records/records_screen.dart';
import '../features/subscriptions/subscription_coach.dart';
import 'app_shell.dart';

GoRouter createAppRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        GoRoute(path: '/records', builder: (_, _) => const RecordsScreen()),
        GoRoute(path: '/capture', builder: (_, _) => const CaptureScreen()),
        GoRoute(path: '/learning', builder: (_, _) => const LearningScreen()),
        GoRoute(
          path: '/future-seed',
          builder: (_, _) => const FutureSeedScreen(),
        ),
        GoRoute(
          path: '/subscriptions',
          builder: (_, _) => const SubscriptionCoachScreen(),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
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
);
