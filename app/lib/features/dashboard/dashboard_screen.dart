ㄋ extends StatelessWidget {
  const _SyntheticDisclosure({required this.guest});
  final bool guest;
  @override
  Widget build(BuildContext context) => NeonCard(
    padding: const EdgeInsets.all(FutureMintTokens.space4),
    radius: 16,
    borderWidth: 1,
    color: _softSurface(context, FutureMintTokens.mintSoft),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 20),
        const SizedBox(width: FutureMintTokens.space3),
        Expanded(
          child: Text(
            guest
                ? '這是訪客暫存資料；離開或重新整理後會清除，不會接觸真實帳戶或付款。'
                : '你的資料會依登入帳號保存；本產品仍不串接真實金融帳戶或付款。',
          ),
        ),
      ],
    ),
  );
}

class _RecentEventTile extends StatelessWidget {
  const _RecentEventTile({required this.event});
  final MoneyEvent event;

  @override
  Widget build(BuildContext context) {
    final income = event.type == MoneyEventType.income;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: income
            ? _softSurface(context, FutureMintTokens.mintSoft)
            : _softSurface(context, FutureMintTokens.coralSoft),
        child: Icon(
          income ? Icons.south_west_rounded : Icons.north_east_rounded,
        ),
      ),
      title: Text(event.merchant ?? categoryLabel(event.category)),
      subtitle: Text(formatTaipeiDateTime(event.occurredAt)),
      trailing: MoneyText(
        income ? event.effectiveAmountMinor : -event.effectiveAmountMinor,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: income
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: SizedBox.square(
      dimension: 44,
      child: Icon(icon, color: FutureMintTokens.ink),
    ),
  );
}

Color _softSurface(BuildContext context, Color light) =>
    Theme.of(context).brightness == Brightness.dark
    ? FutureMintTokens.darkSurfaceRaised
    : light;

String categoryLabel(MoneyCategory category) => switch (category) {
  MoneyCategory.food => '餐飲',
  MoneyCategory.transport => '交通',
  MoneyCategory.entertainment => '娛樂',
  MoneyCategory.education => '學習',
  MoneyCategory.shopping => '購物',
  MoneyCategory.income => '收入',
  MoneyCategory.subscription => '訂閱',
  MoneyCategory.other => '其他',
};
