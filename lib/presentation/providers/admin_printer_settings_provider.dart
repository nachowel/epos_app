import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/exceptions.dart';
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
    required this.connectionType,
    required this.selectedAddress,
    required this.selectedName,
    required this.ipAddress,
    required this.port,
    required this.paperWidth,
    required this.isLoading,
    required this.isSaving,
    required this.isTesting,
    required this.errorMessage,
    required this.bluetoothAvailable,
  });

  const AdminPrinterSettingsState.initial()
    : devices = const <PrinterDeviceOption>[],
      activeSettings = null,
      connectionType = PrinterConnectionType.bluetooth,
      selectedAddress = null,
      selectedName = null,
      ipAddress = '',
      port = '${PrinterSettingsModel.defaultEthernetPort}',
      paperWidth = 80,
      isLoading = false,
      isSaving = false,
      isTesting = false,
      errorMessage = null,
      bluetoothAvailable = true;

  final List<PrinterDeviceOption> devices;
  final PrinterSettingsModel? activeSettings;
  final PrinterConnectionType connectionType;
  final String? selectedAddress;
  final String? selectedName;
  final String ipAddress;
  final String port;
  final int paperWidth;
  final bool isLoading;
  final bool isSaving;
  final bool isTesting;
  final String? errorMessage;
  final bool bluetoothAvailable;

  AdminPrinterSettingsState copyWith({
    List<PrinterDeviceOption>? devices,
    Object? activeSettings = _unset,
    PrinterConnectionType? connectionType,
    Object? selectedAddress = _unset,
    Object? selectedName = _unset,
    String? ipAddress,
    String? port,
    int? paperWidth,
    bool? isLoading,
    bool? isSaving,
    bool? isTesting,
    Object? errorMessage = _unset,
    bool? bluetoothAvailable,
  }) {
    return AdminPrinterSettingsState(
      devices: devices ?? this.devices,
      activeSettings: activeSettings == _unset
          ? this.activeSettings
          : activeSettings as PrinterSettingsModel?,
      connectionType: connectionType ?? this.connectionType,
      selectedAddress: selectedAddress == _unset
          ? this.selectedAddress
          : selectedAddress as String?,
      selectedName: selectedName == _unset
          ? this.selectedName
          : selectedName as String?,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      paperWidth: paperWidth ?? this.paperWidth,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isTesting: isTesting ?? this.isTesting,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      bluetoothAvailable: bluetoothAvailable ?? this.bluetoothAvailable,
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
      final adminService = _ref.read(adminServiceProvider);
      final PrinterSettingsModel? activeSettings =
          await adminService.getActivePrinterSettings(user: currentUser);

      // Detect bluetooth platform support independently so a
      // MissingPluginException on Windows never kills the entire load.
      final bool btAvailable = await adminService.isBluetoothAvailable();

      // Only attempt bluetooth device enumeration when the plugin exists.
      List<PrinterDeviceOption> visibleDevices = const <PrinterDeviceOption>[];
      if (btAvailable) {
        final List<PrinterDeviceOption> devices =
            await adminService.getBondedPrinterDevices(user: currentUser);
        visibleDevices = List<PrinterDeviceOption>.from(devices);
        final bool activeExists =
            activeSettings == null ||
            activeSettings.connectionType != PrinterConnectionType.bluetooth ||
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
      }

      // When bluetooth is unavailable and no saved connection type exists,
      // default to ethernet so the UI opens into a usable state.
      final PrinterConnectionType resolvedType =
          activeSettings?.connectionType ??
          (btAvailable
              ? PrinterConnectionType.bluetooth
              : PrinterConnectionType.ethernet);

      state = state.copyWith(
        devices: visibleDevices,
        activeSettings: activeSettings,
        connectionType: resolvedType,
        selectedAddress: activeSettings?.deviceAddress,
        selectedName: _sanitizeEditableDeviceName(activeSettings?.deviceName),
        ipAddress: activeSettings?.ipAddress ?? '',
        port:
            '${activeSettings?.port ?? PrinterSettingsModel.defaultEthernetPort}',
        paperWidth: activeSettings?.paperWidth ?? 80,
        isLoading: false,
        errorMessage: null,
        bluetoothAvailable: btAvailable,
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
      selectedName: _sanitizeEditableDeviceName(device?.name),
      errorMessage: null,
    );
  }

  void setConnectionType(PrinterConnectionType value) {
    state = state.copyWith(connectionType: value, errorMessage: null);
  }

  void setIpAddress(String value) {
    state = state.copyWith(ipAddress: value, errorMessage: null);
  }

  void setPort(String value) {
    state = state.copyWith(port: value, errorMessage: null);
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
            connectionType: state.connectionType,
            deviceName: _resolvedDeviceName(),
            deviceAddress: state.selectedAddress,
            ipAddress: _resolvedIpAddress(),
            port: _resolvedPort(),
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
            connectionType: state.connectionType,
            deviceName: _resolvedDeviceName(),
            deviceAddress: state.selectedAddress,
            ipAddress: _resolvedIpAddress(),
            port: _resolvedPort(),
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

  String? _resolvedDeviceName() {
    if (state.connectionType == PrinterConnectionType.bluetooth) {
      return _sanitizeEditableDeviceName(state.selectedName);
    }

    final String ipAddress = state.ipAddress.trim();
    if (ipAddress.isEmpty) {
      return null;
    }
    return 'Ethernet Printer';
  }

  String? _resolvedIpAddress() {
    if (state.connectionType == PrinterConnectionType.bluetooth) {
      return null;
    }
    return state.ipAddress.trim();
  }

  int? _resolvedPort() {
    if (state.connectionType == PrinterConnectionType.bluetooth) {
      return null;
    }
    final String portText = state.port.trim();
    if (portText.isEmpty) {
      return PrinterSettingsModel.defaultEthernetPort;
    }
    final int? port = int.tryParse(portText);
    if (port == null) {
      throw ValidationException('Printer port must be a valid number.');
    }
    return port;
  }

  String? _sanitizeEditableDeviceName(String? value) {
    if (value == null) {
      return null;
    }
    // The UI must only ever carry the human-readable printer name. If an
    // editable field or stale state ever contains the temporary compatibility
    // envelope, strip it here so save() regenerates fresh metadata instead of
    // letting user edits corrupt the envelope.
    final String normalized = PrinterSettingsModel.normalizeEditableDeviceName(
      value,
    );
    return normalized.isEmpty ? null : normalized;
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
