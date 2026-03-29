import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/printer_device_option.dart';
import '../../domain/models/printer_settings.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminPrinterSettingsState {
  const AdminPrinterSettingsState({
    required this.devices,
    required this.activeSettings,
    required this.selectedAddress,
    required this.selectedName,
    required this.paperWidth,
    required this.isLoading,
    required this.isSaving,
    required this.isTesting,
    required this.errorMessage,
  });

  const AdminPrinterSettingsState.initial()
    : devices = const <PrinterDeviceOption>[],
      activeSettings = null,
      selectedAddress = null,
      selectedName = null,
      paperWidth = 80,
      isLoading = false,
      isSaving = false,
      isTesting = false,
      errorMessage = null;

  final List<PrinterDeviceOption> devices;
  final PrinterSettingsModel? activeSettings;
  final String? selectedAddress;
  final String? selectedName;
  final int paperWidth;
  final bool isLoading;
  final bool isSaving;
  final bool isTesting;
  final String? errorMessage;

  AdminPrinterSettingsState copyWith({
    List<PrinterDeviceOption>? devices,
    Object? activeSettings = _unset,
    Object? selectedAddress = _unset,
    Object? selectedName = _unset,
    int? paperWidth,
    bool? isLoading,
    bool? isSaving,
    bool? isTesting,
    Object? errorMessage = _unset,
  }) {
    return AdminPrinterSettingsState(
      devices: devices ?? this.devices,
      activeSettings: activeSettings == _unset
          ? this.activeSettings
          : activeSettings as PrinterSettingsModel?,
      selectedAddress: selectedAddress == _unset
          ? this.selectedAddress
          : selectedAddress as String?,
      selectedName: selectedName == _unset
          ? this.selectedName
          : selectedName as String?,
      paperWidth: paperWidth ?? this.paperWidth,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isTesting: isTesting ?? this.isTesting,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminPrinterSettingsNotifier
    extends StateNotifier<AdminPrinterSettingsState> {
  AdminPrinterSettingsNotifier(this._ref)
    : super(const AdminPrinterSettingsState.initial());

  final Ref _ref;

  Future<void> load() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final PrinterSettingsModel? activeSettings = await _ref
          .read(adminServiceProvider)
          .getActivePrinterSettings(user: currentUser);
      final List<PrinterDeviceOption> devices = await _ref
          .read(adminServiceProvider)
          .getBondedPrinterDevices(user: currentUser);
      final List<PrinterDeviceOption> visibleDevices =
          List<PrinterDeviceOption>.from(devices);
      final bool activeExists =
          activeSettings == null ||
          visibleDevices.any(
            (PrinterDeviceOption device) =>
                device.address == activeSettings.deviceAddress,
          );
      if (!activeExists) {
        visibleDevices.add(
          PrinterDeviceOption(
            name: activeSettings.deviceName,
            address: activeSettings.deviceAddress,
          ),
        );
      }
      state = state.copyWith(
        devices: visibleDevices,
        activeSettings: activeSettings,
        selectedAddress: activeSettings?.deviceAddress,
        selectedName: activeSettings?.deviceName,
        paperWidth: activeSettings?.paperWidth ?? 80,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_printer_settings_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void selectDevice(String? address) {
    PrinterDeviceOption? device;
    for (final PrinterDeviceOption option in state.devices) {
      if (option.address == address) {
        device = option;
        break;
      }
    }
    state = state.copyWith(
      selectedAddress: address,
      selectedName: device?.name,
      errorMessage: null,
    );
  }

  void setPaperWidth(int width) {
    state = state.copyWith(paperWidth: width, errorMessage: null);
  }

  Future<bool> save() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .savePrinterSettings(
            user: currentUser,
            deviceName: state.selectedName ?? '',
            deviceAddress: state.selectedAddress ?? '',
            paperWidth: state.paperWidth,
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
          eventType: 'admin_printer_settings_save_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> testPrint() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    state = state.copyWith(isTesting: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .printTestPage(
            user: currentUser,
            deviceName: state.selectedName ?? '',
            deviceAddress: state.selectedAddress ?? '',
            paperWidth: state.paperWidth,
          );
      state = state.copyWith(isTesting: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isTesting: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_printer_settings_test_print_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }
}

final StateNotifierProvider<
  AdminPrinterSettingsNotifier,
  AdminPrinterSettingsState
>
adminPrinterSettingsNotifierProvider =
    StateNotifierProvider<
      AdminPrinterSettingsNotifier,
      AdminPrinterSettingsState
    >((Ref ref) => AdminPrinterSettingsNotifier(ref));

const Object _unset = Object();
