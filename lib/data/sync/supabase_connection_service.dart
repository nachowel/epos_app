import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import 'phase1_sync_contract.dart';

enum SupabaseConnectionState {
  notConfigured,
  connected,
  schemaMissing,
  unreachable,
  misconfigured,
}

enum SupabaseRemoteTableState { unchecked, present, missing, inaccessible }

class SupabaseConnectionStatus {
  const SupabaseConnectionStatus({
    required this.state,
    required this.checkedAt,
    required this.message,
    required this.requiredTables,
    required this.successfulQueryCount,
  });

  final SupabaseConnectionState state;
  final DateTime checkedAt;
  final String message;
  final Map<String, SupabaseRemoteTableState> requiredTables;
  final int successfulQueryCount;

  bool get isAvailable => state == SupabaseConnectionState.connected;

  List<String> get missingTables => requiredTables.entries
      .where(
        (MapEntry<String, SupabaseRemoteTableState> entry) =>
            entry.value == SupabaseRemoteTableState.missing,
      )
      .map((MapEntry<String, SupabaseRemoteTableState> entry) => entry.key)
      .toList(growable: false);
}

abstract class SupabaseConnectionProbe {
  Future<Map<String, SupabaseRemoteTableState>> probeRequiredTables(
    List<String> tableNames,
  );
}

class SupabaseFlutterConnectionProbe implements SupabaseConnectionProbe {
  const SupabaseFlutterConnectionProbe(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, SupabaseRemoteTableState>> probeRequiredTables(
    List<String> tableNames,
  ) async {
    final FunctionResponse response = await _client.functions
        .invoke(
          'mirror-health',
          body: <String, Object?>{'required_tables': tableNames},
        )
        .timeout(const Duration(seconds: 5));
    final dynamic data = response.data;
    if (data is! Map) {
      throw StateError('Mirror health probe returned a non-JSON response.');
    }
    final Object? tableStates = data['table_states'];
    if (tableStates is! Map) {
      throw StateError('Mirror health probe did not include table_states.');
    }

    return <String, SupabaseRemoteTableState>{
      for (final MapEntry<Object?, Object?> entry in tableStates.entries)
        entry.key! as String: _stateFromWire(entry.value),
    };
  }

  static SupabaseRemoteTableState _stateFromWire(Object? value) {
    switch (value) {
      case 'present':
        return SupabaseRemoteTableState.present;
      case 'missing':
        return SupabaseRemoteTableState.missing;
      case 'inaccessible':
        return SupabaseRemoteTableState.inaccessible;
      default:
        throw StateError('Unsupported mirror health table state: $value');
    }
  }
}

class SupabaseConnectionService {
  const SupabaseConnectionService({
    required AppConfig config,
    SupabaseConnectionProbe? probe,
  }) : _config = config,
       _probe = probe;

  final AppConfig _config;
  final SupabaseConnectionProbe? _probe;

  bool get isConfigured =>
      _config.supabaseConfigurationStatus ==
      SupabaseConfigurationStatus.valid;

  // Read-only operational check:
  // Can the remote mirror be reached, and are the required mirror tables ready?
  // This never blocks startup and never changes local authority.
  Future<SupabaseConnectionStatus> checkHealth() async {
    final DateTime checkedAt = DateTime.now().toUtc();
    final Map<String, SupabaseRemoteTableState> requiredTables =
        _initialRequiredTableState();

    switch (_config.supabaseConfigurationStatus) {
      case SupabaseConfigurationStatus.disabled:
      case SupabaseConfigurationStatus.missing:
        return SupabaseConnectionStatus(
          state: SupabaseConnectionState.notConfigured,
          checkedAt: checkedAt,
          message:
              _config.supabaseConfigurationIssue ??
              'Remote Supabase mirror is not configured for this build.',
          requiredTables: requiredTables,
          successfulQueryCount: 0,
        );
      case SupabaseConfigurationStatus.invalidUrl:
      case SupabaseConfigurationStatus.rejectedServiceRoleKey:
        return SupabaseConnectionStatus(
          state: SupabaseConnectionState.misconfigured,
          checkedAt: checkedAt,
          message:
              _config.supabaseConfigurationIssue ??
              'Remote Supabase mirror configuration is invalid.',
          requiredTables: requiredTables,
          successfulQueryCount: 0,
        );
      case SupabaseConfigurationStatus.valid:
        break;
    }

    final SupabaseConnectionProbe? probe = _probe;
    if (probe == null) {
      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.unreachable,
        checkedAt: checkedAt,
        message:
            'Remote Supabase mirror is configured, but the client is unavailable in this runtime.',
        requiredTables: requiredTables,
        successfulQueryCount: 0,
      );
    }

