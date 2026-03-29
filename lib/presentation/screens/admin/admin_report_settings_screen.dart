import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/report_category_display_formatter.dart';
import '../../../domain/models/report_settings_policy.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/language_selector_card.dart';
import 'widgets/admin_scaffold.dart';

class AdminReportSettingsScreen extends ConsumerStatefulWidget {
  const AdminReportSettingsScreen({super.key});

  @override
  ConsumerState<AdminReportSettingsScreen> createState() =>
      _AdminReportSettingsScreenState();
}

class _AdminReportSettingsScreenState
    extends ConsumerState<AdminReportSettingsScreen> {
  late final TextEditingController _businessNameController;
  late final TextEditingController _businessAddressController;
  late final TextEditingController _maxVisibleTotalController;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _businessAddressController = TextEditingController();
    _maxVisibleTotalController = TextEditingController();
    Future<void>.microtask(
      () => ref.read(settingsNotifierProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _maxVisibleTotalController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    ref.listen<SettingsState>(settingsNotifierProvider, (
      SettingsState? _,
      SettingsState next,
    ) {
      _syncController(_businessNameController, next.businessName);
      _syncController(_businessAddressController, next.businessAddress);
      _syncController(_maxVisibleTotalController, next.maxVisibleTotalInput);
    });

    final authState = ref.watch(authNotifierProvider);
    final state = ref.watch(settingsNotifierProvider);
    final bool isBusy = state.isLoading || state.isSaving;

    return AdminScaffold(
      title: AppStrings.reportSettingsTitle,
      currentRoute: '/admin/settings',
      child: ListView(
        children: <Widget>[
          _SettingsSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.cashierZReportPolicyTitle,
                  style: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  AppStrings.cashierZReportPolicyHint,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.spacingLg),
                DropdownButtonFormField<CashierReportMode>(
                  key: const Key('cashier-report-mode-field'),
                  value: state.cashierReportMode,
                  decoration: InputDecoration(
                    labelText: AppStrings.cashierProjectionModeLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<CashierReportMode>>[
                    DropdownMenuItem<CashierReportMode>(
                      value: CashierReportMode.percentage,
                      child: Text(AppStrings.cashierProjectionModePercentage),
                    ),
                    DropdownMenuItem<CashierReportMode>(
                      value: CashierReportMode.capAmount,
                      child: Text(AppStrings.cashierProjectionModeCapAmount),
                    ),
                  ],
                  onChanged: isBusy
                      ? null
                      : (CashierReportMode? value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(settingsNotifierProvider.notifier)
                              .setDraftMode(value);
                        },
                ),
                const SizedBox(height: AppSizes.spacingLg),
                if (state.cashierReportMode == CashierReportMode.percentage)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '%${(state.visibilityRatio * 100).round()}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingXs),
                      Text(
                        AppStrings.cashierProjectionPercentageHelp,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      Slider(
                        key: const Key('cashier-visibility-ratio-slider'),
                        value: state.visibilityRatio,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        label: '%${(state.visibilityRatio * 100).round()}',
                        onChanged: isBusy
                            ? null
                            : (double value) {
                                ref
                                    .read(settingsNotifierProvider.notifier)
                                    .setDraftRatio(value);
                              },
                      ),
                    ],
                  )
                else
                  TextField(
                    key: const Key('max-visible-total-field'),
                    controller: _maxVisibleTotalController,
                    enabled: !isBusy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppStrings.cashierProjectionCapAmountLabel,
                      hintText: AppStrings.cashierProjectionCapAmountHint,
                      helperText: AppStrings.cashierProjectionCapAmountHelp,
                      prefixText: '£',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (String value) {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setMaxVisibleTotalInput(value);
                    },
                  ),
                if (state.errorMessage != null) ...<Widget>[
                  const SizedBox(height: AppSizes.spacingMd),
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _SettingsSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.businessIdentitySectionTitle,
                  style: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  AppStrings.businessIdentitySectionHint,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.spacingLg),
                TextField(
                  key: const Key('business-name-field'),
                  controller: _businessNameController,
                  enabled: !isBusy,
                  decoration: InputDecoration(
                    labelText: AppStrings.businessName,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (String value) {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .setBusinessName(value);
                  },
                ),
                const SizedBox(height: AppSizes.spacingMd),
                TextField(
                  key: const Key('business-address-field'),
                  controller: _businessAddressController,
                  enabled: !isBusy,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppStrings.businessAddress,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (String value) {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .setBusinessAddress(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _SettingsSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.cashierProjectionPreviewTitle,
                  style: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  AppStrings.cashierProjectionPreviewHint,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.spacingLg),
                if (!state.projectionPreview.hasSourceReport)
                  Text(
                    AppStrings.cashierProjectionPreviewUnavailable,
                    style: const TextStyle(color: AppColors.textSecondary),
                  )
                else
                  Column(
                    children: <Widget>[
                      _PreviewRow(
                        label: AppStrings.realTotalLabel,
                        value: CurrencyFormatter.fromMinor(
                          state.projectionPreview.realTotalMinor,
                        ),
                      ),
                      _PreviewRow(
                        label: AppStrings.cashierVisibleTotalLabel,
                        value: CurrencyFormatter.fromMinor(
                          state.projectionPreview.cashierVisibleTotalMinor,
                        ),
                        emphasize: true,
                      ),
                      const Divider(height: AppSizes.spacingLg),
                      _PreviewRow(
                        label: AppStrings.realCashLabel,
                        value: CurrencyFormatter.fromMinor(
                          state.projectionPreview.realCashMinor,
                        ),
                      ),
                      _PreviewRow(
                        label: AppStrings.cashierVisibleCashLabel,
                        value: CurrencyFormatter.fromMinor(
                          state.projectionPreview.cashierVisibleCashMinor,
                        ),
                      ),
                      _PreviewRow(
                        label: AppStrings.realCardLabel,
                        value: CurrencyFormatter.fromMinor(
                          state.projectionPreview.realCardMinor,
                        ),
                      ),
                      _PreviewRow(
                        label: AppStrings.cashierVisibleCardLabel,
                        value: CurrencyFormatter.fromMinor(
                          state.projectionPreview.cashierVisibleCardMinor,
                        ),
                      ),
                      if (state
                          .projectionPreview
                          .categoryBreakdown
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSizes.spacingMd),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppStrings.categoryBreakdown,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacingSm),
                        for (final category
                            in state.projectionPreview.categoryBreakdown)
                          _PreviewRow(
                            label: ReportCategoryDisplayFormatter.toEnglish(
                              category.categoryName,
                            ),
                            value: CurrencyFormatter.fromMinor(
                              category.visibleAmountMinor,
                            ),
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              key: const Key('save-report-settings-button'),
              onPressed: authState.currentUser == null || isBusy
                  ? null
                  : () async {
                      final bool saved = await ref
                          .read(settingsNotifierProvider.notifier)
                          .save(currentUser: authState.currentUser!);
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            saved
                                ? AppStrings.reportSettingSaved
                                : (ref
                                          .read(settingsNotifierProvider)
                                          .errorMessage ??
                                      AppStrings.saveFailed),
                          ),
                        ),
                      );
                    },
              child: state.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppStrings.saveSettings),
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          const LanguageSelectorCard(),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: AppSizes.fontSm,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
      color: emphasize ? AppColors.primary : AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
