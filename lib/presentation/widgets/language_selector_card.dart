import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../providers/app_locale_provider.dart';

class LanguageSelectorCard extends ConsumerWidget {
  const LanguageSelectorCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Locale locale = ref.watch(appLocaleProvider);

    return Container(
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
            AppStrings.languageLabel,
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            AppStrings.languageSettingsHint,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.spacingLg),
          DropdownButtonFormField<String>(
            value: locale.languageCode,
            decoration: InputDecoration(
              labelText: AppStrings.languageLabel,
              filled: true,
              fillColor: AppColors.surfaceMuted,
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'en',
                child: Text(AppStrings.english),
              ),
              DropdownMenuItem<String>(
                value: 'tr',
                child: Text(AppStrings.turkish),
              ),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              ref.read(appLocaleProvider.notifier).setLanguageCode(value);
            },
          ),
        ],
      ),
    );
  }
}