    try {
      requiredTables.addAll(
        await probe.probeRequiredTables(Phase1SyncContract.requiredRemoteTables),
      );
    } on TimeoutException {
      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.unreachable,
        checkedAt: checkedAt,
        message: 'Remote Supabase mirror probe timed out.',
        requiredTables: requiredTables,
        successfulQueryCount: 0,
      );
    } catch (error) {
      final String lower = error.toString().toLowerCase();
      if (_looksLikeConnectivityIssue(lower)) {
        return SupabaseConnectionStatus(
          state: SupabaseConnectionState.unreachable,
          checkedAt: checkedAt,
          message: 'Remote Supabase mirror is configured but currently unreachable.',
          requiredTables: requiredTables,
          successfulQueryCount: 0,
        );
      }

      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.misconfigured,
        checkedAt: checkedAt,
        message: 'Remote mirror probe failed: $error',
        requiredTables: requiredTables,
        successfulQueryCount: 0,
      );
    }

    final int successfulQueryCount = requiredTables.values
        .where((SupabaseRemoteTableState value) => value == SupabaseRemoteTableState.present)
        .length;
    final bool hasMissingTables = requiredTables.values.any(
      (SupabaseRemoteTableState value) => value == SupabaseRemoteTableState.missing,
    );
    final bool hasInaccessibleTables = requiredTables.values.any(
      (SupabaseRemoteTableState value) =>
          value == SupabaseRemoteTableState.inaccessible,
    );

    if (hasInaccessibleTables) {
      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.misconfigured,
        checkedAt: checkedAt,
        message: 'Remote mirror health probe reached Supabase, but one or more tables are inaccessible through the trusted probe.',
        requiredTables: requiredTables,
        successfulQueryCount: successfulQueryCount,
      );
    }

    if (hasMissingTables) {
      final List<String> missingTables = requiredTables.entries
          .where(
            (MapEntry<String, SupabaseRemoteTableState> entry) =>
                entry.value == SupabaseRemoteTableState.missing,
          )
          .map((MapEntry<String, SupabaseRemoteTableState> entry) => entry.key)
          .toList(growable: false);
      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.schemaMissing,
        checkedAt: checkedAt,
        message:
            'Remote Supabase mirror is reachable, but required mirror tables are missing: '
            '${missingTables.join(', ')}.',
        requiredTables: requiredTables,
        successfulQueryCount: successfulQueryCount,
      );
    }

    return SupabaseConnectionStatus(
      state: SupabaseConnectionState.connected,
      checkedAt: checkedAt,
      message: 'Remote Supabase mirror is reachable and required mirror tables are ready.',
      requiredTables: requiredTables,
      successfulQueryCount: successfulQueryCount,
    );
  }

  Future<SupabaseConnectionStatus> runDebugReadOnlyProbe() {
    return checkHealth();
  }

  static Map<String, SupabaseRemoteTableState> _initialRequiredTableState() {
    return <String, SupabaseRemoteTableState>{
      for (final String tableName in Phase1SyncContract.requiredRemoteTables)
        tableName: SupabaseRemoteTableState.unchecked,
    };
  }

  static bool _looksLikeConnectivityIssue(String value) {
    return value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('network is unreachable') ||
        value.contains('timed out') ||
        value.contains('clientexception');
  }
}
