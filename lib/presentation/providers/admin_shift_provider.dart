import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/errors/exceptions.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/shift_report.dart';
import '../../domain/models/stale_final_close_recovery_details.dart';
import '../../domain/models/user.dart';
import '../../domain/models/z_report_action_result.dart';
import 'auth_provider.dart';
import 'orders_provider.dart';

class AdminShiftState {
  const AdminShiftState({
    required this.activeShift,
    required this.activeReport,
    required this.recentShifts,
    required this.isLoading,
    required this.isActionLoading,
    required this.staleFinalCloseRecovery,
    required this.errorMessage,
  });

  const AdminShiftState.initial()
    : activeShift = null,
      activeReport = null,
      recentShifts = const <Shift>[],
      isLoading = false,
      isActionLoading = false,
      staleFinalCloseRecovery = null,
      errorMessage = null;

  final Shift? activeShift;
  final ShiftReport? activeReport;
  final List<Shift> recentShifts;
  final bool isLoading;
  final bool isActionLoading;
  final StaleFinalCloseRecoveryDetails? staleFinalCloseRecovery;
  final String? errorMessage;

  AdminShiftState copyWith({
    Object? activeShift = _unset,
    Object? activeReport = _unset,
    List<Shift>? recentShifts,
    bool? isLoading,
    bool? isActionLoading,
    Object? staleFinalCloseRecovery = _unset,
    Object? errorMessage = _unset,
  }) {
    return AdminShiftState(
      activeShift: activeShift == _unset
          ? this.activeShift
          : activeShift as Shift?,
      activeReport: activeReport == _unset
          ? this.activeReport
          : activeReport as ShiftReport?,
      recentShifts: recentShifts ?? this.recentShifts,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      staleFinalCloseRecovery: staleFinalCloseRecovery == _unset
          ? this.staleFinalCloseRecovery
          : staleFinalCloseRecovery as StaleFinalCloseRecoveryDetails?,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminShiftNotifier extends StateNotifier<AdminShiftState> {
  AdminShiftNotifier(this._ref) : super(const AdminShiftState.initial());

  final Ref _ref;

  Future<void> load() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final Shift? activeShift = await _ref
          .read(adminServiceProvider)
          .getActiveShift(user: currentUser);
      final List<Shift> recentShifts = await _ref
          .read(adminServiceProvider)
          .getRecentShifts(user: currentUser, limit: 30);
      final ShiftReport? activeReport = activeShift == null
          ? null
          : await _ref
                .read(adminServiceProvider)
                .getRawShiftReport(user: currentUser, shiftId: activeShift.id);

      state = state.copyWith(
        activeShift: activeShift,
        activeReport: activeReport,
        recentShifts: recentShifts,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_shift_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<bool> runFinalClose({required int countedCashMinor}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);
    try {
      final ZReportActionResult result = await _ref
          .read(adminServiceProvider)
          .runAdminFinalClose(
            user: currentUser,
            countedCashMinor: countedCashMinor,
          );
      await _ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      await load();
      state = state.copyWith(
        activeShift: null,
        activeReport: result.report,
        isActionLoading: false,
        staleFinalCloseRecovery: null,
        errorMessage: null,
      );
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
          eventType: 'admin_shift_final_close_failed',
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
      await _ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      await load();
      state = state.copyWith(
        activeShift: null,
        activeReport: result.report,
        isActionLoading: false,
        staleFinalCloseRecovery: null,
        errorMessage: null,
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
          eventType: 'admin_shift_final_close_resume_failed',
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
      await load();
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
          eventType: 'admin_shift_final_close_discard_failed',
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
}

final StateNotifierProvider<AdminShiftNotifier, AdminShiftState>
adminShiftNotifierProvider =
    StateNotifierProvider<AdminShiftNotifier, AdminShiftState>(
      (Ref ref) => AdminShiftNotifier(ref),
    );

const Object _unset = Object();
