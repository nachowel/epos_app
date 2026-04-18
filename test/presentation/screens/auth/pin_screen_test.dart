import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/data/repositories/auth_lockout_store.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/screens/auth/pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  testWidgets('PIN field is secure, numeric, and requests focus on tap', (
    WidgetTester tester,
  ) async {
    final _FakeAuthNotifier fakeAuthNotifier = await _pumpPinScreen(tester);

    expect(find.byKey(kPinScreenMainLayoutKey), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('HALFWAY CAFE'), findsOneWidget);
    expect(find.text('Staff Login'), findsOneWidget);
    expect(find.byKey(kPinScreenInputKey), findsOneWidget);
    expect(find.byKey(kPinScreenSignInButtonKey), findsOneWidget);

    final TextField pinField = _pinField(tester);
    expect(pinField.obscureText, isTrue);
    expect(pinField.keyboardType, TextInputType.number);
    expect(pinField.decoration?.hintText, 'Enter PIN');
    expect(
      pinField.inputFormatters!.whereType<FilteringTextInputFormatter>().length,
      greaterThanOrEqualTo(1),
    );

    await tester.tap(find.byKey(kPinScreenInputKey));
    await tester.pump();

    expect(_pinField(tester).focusNode?.hasPrimaryFocus, isTrue);
    expect(fakeAuthNotifier.loginCallCount, 0);
  });

  testWidgets(
    'keypad digit entry updates the same controller as keyboard input',
    (WidgetTester tester) async {
      await _pumpPinScreen(tester);

      await tester.tap(find.byKey(kPinScreenInputKey));
      await tester.pump();
      await tester.enterText(find.byKey(kPinScreenInputKey), '12');
      await tester.pump();

      expect(_pinField(tester).controller?.text, '12');

      await _tapKeypadDigit(tester, '3');

      expect(_pinField(tester).controller?.text, '123');
      expect(_pinField(tester).focusNode?.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets(
    'keypad backspace removes only the last digit and preserves focus',
    (WidgetTester tester) async {
      await _pumpPinScreen(tester);

      await tester.tap(find.byKey(kPinScreenInputKey));
      await tester.pump();
      await tester.enterText(find.byKey(kPinScreenInputKey), '789');
      await tester.pump();

      await tester.ensureVisible(find.byKey(kPinScreenKeypadBackspaceKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kPinScreenKeypadBackspaceKey));
      await tester.pump();

      expect(_pinField(tester).controller?.text, '78');
      expect(_pinField(tester).focusNode?.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('mixing field input and keypad input does not duplicate digits', (
    WidgetTester tester,
  ) async {
    await _pumpPinScreen(tester);

    await tester.tap(find.byKey(kPinScreenInputKey));
    await tester.pump();
    await tester.enterText(find.byKey(kPinScreenInputKey), '45');
    await tester.pump();

    await _tapKeypadDigit(tester, '6');
    await _tapKeypadDigit(tester, '7');

    expect(_pinField(tester).controller?.text, '4567');
    expect(_pinField(tester).focusNode?.hasPrimaryFocus, isTrue);
  });

  testWidgets('Sign In with typed PIN uses the existing login path', (
    WidgetTester tester,
  ) async {
    final _FakeAuthNotifier fakeAuthNotifier = await _pumpPinScreen(tester);

    await tester.enterText(find.byKey(kPinScreenInputKey), '2468');
    await tester.pump();
    await tester.ensureVisible(find.byKey(kPinScreenSignInButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kPinScreenSignInButtonKey));
    await tester.pump();

    expect(fakeAuthNotifier.loginCallCount, 1);
    expect(fakeAuthNotifier.lastLoginPin, '2468');
  });

  testWidgets('Sign In with keypad PIN uses the existing login path', (
    WidgetTester tester,
  ) async {
    final _FakeAuthNotifier fakeAuthNotifier = await _pumpPinScreen(tester);

    await _tapKeypadDigit(tester, '1');
    await _tapKeypadDigit(tester, '2');
    await _tapKeypadDigit(tester, '3');
    await _tapKeypadDigit(tester, '4');

    await tester.ensureVisible(find.byKey(kPinScreenSignInButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kPinScreenSignInButtonKey));
    await tester.pump();

    expect(fakeAuthNotifier.loginCallCount, 1);
    expect(fakeAuthNotifier.lastLoginPin, '1234');
  });

  testWidgets('invalid PIN error state still appears correctly', (
    WidgetTester tester,
  ) async {
    final _FakeAuthNotifier fakeAuthNotifier = await _pumpPinScreen(
      tester,
      loginError: AppStrings.invalidPinOrInactiveUser,
    );

    await tester.enterText(find.byKey(kPinScreenInputKey), '9999');
    await tester.pump();
    await tester.ensureVisible(find.byKey(kPinScreenSignInButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kPinScreenSignInButtonKey));
    await tester.pumpAndSettle();

    expect(fakeAuthNotifier.loginCallCount, 1);
    expect(
      find.descendant(
        of: find.byKey(kPinScreenErrorBannerKey),
        matching: find.text(AppStrings.invalidPinOrInactiveUser),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.invalidPinOrInactiveUser), findsWidgets);
  });
}

Future<_FakeAuthNotifier> _pumpPinScreen(
  WidgetTester tester, {
  String? loginError,
  User? loginResult,
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  late final _FakeAuthNotifier fakeAuthNotifier;

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authNotifierProvider.overrideWith((Ref ref) {
          fakeAuthNotifier = _FakeAuthNotifier(
            ref,
            prefs,
            loginError: loginError,
            loginResult: loginResult,
          );
          return fakeAuthNotifier;
        }),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PinScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return fakeAuthNotifier;
}

Future<void> _tapKeypadDigit(WidgetTester tester, String digit) async {
  final Finder digitButton = find.byKey(pinScreenKeypadDigitKey(digit));
  await tester.ensureVisible(digitButton);
  await tester.pumpAndSettle();
  await tester.tap(digitButton);
  await tester.pump();
}

TextField _pinField(WidgetTester tester) {
  return tester.widget<TextField>(find.byKey(kPinScreenInputKey));
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(
    Ref ref,
    SharedPreferences prefs, {
    this.loginError,
    this.loginResult,
  }) : super(ref, AuthLockoutStore(prefs));

  final String? loginError;
  final User? loginResult;
  int loginCallCount = 0;
  String? lastLoginPin;

  @override
  Future<User?> loginWithPin(String pin) async {
    loginCallCount++;
    lastLoginPin = pin;
    state = state.copyWith(
      isLoading: false,
      errorMessage: loginResult == null ? loginError : null,
      currentUser: loginResult,
    );
    return loginResult;
  }
}
