import 'package:epos_app/core/services/system_keyboard_service.dart';
import 'package:epos_app/presentation/widgets/selective_system_keyboard_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SystemKeyboardService.debugSupportsSelectiveSystemKeyboardOverride = null;
  });

  testWidgets('selective text field opens and closes the system keyboard', (
    WidgetTester tester,
  ) async {
    SystemKeyboardService.debugSupportsSelectiveSystemKeyboardOverride = true;

    final List<String> methodCalls = <String>[];
    const MethodChannel channel = MethodChannel(
      SystemKeyboardService.channelName,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          methodCalls.add(methodCall.method);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: SelectiveSystemKeyboardTextField(
                key: ValueKey<String>('selective-text-field'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('selective-text-field')),
    );
    await tester.pump();
    await tester.pump();

    expect(methodCalls, contains('show'));

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.pump();

    expect(methodCalls, contains('hide'));
  });
}
