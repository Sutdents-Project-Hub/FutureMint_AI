DateTime toTaipeiTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 8));

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime clampPickerDate(
  DateTime value, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final candidate = dateOnly(value);
  final first = dateOnly(firstDate);
  final last = dateOnly(lastDate);
  if (candidate.isBefore(first)) return first;
  if (candidate.isAfter(last)) return last;
  return candidate;
}

String formatTaipeiDateTime(DateTime value, {bool includeYear = false}) {
  final taipei = toTaipeiTime(value);
  final time =
      '${taipei.hour.toString().padLeft(2, '0')}:${taipei.minute.toString().padLeft(2, '0')}';
  return includeYear
      ? '${taipei.year}/${taipei.month}/${taipei.day} $time'
      : '${taipei.month}/${taipei.day} $time';
}
