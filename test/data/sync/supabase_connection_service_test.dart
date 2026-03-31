import 'dart:async';

import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/data/sync/supabase_connection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports notConfigured when Supabase env is missing', () async {
    final SupabaseConnectionService service = SupabaseConnectionService(
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: null,
        supabaseAnonKey: null,
      ),
    );

    final SupabaseConnectionStatus status = await service.checkHealth();

    expect(status.state, SupabaseConnectionState.notConfigured);
    expect(status.successfulQueryCount, 0);
  });

  test('reports misconfigured when URL is invalid', () async {
    final SupabaseConnectionService service = SupabaseConnectionService(
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'http://localhost',
        supabaseAnonKey: 'anon-key',
      ),
    );

    final SupabaseConnectionStatus status = await service.checkHealth();

    expect(status.state, SupabaseConnectionState.misconfigured);
    expect(status.successfulQueryCount, 0);
  });

  test(
    'reports unreachable when config is valid but no client probe exists',
    () async {
      final SupabaseConnectionService service = SupabaseConnectionService(
        config: AppConfig.fromValues(
          environment: 'test',
          appVersion: 'test',
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
        ),
      );

      final SupabaseConnectionStatus status = await service.checkHealth();

      expect(status.state, SupabaseConnectionState.unreachable);
      expect(status.successfulQueryCount, 0);
    },
  );

  test('reports connected when all required table probes succeed', () async {
    final SupabaseConnectionService service = SupabaseConnectionService(
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      probe: _RecordingProbe(
        tableStates: <String, SupabaseRemoteTableState>{
          'transactions': SupabaseRemoteTableState.present,
          'transaction_lines': SupabaseRemoteTableState.present,
          'order_modifiers': SupabaseRemoteTableState.present,
          'payments': SupabaseRemoteTableState.present,
        },
      ),
    );

    final SupabaseConnectionStatus status = await service.checkHealth();

    expect(status.state, SupabaseConnectionState.connected);
    expect(status.successfulQueryCount, 4);
    expect(
      status.requiredTables.values,
      everyElement(SupabaseRemoteTableState.present),
    );
  });

  test('reports schemaMissing when one required table is absent', () async {
    final SupabaseConnectionService service = SupabaseConnectionService(
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      probe: _RecordingProbe(
        tableStates: <String, SupabaseRemoteTableState>{
          'transactions': SupabaseRemoteTableState.present,
          'transaction_lines': SupabaseRemoteTableState.missing,
          'order_modifiers': SupabaseRemoteTableState.present,
          'payments': SupabaseRemoteTableState.present,
        },
      ),
    );

    final SupabaseConnectionStatus status = await service.checkHealth();

    expect(status.state, SupabaseConnectionState.schemaMissing);
    expect(status.successfulQueryCount, 3);
    expect(
      status.requiredTables['transaction_lines'],
      SupabaseRemoteTableState.missing,
    );
    expect(status.missingTables, <String>['transaction_lines']);
  });

  test('reports unreachable on timeout-like probe failures', () async {
    final SupabaseConnectionService service = SupabaseConnectionService(
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      probe: _RecordingProbe(error: TimeoutException('timed out')),
    );

    final SupabaseConnectionStatus status = await service.checkHealth();

    expect(status.state, SupabaseConnectionState.unreachable);
    expect(status.successfulQueryCount, 0);
  });

  test(
    'reports misconfigured on permission-like table probe failures',
    () async {
      final SupabaseConnectionService service = SupabaseConnectionService(
        config: AppConfig.fromValues(
          environment: 'test',
          appVersion: 'test',
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
        ),
        probe: _RecordingProbe(
          tableStates: <String, SupabaseRemoteTableState>{
            'transactions': SupabaseRemoteTableState.inaccessible,
            'transaction_lines': SupabaseRemoteTableState.present,
            'order_modifiers': SupabaseRemoteTableState.present,
            'payments': SupabaseRemoteTableState.present,
          },
        ),
      );

      final SupabaseConnectionStatus status = await service.checkHealth();

      expect(status.state, SupabaseConnectionState.misconfigured);
      expect(
        status.requiredTables['transactions'],
        SupabaseRemoteTableState.inaccessible,
      );
    },
  );

  test(
    'runDebugReadOnlyProbe reuses the same safe read-only health check',
    () async {
      final SupabaseConnectionService service = SupabaseConnectionService(
        config: AppConfig.fromValues(
          environment: 'test',
          appVersion: 'test',
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
        ),
        probe: _RecordingProbe(
          tableStates: <String, SupabaseRemoteTableState>{
            'transactions': SupabaseRemoteTableState.present,
            'transaction_lines': SupabaseRemoteTableState.present,
            'order_modifiers': SupabaseRemoteTableState.present,
            'payments': SupabaseRemoteTableState.present,
          },
        ),
      );

      final SupabaseConnectionStatus status = await service
          .runDebugReadOnlyProbe();

      expect(status.state, SupabaseConnectionState.connected);
      expect(status.successfulQueryCount, 4);
    },
  );
}

class _RecordingProbe implements SupabaseConnectionProbe {
  const _RecordingProbe({
    this.tableStates = const <String, SupabaseRemoteTableState>{},
    this.error,
  });

  final Map<String, SupabaseRemoteTableState> tableStates;
  final Object? error;

  @override
  Future<Map<String, SupabaseRemoteTableState>> probeRequiredTables(
    List<String> tableNames,
  ) async {
    final Object? currentError = error;
    if (currentError != null) {
      throw currentError;
    }

    return <String, SupabaseRemoteTableState>{
      for (final String tableName in tableNames)
        tableName: tableStates[tableName] ?? SupabaseRemoteTableState.present,
    };
  }
}
