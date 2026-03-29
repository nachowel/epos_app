import 'dart:convert';

import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../data/repositories/audit_log_repository.dart';
import '../models/audit_log_record.dart';

abstract class AuditLogService {
  const AuditLogService();

  Future<AuditLogRecord> logAction({
    required int actorUserId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  });

  Future<void> logActionSafely({
    required int actorUserId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  });
}

class NoopAuditLogService implements AuditLogService {
  const NoopAuditLogService();

  @override
  Future<AuditLogRecord> logAction({
    required int actorUserId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  }) async {
    return AuditLogRecord(
      id: 0,
      actorUserId: actorUserId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      metadataJson: jsonEncode(metadata),
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  @override
  Future<void> logActionSafely({
    required int actorUserId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  }) async {}
}

class PersistedAuditLogService implements AuditLogService {
  PersistedAuditLogService({
    required AuditLogRepository auditLogRepository,
    required AppLogger logger,
  }) : _auditLogRepository = auditLogRepository,
       _logger = logger;

  final AuditLogRepository _auditLogRepository;
  final AppLogger _logger;

  @override
  Future<AuditLogRecord> logAction({
    required int actorUserId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  }) async {
    _validateActor(actorUserId);
    final String normalizedAction = _requireValue(action, fieldName: 'Action');
    final String normalizedEntityType = _requireValue(
      entityType,
      fieldName: 'Entity type',
    );
    final String normalizedEntityId = _requireValue(
      entityId,
      fieldName: 'Entity id',
    );

    late final String encodedMetadata;
    try {
      encodedMetadata = jsonEncode(metadata);
    } catch (error) {
      throw ValidationException('Audit log metadata must be JSON encodable.');
    }

    final AuditLogRecord record = await _auditLogRepository.createAuditLog(
      actorUserId: actorUserId,
      action: normalizedAction,
      entityType: normalizedEntityType,
      entityId: normalizedEntityId,
      metadataJson: encodedMetadata,
      createdAt: createdAt,
    );

    _logger.audit(
      eventType: normalizedAction,
      entityId: normalizedEntityId,
      metadata: <String, Object?>{
        'entity_type': normalizedEntityType,
        'actor_user_id': actorUserId,
        ...metadata,
      },
    );
    return record;
  }

  @override
  Future<void> logActionSafely({
    required int actorUserId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  }) async {
    try {
      await logAction(
        actorUserId: actorUserId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
        createdAt: createdAt,
      );
    } catch (error, stackTrace) {
      _logger.warn(
        eventType: 'audit_log_write_failed',
        entityId: entityId,
        message: 'Audit log write failed.',
        metadata: <String, Object?>{
          'action': action,
          'entity_type': entityType,
          'actor_user_id': actorUserId,
        },
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _requireValue(String value, {required String fieldName}) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ValidationException('$fieldName is required.');
    }
    return trimmed;
  }

  void _validateActor(int actorUserId) {
    if (actorUserId <= 0) {
      throw ValidationException('Actor user id is required.');
    }
  }
}
