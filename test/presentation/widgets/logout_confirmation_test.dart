import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/domain/models/exit_safety.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/exit_safety_service.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/widgets/logout_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake that returns a canned evaluation — lets us drive each branch without
/// standing up the real shift/order repositories.
class _FakeExitSafetyService extends ExitSafetyService {
  _FakeExitSafetyService(this.result);

  final ExitSafetyEvaluation result;
  int evaluateCallCount = 0;

  @override
  Future<ExitSafetyEvaluation> evaluate({User? currentUser}) async {
    evaluateCallCount++;
    return result;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<_Harness> pumpHarness(
    WidgetTester tester, {
    required ExitSafetyEvaluation evaluation,
  }) async {
    final _FakeExitSafetyService fake = _FakeExitSafetyService(evaluation);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <GoRoute>[
        GoRoute(path: '/home', builder: (_, __) => const _HomePage()),
        GoRoute(path: '/login', builder: (_, __) => const _LoginPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
          exitSafetyServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    return _Harness(fake: fake, router: router);
  }

  testWidgets('no risk → simple confirm dialog only', (tester) async {
    final harness = await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.noRisk,
        reasons: <ExitSafetyReason>{},
        openOrderCount: 0,
        sentOrderCount: 0,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byKey(kLogoutSimpleDialogKey), findsOneWidget);
    expect(find.byKey(kLogoutWarnDialogKey), findsNothing);
    expect(find.byKey(kLogoutBlockedDialogKey), findsNothing);
    expect(harness.fake.evaluateCallCount, 1);

    await tester.tap(find.byKey(kLogoutConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(_LoginPage), findsOneWidget);
  });

  testWidgets('active shift only → warning dialog (not blocked)', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.warnOnly,
        reasons: <ExitSafetyReason>{ExitSafetyReason.activeShift},
        openOrderCount: 0,
        sentOrderCount: 0,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byKey(kLogoutWarnDialogKey), findsOneWidget);
    expect(find.byKey(kLogoutBlockedDialogKey), findsNothing);
    expect(find.text('Shift is still active'), findsNothing);
    expect(find.textContaining('Shift is still active'), findsOneWidget);
    // User must be able to proceed from the warning.
    expect(find.byKey(kLogoutConfirmButtonKey), findsOneWidget);
    // Cancel aborts cleanly.
    await tester.tap(find.byKey(kLogoutCancelButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(_HomePage), findsOneWidget);
  });

  testWidgets('open orders exist → hard block dialog, no exit button', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.blocked,
        reasons: <ExitSafetyReason>{ExitSafetyReason.openOrders},
        openOrderCount: 2,
        sentOrderCount: 0,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byKey(kLogoutBlockedDialogKey), findsOneWidget);
    expect(find.byKey(kLogoutConfirmButtonKey), findsNothing);
    expect(find.byKey(kLogoutBlockedAcknowledgeKey), findsOneWidget);
    expect(find.textContaining('Open orders exist (2)'), findsOneWidget);

    // Acknowledging the blocked dialog must NOT log out.
    await tester.tap(find.byKey(kLogoutBlockedAcknowledgeKey));
    await tester.pumpAndSettle();
    expect(find.byType(_HomePage), findsOneWidget);
    expect(find.byType(_LoginPage), findsNothing);
  });

  testWidgets('sent orders exist → hard block dialog', (tester) async {
    await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.blocked,
        reasons: <ExitSafetyReason>{ExitSafetyReason.sentOrders},
        openOrderCount: 0,
        sentOrderCount: 3,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byKey(kLogoutBlockedDialogKey), findsOneWidget);
    expect(find.textContaining('Sent orders exist (3)'), findsOneWidget);
  });

  testWidgets('verification failure → blocked dialog with explicit reason', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.blocked,
        reasons: <ExitSafetyReason>{ExitSafetyReason.verificationFailed},
        openOrderCount: 0,
        sentOrderCount: 0,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.byKey(kLogoutBlockedDialogKey), findsOneWidget);
    expect(
      find.textContaining('Order status could not be verified.'),
      findsOneWidget,
    );
    // No exit button is offered under verification failure.
    expect(find.byKey(kLogoutConfirmButtonKey), findsNothing);
  });

  testWidgets('Enter key activates Cancel (simple dialog)', (tester) async {
    await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.noRisk,
        reasons: <ExitSafetyReason>{},
        openOrderCount: 0,
        sentOrderCount: 0,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(find.byKey(kLogoutSimpleDialogKey), findsOneWidget);
    expect(_cancelButton(tester).focusNode?.hasPrimaryFocus, isTrue);

    // Cancel is the default focused action, and Enter must not hit Exit.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(kLogoutSimpleDialogKey), findsNothing);
    // We are back on /home (cancel), NOT on /login (exit).
    expect(find.byType(_HomePage), findsOneWidget);
    expect(find.byType(_LoginPage), findsNothing);
  });

  testWidgets('Enter key activates Cancel (warn dialog)', (tester) async {
    await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.warnOnly,
        reasons: <ExitSafetyReason>{ExitSafetyReason.activeShift},
        openOrderCount: 0,
        sentOrderCount: 0,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(find.byKey(kLogoutWarnDialogKey), findsOneWidget);
    expect(_cancelButton(tester).focusNode?.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(kLogoutWarnDialogKey), findsNothing);
    expect(find.byType(_HomePage), findsOneWidget);
    expect(find.byType(_LoginPage), findsNothing);
  });

  testWidgets('Escape routes to Cancel (never silent dismiss)', (tester) async {
    await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.warnOnly,
        reasons: <ExitSafetyReason>{ExitSafetyReason.activeShift},
        openOrderCount: 0,
        sentOrderCount: 0,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    expect(find.byKey(kLogoutWarnDialogKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(kLogoutWarnDialogKey), findsNothing);
    // Escape resolved to Cancel → we remain on /home, no exit happened.
    expect(find.byType(_HomePage), findsOneWidget);
    expect(find.byType(_LoginPage), findsNothing);
  });

  testWidgets('Cancel is the default focused action on open', (tester) async {
    await pumpHarness(
      tester,
      evaluation: const ExitSafetyEvaluation(
        level: ExitSafetyLevel.noRisk,
        reasons: <ExitSafetyReason>{},
        openOrderCount: 0,
        sentOrderCount: 0,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    final TextButton cancelButton = _cancelButton(tester);
    expect(cancelButton.focusNode, isNotNull);
    expect(cancelButton.focusNode?.hasPrimaryFocus, isTrue);
    expect(find.byKey(kLogoutConfirmButtonKey), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byKey(kLogoutConfirmButtonKey)).focusNode,
      isNull,
    );
  });
}

TextButton _cancelButton(WidgetTester tester) {
  return tester.widget<TextButton>(find.byKey(kLogoutCancelButtonKey));
}

class _Harness {
  _Harness({required this.fake, required this.router});
  final _FakeExitSafetyService fake;
  final GoRouter router;
}

class _HomePage extends ConsumerWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => handleLogoutRequest(context, ref),
          child: const Text('trigger'),
        ),
      ),
    );
  }
}

class _LoginPage extends StatelessWidget {
  const _LoginPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('login')));
  }
}
