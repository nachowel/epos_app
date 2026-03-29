import 'business_identity_settings.dart';
import 'report_settings_policy.dart';

class CashierZReportSettings {
  const CashierZReportSettings({
    required this.policy,
    required this.businessIdentity,
  });

  const CashierZReportSettings.defaults()
    : policy = const ReportSettingsPolicy.defaults(),
      businessIdentity = const BusinessIdentitySettings.empty();

  final ReportSettingsPolicy policy;
  final BusinessIdentitySettings businessIdentity;

  CashierZReportSettings copyWith({
    ReportSettingsPolicy? policy,
    BusinessIdentitySettings? businessIdentity,
  }) {
    return CashierZReportSettings(
      policy: policy ?? this.policy,
      businessIdentity: businessIdentity ?? this.businessIdentity,
    );
  }
}
