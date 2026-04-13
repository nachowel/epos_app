import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../widgets/admin_scaffold.dart';

class AnalyticsDetailPlaceholderScreen extends StatelessWidget {
  const AnalyticsDetailPlaceholderScreen({
    required this.title,
    required this.currentRoute,
    required this.summary,
    super.key,
  });

  final String title;
  final String currentRoute;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: title,
      currentRoute: currentRoute,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spacingXl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.insights_rounded,
                  size: 40,
                  color: AppColors.primaryStrong,
                ),
                const SizedBox(height: AppSizes.spacingMd),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingLg),
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/analytics'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Overview'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
