class ServicePolicy {
  const ServicePolicy({
    required this.aiPolicyVersion,
    required this.aiDisplayName,
    required this.aiProvider,
    required this.dataRecipients,
    required this.dataTerms,
    this.model,
    this.reviewed = true,
    this.eligibilityRequired = true,
    this.mailEnabled = true,
    this.registrationEnabled = true,
    this.emailVerificationRequired = true,
  });
  final String aiPolicyVersion, aiDisplayName, aiProvider, dataTerms;
  final String? model;
  final List<String> dataRecipients;
  final bool reviewed;
  final bool eligibilityRequired;
  final bool mailEnabled;
  final bool registrationEnabled;
  final bool emailVerificationRequired;
  String get signature =>
      '$aiPolicyVersion|$aiProvider|$aiDisplayName|$model|${dataRecipients.join('|')}|$dataTerms|$reviewed|$eligibilityRequired|$mailEnabled|$registrationEnabled|$emailVerificationRequired';
  factory ServicePolicy.fromJson(Map<String, dynamic> j) {
    final ai = j['ai'] as Map<String, dynamic>;
    return ServicePolicy(
      aiPolicyVersion: ai['policyVersion'] as String,
      reviewed: ai['reviewed'] as bool? ?? false,
      eligibilityRequired: j['eligibilityRequired'] as bool? ?? true,
      mailEnabled: j['mailEnabled'] as bool? ?? true,
      registrationEnabled: j['registrationEnabled'] as bool? ?? true,
      emailVerificationRequired:
          j['emailVerificationRequired'] as bool? ??
          (j['mailEnabled'] as bool? ?? true),
      aiDisplayName: ai['displayName'] as String,
      aiProvider: ai['provider'] as String,
      model: ai['model'] as String?,
      dataRecipients: List<String>.from(ai['dataRecipients'] as List? ?? []),
      dataTerms: ai['dataTerms'] is String
          ? ai['dataTerms'] as String
          : '${ai['dataTerms']}',
    );
  }
}

class EligibilityStatus {
  const EligibilityStatus({
    required this.status,
    required this.canWrite,
    this.ageBand,
    this.guardianStatus,
  });
  final String status;
  final String? ageBand, guardianStatus;
  final bool canWrite;
  factory EligibilityStatus.fromJson(Map<String, dynamic> j) =>
      EligibilityStatus(
        status: j['status'] as String,
        canWrite: j['canWrite'] as bool? ?? false,
        ageBand: j['ageBand'] as String?,
        guardianStatus: j['guardianStatus'] as String?,
      );
}

const agePolicyVersion = 'tw-service-age-15-v1';
