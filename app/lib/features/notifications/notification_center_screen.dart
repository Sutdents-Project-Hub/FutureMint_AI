import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../design/soft_components.dart';
import '../../design/tokens.dart';
import '../../shared/money_text.dart';
import '../../state/app_controller.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notices =
        context.watch<AppController>().insights?.notices ??
        const <InsightNotice>[];
    final gutter = FutureMintTokens.pageGutter(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        FutureMintTokens.space5,
        gutter,
        FutureMintTokens.space7,
      ),
      children: [
        ResponsivePageCanvas(
          compactMaxWidth: FutureMintTokens.contentReading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeading(
                kicker: '圖形化提醒',
                title: '需要注意的，不只是一串數字',
                description: '提醒來自已確認的紀錄；訂閱提醒是檢查邀請，不代表一定浪費。',
                accent: FutureMintTokens.coralInk,
              ),
              const SizedBox(height: FutureMintTokens.space5),
              if (notices.isEmpty)
                const SoftCard(
                  child: Row(
                    children: [
                      Icon(Icons.notifications_none_rounded),
                      SizedBox(width: FutureMintTokens.space3),
                      Expanded(child: Text('目前沒有需要處理的提醒。')),
                    ],
                  ),
                )
              else
                for (final notice in notices)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: FutureMintTokens.space3,
                    ),
                    child: _NoticeCard(notice: notice),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final InsightNotice notice;

  @override
  Widget build(BuildContext context) {
    final dark = FutureMintTokens.isDark(context);
    final (surface, accent) = switch (notice.level) {
      InsightLevel.attention => (
        FutureMintTokens.sunSoft,
        FutureMintTokens.sun,
      ),
      InsightLevel.positive => (
        FutureMintTokens.mintSoft,
        FutureMintTokens.lavender,
      ),
      InsightLevel.info => (FutureMintTokens.skySoft, FutureMintTokens.sky),
    };
    final icon = switch (notice.kind) {
      InsightKind.subscription => Icons.autorenew_rounded,
      InsightKind.spending => Icons.donut_small_rounded,
      InsightKind.saving => Icons.trending_up_rounded,
      InsightKind.learning => Icons.school_outlined,
    };
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: Material(
        color: dark ? FutureMintTokens.darkSurfaceRaised : surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusMedium),
          side: BorderSide(
            color: dark
                ? accent.withValues(alpha: .28)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(notice.actionPath),
          child: Padding(
            padding: FutureMintTokens.cardPadding(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The icon keeps its own tinted disc in both themes so it never
                // disappears into the card surface.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark
                        ? accent.withValues(alpha: .2)
                        : theme.colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      icon,
                      color: dark ? accent : FutureMintTokens.ink,
                    ),
                  ),
                ),
                const SizedBox(width: FutureMintTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: FutureMintTokens.space1),
                      Text(notice.message),
                      const SizedBox(height: FutureMintTokens.space3),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: FutureMintTokens.space3,
                        runSpacing: FutureMintTokens.space2,
                        children: [
                          if (notice.amountMinor != null)
                            MoneyText(
                              notice.amountMinor!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '前往查看',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: FutureMintTokens.space1),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
