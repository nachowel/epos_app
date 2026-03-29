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
  });

  test('reports unreachable when config is valid but no client probe exists', () async {
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
  });

  test('reports available when probe succeeds', () async {
    final SupabaseConnectionService service = SupabaseConnectionService(
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      probe: const _SuccessProbe(),
    );

    final SupabaseConnectionStatus status = await service.checkHealth();

    expect(status.state, SupabaseConnectionState.available);
  });

  test('reports unreachable on timeout-like probe failures', () async {
    final SupabaseConnectionService service = SupabaseConnectionService(
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      probe: const _TimeoutProbe(),
    );

    final SupabaseConnectionStatus status = await service.checkHealth();

    expect(status.state, SupabaseConnectionState.unreachable);
  });
}

class _SuccessProbe implements SupabaseConnectionProbe {
  const _SuccessProbe();

  @override
  Future<void> run() async {}
}

class _TimeoutProbe implements SupabaseConnectionProbe {
  const _TimeoutProbe();

  @override
  Future<void> run() {
    throw TimeoutException('timed out');
  }
}
