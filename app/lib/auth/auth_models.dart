class PublicAccount {
  const PublicAccount({
    required this.id,
    required this.email,
    required this.profileComplete,
    required this.createdAt,
  });

  final String id;
  final String email;
  final bool profileComplete;
  final DateTime createdAt;

  factory PublicAccount.fromJson(Map<String, dynamic> json) => PublicAccount(
    id: json['id'] as String,
    email: json['email'] as String,
    profileComplete: json['profileComplete'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  PublicAccount copyWith({bool? profileComplete}) => PublicAccount(
    id: id,
    email: email,
    profileComplete: profileComplete ?? this.profileComplete,
    createdAt: createdAt,
  );
}

class AuthSession {
  const AuthSession({required this.token, required this.account});

  final String token;
  final PublicAccount account;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String,
    account: PublicAccount.fromJson(json['account'] as Map<String, dynamic>),
  );
}

class AiConsentStatus {
  const AiConsentStatus({
    required this.granted,
    required this.policyVersion,
    this.grantedAt,
    this.withdrawnAt,
  });

  const AiConsentStatus.notGranted()
    : granted = false,
      policyVersion = null,
      grantedAt = null,
      withdrawnAt = null;

  final bool granted;
  final String? policyVersion;
  final DateTime? grantedAt;
  final DateTime? withdrawnAt;

  factory AiConsentStatus.fromJson(Map<String, dynamic> json) =>
      AiConsentStatus(
        granted: json['granted'] as bool? ?? false,
        policyVersion: json['policyVersion'] as String?,
        grantedAt: _dateOrNull(json['grantedAt']),
        withdrawnAt: _dateOrNull(json['withdrawnAt']),
      );

  static DateTime? _dateOrNull(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
