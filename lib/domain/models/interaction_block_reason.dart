import '../../core/constants/app_strings.dart';

enum InteractionBlockReason {
  unauthenticated,
  noOpenShift,
  adminFinalCloseRequired,
}

extension InteractionBlockReasonMessaging on InteractionBlockReason {
  String get operatorMessage {
    switch (this) {
      case InteractionBlockReason.unauthenticated:
        return AppStrings.accessDenied;
      case InteractionBlockReason.noOpenShift:
        return AppStrings.shiftClosedOpenShiftRequired;
      case InteractionBlockReason.adminFinalCloseRequired:
        return AppStrings.salesLockedAdminCloseRequired;
    }
  }
}
