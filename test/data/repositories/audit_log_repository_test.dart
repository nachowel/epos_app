import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('AuditLogRepository', () {
    test('creates and lists audit logs', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int actorUserId = await insertUser(
        db,
        name: 'Admin',
        role: 'admin',
      );
      final AuditLogRepository repository = AuditLogRepository(db);

      final created = await repository.createAuditLog(
        actorUserId: actorUserId,
        action: 'product_created',
        entityType: 'product',
        entityId: '42',
        metadataJson: '{"name":"Tea"}',
      );

      final logs = await repository.listAuditLogs(limit: 10);

      expect(created.actorUserId, actorUserId);
      expect(created.action, 'product_created');
      expect(created.entityType, 'product');
      expect(created.entityId, '42');
      expect(created.metadataJson, '{"name":"Tea"}');
      expect(logs, hasLength(1));
      expect(logs.single, created);
    });

    test('append-only repository exposes no update or delete paths', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final dynamic repository = AuditLogRepository(db);

      expect(
        () => repository.updateAuditLog(id: 1),
        throwsA(isA<NoSuchMethodError>()),
      );
      expect(
        () => repository.deleteAuditLog(id: 1),
        throwsA(isA<NoSuchMethodError>()),
      );
    });

    test('rejects insert when actor does not exist', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final AuditLogRepository repository = AuditLogRepository(db);

      await expectLater(
        repository.createAuditLog(
          actorUserId: 999,
          action: 'shift_opened',
          entityType: 'shift',
          entityId: '1',
          metadataJson: '{}',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
