import 'dart:convert';

import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/domain/services/audit_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('AuditLogService', () {
    test('create audit log record', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int actorUserId = await insertUser(db, name: 'Admin', role: 'admin');
      final PersistedAuditLogService service = PersistedAuditLogService(
        auditLogRepository: AuditLogRepository(db),
        logger: const NoopAppLogger(),
      );

      final record = await service.logAction(
        actorUserId: actorUserId,
        action: 'product_created',
        entityType: 'product',
        entityId: '7',
        metadata: const <String, Object?>{'name': 'Tea'},
      );

      expect(record.actorUserId, actorUserId);
      expect(record.action, 'product_created');
      expect(record.entityType, 'product');
      expect(record.entityId, '7');
      expect(record.metadata['name'], 'Tea');
    });

    test('reject empty action', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int actorUserId = await insertUser(db, name: 'Admin', role: 'admin');
      final PersistedAuditLogService service = PersistedAuditLogService(
        auditLogRepository: AuditLogRepository(db),
        logger: const NoopAppLogger(),
      );

      await expectLater(
        service.logAction(
          actorUserId: actorUserId,
          action: '   ',
          entityType: 'product',
          entityId: '1',
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Action is required.',
          ),
        ),
      );
    });

    test('reject empty entity type', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int actorUserId = await insertUser(db, name: 'Admin', role: 'admin');
      final PersistedAuditLogService service = PersistedAuditLogService(
        auditLogRepository: AuditLogRepository(db),
        logger: const NoopAppLogger(),
      );

      await expectLater(
        service.logAction(
          actorUserId: actorUserId,
          action: 'product_created',
          entityType: ' ',
          entityId: '1',
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Entity type is required.',
          ),
        ),
      );
    });

    test('reject empty entity id', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int actorUserId = await insertUser(db, name: 'Admin', role: 'admin');
      final PersistedAuditLogService service = PersistedAuditLogService(
        auditLogRepository: AuditLogRepository(db),
        logger: const NoopAppLogger(),
      );

      await expectLater(
        service.logAction(
          actorUserId: actorUserId,
          action: 'product_created',
          entityType: 'product',
          entityId: '   ',
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Entity id is required.',
          ),
        ),
      );
    });

    test('metadata JSON encoded correctly', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int actorUserId = await insertUser(db, name: 'Admin', role: 'admin');
      final PersistedAuditLogService service = PersistedAuditLogService(
        auditLogRepository: AuditLogRepository(db),
        logger: const NoopAppLogger(),
      );

      final record = await service.logAction(
        actorUserId: actorUserId,
        action: 'product_visibility_changed',
        entityType: 'product',
        entityId: '9',
        metadata: const <String, Object?>{
          'old_is_visible_on_pos': true,
          'new_is_visible_on_pos': false,
        },
      );

      expect(
        jsonDecode(record.metadataJson),
        <String, Object?>{
          'old_is_visible_on_pos': true,
          'new_is_visible_on_pos': false,
        },
      );
    });
  });
}
