import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/user_repository.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/auth_security.dart';
import 'package:epos_app/domain/services/auth_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('AuthService', () {
    test(
      'upgrades legacy plain text pins to hashed storage on successful login',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int userId = await insertUser(
          db,
          name: 'Legacy Cashier',
          role: 'cashier',
          pin: '1234',
        );

        final service = AuthService(
          UserRepository(db),
          ShiftSessionService(ShiftRepository(db)),
        );
        final user = await service.loginWithPin('1234');
        final upgraded = await UserRepository(db).getById(userId);

        expect(user, isNotNull);
        expect(upgraded, isNotNull);
        expect(upgraded!.pin, startsWith('sha256:'));
        expect(upgraded.pin, isNot('1234'));
        expect(
          AuthSecurity.verifyPin(candidate: '1234', storedValue: upgraded.pin),
          SecretVerificationStatus.valid,
        );
      },
    );

    test('first successful login opens shift when none exists', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Morning Cashier',
        role: 'cashier',
        pin: AuthSecurity.hashPin('2468'),
      );

      final ShiftRepository shiftRepository = ShiftRepository(db);
      final service = AuthService(
        UserRepository(db),
        ShiftSessionService(shiftRepository),
      );

      final user = await service.loginWithPin('2468');
      final openShift = await shiftRepository.getOpenShift();

      expect(user, isNotNull);
      expect(openShift, isNotNull);
      expect(openShift!.openedBy, cashierId);
    });

    test('second login continues same shift', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int firstUserId = await insertUser(
        db,
        name: 'Cashier One',
        role: 'cashier',
        pin: AuthSecurity.hashPin('1111'),
      );
      await insertUser(
        db,
        name: 'Admin Later',
        role: 'admin',
        pin: AuthSecurity.hashPin('2222'),
      );

      final ShiftRepository shiftRepository = ShiftRepository(db);
      final service = AuthService(
        UserRepository(db),
        ShiftSessionService(shiftRepository),
      );

      final firstUser = await service.loginWithPin('1111');
      final firstShift = await shiftRepository.getOpenShift();
      final secondUser = await service.loginWithPin('2222');
      final secondShift = await shiftRepository.getOpenShift();

      expect(firstUser, isNotNull);
      expect(secondUser, isNotNull);
      expect(firstShift, isNotNull);
      expect(secondShift, isNotNull);
      expect(secondShift!.id, firstShift!.id);
      expect(secondShift.openedBy, firstUserId);
    });

    test('rejects inactive users even when hash matches', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(
        db,
        name: 'Inactive Admin',
        role: 'admin',
        pin: AuthSecurity.hashPin('1234'),
        isActive: false,
      );

      final service = AuthService(
        UserRepository(db),
        ShiftSessionService(ShiftRepository(db)),
      );
      final user = await service.loginWithPin('1234');

      expect(user, isNull);
    });

    test(
      'concurrent first-login race reuses the existing open shift instead of failing the second login',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final existingShift = Shift(
          id: 77,
          openedBy: 1,
          openedAt: DateTime.now(),
          closedBy: null,
          closedAt: null,
          cashierPreviewedBy: null,
          cashierPreviewedAt: null,
          status: ShiftStatus.open,
        );
        final shiftSessionService = ShiftSessionService(
          _RaceShiftRepository(db, existingShift: existingShift),
        );

        final reusedShift = await shiftSessionService
            .ensureShiftStartedForLogin(
              User(
                id: 2,
                name: 'Second Login',
                pin: null,
                password: null,
                role: UserRole.cashier,
                isActive: true,
                createdAt: DateTime.now(),
              ),
            );

        expect(reusedShift.id, existingShift.id);
        expect(reusedShift.openedBy, existingShift.openedBy);
      },
    );
  });
}

class _RaceShiftRepository extends ShiftRepository {
  _RaceShiftRepository(super.database, {required this.existingShift});

  final Shift existingShift;
  int _openShiftReads = 0;

  @override
  Future<Shift?> getOpenShift() async {
    _openShiftReads += 1;
    if (_openShiftReads == 1) {
      return null;
    }
    return existingShift;
  }

  @override
  Future<Shift> openShift(int userId) async {
    throw ShiftAlreadyOpenException();
  }
}
