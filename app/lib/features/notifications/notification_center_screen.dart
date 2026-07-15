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
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: FutureMintTokens.contentReading,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeading(
                  kicker: '圖形化提醒',
                  title: '需要注意的，不只是一串數字',
                  description: '提醒來自已確認的紀錄；訂閱提醒是檢查邀請，不代表一定浪費。',
                  accent: FutureMintTokens.coral,
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
    final color = switch (notice.level) {
      InsightLevel.attention => FutureMintTokens.sunSoft,
      InsightLevel.positive => FutureMintTokens.mintSoft,
      InsightLevel.info => FutureMintTokens.skySoft,
    };
    final icon = switch (notice.kind) {
      InsightKind.subscription => Icons.autorenew_rounded,
      InsightKind.spending => Icons.donut_small_rounded,
      InsightKind.saving => Icons.trending_up_rounded,
      InsightKind.learning => Icons.school_outlined,
    };
    return SoftCard(
      borderWidth: 1,
      color: Theme.of(context).brightness == Brightness.dark
          ? FutureMintTokens.darkSurfaceRaised
          : color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: FutureMintTokens.ink,
            child: Icon(icon),
          ),
          const SizedBox(width: FutureMintTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: FutureMintTokens.space1),
                Text(notice.message),
                if (notice.amountMinor != null) ...[
                  const SizedBox(height: FutureMintTokens.space2),
                  MoneyText(
                    notice.amountMinor!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
                const SizedBox(height: FutureMintTokens.space2),
                TextButton.icon(
                  onPressed: () => context.go(notice.actionPath),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('前往查看'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
