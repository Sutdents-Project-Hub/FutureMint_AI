import 'package:flutter_test/flutter_test.dart';
import 'package:futuremint_app/core/release_config.dart';

ReleaseConfig config({
  String api = 'https://api.futuremint.tw/api/',
  String environment = 'production',
  String email = 'support@futuremint.tw',
}) => ReleaseConfig(
  apiBaseUri: Uri.parse(api),
  privacyPolicyUri: Uri.parse('https://futuremint.tw/privacy'),
  supportUri: Uri.parse('https://futuremint.tw/support'),
  supportEmail: email,
  serviceOperator: 'Synthetic test operator',
  buildEnvironment: environment,
);

void main() {
  test('release must explicitly select production or CI validation', () {
    expect(
      () => config(
        environment: 'development',
      ).validateForRuntime(isReleaseMode: true),
      throwsStateError,
    );
    expect(
      () => config(
        environment: 'validation',
      ).validateForRuntime(isReleaseMode: true),
      returnsNormally,
    );
    expect(
      () => config(
        environment: 'development',
      ).validateForRuntime(isReleaseMode: false),
      returnsNormally,
    );
  });

  test('public DNS domains starting fc and fd are accepted', () {
    for (final host in ['fcfinance.tw', 'fdfinance.tw']) {
      expect(
        () => config(
          api: 'https://$host/api/',
        ).validateForRuntime(isReleaseMode: true),
        returnsNormally,
      );
    }
  });

  test('release rejects local, IP, reserved and ambiguous URL forms', () {
    for (final url in [
      'http://api.futuremint.tw/api/',
      'https://127.0.0.1/api/',
      'https://8.8.8.8/api/',
      'https://[::1]/api/',
      'https://example.com/api/',
      'https://api.example.invalid/api/',
      'https://api.internal/api/',
      'https://api.localhost/api/',
      'https://api.test/api/',
      'https://api.futuremint.tw./api/',
      'https://user:password@api.futuremint.tw/api/',
      'https://api.futuremint.tw:3000/api/',
      'https://api.futuremint.tw/api/?redirect=foo',
      'https://api.futuremint.tw/api/#token',
      'https://api.futuremint.tw/',
    ]) {
      expect(
        () => config(api: url).validateForRuntime(isReleaseMode: true),
        throwsStateError,
        reason: url,
      );
    }
  });

  test('support address cannot use placeholder host', () {
    expect(
      () => config(
        email: 'support@example.com',
      ).validateForRuntime(isReleaseMode: true),
      throwsStateError,
    );
  });
}
