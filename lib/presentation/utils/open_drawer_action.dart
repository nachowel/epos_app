import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../providers/auth_provider.dart';

/// Shared "Open Drawer" handler used by the Category and POS top bars.
///
/// Delegates to [PrinterService.openCashDrawerManually] so both entry points
/// execute the identical domain action (no UI-layer drawer logic).
Future<void> triggerOpenDrawerAction(BuildContext context, WidgetRef ref) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final int? actorUserId = ref.read(authNotifierProvider).currentUser?.id;
  try {
    await ref
        .read(printerServiceProvider)
        .openCashDrawerManually(actorUserId: actorUserId);
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Cash drawer unavailable: $error')),
    );
  }
}
