import 'package:epos_app/core/bootstrap/bootstrap_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BootstrapPolicy', () {
    test('debug builds auto-seed by default', () {
      expect(
        BootstrapPolicy.resolveShouldAutoSeed(
          isDebugMode: true,
          seedFlagEnabled: false,
        ),
        isTrue,
      );
    });

    test('release builds do not auto-seed without explicit flag', () {
      expect(
        BootstrapPolicy.resolveShouldAutoSeed(
          isDebugMode: false,
          seedFlagEnabled: false,
        ),
        isFalse,
      );
    });

    test('release builds can opt into seed with compile-time flag', () {
      expect(
        BootstrapPolicy.resolveShouldAutoSeed(
          isDebugMode: false,
          seedFlagEnabled: true,
        ),
        isTrue,
      );
    });
  });
}
