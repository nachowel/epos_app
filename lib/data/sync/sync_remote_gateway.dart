import 'sync_transaction_graph.dart';

abstract class SyncRemoteGateway {
  bool get isConfigured;
  String? get configurationIssue;

  /// Accepts finalized local transaction graphs only.
  /// Implementations must never become the source of business authority.
  Future<void> syncTransactionGraph(SyncTransactionGraph graph);
}
