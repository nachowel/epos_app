import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/exit_safety.dart';
import '../providers/auth_provider.dart';

/// Dialog widget keys used by tests and by assistive callers.
const ValueKey<String> kLogoutSimpleDialogKey = ValueKey<String>(
  'logout_confirmation_simple_dialog',
);
const ValueKey<String> kLogoutWarnDialogKey = ValueKey<String>(
  'logout_confirmation_warn_dialog',
);
const ValueKey<String> kLogoutBlockedDialogKey = ValueKey<String>(
  'logout_confirmation_blocked_dialog',
);
const ValueKey<String> kLogoutCancelButtonKey = ValueKey<String>(
  'logout_confirmation_cancel',
);
const ValueKey<String> kLogoutConfirmButtonKey = ValueKey<String>(
  'logout_confirmation_confirm',
);
const ValueKey<String> kLogoutBlockedAcknowledgeKey = ValueKey<String>(
  'logout_confirmation_blocked_acknowledge',
);

/// Centralised exit/logout gate. EVERY logout entry point in the app MUST
/// funnel through this handler so that the risk rules are applied uniformly.
///
/// Contract:
///   * Re-validates shift + open/sent orders against the freshest source
///     (DB-backed repositories via [ExitSafetyService]).
///   * If any OPEN (draft) or SENT transactions exist, OR if verification
///     fails → blocking dialog; logout is refused.
///   * If only an active shift exists → warning dialog; user must deliberately
///     confirm.
///   * If nothing is active → simple confirm dialog.
///   * Cancel is always the default focused + Enter-activated action.
///   * Escape routes to the same Cancel action (never silent-dismiss).
Future<void> handleLogoutRequest(BuildContext context, WidgetRef ref) async {
  final ExitSafetyEvaluation evaluation = await ref
      .read(exitSafetyServiceProvider)
      .evaluate(currentUser: ref.read(authNotifierProvider).currentUser);
  _debugLogoutDialogLog('evaluation level=${evaluation.level.name}');

  if (!context.mounted) {
    return;
  }

  switch (evaluation.level) {
    case ExitSafetyLevel.blocked:
      await _showBlockedDialog(context, evaluation);
      return;
    case ExitSafetyLevel.warnOnly:
      final bool confirmed =
          await _showWarnDialog(context, evaluation) ?? false;
      if (!confirmed) return;
      break;
    case ExitSafetyLevel.noRisk:
      final bool confirmed = await _showSimpleDialog(context) ?? false;
      if (!confirmed) return;
      break;
  }

  if (!context.mounted) {
    return;
  }
  ref.read(authNotifierProvider.notifier).logout();
  context.go('/login');
}

// ---------------------------------------------------------------------------
// Dialog variants
// ---------------------------------------------------------------------------

Future<bool?> _showSimpleDialog(BuildContext context) {
  _debugLogoutDialogLog('show simple dialog');
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return _KeyboardSafeDialog(
        onCancel: () => Navigator.of(dialogContext).pop(false),
        child: AlertDialog(
          key: kLogoutSimpleDialogKey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          title: const _DialogHeader(
            title: 'Exit EPOS?',
            subtitle: 'Ready to finish your session?',
            icon: Icons.logout_rounded,
            iconColor: AppColors.primary,
          ),
          content: const Padding(
            padding: EdgeInsets.only(top: AppSizes.spacingSm),
            child: Text('You will be logged out and returned to the PIN screen.'),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSizes.spacingLg,
            AppSizes.spacingSm,
            AppSizes.spacingLg,
            AppSizes.spacingMd,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSizes.spacingLg,
            0,
            AppSizes.spacingLg,
            AppSizes.spacingLg,
          ),
          actions: <Widget>[
            _SafeActionButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              label: 'Stay in App',
            ),
            _DestructiveActionButton(
              buttonKey: kLogoutConfirmButtonKey,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              label: 'Exit Now',
            ),
          ],
        ),
      );
    },
  ).then((bool? result) {
    _debugLogoutDialogLog('dismiss simple dialog result=$result');
    return result;
  });
}

Future<bool?> _showWarnDialog(
  BuildContext context,
  ExitSafetyEvaluation evaluation,
) {
  _debugLogoutDialogLog('show warn dialog');
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final List<String> bullets = _warnBullets(evaluation);
      return _KeyboardSafeDialog(
        onCancel: () => Navigator.of(dialogContext).pop(false),
        child: AlertDialog(
          key: kLogoutWarnDialogKey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          title: const _DialogHeader(
            title: 'Exit EPOS?',
            subtitle: 'Active operational work is currently in progress.',
            icon: Icons.warning_rounded,
            iconColor: AppColors.warningStrong,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _WarningBox(items: bullets),
              const SizedBox(height: AppSizes.spacingMd),
              const Text(
                'Are you sure you want to exit now?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSizes.spacingLg,
            AppSizes.spacingSm,
            AppSizes.spacingLg,
            AppSizes.spacingMd,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSizes.spacingLg,
            0,
            AppSizes.spacingLg,
            AppSizes.spacingLg,
          ),
          actions: <Widget>[
            _SafeActionButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              label: 'Stay in App',
            ),
            _DestructiveActionButton(
              buttonKey: kLogoutConfirmButtonKey,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              label: 'Exit Now',
            ),
          ],
        ),
      );
    },
  ).then((bool? result) {
    _debugLogoutDialogLog('dismiss warn dialog result=$result');
    return result;
  });
}

