import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/audit_log_record.dart';
import '../database/app_database.dart' as db;

class AuditLogRepository {
  const AuditLogRepository(this._database);

  final db.AppDatabase _database;

  Future<AuditLogRecord> createAuditLog({
    required int actorUserId,
    required String action,
    required String entityType,
    required String entityId,
    required String metadataJson,
    DateTime? createdAt,
  }) async {
    await _ensureActorExists(actorUserId);

    final int logId = await _database
        .into(_database.auditLogs)
        .insert(
          db.AuditLogsCompanion.insert(
            actorUserId: actorUserId,
            action: action,
            entityType: entityType,
            entityId: entityId,
            metadataJson: metadataJson,
            createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
          ),
        );

    final db.AuditLog inserted = await (_database.select(_database.auditLogs)
          ..where((db.$AuditLogsTable t) => t.id.equals(logId)))
        .getSingle();
    return _mapLog(inserted);
  }

  Future<List<AuditLogRecord>> listAuditLogs({
    int limit = 100,
    int? actorUserId,
    String? action,
    String? entityType,
  }) async {
    final SimpleSelectStatement<db.$AuditLogsTable, db.AuditLog> query =
        _database.select(_database.auditLogs)
          ..orderBy(<OrderingTerm Function(db.$AuditLogsTable)>[
            (db.$AuditLogsTable t) => OrderingTerm.desc(t.createdAt),
            (db.$AuditLogsTable t) => OrderingTerm.desc(t.id),
          ])
          ..limit(limit);

    if (actorUserId != null) {
      query.where((db.$AuditLogsTable t) => t.actorUserId.equals(actorUserId));
    }
    if (action != null && action.trim().isNotEmpty) {
      query.where((db.$AuditLogsTable t) => t.action.equals(action.trim()));
    }
    if (entityType != null && entityType.trim().isNotEmpty) {
      query.where(
        (db.$AuditLogsTable t) => t.entityType.equals(entityType.trim()),
      );
    }

    final List<db.AuditLog> rows = await query.get();
    return rows.map(_mapLog).toList(growable: false);
  }

  Future<List<AuditLogRecord>> listAuditLogsByEntity({
    required String entityType,
    required String entityId,
    int limit = 100,
  }) async {
    final List<db.AuditLog> rows =
        await (_database.select(_database.auditLogs)
              ..where((db.$AuditLogsTable t) {
                return t.entityType.equals(entityType) &
                    t.entityId.equals(entityId);
              })
              ..orderBy(<OrderingTerm Function(db.$AuditLogsTable)>[
                (db.$AuditLogsTable t) => OrderingTerm.desc(t.createdAt),
                (db.$AuditLogsTable t) => OrderingTerm.desc(t.id),
              ])
              ..limit(limit))
            .get();
    return rows.map(_mapLog).toList(growable: false);
  }

  Future<List<AuditLogRecord>> listAuditLogsByActor({
    required int actorUserId,
    int limit = 100,
  }) {
    return listAuditLogs(actorUserId: actorUserId, limit: limit);
  }

  Future<List<AuditLogRecord>> listRecent({int limit = 100}) {
    return listAuditLogs(limit: limit);
  }

  AuditLogRecord _mapLog(db.AuditLog row) {
    return AuditLogRecord(
      id: row.id,
      actorUserId: row.actorUserId,
      action: row.action,
      entityType: row.entityType,
      entityId: row.entityId,
      metadataJson: row.metadataJson,
      createdAt: row.createdAt,
    );
  }

  Future<void> _ensureActorExists(int actorUserId) async {
    final db.User? actor = await (_database.select(_database.users)
          ..where((db.$UsersTable t) => t.id.equals(actorUserId)))
        .getSingleOrNull();
    if (actor == null) {
      throw ValidationException('Audit log actor is invalid.');
    }
  }
}
