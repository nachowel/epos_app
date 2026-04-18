class CustomSaleOverrideRequest {
  const CustomSaleOverrideRequest({required this.adminPin});

  final String adminPin;
}

class CustomSaleWriteRequest {
  const CustomSaleWriteRequest({
    required this.amountMinor,
    this.note,
    this.overrideRequest,
  });

  final int amountMinor;
  final String? note;
  final CustomSaleOverrideRequest? overrideRequest;
}

class CustomSaleValidationResult {
  const CustomSaleValidationResult({
    required this.amountMinor,
    required this.limitMinor,
    required this.note,
    required this.requiresAdminOverride,
  });

  final int amountMinor;
  final int limitMinor;
  final String? note;
  final bool requiresAdminOverride;
}
