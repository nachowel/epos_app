import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

class AppCrashGuard {
  const AppCrashGuard._();

  static void installFlutterErrorHandler(AppLogger logger) {
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.error(
        eventType: 'flutter_error',
        message: details.exceptionAsString(),
        metadata: <String, Object?>{
          'library': details.library,
          'context': details.context?.toDescription(),
        },
        error: details.exception,
        stackTrace: details.stack,
      );
      FlutterError.presentError(details);
    };
  }

  static Future<void> runGuarded({
    required AppLogger Function() logger,
    required Future<void> Function() body,
  }) {
    final Completer<void> completer = Completer<void>();
    runZonedGuarded(
      () async {
        try {
          await body();
          if (!completer.isCompleted) {
            completer.complete();
          }
        } catch (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
          rethrow;
        }
      },
      (Object error, StackTrace stackTrace) {
        logger().error(
          eventType: 'zone_error',
          message: 'Unhandled zone exception',
          error: error,
          stackTrace: stackTrace,
        );
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    return completer.future;
  }
}
