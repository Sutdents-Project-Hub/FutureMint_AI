import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../design/tokens.dart';
import '../features/settings/settings_sheet.dart';
import '../state/app_controller.dart';

class AppDestination {
  const AppDestination(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const appDestinations = [
  AppDestination('/', '首頁', Icons.home_outlined, Icons.home_rounded),
  AppDestination(
    '/records',
    '紀錄',
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
  ),
  AppDestination(
    '/capture',
    '記一筆',
    Icons.add_circle_outline_rounded,
    Icons.add_circle_rounded,
  ),
  AppDestination(
    '/learning',
    '學習',
    Icons.school_outlined,
    Icons.school_rounded,
  ),
  AppDestination(
    '/future-seed',
    '未來',
    Icons.trending_up_outlined,
    Icons.trending_up_rounded,
  ),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get _selectedIndex {
    final index = appDestinations.indexWhere((item) => item.path == location);
    return index < 0 ? 0 : index;
  }

  void _go(BuildContext context, int index) =>
      context.go(appDestinations[index].path);

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= FutureMintTokens.railBreakpoint;
    final controller = context.watch<AppController>();
    final offline = controller.mode == AppMode.offlineDemo;

    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FutureMintTokens.pageMaxWidth,
          ),
          child: Column(
            children: [
              if (controller.errorMessage != null ||
                  controller.noticeMessage != null)
                _GlobalMessage(
                  message: controller.errorMessage ?? controller.noticeMessage!,
                  error: controller.errorMessage != null,
                  onClose: controller.clearMessages,
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );

    if (!wide) {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: const _Brand(),
          actions: [
            _ModeChip(offline: offline),
            IconButton(
              tooltip: '設定',
              onPressed: () => showSettingsSheet(context),
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => _go(context, index),
          destinations: [
            for (final item in appDestinations)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 264,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 16, 12),
                    child: _Brand(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _ModeChip(offline: offline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: NavigationRail(
                      extended: true,
                      minExtendedWidth: 263,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) => _go(context, index),
                      groupAlignment: -1,
                      labelType: NavigationRailLabelType.none,
                      destinations: [
                        for (final item in appDestinations)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: () => showSettingsSheet(context),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('設定與服務狀態'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.spa_rounded, size: 22),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          'FutureMint AI',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
      ),
    ],
  );
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.offline});
  final bool offline;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: offline
        ? '使用內建合成資料，不會連線到真實金融服務'
        : '設定為 Connected 模式；實際可用狀態以畫面回應為準',
    child: Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        offline ? Icons.offline_bolt_outlined : Icons.cloud_outlined,
        size: 16,
      ),
      label: Text(offline ? '離線展示' : 'Connected 模式'),
    ),
  );
}

class _GlobalMessage extends StatelessWidget {
  const _GlobalMessage({
    required this.message,
    required this.error,
    required this.onClose,
  });

  final String message;
  final bool error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.info_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (error)
            TextButton(
              onPressed: () => showSettingsSheet(context),
              child: const Text('服務設定'),
            ),
          IconButton(
            tooltip: '關閉訊息',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    ),
  );
}
