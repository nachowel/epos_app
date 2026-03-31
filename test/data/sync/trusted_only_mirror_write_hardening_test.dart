import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'trusted-only hardening migration removes permissive client policies',
    () {
      final String sql = File(
        'supabase/migrations/20260330130000_trusted_only_mirror_writes.sql',
      ).readAsStringSync();

      expect(sql, contains('drop policy if exists transactions_insert_sync'));
      expect(sql, contains('drop policy if exists transactions_update_sync'));
      expect(
        sql,
        contains('drop policy if exists transaction_lines_insert_sync'),
      );
      expect(
        sql,
        contains('drop policy if exists transaction_lines_update_sync'),
      );
      expect(
        sql,
        contains('drop policy if exists order_modifiers_insert_sync'),
      );
      expect(
        sql,
        contains('drop policy if exists order_modifiers_update_sync'),
      );
      expect(sql, contains('drop policy if exists payments_insert_sync'));
      expect(sql, contains('drop policy if exists payments_update_sync'));
    },
  );

  test(
    'trusted-only hardening migration revokes anon/authenticated table access',
    () {
      final String sql = File(
        'supabase/migrations/20260330130000_trusted_only_mirror_writes.sql',
      ).readAsStringSync();

      expect(sql, contains('enable row level security'));
      expect(
        sql,
        contains(
          'revoke all privileges on public.transactions from anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all privileges on public.transaction_lines from anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all privileges on public.order_modifiers from anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'revoke all privileges on public.payments from anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains('service_role-backed Edge Functions continue to write'),
      );
    },
  );

  test('baseline and docs keep schema alignment separate from hardening', () {
    final String baseline = File(
      'supabase/phase1_sales_sync_foundation.sql',
    ).readAsStringSync();
    final String docs = File(
      'docs/supabase_phase2_setup.md',
    ).readAsStringSync();

    expect(baseline, contains('trusted-only write enforcement are'));
    expect(
      baseline,
      contains(
        'client direct write closure arrives through a separate hardening migration',
      ),
    );
    expect(docs, contains('20260330130000_trusted_only_mirror_writes.sql'));
    expect(
      docs,
      contains('Trusted function artık hedeflenen tek remote write yoludur'),
    );
    expect(docs, contains('Anon direct insert fail'));
    expect(docs, contains('Anon direct update fail'));
    expect(docs, contains('Trusted function write still works'));
  });
}
