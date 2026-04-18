import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guardrail: every screen that exposes a Çıkış/logout button MUST
/// delegate to `handleLogoutRequest`. This prevents accidental reintroduction
/// of a bare `authNotifierProvider.notifier.logout()` call that bypasses the
/// centralised risk evaluation.
void main() {
  // These are the screens that currently wire SectionAppBar.onLogout.
  // Adding a new screen with onLogout? Add it here too — and wire it through
  // handleLogoutRequest.
  const List<String> screensWithLogoutButton = <String>[
    'lib/presentation/screens/dashboard/cashier_dashboard_screen.dart',
    'lib/presentation/screens/orders/orders_screen.dart',
    'lib/presentation/screens/orders/order_detail_screen.dart',
    'lib/presentation/screens/pos/pos_screen.dart',
    'lib/presentation/screens/pos/category_entry_screen.dart',
    'lib/presentation/screens/shifts/shift_management_screen.dart',
    'lib/presentation/screens/settings/settings_screen.dart',
    'lib/presentation/screens/reports/z_report_screen.dart',
    'lib/presentation/screens/admin/widgets/admin_scaffold.dart',
  ];

  test('every screen with a logout button routes through handleLogoutRequest',
      () {
    final List<String> offenders = <String>[];
    for (final String path in screensWithLogoutButton) {
      final File file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: '$path is missing — did the file move? '
            'Update logout_call_sites_test.dart to reflect the new path.',
      );
      final String contents = file.readAsStringSync();

      final bool hasOnLogout = contents.contains('onLogout:');
      final bool delegates = contents.contains('handleLogoutRequest(');
      if (hasOnLogout && !delegates) {
        offenders.add('$path declares onLogout but never calls '
            'handleLogoutRequest — this is a bypass risk.');
      }

      // Also forbid direct logout() calls in screens. The only legitimate
      // caller is `handleLogoutRequest` itself, which lives in the widgets
      // folder, not screens.
      if (contents.contains('authNotifierProvider.notifier).logout()')) {
        offenders.add('$path calls authNotifierProvider.notifier.logout() '
            'directly — use handleLogoutRequest instead.');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Logout bypass detected:\n${offenders.join('\n')}',
    );
  });

  test('handleLogoutRequest is the sole caller of AuthNotifier.logout() in lib/',
      () {
    final List<String> offenders = <String>[];
    final Directory root = Directory('lib');
    for (final FileSystemEntity entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final String normalized = entity.path.replaceAll(r'\', '/');
      // The centralised handler itself is allowed to call .logout().
      if (normalized.endsWith(
        'lib/presentation/widgets/logout_confirmation.dart',
      )) {
        continue;
      }
      final String contents = entity.readAsStringSync();
      if (contents.contains('authNotifierProvider.notifier).logout()')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Only logout_confirmation.dart may call authNotifierProvider.notifier.logout() directly. '
          'Offenders:\n${offenders.join('\n')}',
    );
  });
}
