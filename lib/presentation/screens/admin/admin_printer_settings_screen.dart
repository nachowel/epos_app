import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/printer_settings.dart';
import '../../providers/admin_printer_settings_provider.dart';
import 'widgets/admin_scaffold.dart';

class AdminPrinterSettingsScreen extends ConsumerStatefulWidget {
  const AdminPrinterSettingsScreen({super.key});

  @override
  ConsumerState<AdminPrinterSettingsScreen> createState() =>
      _AdminPrinterSettingsScreenState();
}

class _AdminPrinterSettingsScreenState
    extends ConsumerState<AdminPrinterSettingsScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _portController = TextEditingController();
    Future<void>.microtask(
      () => ref.read(adminPrinterSettingsNotifierProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPrinterSettingsNotifierProvider);
    _syncController(_ipController, state.ipAddress);
    _syncController(_portController, state.port);

    return AdminScaffold(
      title: AppStrings.printerSettingsTitle,
      currentRoute: '/admin/settings/printer',
      child: ListView(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSizes.spacingLg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Printer Connection',
                  style: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  AppStrings.printerSelectionMessage,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.spacingLg),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                SegmentedButton<PrinterConnectionType>(
                  segments: <ButtonSegment<PrinterConnectionType>>[
                    ButtonSegment<PrinterConnectionType>(
                      value: PrinterConnectionType.bluetooth,
                      label: const Text('Bluetooth'),
                      enabled: state.bluetoothAvailable,
                    ),
                    const ButtonSegment<PrinterConnectionType>(
                      value: PrinterConnectionType.ethernet,
                      label: Text('Ethernet'),
                    ),
                  ],
                  selected: <PrinterConnectionType>{state.connectionType},
                  onSelectionChanged: state.isLoading
                      ? null
                      : (Set<PrinterConnectionType> values) {
                          ref
                              .read(
                                adminPrinterSettingsNotifierProvider.notifier,
                              )
                              .setConnectionType(values.first);
                        },
                ),
                if (!state.bluetoothAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.spacingXs),
                    child: Text(
                      AppStrings.bluetoothUnsupportedPlatform,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppSizes.fontSm,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSizes.spacingLg),
                if (state.connectionType == PrinterConnectionType.bluetooth)
                  DropdownButtonFormField<String>(
                    value: state.selectedAddress,
                    decoration: InputDecoration(
                      labelText: AppStrings.bondedDevice,
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                    ),
                    items: state.devices
                        .map(
                          (device) => DropdownMenuItem<String>(
                            value: device.address,
                            child: Text('${device.name} · ${device.address}'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: state.isLoading
                        ? null
                        : (String? value) {
                            ref
                                .read(
                                  adminPrinterSettingsNotifierProvider.notifier,
                                )
                                .selectDevice(value);
                          },
                  )
                else
                  Column(
                    children: <Widget>[
                      TextField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                          labelText: 'IP Address',
                          filled: true,
                          fillColor: AppColors.surfaceMuted,
                        ),
                        keyboardType: TextInputType.url,
                        onChanged: (String value) {
                          ref
                              .read(
                                adminPrinterSettingsNotifierProvider.notifier,
                              )
                              .setIpAddress(value);
                        },
                      ),
                      const SizedBox(height: AppSizes.spacingMd),
                      TextField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          filled: true,
                          fillColor: AppColors.surfaceMuted,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (String value) {
                          ref
                              .read(
                                adminPrinterSettingsNotifierProvider.notifier,
                              )
                              .setPort(value);
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: AppSizes.spacingLg),
                SegmentedButton<int>(
                  segments: <ButtonSegment<int>>[
                    ButtonSegment<int>(
                      value: 58,
                      label: Text(AppStrings.paperWidth58),
                    ),
                    ButtonSegment<int>(
                      value: 80,
                      label: Text(AppStrings.paperWidth80),
                    ),
                  ],
                  selected: <int>{state.paperWidth},
                  onSelectionChanged: (Set<int> values) {
                    ref
                        .read(adminPrinterSettingsNotifierProvider.notifier)
                        .setPaperWidth(values.first);
                  },
                ),
                const SizedBox(height: AppSizes.spacingLg),
                Wrap(
                  spacing: AppSizes.spacingSm,
                  runSpacing: AppSizes.spacingSm,
                  children: <Widget>[
                    ElevatedButton.icon(
                      onPressed: state.isSaving
                          ? null
                          : () async {
                              final bool saved = await ref
                                  .read(
                                    adminPrinterSettingsNotifierProvider
                                        .notifier,
                                  )
                                  .save();
                              if (!mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    saved
                                        ? AppStrings.printerSettingSaved
                                        : (ref
                                                  .read(
                                                    adminPrinterSettingsNotifierProvider,
                                                  )
                                                  .errorMessage ??
                                              AppStrings.saveFailed),
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.save_rounded),
                      label: state.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(AppStrings.saveSettings),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.isTesting
                          ? null
                          : () async {
                              final bool printed = await ref
                                  .read(
                                    adminPrinterSettingsNotifierProvider
                                        .notifier,
                                  )
                                  .testPrint();
                              if (!mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    printed
                                        ? AppStrings.testPrintSent
                                        : (ref
                                                  .read(
                                                    adminPrinterSettingsNotifierProvider,
                                                  )
                                                  .errorMessage ??
                                              AppStrings.testPrintFailed),
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.print_rounded),
                      label: state.isTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(AppStrings.testPrint),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
