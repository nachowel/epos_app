import 'package:drift/drift.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/user_repository.dart';
import 'package:epos_app/data/database/app_database.dart'
    show TransactionLinesCompanion;
import 'package:epos_app/domain/models/business_identity_settings.dart';
import 'package:epos_app/domain/models/cashier_projected_category_line.dart';
import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/cashier_report_projection_service.dart';
import 'package:epos_app/domain/services/cashier_report_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('CashierReportService', () {
    test(
      'returns cashier projected report only with projected category totals',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(
          db,
          openedBy: cashierId,
          cashierPreviewedBy: cashierId,
          cashierPreviewedAt: DateTime(2026, 3, 28, 18, 0),
        );
        final int categoryId = await insertCategory(db, name: 'Food');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Toastie',
          priceMinor: 1000,
        );
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'cashier-projected-report',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 1000,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await db
            .into(db.transactionLines)
            .insert(
              TransactionLinesCompanion.insert(
                uuid: 'cashier-projected-line',
                transactionId: paidOrderId,
                productId: productId,
                productName: 'Toastie',
                unitPriceMinor: 1000,
                quantity: const Value<int>(1),
                lineTotalMinor: 1000,
              ),
            );
        await insertPayment(
          db,
          uuid: 'cashier-projected-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1000,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );

        final SettingsRepository settingsRepository = SettingsRepository(db);
        await settingsRepository.updateVisibilityRatio(0.5, userId: cashierId);
        await settingsRepository.updateBusinessIdentitySettings(
          const BusinessIdentitySettings(
            businessName: 'Cafe Rialto',
            businessAddress: '123 Market Street',
          ),
          userId: cashierId,
        );
        final UserRepository userRepository = UserRepository(db);
        final DateTime generatedAt = DateTime(2026, 3, 28, 18, 15);
        final CashierReportService service = CashierReportService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          reportService: _makeReportService(db),
          settingsRepository: settingsRepository,
          projectionService: const CashierReportProjectionService(),
          userRepository: userRepository,
          clock: () => generatedAt,
        );

        final User user = (await userRepository.getById(cashierId))!;
        final projected = await service.getReport(user: user);

        expect(projected, isNot(isA<ShiftReport>()));
        expect(projected.hasOpenShift, isTrue);
        expect(projected.shiftId, shiftId);
        expect(projected.previewTaken, isTrue);
        expect(projected.previewTakenByUserName, 'Cashier');
        expect(projected.generatedAt, generatedAt);
        expect(projected.operatorName, 'Cashier');
        expect(projected.businessName, 'Cafe Rialto');
        expect(projected.businessAddress, '123 Market Street');
        expect(projected.visibleTotalMinor, 500);
        expect(projected.visibleGrossCashMinor, 500);
        expect(projected.visibleCashMinor, 500);
        expect(projected.visibleCardMinor, 0);
        expect(projected.visibleOpenOrdersTotalMinor, 0);
        expect(
          projected.categoryBreakdown,
          const <CashierProjectedCategoryLine>[
            CashierProjectedCategoryLine(
              categoryName: 'Food',
              visibleAmountMinor: 500,
            ),
          ],
        );
      },
    );

    test('admin is rejected from cashier projected report service', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final UserRepository userRepository = UserRepository(db);
      final CashierReportService service = CashierReportService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        reportService: _makeReportService(db),
        settingsRepository: SettingsRepository(db),
        projectionService: const CashierReportProjectionService(),
        userRepository: userRepository,
      );

      final User user = (await userRepository.getById(adminId))!;

      await expectLater(
        service.getReport(user: user),
        throwsA(isA<UnauthorisedException>()),
      );
    });
  });
}

ReportService _makeReportService(db) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  return ReportService(
    shiftRepository: shiftRepository,
    shiftSessionService: ShiftSessionService(shiftRepository),
    transactionRepository: TransactionRepository(db),
    paymentRepository: PaymentRepository(db),
    settingsRepository: SettingsRepository(db),
    reportVisibilityService: const ReportVisibilityService(),
  );
}
