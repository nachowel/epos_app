import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/errors/exceptions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/models/business_identity_settings.dart';
import '../../domain/models/cashier_projection_preview.dart';
import '../../domain/models/cashier_z_report_settings.dart';
import '../../domain/models/report_settings_policy.dart';
import '../../domain/models/shift_report.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class SettingsState {
  const SettingsState({
    required this.cashierReportMode,
    required this.visibilityRatio,
    required this.maxVisibleTotalInput,
    required this.businessName,
    required this.businessAddress,
    required this.projectionPreview,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  const SettingsState.initial()
    : cashierReportMode = CashierReportMode.percentage,
      visibilityRatio = 1.0,
      maxVisibleTotalInput = '',
      businessName = '',
      businessAddress = '',
      projectionPreview = const CashierProjectionPreview.unavailable(),
      isLoading = false,
      isSaving = false,
      errorMessage = null;

  final CashierReportMode cashierReportMode;
  final double visibilityRatio;
  final String maxVisibleTotalInput;
  final String businessName;
  final String businessAddress;
  final CashierProjectionPreview projectionPreview;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  int? get parsedMaxVisibleTotalMinor {
    return CurrencyFormatter.tryParseEditableMajorInput(maxVisibleTotalInput);
  }

  SettingsState copyWith({
    CashierReportMode? cashierReportMode,
    double? visibilityRatio,
    String? maxVisibleTotalInput,
    String? businessName,
    String? businessAddress,
    CashierProjectionPreview? projectionPreview,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return SettingsState(
      cashierReportMode: cashierReportMode ?? this.cashierReportMode,
      visibilityRatio: visibilityRatio ?? this.visibilityRatio,
      maxVisibleTotalInput: maxVisibleTotalInput ?? this.maxVisibleTotalInput,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      projectionPreview: projectionPreview ?? this.projectionPreview,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._ref) : super(const SettingsState.initial());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final CashierZReportSettings settings = await _ref
          .read(reportServiceProvider)
          .getCashierZReportSettings();
      final User? currentUser = _ref.read(authNotifierProvider).currentUser;
      final CashierProjectionPreview preview =
          await _buildProjectionPreviewOrUnavailable(
            user: currentUser,
            policy: settings.policy,
          );
      state = state.copyWith(
        cashierReportMode: settings.policy.cashierReportMode,
        visibilityRatio: settings.policy.visibilityRatio,
        maxVisibleTotalInput: settings.policy.maxVisibleTotalMinor == null
            ? ''
            : CurrencyFormatter.toEditableMajorInput(
                settings.policy.maxVisibleTotalMinor!,
              ),
        businessName: settings.businessIdentity.businessName ?? '',
        businessAddress: settings.businessIdentity.businessAddress ?? '',
        projectionPreview: preview,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'settings_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void setDraftMode(CashierReportMode mode) {
    state = state.copyWith(cashierReportMode: mode, errorMessage: null);
    unawaited(_refreshProjectionPreview());
  }

  void setDraftRatio(double ratio) {
    state = state.copyWith(visibilityRatio: ratio, errorMessage: null);
    unawaited(_refreshProjectionPreview());
  }

  void setMaxVisibleTotalInput(String value) {
    state = state.copyWith(maxVisibleTotalInput: value, errorMessage: null);
    unawaited(_refreshProjectionPreview());
  }

  void setBusinessName(String value) {
    state = state.copyWith(businessName: value, errorMessage: null);
  }

  void setBusinessAddress(String value) {
    state = state.copyWith(businessAddress: value, errorMessage: null);
  }

  Future<bool> save({required User currentUser}) async {
    if (state.isSaving) {
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final CashierZReportSettings settings = _buildDraftSettings();
      await _ref
          .read(reportServiceProvider)
          .updateCashierZReportSettings(user: currentUser, settings: settings);
      final CashierProjectionPreview preview =
          await _buildProjectionPreviewOrUnavailable(
            user: currentUser,
            policy: settings.policy,
          );
      state = state.copyWith(
        isSaving: false,
        projectionPreview: preview,
        errorMessage: null,
      );
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'settings_save_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<void> _refreshProjectionPreview() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    final ReportSettingsPolicy? draftPolicy = _tryBuildDraftPolicy();
    if (draftPolicy == null) {
      state = state.copyWith(
        projectionPreview: const CashierProjectionPreview.unavailable(),
      );
      return;
    }

    final CashierProjectionPreview preview =
        await _buildProjectionPreviewOrUnavailable(
          user: currentUser,
          policy: draftPolicy,
        );
    state = state.copyWith(projectionPreview: preview);
  }

  Future<CashierProjectionPreview> _buildProjectionPreviewOrUnavailable({
    required User? user,
    required ReportSettingsPolicy policy,
  }) async {
    if (user == null || user.role != UserRole.admin) {
      return const CashierProjectionPreview.unavailable();
    }

    try {
      final ShiftReport? rawReport = await _ref
          .read(reportServiceProvider)
          .getOpenShiftReportForAdmin(user: user);
      if (rawReport == null) {
        return const CashierProjectionPreview.unavailable();
      }

      final projected = _ref
          .read(cashierReportProjectionServiceProvider)
          .project(rawReport: rawReport, settings: policy);
      return CashierProjectionPreview(
        hasSourceReport: true,
        shiftId: rawReport.shiftId,
        realTotalMinor: rawReport.netSalesMinor,
        cashierVisibleTotalMinor: projected.visibleTotalMinor,
        realCashMinor: rawReport.cashTotalMinor,
        cashierVisibleCashMinor: projected.visibleCashMinor,
        realCardMinor: rawReport.cardTotalMinor,
        cashierVisibleCardMinor: projected.visibleCardMinor,
        categoryBreakdown: projected.categoryBreakdown,
      );
    } on AppException {
      return const CashierProjectionPreview.unavailable();
    }
  }

  CashierZReportSettings _buildDraftSettings() {
    final ReportSettingsPolicy policy = _buildDraftPolicy();
    return CashierZReportSettings(
      policy: policy,
      businessIdentity: BusinessIdentitySettings(
        businessName: _normalizeNullableText(state.businessName),
        businessAddress: _normalizeNullableText(state.businessAddress),
      ),
    );
  }

  ReportSettingsPolicy _buildDraftPolicy() {
    final int? maxVisibleTotalMinor = _parseMaxVisibleTotalMinor();
    return ReportSettingsPolicy(
      cashierReportMode: state.cashierReportMode,
      visibilityRatio: state.visibilityRatio,
      maxVisibleTotalMinor:
          state.cashierReportMode == CashierReportMode.capAmount
          ? maxVisibleTotalMinor
          : null,
    );
  }

  ReportSettingsPolicy? _tryBuildDraftPolicy() {
    try {
      return _buildDraftPolicy();
    } on ValidationException {
      return null;
    }
  }

  int? _parseMaxVisibleTotalMinor() {
    if (state.cashierReportMode != CashierReportMode.capAmount) {
      return null;
    }

    final String trimmed = state.maxVisibleTotalInput.trim();
    if (trimmed.isEmpty) {
      throw ValidationException(AppStrings.maxVisibleTotalRequired);
    }

    final int? parsed = CurrencyFormatter.tryParseEditableMajorInput(trimmed);
    if (parsed == null) {
      throw ValidationException(AppStrings.maxVisibleTotalInvalid);
    }
    return parsed;
  }

  String? _normalizeNullableText(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final StateNotifierProvider<SettingsNotifier, SettingsState>
settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
      (Ref ref) => SettingsNotifier(ref),
    );

const Object _unset = Object();
