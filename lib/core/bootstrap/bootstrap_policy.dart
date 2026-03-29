import 'package:flutter/foundation.dart';

class BootstrapPolicy {
  const BootstrapPolicy._();

  static const String seedFlagName = 'EPOS_ENABLE_DEMO_SEED';

  static bool get shouldAutoSeed => resolveShouldAutoSeed(
    isDebugMode: kDebugMode,
    seedFlagEnabled: const bool.fromEnvironment(seedFlagName),
  );

  static bool resolveShouldAutoSeed({
    required bool isDebugMode,
    required bool seedFlagEnabled,
  }) {
    return isDebugMode || seedFlagEnabled;
  }
}
