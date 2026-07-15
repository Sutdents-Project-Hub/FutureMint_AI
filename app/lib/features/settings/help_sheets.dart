import 'package:flutter/material.dart';

import '../../design/soft_components.dart';
import '../../design/tokens.dart';

Future<void> showAppWalkthrough(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WalkthroughSheet(),
    );

Future<void> showSupportBot(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _SupportBotSheet(),
);

class _WalkthroughSheet extends StatelessWidget {
  const _WalkthroughSheet();

  @override
  Widget build(BuildContext context) => const _HelpFrame(
    title: '四步開始使用',
    children: [
      _Step(
        index: 1,
        icon: Icons.record_voice_over_outlined,
        title: '說出一筆',
        body: '用一句話輸入已發生的收入、支出或訂閱。',
      ),
      _Step(
        index: 2,
        icon: Icons.rule_rounded,
        title: '確認 AI 草稿',
        body: '檢查金額、日期與需要／想要建議，再由你決定是否保存。',
      ),
      _Step(
        index: 3,
        icon: Icons.analytics_outlined,
        title: '先看分析',
        body: '從紀錄頁觀察收支、固定成本與自己的選擇模式。',
      ),
      _Step(
        index: 4,
        icon: Icons.trending_up_rounded,
        title: '把省下的錢放進時間',
        body: '比較三種合成風險路徑，讓 AI 陪讀員解釋曲線。',
      ),
    ],
  );
}

class _SupportBotSheet extends StatefulWidget {
  const _SupportBotSheet();

  @override
  State<_SupportBotSheet> createState() => _SupportBotSheetState();
}

class _SupportBotSheetState extends State<_SupportBotSheet> {
  String? selected;

  static const answers = {
    '如何記帳？': '到「記一筆」說出已發生的交易，確認 AI 草稿後才會保存。',
    '資料存在哪？': '訪客資料只留在這次使用期間；登入後依帳號保存。本服務不串接銀行或付款。',
    '訂閱提醒怎麼看？': '提醒是請你檢查使用頻率、重複方案與續訂日，不會直接判定為浪費。',
    '模擬投資是真的嗎？': '不是。三條曲線使用固定版本的合成報酬路徑，只用來理解時間、紀律與風險。',
    'AI 沒有回應': '可先確認 API 服務狀態；系統也提供離線示範內容，不應輸入任何帳號、卡號或個資。',
  };

  @override
  Widget build(BuildContext context) => _HelpFrame(
    title: '服務諮詢機器人',
    children: [
      const Text('請選擇問題類型。這是制式客服，不會讀取你的交易明細。'),
      const SizedBox(height: FutureMintTokens.space4),
      for (final question in answers.keys)
        Padding(
          padding: const EdgeInsets.only(bottom: FutureMintTokens.space2),
          child: OutlinedButton(
            onPressed: () => setState(() => selected = question),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(question),
            ),
          ),
        ),
      if (selected != null) ...[
        const SizedBox(height: FutureMintTokens.space3),
        SoftCard(
          color: Theme.of(context).brightness == Brightness.dark
              ? FutureMintTokens.darkSurfaceRaised
              : FutureMintTokens.mintSoft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.support_agent_rounded),
              const SizedBox(width: FutureMintTokens.space3),
              Expanded(child: Text(answers[selected]!)),
            ],
          ),
        ),
      ],
    ],
  );
}

class _HelpFrame extends StatelessWidget {
  const _HelpFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        FutureMintTokens.space5,
        FutureMintTokens.space1,
        FutureMintTokens.space5,
        FutureMintTokens.space6 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: FutureMintTokens.space5),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.body,
  });

  final int index;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FutureMintTokens.space4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: FutureMintTokens.mintSoft,
          foregroundColor: FutureMintTokens.ink,
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: FutureMintTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index. $title',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: FutureMintTokens.space1),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
}
