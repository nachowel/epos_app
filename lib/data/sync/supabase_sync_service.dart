import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import 'phase1_sync_contract.dart';
import 'supabase_mirror_writer.dart';
import 'sync_remote_gateway.dart';
import 'sync_transaction_graph.dart';
import 'trusted_supabase_mirror_writer.dart';

class SupabaseSyncService implements SyncRemoteGateway {
  factory SupabaseSyncService({
    SupabaseClient? client,
    AppConfig? config,
    AppLogger logger = const NoopAppLogger(),
    SupabaseMirrorWriter? mirrorWriter,
    TrustedMirrorBoundaryInvoker? trustedBoundaryInvoker,
  }) {
    final _MirrorWriterSelection selection = _selectMirrorWriter(
      client,
      config,
      logger,
      trustedBoundaryInvoker,
    );
    return SupabaseSyncService._(
      mirrorWriter: mirrorWriter ?? selection.writer,
      configurationIssue: mirrorWriter == null ? selection.issue : null,
    );
  }

  const SupabaseSyncService._({
    required SupabaseMirrorWriter? mirrorWriter,
    required String? configurationIssue,
  }) : _mirrorWriter = mirrorWriter,
       _configurationIssue = configurationIssue;

  final SupabaseMirrorWriter? _mirrorWriter;
  final String? _configurationIssue;

  @override
  bool get isConfigured => _mirrorWriter != null;

  @override
  String? get configurationIssue => _configurationIssue;

  @override
  Future<void> syncTransactionGraph(SyncTransactionGraph graph) async {
    final SupabaseMirrorWriter? mirrorWriter = _mirrorWriter;
    if (mirrorWriter == null) {
      throw StateError('Supabase mirror writer is not configured.');
    }

    final SyncGraphRecord transactionRecord = graph.records.firstWhere(
      (SyncGraphRecord record) =>
          record.tableName == Phase1SyncTable.transactions.tableName,
      orElse: () => throw StateError(
        'Supabase mirror sync requires a transaction root payload.',
      ),
    );
    final Object? status = transactionRecord.payload['status'];

    // Supabase is a synchronized mirror/report target. It must never receive
    // remote-driving lifecycle states for in-progress local orders.
    if (status is! String ||
        !Phase1SyncContract.isTerminalTransactionStatus(status)) {
      throw StateError(
        'Only finalized local transactions may be mirrored to Supabase.',
      );
    }

    await mirrorWriter.writeTransactionGraph(graph);
  }

  static _MirrorWriterSelection _selectMirrorWriter(
    SupabaseClient? client,
    AppConfig? config,
    AppLogger logger,
    TrustedMirrorBoundaryInvoker? trustedBoundaryInvoker,
  ) {
    if (client == null) {
      return const _MirrorWriterSelection(
        writer: null,
        issue: 'Supabase client is unavailable in this runtime.',
      );
    }
    final MirrorWriteMode mode =
        config?.mirrorWriteMode ?? MirrorWriteMode.trustedSyncBoundary;
    switch (mode) {
      case MirrorWriteMode.directMirrorWrite:
        if (config?.mirrorWriteModeIssue case final String issue) {
          return _MirrorWriterSelection(writer: null, issue: issue);
        }
        return _MirrorWriterSelection(
          writer: DirectSupabaseMirrorWriter(client),
          issue:
              'Direct client mirror write is enabled. This path is for controlled non-production use only.',
        );
      case MirrorWriteMode.trustedSyncBoundary:
        return _MirrorWriterSelection(
          writer: TrustedSupabaseMirrorWriter(
            trustedBoundaryInvoker ??
                SupabaseTrustedMirrorBoundaryInvoker(
                  client: client,
                  config: config ?? AppConfig.fallback(),
                  logger: logger,
                ),
          ),
          issue: null,
        );
    }
  }
}

class _MirrorWriterSelection {
  const _MirrorWriterSelection({required this.writer, required this.issue});

  final SupabaseMirrorWriter? writer;
  final String? issue;
}
