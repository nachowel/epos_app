import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart'
    hide CashMovement, User;
import 'package:epos_app/data/repositories/cash_movement_repository.dart';
import 'package:epos_app/domain/models/cash_movement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('CashMovementRepository', () {
    test('rejects insert when shift does not exist', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(db, name: 'Admin', role: 'admin');
      final CashMovementRepository repository = CashMovementRepository(db);

      await expectLater(
        repository.createCashMovement(
          shiftId: 999,
          type: CashMovementType.income,
          category: 'Float',
          amountMinor: 1000,
          paymentMethod: CashMovementPaymentMethod.cash,
          createdByUserId: userId,
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Cash movement shift is invalid.',
          ),
        ),
      );
    });

    test('rejects insert when actor does not exist', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int shiftUserId = await insertUser(
        db,
        name: 'Admin',
        role: 'admin',
      );
      final int shiftId = await insertShift(db, openedBy: shiftUserId);
      final CashMovementRepository repository = CashMovementRepository(db);

      await expectLater(
        repository.createCashMovement(
          shiftId: shiftId,
          type: CashMovementType.expense,
          category: 'Petty cash',
          amountMinor: 300,
          paymentMethod: CashMovementPaymentMethod.cash,
          createdByUserId: 999,
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Cash movement actor is invalid.',
          ),
        ),
      );
    });
  });
}
