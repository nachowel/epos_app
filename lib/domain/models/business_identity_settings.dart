class BusinessIdentitySettings {
  const BusinessIdentitySettings({
    required this.businessName,
    required this.businessAddress,
  });

  const BusinessIdentitySettings.empty()
    : businessName = null,
      businessAddress = null;

  final String? businessName;
  final String? businessAddress;

  BusinessIdentitySettings copyWith({
    Object? businessName = _unset,
    Object? businessAddress = _unset,
  }) {
    return BusinessIdentitySettings(
      businessName: businessName == _unset
          ? this.businessName
          : businessName as String?,
      businessAddress: businessAddress == _unset
          ? this.businessAddress
          : businessAddress as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BusinessIdentitySettings &&
        other.businessName == businessName &&
        other.businessAddress == businessAddress;
  }

  @override
  int get hashCode => Object.hash(businessName, businessAddress);
}

const Object _unset = Object();
