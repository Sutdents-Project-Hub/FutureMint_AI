/// Public, compile-time configuration for a FutureMint client build.
///
/// Secrets do not belong here: every value is embedded into a Web or iOS
/// release bundle. Production builds must provide public endpoints and support
/// details explicitly instead of inheriting local development defaults.
final class ReleaseConfig {
  const ReleaseConfig({
    required this.apiBaseUri,
    required this.privacyPolicyUri,
    required this.supportUri,
    required this.supportEmail,
    required this.serviceOperator,
    required this.buildEnvironment,
  });

  static final ReleaseConfig current = ReleaseConfig.fromEnvironment();

  factory ReleaseConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000/api/',
    );
    const privacyPolicyUrl = String.fromEnvironment(
      'PRIVACY_POLICY_URL',
      defaultValue: 'http://localhost:3000/privacy',
    );
    const supportUrl = String.fromEnvironment(
      'SUPPORT_URL',
      defaultValue: 'http://localhost:3000/support',
    );
    const supportEmail = String.fromEnvironment(
      'SUPPORT_EMAIL',
      defaultValue: 'support@localhost',
    );
    const serviceOperator = String.fromEnvironment(
      'SERVICE_OPERATOR',
      defaultValue: 'FutureMint AI development',
    );
    const buildEnvironment = String.fromEnvironment(
      'BUILD_ENV',
      defaultValue: 'development',
    );

    return ReleaseConfig(
      apiBaseUri: Uri.parse(apiBaseUrl),
      privacyPolicyUri: Uri.parse(privacyPolicyUrl),
      supportUri: Uri.parse(supportUrl),
      supportEmail: supportEmail.trim(),
      serviceOperator: serviceOperator.trim(),
      buildEnvironment: buildEnvironment.trim(),
    );
  }

  final Uri apiBaseUri;
  final Uri privacyPolicyUri;
  final Uri supportUri;
  final String supportEmail;
  final String serviceOperator;
  final String buildEnvironment;

  bool get isProduction => buildEnvironment == 'production';

  /// Rejects unsafe public configuration before a production release starts.
  ///
  /// `validation` exists for CI's unsigned compile check only. The App Store
  /// archive script independently rejects it, so it cannot create an IPA.
  void validateForRuntime({required bool isReleaseMode}) {
    if (!isReleaseMode) return;
    if (buildEnvironment == 'validation') return;
    if (!isProduction) {
      throw StateError(
        'Release builds require BUILD_ENV=production or BUILD_ENV=validation.',
      );
    }

    _requirePublicApiUrl(apiBaseUri);
    _requirePublicUrl('PRIVACY_POLICY_URL', privacyPolicyUri);
    _requirePublicUrl('SUPPORT_URL', supportUri);
    if (!_emailPattern.hasMatch(supportEmail) ||
        _isReservedOrLocalHost(supportEmail.split('@').last)) {
      throw StateError('SUPPORT_EMAIL must be a valid public email address.');
    }
    if (serviceOperator.trim().isEmpty ||
        RegExp(
          r'[<>]|placeholder|未定',
          caseSensitive: false,
        ).hasMatch(serviceOperator)) {
      throw StateError('SERVICE_OPERATOR is required in production.');
    }
  }

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static void _requirePublicApiUrl(Uri value) {
    _requirePublicUrl('API_BASE_URL', value);
    if (!value.path.endsWith('/api/')) {
      throw StateError('API_BASE_URL must end in /api/.');
    }
  }

  static void _requirePublicUrl(String name, Uri value) {
    if (value.scheme != 'https' ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasQuery ||
        value.hasFragment ||
        (value.hasPort && value.port != 443)) {
      throw StateError('$name must be a public HTTPS URL.');
    }
    if (_isReservedOrLocalHost(value.host)) {
      throw StateError('$name cannot use a local or placeholder host.');
    }
  }

  static bool _isReservedOrLocalHost(String host) {
    final normalized = host.toLowerCase();
    // Require a DNS name. This also excludes IPv4, IPv6, single-label internal
    // names and trailing-dot aliases without rejecting domains beginning fc/fd.
    if (!RegExp(
      r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
    ).hasMatch(normalized)) {
      return true;
    }
    const reserved = [
      'localhost',
      'local',
      'internal',
      'test',
      'invalid',
      'example',
      'example.com',
      'example.net',
      'example.org',
    ];
    return reserved.any(
      (suffix) => normalized == suffix || normalized.endsWith('.$suffix'),
    );
  }
}
