import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _integer = NumberFormat.decimalPattern('zh_TW');

String formatTwd(int amountMinor) => 'NT\$ ${_integer.format(amountMinor)}';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amountMinor, {
    super.key,
    this.style,
    this.semanticLabel,
  });

  final int amountMinor;
  final TextStyle? style;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? '${_integer.format(amountMinor)} 元',
    child: Text(
      formatTwd(amountMinor),
      style:
          style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]) ??
          const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    ),
  );
}
