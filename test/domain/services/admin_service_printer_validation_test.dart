import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/cash_movement_repository.dart';
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/repositories/system_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/printer_settings.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/admin_service.dart';
import 'package:epos_app/domain/services/cash_movement_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('AdminService printer validation', () {
    test('rejects invalid ethernet host', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final AdminService service = _makeAdminService(db);

      await expectLater(
        service.savePrinterSettings(
          user: _adminUser(),
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: '999.999.999.999',
          port: 9100,
          paperWidth: 80,
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            contains('valid IPv4 address or hostname'),
          ),
        ),
      );
    });

    test('rejects invalid ethernet port', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final AdminService service = _makeAdminService(db);

      await expectLater(
        service.savePrinterSettings(
          user: _adminUser(),
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: '192.168.1.100',
          port: 70000,
          paperWidth: 80,
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            contains('between 1 and 65535'),
          ),
        ),
      );
    });
  });
}

AdminService _makeAdminService(AppDatabase db) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  final TransactionRepository transactionRepository = TransactionRepository(db);
  final SettingsRepository settingsRepository = SettingsRepository(db);
  final ShiftSessionService shiftSessionService = ShiftSessionService(
    shiftRepository,
  );
  return AdminService(
    categoryRepository: CategoryRepository(db),
    productRepository: ProductRepository(db),
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
    modifierRepository: ModifierRepository(db),
    shiftRepository: shiftRepository,
    transactionRepository: transactionRepository,
    syncQueueRepository: SyncQueueRepository(db),
    settingsRepository: settingsRepository,
    systemRepository: SystemRepository(
      db,
      databaseFileResolver: () async =>
          throw UnsupportedError('No file export in this test.'),
    ),
    reportService: ReportService(
      shiftRepository: shiftRepository,
      shiftSessionService: shiftSessionService,
      transactionRepository: transactionRepository,
      paymentRepository: PaymentRepository(db),
      settingsRepository: settingsRepository,
      reportVisibilityService: const ReportVisibilityService(),
    ),
    shiftSessionService: shiftSessionService,
    cashMovementService: CashMovementService(
      cashMovementRepository: CashMovementRepository(db),
      shiftSessionService: shiftSessionService,
    ),
    printerService: PrinterService(
      transactionRepository,
      paymentRepository: PaymentRepository(db),
      settingsRepository: settingsRepository,
    ),
    appConfig: AppConfig.fromValues(environment: 'test', appVersion: 'test'),
  );
}

User _adminUser() {
  return User(
    id: 1,
    name: 'Admin',
    pin: null,
    password: null,
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.now(),
  );
}
