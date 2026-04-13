import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';

class AnalyticsKpiCard extends StatelessWidget {
  const AnalyticsKpiCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.value,
    this.subtitle,
    this.body,
    this.isHero = false,
    this.accentColor = AppColors.primary,
    super.key,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? value;
  final String? subtitle;
  final Widget? body;
  final bool isHero;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(
      isHero ? AppSizes.radiusLg : AppSizes.radiusMd,
    );
    final Widget content = Container(
      padding: EdgeInsets.all(isHero ? AppSizes.spacingLg : AppSizes.spacingMd),
      decoration: BoxDecoration(
        gradient: isHero
            ? const LinearGradient(
                colors: <Color>[
                  AppColors.primaryStrong,
                  AppColors.primaryDarker,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isHero ? null : AppColors.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: isHero ? Colors.transparent : AppColors.border,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.textPrimary.withValues(
              alpha: isHero ? 0.14 : 0.06,
            ),
            blurRadius: isHero ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSizes.spacingSm),
                decoration: BoxDecoration(
                  color: isHero
                      ? Colors.white.withValues(alpha: 0.16)
                      : accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  icon,
                  color: isHero ? AppColors.textOnPrimary : accentColor,
                  size: 22,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                color: isHero
                    ? AppColors.textOnPrimary.withValues(alpha: 0.88)
                    : AppColors.textSecondary,
              ),
            ],
          ),
          SizedBox(height: isHero ? AppSizes.spacingLg : AppSizes.spacingMd),
          Text(
            title,
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w700,
              color: isHero
                  ? AppColors.textOnPrimary.withValues(alpha: 0.86)
                  : AppColors.textSecondary,
            ),
          ),
          SizedBox(height: isHero ? AppSizes.spacingSm : AppSizes.spacingXs),
          if (body != null)
            body!
          else
            Text(
              value ?? '',
              style: TextStyle(
                fontSize: isHero ? 40 : 30,
                fontWeight: FontWeight.w900,
                color: isHero ? AppColors.textOnPrimary : AppColors.textPrimary,
                height: 1.0,
              ),
            ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: AppSizes.spacingSm),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isHero
                    ? AppColors.textOnPrimary.withValues(alpha: 0.78)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: borderRadius, onTap: onTap, child: content),
    );
  }
}
