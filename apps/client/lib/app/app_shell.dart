import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../design/soft_components.dart';
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
    final index = appDestinations.indexWhere(
      (item) =>
          item.path == location ||
          (item.path != '/' && location.startsWith('${item.path}/')),
    );
    return index < 0 ? 0 : index;
  }

  void _go(BuildContext context, int index) =>
      context.go(appDestinations[index].path);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final guest = controller.mode == AppMode.guest;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= FutureMintTokens.railBreakpoint;
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
                      message:
                          controller.errorMessage ?? controller.noticeMessage!,
                      error: controller.errorMessage != null,
                      onClose: controller.clearMessages,
                    ),
                  if (guest) const _GuestNotice(),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        );

        if (!wide) {
          return Scaffold(
            appBar: AppBar(
              titleSpacing: FutureMintTokens.space4,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: const _Brand(),
              actions: [
                _ModeChip(
                  guest: guest,
                  accountEmail: controller.accountEmail,
                  accountRole: controller.profile?.accountRole,
                ),
                _NotificationButton(
                  count: controller.insights?.notices.length ?? 0,
                ),
                IconButton(
                  tooltip: '設定',
                  onPressed: () => showSettingsSheet(context),
                  icon: const Icon(Icons.tune_rounded),
                ),
                const SizedBox(width: FutureMintTokens.space2),
              ],
            ),
            body: content,
            bottomNavigationBar: _MobileNavigation(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => _go(context, index),
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? FutureMintTokens.darkSurface
                        : FutureMintTokens.paper,
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, railConstraints) {
                      NavigationRail buildRail() => NavigationRail(
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
                      );
                      final header = <Widget>[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 24, 16, 12),
                          child: _Brand(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FutureMintTokens.space4,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _ModeChip(
                              guest: guest,
                              accountEmail: controller.accountEmail,
                              accountRole: controller.profile?.accountRole,
                            ),
                          ),
                        ),
                        const SizedBox(height: FutureMintTokens.space5),
                      ];
                      final settings = Padding(
                        padding: const EdgeInsets.all(FutureMintTokens.space4),
                        child: SoftCard(
                          padding: EdgeInsets.zero,
                          borderWidth: 1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? FutureMintTokens.darkSurfaceRaised
                              : FutureMintTokens.mintSoft,
                          child: Column(
                            children: [
                              TextButton.icon(
                                onPressed: () => context.go('/notifications'),
                                icon: Badge(
                                  isLabelVisible:
                                      (controller.insights?.notices.length ??
                                          0) >
                                      0,
                                  label: Text(
                                    '${controller.insights?.notices.length ?? 0}',
                                  ),
                                  child: const Icon(
                                    Icons.notifications_outlined,
                                  ),
                                ),
                                label: const Text('分析提醒'),
                              ),
                              TextButton.icon(
                                onPressed: () => showSettingsSheet(context),
                                icon: const Icon(Icons.tune_rounded),
                                label: const Text('設定與服務狀態'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (railConstraints.maxHeight < 560) {
                        return SingleChildScrollView(
                          key: const Key('short-rail-scroll'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...header,
                              SizedBox(
                                height: appDestinations.length * 52 + 16,
                                child: buildRail(),
                              ),
                              settings,
                            ],
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...header,
                          Expanded(child: buildRail()),
                          settings,
                        ],
                      );
                    },
                  ),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final foreground = dark
        ? theme.colorScheme.onSurface
        : FutureMintTokens.paper;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: DecoratedBox(
          key: const Key('mobile-navigation-shell'),
          decoration: BoxDecoration(
            color: dark
                ? FutureMintTokens.darkSurfaceRaised
                : FutureMintTokens.ink,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBarTheme(
              data: theme.navigationBarTheme.copyWith(
                indicatorColor: dark
                    ? FutureMintTokens.lavender
                    : FutureMintTokens.mintSoft,
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: FutureMintTokens.ink);
                  }
                  return IconThemeData(color: foreground);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    color: selected ? FutureMintTokens.ink : foreground,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  );
                }),
              ),
              child: NavigationBar(
                animationDuration: Duration.zero,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: [
                  for (final item in appDestinations)
                    NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    ),
                ],
              ),
            ),
          ),
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
      const MoneyBuddy(
        size: 40,
        color: FutureMintTokens.mint,
        excludeSemantics: true,
      ),
      const SizedBox(width: FutureMintTokens.space3),
      Flexible(
        child: Text(
          'FutureMint AI',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    ],
  );
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.guest, this.accountEmail, this.accountRole});
  final bool guest;
  final String? accountEmail;
  final AccountRole? accountRole;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = dark ? FutureMintTokens.paper : FutureMintTokens.ink;
    return Tooltip(
      message:
          '${guest ? '訪客資料只保留在這次使用期間，不會寫入帳號。' : '已登入 ${accountEmail ?? '你的帳號'}；資料會依帳號分開保存。'}'
          ' 目前角色：${accountRole == AccountRole.parent ? '家長陪伴' : '孩子使用'}。',
      child: Chip(
        visualDensity: VisualDensity.compact,
        backgroundColor: guest
            ? (dark
                  ? FutureMintTokens.darkSurfaceRaised
                  : FutureMintTokens.mintSoft)
            : (dark ? const Color(0xFF184B60) : FutureMintTokens.skySoft),
        avatar: Icon(
          guest ? Icons.visibility_outlined : Icons.verified_user_outlined,
          size: 16,
          color: guest ? FutureMintTokens.mint : FutureMintTokens.sky,
        ),
        label: Text(
          guest ? '訪客' : '已登入',
          style: TextStyle(color: labelColor, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '分析提醒',
    onPressed: () => context.go('/notifications'),
    icon: Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: const Icon(Icons.notifications_outlined),
    ),
  );
}

class _GuestNotice extends StatelessWidget {
  const _GuestNotice();

  @override
  Widget build(BuildContext context) => Container(
    color: Theme.of(context).brightness == Brightness.dark
        ? FutureMintTokens.darkSurfaceRaised
        : FutureMintTokens.lavenderSoft,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: FutureMintTokens.space3),
        Expanded(
          child: Wrap(
            spacing: FutureMintTokens.space3,
            runSpacing: FutureMintTokens.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '訪客資料不會儲存',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text('離開或重新整理後會清除', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : FutureMintTokens.lavenderSoft,
      border: Border(
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.info_outline, size: 20),
          const SizedBox(width: FutureMintTokens.space3),
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
