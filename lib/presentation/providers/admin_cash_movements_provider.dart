import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/cash_movement.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminCashMovementsState {
  const AdminCashMovementsState({
    required this.activeShift,
    required this.movements,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  const AdminCashMovementsState.initial()
    : activeShift = null,
      movements = const <CashMovement>[],
      isLoading = false,
      isSaving = false,
      errorMessage = null;

  final Shift? activeShift;
  final List<CashMovement> movements;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  AdminCashMovementsState copyWith({
    Object? activeShift = _unset,
    List<CashMovement>? movements,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return AdminCashMovementsState(
      activeShift: activeShift == _unset
          ? this.activeShift
          : activeShift as Shift?,
      movements: movements ?? this.movements,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminCashMovementsNotifier
    extends StateNotifier<AdminCashMovementsState> {
  AdminCashMovementsNotifier(this._ref)
    : super(const AdminCashMovementsState.initial());

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
      final List<CashMovement> movements = activeShift == null
          ? const <CashMovement>[]
          : await _ref
                .read(adminServiceProvider)
                .getCashMovementsForActiveShift(user: currentUser);

      state = state.copyWith(
        activeShift: activeShift,
        movements: movements,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_cash_movements_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<bool> createCashMovement({
    required CashMovementType type,
    required String category,
    required int amountMinor,
    required CashMovementPaymentMethod paymentMethod,
    String? note,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .createManualCashMovement(
            user: currentUser,
            type: type,
            category: category,
            amountMinor: amountMinor,
            paymentMethod: paymentMethod,
            note: note,
          );
      await load();
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_cash_movement_create_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }
}

final StateNotifierProvider<AdminCashMovementsNotifier, AdminCashMovementsState>
adminCashMovementsNotifierProvider =
    StateNotifierProvider<AdminCashMovementsNotifier, AdminCashMovementsState>(
      (Ref ref) => AdminCashMovementsNotifier(ref),
    );

const Object _unset = Object();
