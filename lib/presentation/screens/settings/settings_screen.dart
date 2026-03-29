import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/language_selector_card.dart';
import '../../widgets/section_app_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(settingsNotifierProvider.notifier).load(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final settingsState = ref.watch(settingsNotifierProvider);
    final currentUser = authState.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.settingsTitle,
        currentRoute: '/admin/settings',
        currentUser: currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.spacingMd),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSizes.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.visibilityRatioTitle,
                  style: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  AppStrings.visibilityRatioHint,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
                Text(
                  '%${(settingsState.visibilityRatio * 100).round()}',
                  style: const TextStyle(
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Slider(
                  value: settingsState.visibilityRatio,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '%${(settingsState.visibilityRatio * 100).round()}',
                  onChanged: settingsState.isLoading || settingsState.isSaving
                      ? null
                      : (double value) {
                          ref
                              .read(settingsNotifierProvider.notifier)
                              .setDraftRatio(value);
                        },
                ),
                if (settingsState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
                    child: Text(
                      settingsState.errorMessage!,
                      style: const TextStyle(
                        fontSize: AppSizes.fontSm,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed:
                        currentUser == null ||
                            settingsState.isLoading ||
                            settingsState.isSaving
                        ? null
                        : () async {
                            final bool saved = await ref
                                .read(settingsNotifierProvider.notifier)
                                .save(currentUser: currentUser);
                            if (!mounted) {
                              return;
                            }
                            _showMessage(
                              saved
                                  ? AppStrings.settingsSaved
                                  : (ref
                                            .read(settingsNotifierProvider)
                                            .errorMessage ??
                                        AppStrings.accessDenied),
                            );
                          },
                    child: settingsState.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppStrings.saveSettings),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          const LanguageSelectorCard(),
        ],
      ),
    );
  }
}
