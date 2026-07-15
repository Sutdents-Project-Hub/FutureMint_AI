import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/shared/date_text.dart';

void main() {
  test('formats API timestamps in Asia Taipei across a UTC date boundary', () {
    expect(
      formatTaipeiDateTime(
        DateTime.parse('2026-07-13T17:30:00Z'),
        includeYear: true,
      ),
      '2026/7/14 01:30',
    );
  });

  test('clamps an untrusted date into a picker range', () {
    final first = DateTime(2026, 1, 1);
    final last = DateTime(2026, 12, 31);

    expect(
      clampPickerDate(DateTime(2025), firstDate: first, lastDate: last),
      first,
    );
    expect(
      clampPickerDate(DateTime(2027), firstDate: first, lastDate: last),
      last,
    );
  });
}
