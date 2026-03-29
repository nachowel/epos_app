import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/app_log_entry.dart';

abstract class AppLogSink {
  Future<void> write(AppLogEntry entry);
}

abstract class AppLogger {
  void info({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
  });

  /// Always-on audit log — never gated by debug flags.
  /// Use for business-critical events: order_created, order_paid,
  /// shift_opened, shift_closed, sync_success, sync_failure, etc.
  void audit({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
  });

  void warn({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  });

  void error({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  });

  Future<void> dispose();
}

class NoopAppLogger implements AppLogger {
  const NoopAppLogger();

  @override
  void error({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  void info({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {}

  @override
  void audit({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {}

  @override
  void warn({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  Future<void> dispose() async {}
}

class StructuredAppLogger implements AppLogger {
  StructuredAppLogger({
    required List<AppLogSink> sinks,
    required bool enableInfoLogs,
  }) : _sinks = sinks,
       _enableInfoLogs = enableInfoLogs {
    _subscription = _controller.stream.asyncMap(_dispatch).listen((_) {});
  }

  static Future<StructuredAppLogger> create({
    required bool enableInfoLogs,
    List<AppLogSink>? additionalSinks,
  }) async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final Directory logDirectory = Directory(
      p.join(documentsDirectory.path, 'logs'),
    );
    await logDirectory.create(recursive: true);
    final File logFile = File(p.join(logDirectory.path, 'epos-events.jsonl'));

    return StructuredAppLogger(
      sinks: <AppLogSink>[
        FileAppLogSink(logFile),
        if (additionalSinks != null) ...additionalSinks,
      ],
      enableInfoLogs: enableInfoLogs,
    );
  }

  final List<AppLogSink> _sinks;
  final bool _enableInfoLogs;
  final StreamController<AppLogEntry> _controller =
      StreamController<AppLogEntry>.broadcast();
  late final StreamSubscription<void> _subscription;

  @override
  void info({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    if (!_enableInfoLogs) {
      return;
    }
    _enqueue(
      AppLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: AppLogLevel.info,
        eventType: eventType,
        message: message,
        entityId: entityId,
        metadata: metadata,
        error: null,
        stackTrace: null,
      ),
    );
  }

  @override
  void audit({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    // Always on — never gated by _enableInfoLogs.
    _enqueue(
      AppLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: AppLogLevel.audit,
        eventType: eventType,
        message: message,
        entityId: entityId,
        metadata: metadata,
        error: null,
        stackTrace: null,
      ),
    );
  }

  @override
  void warn({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _enqueue(
      AppLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: AppLogLevel.warn,
        eventType: eventType,
        message: message,
        entityId: entityId,
        metadata: metadata,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      ),
    );
  }

  @override
  void error({
    required String eventType,
    String? message,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _enqueue(
      AppLogEntry(
        timestamp: DateTime.now().toUtc(),
        level: AppLogLevel.error,
        eventType: eventType,
        message: message,
        entityId: entityId,
        metadata: metadata,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
    await _subscription.cancel();
  }

  void _enqueue(AppLogEntry entry) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(entry);
  }

  Future<void> _dispatch(AppLogEntry entry) async {
    for (final AppLogSink sink in _sinks) {
      await sink.write(entry);
    }
  }
}

class FileAppLogSink implements AppLogSink {
  const FileAppLogSink(this._file);

  final File _file;

  @override
  Future<void> write(AppLogEntry entry) async {
    await _file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

class MemoryAppLogSink implements AppLogSink {
  final List<AppLogEntry> entries = <AppLogEntry>[];

  @override
  Future<void> write(AppLogEntry entry) async {
    entries.add(entry);
  }
}
