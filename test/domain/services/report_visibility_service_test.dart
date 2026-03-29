import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportVisibilityService', () {
    const service = ReportVisibilityService();
    final admin = User(
      id: 1,
      name: 'Admin',
      pin: null,
      password: null,
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026),
    );
    final cashier = User(
      id: 2,
      name: 'Cashier',
      pin: null,
      password: null,
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime(2026),
    );
    const raw = ShiftReport(
      shiftId: 10,
      paidCount: 3,
      paidTotalMinor: 1250,
      openCount: 2,
      openTotalMinor: 101,
      cancelledCount: 1,
      cashCount: 1,
      cashTotalMinor: 500,
      cardCount: 2,
      cardTotalMinor: 750,
    );

    test('admin receives raw report unchanged', () {
      expect(service.applyVisibilityToReport(raw, admin, 0.2), raw);
    });

    test(
      'cashier ratio 0.2 masks only amount fields and keeps counts intact',
      () {
        final visible = service.applyVisibilityToReport(raw, cashier, 0.2);

        expect(visible.paidCount, raw.paidCount);
        expect(visible.openCount, raw.openCount);
        expect(visible.cancelledCount, raw.cancelledCount);
        expect(visible.cashCount, raw.cashCount);
        expect(visible.cardCount, raw.cardCount);
        expect(visible.paidTotalMinor, 250);
        expect(visible.openTotalMinor, 20);
        expect(visible.cashTotalMinor, 100);
        expect(visible.cardTotalMinor, 150);
        expect(
          visible.cashTotalMinor + visible.cardTotalMinor,
          visible.paidTotalMinor,
        );
      },
    );

    test(
      'ratio edge cases are deterministic for 1.0, 0.0, 0.2 and tiny amounts',
      () {
        expect(service.applyVisibilityRatio(1250, 1.0), 1250);
        expect(service.applyVisibilityRatio(1250, 0.0), 0);
        expect(service.applyVisibilityRatio(1250, 0.2), 250);
        expect(service.applyVisibilityRatio(1, 0.2), 0);
        expect(service.applyVisibilityRatio(5, 0.2), 1);
      },
    );

    test(
      'card total receives deterministic remainder so breakdown matches total',
      () {
        const uneven = ShiftReport(
          shiftId: 11,
          paidCount: 2,
          paidTotalMinor: 3,
          openCount: 0,
          openTotalMinor: 0,
          cancelledCount: 0,
          cashCount: 1,
          cashTotalMinor: 1,
          cardCount: 1,
          cardTotalMinor: 2,
        );

        final visible = service.applyVisibilityToReport(uneven, cashier, 0.5);

        expect(visible.paidTotalMinor, 2);
        expect(visible.cashTotalMinor, 1);
        expect(visible.cardTotalMinor, 1);
        expect(
          visible.cashTotalMinor + visible.cardTotalMinor,
          visible.paidTotalMinor,
        );
      },
    );
  });
}
