import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/errors/exceptions.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/authorization_policy.dart';
import '../../domain/models/cashier_projected_report.dart';
import '../../domain/models/shift_report.dart';
import '../../domain/models/stale_final_close_recovery_details.dart';
import '../../domain/models/user.dart';
import '../../domain/models/z_report_action_result.dart';
import 'auth_provider.dart';
import 'orders_provider.dart';
import 'shift_provider.dart';

class ReportsState {
  const ReportsState({
    required this.adminReport,
    required this.cashierReport,
    required this.currentShiftId,
    required this.isLoading,
    required this.isActionLoading,
    required this.isPrintLoading,
    required this.staleFinalCloseRecovery,
    required this.errorMessage,
  });

  const ReportsState.initial()
    : adminReport = null,
      cashierReport = null,
      currentShiftId = null,
      isLoading = false,
      isActionLoading = false,
      isPrintLoading = false,
      staleFinalCloseRecovery = null,
      errorMessage = null;

  final ShiftReport? adminReport;
  final CashierProjectedReport? cashierReport;
  final int? currentShiftId;
  final bool isLoading;
  final bool isActionLoading;
  final bool isPrintLoading;
  final StaleFinalCloseRecoveryDetails? staleFinalCloseRecovery;
  final String? errorMessage;

  ReportsState copyWith({
    Object? adminReport = _unset,
    Object? cashierReport = _unset,
    Object? currentShiftId = _unset,
    bool? isLoading,
    bool? isActionLoading,
    bool? isPrintLoading,
    Object? staleFinalCloseRecovery = _unset,
    Object? errorMessage = _unset,
  }) {
    return ReportsState(
      adminReport: adminReport == _unset
          ? this.adminReport
          : adminReport as ShiftReport?,
      cashierReport: cashierReport == _unset
          ? this.cashierReport
          : cashierReport as CashierProjectedReport?,
      currentShiftId: currentShiftId == _unset
          ? this.currentShiftId
          : currentShiftId as int?,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isPrintLoading: isPrintLoading ?? this.isPrintLoading,
      staleFinalCloseRecovery: staleFinalCloseRecovery == _unset
          ? this.staleFinalCloseRecovery
          : staleFinalCloseRecovery as StaleFinalCloseRecoveryDetails?,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class ReportsNotifier extends StateNotifier<ReportsState> {
  ReportsNotifier(this._ref) : super(const ReportsState.initial());

  final Ref _ref;

  Future<void> loadReportForShift(int shiftId) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (currentUser.role == UserRole.admin) {
        final ShiftReport visibleReport = await _ref
            .read(reportServiceProvider)
            .getVisibleShiftReport(shiftId: shiftId, user: currentUser);

        state = state.copyWith(
          adminReport: visibleReport,
          cashierReport: null,
          currentShiftId: shiftId,
          isLoading: false,
          errorMessage: null,
        );
      } else {
        final CashierProjectedReport cashierReport = await _ref
            .read(cashierReportServiceProvider)
            .getReport(user: currentUser);
        state = state.copyWith(
          adminReport: null,
          cashierReport: cashierReport,
          currentShiftId: cashierReport.shiftId,
          isLoading: false,
          errorMessage: null,
        );
      }
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'report_load_shift_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> loadReportForOpenShift() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (currentUser.role == UserRole.cashier) {
        final CashierProjectedReport cashierReport = await _ref
            .read(cashierReportServiceProvider)
            .getReport(user: currentUser);
        state = state.copyWith(
          adminReport: null,
          cashierReport: cashierReport,
          currentShiftId: cashierReport.shiftId,
          isLoading: false,
          errorMessage: null,
        );
        return;
      }

      await _ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
      final openShift = _ref.read(shiftNotifierProvider).backendOpenShift;
      if (openShift == null) {
        state = state.copyWith(
          adminReport: null,
          cashierReport: null,
          currentShiftId: null,
          isLoading: false,
          errorMessage: null,
        );
        return;
      }

      await loadReportForShift(openShift.id);
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'report_load_open_shift_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<bool> takeCashierEndOfDayPreview() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);
    try {
      final ZReportActionResult result = await _ref
          .read(reportServiceProvider)
          .takeCashierEndOfDayPreview(user: currentUser);
      await _syncAfterReportAction(result);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'cashier_preview_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> runAdminFinalClose({required int countedCashMinor}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);
    try {
      final ZReportActionResult result = await _ref
          .read(reportServiceProvider)
          .runAdminFinalCloseWithCountedCash(
            user: currentUser,
            countedCashMinor: countedCashMinor,
          );
      await _syncAfterReportAction(result);
      await _ref.read(shiftNotifierProvider.notifier).loadRecentShifts();
      state = state.copyWith(staleFinalCloseRecovery: null);
      return true;
    } on StaleFinalCloseReconciliationException catch (error) {
      state = state.copyWith(
        isActionLoading: false,
        staleFinalCloseRecovery: error.details,
        errorMessage: null,
      );
      return false;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isActionLoading: false,
        staleFinalCloseRecovery: null,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_final_close_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> resumeStaleFinalClose() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    final StaleFinalCloseRecoveryDetails? recovery =
        state.staleFinalCloseRecovery;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    if (recovery == null) {
      state = state.copyWith(errorMessage: AppStrings.finalCloseFailed);
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);
    try {
      final ZReportActionResult result = await _ref
          .read(reportServiceProvider)
          .resumeStaleAdminFinalClose(user: currentUser, recovery: recovery);
      await _syncAfterReportAction(result);
      await _ref.read(shiftNotifierProvider.notifier).loadRecentShifts();
      state = state.copyWith(staleFinalCloseRecovery: null);
      return true;
    } catch (error, stackTrace) {
      final bool clearRecovery =
          error is ShiftClosedException ||
          error is ShiftNotActiveException ||
          error is StaleFinalCloseRecoveryUnavailableException;
      state = state.copyWith(
        isActionLoading: false,
        staleFinalCloseRecovery: clearRecovery ? null : recovery,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_final_close_resume_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> discardStaleFinalClose() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    final StaleFinalCloseRecoveryDetails? recovery =
        state.staleFinalCloseRecovery;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    if (recovery == null) {
      state = state.copyWith(errorMessage: AppStrings.finalCloseFailed);
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);
    try {
      await _ref
          .read(reportServiceProvider)
          .discardStaleAdminFinalClose(user: currentUser, recovery: recovery);
      await loadReportForOpenShift();
      await _ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      state = state.copyWith(
        isActionLoading: false,
        staleFinalCloseRecovery: null,
      );
      return true;
    } catch (error, stackTrace) {
      final bool clearRecovery =
          error is ShiftClosedException ||
          error is ShiftNotActiveException ||
          error is StaleFinalCloseRecoveryUnavailableException;
      state = state.copyWith(
        isActionLoading: false,
        staleFinalCloseRecovery: clearRecovery ? null : recovery,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_final_close_discard_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  void clearStaleFinalCloseRecovery() {
    state = state.copyWith(
      isActionLoading: false,
      staleFinalCloseRecovery: null,
      errorMessage: null,
    );
  }

  Future<bool> printCurrentReport() async {
    final ShiftReport? report = state.adminReport;
    if (report == null) {
      state = state.copyWith(errorMessage: AppStrings.noReportData);
      return false;
    }

    state = state.copyWith(isPrintLoading: true, errorMessage: null);
    try {
      await _ref.read(printerServiceProvider).printZReport(report);
      state = state.copyWith(isPrintLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isPrintLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'z_report_print_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> printCashierReport() async {
    final CashierProjectedReport? report = state.cashierReport;
    if (report == null || !report.hasOpenShift) {
      state = state.copyWith(errorMessage: AppStrings.noReportData);
      return false;
    }

    state = state.copyWith(isPrintLoading: true, errorMessage: null);
    try {
      await _ref.read(printerServiceProvider).printCashierZReport(report);
      state = state.copyWith(isPrintLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isPrintLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'cashier_z_report_print_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<void> _syncAfterReportAction(ZReportActionResult result) async {
    await _ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
    await _ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: AppStrings.accessDenied,
      );
      return;
    }

    if (currentUser.role == UserRole.admin) {
      state = state.copyWith(
        adminReport: result.report,
        cashierReport: null,
        currentShiftId: result.shiftId,
        isActionLoading: false,
        errorMessage: null,
      );
      return;
    }

    final CashierProjectedReport cashierReport = await _ref
        .read(cashierReportServiceProvider)
        .getReport(user: currentUser);
    state = state.copyWith(
      adminReport: null,
      cashierReport: cashierReport,
      currentShiftId: cashierReport.shiftId,
      isActionLoading: false,
      errorMessage: null,
    );
  }
}

final StateNotifierProvider<ReportsNotifier, ReportsState>
reportsNotifierProvider = StateNotifierProvider<ReportsNotifier, ReportsState>(
  (Ref ref) => ReportsNotifier(ref),
);

final adminVisibleShiftReportProvider = FutureProvider.family<ShiftReport, int>(
  (Ref ref, int shiftId) async {
    final User? currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      throw StateError(
        'Current user is required to load a visible shift report.',
      );
    }
    AuthorizationPolicy.ensureAllowed(
      currentUser,
      OperatorPermission.viewFullReports,
    );
    return ref
        .read(reportServiceProvider)
        .getVisibleShiftReport(shiftId: shiftId, user: currentUser);
  },
);

const Object _unset = Object();
