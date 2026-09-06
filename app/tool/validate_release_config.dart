import 'dart:io';

import 'package:futuremint_app/core/release_config.dart';

void main() {
  final env = Platform.environment;
  try {
    ReleaseConfig(
      apiBaseUri: Uri.parse(env['API_BASE_URL'] ?? ''),
      privacyPolicyUri: Uri.parse(env['PRIVACY_POLICY_URL'] ?? ''),
      supportUri: Uri.parse(env['SUPPORT_URL'] ?? ''),
      supportEmail: env['SUPPORT_EMAIL'] ?? '',
      serviceOperator: env['SERVICE_OPERATOR'] ?? '',
      buildEnvironment: env['BUILD_ENV'] ?? '',
    ).validateForRuntime(isReleaseMode: true);
  } on Object catch (error) {
    stderr.writeln('Invalid release configuration: $error');
    exitCode = 1;
  }
}
