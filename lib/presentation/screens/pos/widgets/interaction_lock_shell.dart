import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class InteractionLockShell extends StatelessWidget {
  const InteractionLockShell({
    required this.isLocked,
    required this.message,
    required this.child,
    super.key,
  });

  final bool isLocked;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IgnorePointer(
          ignoring: isLocked,
          child: Opacity(opacity: isLocked ? 0.5 : 1, child: child),
        ),
        if (isLocked)
          Positioned.fill(
            child: Container(
              color: AppColors.background.withValues(alpha: 0.14),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(AppSizes.spacingLg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacingLg,
                  vertical: AppSizes.spacingMd,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