Future<void> _showBlockedDialog(
  BuildContext context,
  ExitSafetyEvaluation evaluation,
) {
  _debugLogoutDialogLog('show blocked dialog');
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final List<String> bullets = _blockedBullets(evaluation);
      return _KeyboardSafeDialog(
        onCancel: () => Navigator.of(dialogContext).pop(),
        child: AlertDialog(
          key: kLogoutBlockedDialogKey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          title: const _DialogHeader(
            title: 'Exit Unavailable',
            subtitle: 'You cannot exit until these issues are resolved.',
            icon: Icons.block_rounded,
            iconColor: AppColors.danger,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _WarningBox(
                items: bullets,
                backgroundColor: AppColors.dangerLight,
                borderColor: AppColors.danger.withOpacity(0.2),
                iconColor: AppColors.danger,
              ),
              const SizedBox(height: AppSizes.spacingMd),
              const Text(
                'Please resolve open and sent orders before attempting to exit.',
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSizes.spacingLg,
            AppSizes.spacingSm,
            AppSizes.spacingLg,
            AppSizes.spacingMd,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSizes.spacingLg,
            0,
            AppSizes.spacingLg,
            AppSizes.spacingLg,
          ),
          actions: <Widget>[
            _SafeActionButton(
              buttonKey: kLogoutBlockedAcknowledgeKey,
              onPressed: () => Navigator.of(dialogContext).pop(),
              label: 'Return to App',
              isFullWidth: true,
            ),
          ],
        ),
      );
    },
  ).then((_) {
    _debugLogoutDialogLog('dismiss blocked dialog');
  });
}

// ---------------------------------------------------------------------------
// Copy helpers
// ---------------------------------------------------------------------------

List<String> _warnBullets(ExitSafetyEvaluation e) {
  final List<String> out = <String>[];
  if (e.hasActiveShift) {
    out.add('Active shift is still open');
  }
  if (e.verificationFailed) {
    out.add('Order status could not be verified');
  }
  // Added as per user instructions
  out.add('Closing now may interrupt service flow');
  return out;
}

List<String> _blockedBullets(ExitSafetyEvaluation e) {
  final List<String> out = <String>[];
  if (e.hasOpenOrders) {
    out.add('Open orders exist (${e.openOrderCount})');
  }
  if (e.hasSentOrders) {
    out.add('Sent orders exist (${e.sentOrderCount})');
  }
  if (e.verificationFailed) {
    out.add('Order status could not be verified.');
  }
  if (out.isEmpty) {
    // Defensive fallback — we only reach the blocked branch with at least one
    // blocking reason, but never emit an empty reason list.
    out.add('Order status could not be verified.');
  }
  return out;
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// Wraps a dialog so that:
///   * Escape → runs [onCancel] (never silent-dismisses).
///   * Enter at the dialog scope also routes to Cancel — a belt-and-braces
///     guard so that even if focus ever escapes the cancel button, Enter
///     cannot silently traverse to a non-Cancel action.
class _KeyboardSafeDialog extends StatelessWidget {
  const _KeyboardSafeDialog({required this.child, required this.onCancel});

  final Widget child;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape):
            _DismissLogoutDialogIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _DismissLogoutDialogIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter):
            _DismissLogoutDialogIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DismissLogoutDialogIntent:
              CallbackAction<_DismissLogoutDialogIntent>(
                onInvoke: (_DismissLogoutDialogIntent intent) {
                  onCancel();
                  return null;
                },
              ),
        },
        child: child,
      ),
    );
  }
}

class _DismissLogoutDialogIntent extends Intent {
  const _DismissLogoutDialogIntent();
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: iconColor ?? AppColors.warning, size: 28),
              const SizedBox(width: AppSizes.spacingSm),
            ],
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.fontLg,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: AppSizes.fontSm,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({
    required this.items,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  });

  final List<String> items;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: borderColor ?? AppColors.warningStrong.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: iconColor ?? AppColors.warningStrong,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: AppSizes.fontSm,
                        color:
                            (iconColor ?? AppColors.warningStrong).withOpacity(
                              0.9,
                            ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SafeActionButton extends StatelessWidget {
  const _SafeActionButton({
    required this.onPressed,
    required this.label,
    this.buttonKey,
    this.isFullWidth = false,
  });

  final VoidCallback onPressed;
  final String label;
  final Key? buttonKey;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final Widget button = FilledButton(
      key: buttonKey ?? kLogoutCancelButtonKey,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacingLg,
          vertical: AppSizes.spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class _DestructiveActionButton extends StatelessWidget {
  const _DestructiveActionButton({
    required this.onPressed,
    required this.label,
    this.buttonKey,
  });

  final VoidCallback onPressed;
  final String label;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.danger,
        backgroundColor: AppColors.danger.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacingLg,
          vertical: AppSizes.spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          side: BorderSide(color: AppColors.danger.withOpacity(0.12)),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

void _debugLogoutDialogLog(String message) {
  if (kDebugMode) {
    debugPrint('[UI_STABILITY][LogoutDialog] $message');
  }
}
