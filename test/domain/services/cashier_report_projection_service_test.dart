import 'package:epos_app/domain/models/cashier_projected_category_line.dart';
import 'package:epos_app/domain/models/report_settings_policy.dart';
import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/models/shift_report_category_line.dart';
import 'package:epos_app/domain/services/cashier_report_projection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CashierReportProjectionService', () {
    const CashierReportProjectionService service =
        CashierReportProjectionService();
    const ShiftReport rawReport = ShiftReport(
      shiftId: 11,
      paidCount: 8,
      paidTotalMinor: 1000,
      refundCount: 1,
      refundTotalMinor: 100,
      netSalesMinor: 900,
      openCount: 2,
      openTotalMinor: 300,
      cancelledCount: 1,
      cashCount: 3,
      cashGrossTotalMinor: 600,
      cashTotalMinor: 540,
      cardCount: 5,
      cardGrossTotalMinor: 400,
      cardTotalMinor: 360,
      categoryBreakdown: <ShiftReportCategoryLine>[
        ShiftReportCategoryLine(categoryName: 'Food', totalMinor: 700),
        ShiftReportCategoryLine(categoryName: 'Drinks', totalMinor: 200),
      ],
    );

    test('percentage mode projection works', () {
      const ReportSettingsPolicy settings = ReportSettingsPolicy(
        cashierReportMode: CashierReportMode.percentage,
        visibilityRatio: 0.5,
        maxVisibleTotalMinor: null,
      );

      final projected = service.project(
        rawReport: rawReport,
        settings: settings,
      );

      expect(projected.visibleTotalMinor, 450);
      expect(projected.visibleNetSalesMinor, 450);
      expect(projected.visibleRefundTotalMinor, 50);
      expect(projected.visibleGrossSalesMinor, 500);
      expect(projected.visibleGrossCashMinor, 300);
      expect(projected.visibleGrossCardMinor, 200);
      expect(projected.visibleOpenOrdersTotalMinor, 150);
    });

    test('cap_amount mode projection works', () {
      const ReportSettingsPolicy settings = ReportSettingsPolicy(
        cashierReportMode: CashierReportMode.capAmount,
        visibilityRatio: 1.0,
        maxVisibleTotalMinor: 200,
      );

      final projected = service.project(
        rawReport: rawReport,
        settings: settings,
      );

      expect(projected.visibleTotalMinor, 200);
      expect(projected.visibleNetSalesMinor, 200);
      expect(
        projected.visibleTotalMinor,
        lessThanOrEqualTo(rawReport.netSalesMinor),
      );
    });

    test('cash and card totals remain consistent', () {
      const ReportSettingsPolicy settings = ReportSettingsPolicy(
        cashierReportMode: CashierReportMode.percentage,
        visibilityRatio: 0.5,
        maxVisibleTotalMinor: null,
      );

      final projected = service.project(
        rawReport: rawReport,
        settings: settings,
      );

      expect(
        projected.visibleCashMinor + projected.visibleCardMinor,
        projected.visibleTotalMinor,
      );
      expect(
        projected.visibleGrossCashMinor + projected.visibleGrossCardMinor,
        projected.visibleGrossSalesMinor,
      );
    });

    test('category totals remain consistent', () {
      const ReportSettingsPolicy settings = ReportSettingsPolicy(
        cashierReportMode: CashierReportMode.capAmount,
        visibilityRatio: 1.0,
        maxVisibleTotalMinor: 200,
      );

      final projected = service.project(
        rawReport: rawReport,
        settings: settings,
      );

      expect(
        projected.categoryBreakdown.fold<int>(
          0,
          (int sum, CashierProjectedCategoryLine line) =>
              sum + line.visibleAmountMinor,
        ),
        projected.visibleTotalMinor,
      );
    });

    test('rounding is deterministic and sums exactly', () {
      const ShiftReport uneven = ShiftReport(
        shiftId: 12,
        paidCount: 3,
        paidTotalMinor: 3,
        refundCount: 0,
        refundTotalMinor: 0,
        netSalesMinor: 3,
        openCount: 0,
        openTotalMinor: 0,
        cancelledCount: 0,
        cashCount: 1,
        cashGrossTotalMinor: 1,
        cashTotalMinor: 1,
        cardCount: 2,
        cardGrossTotalMinor: 2,
        cardTotalMinor: 2,
        categoryBreakdown: <ShiftReportCategoryLine>[
          ShiftReportCategoryLine(categoryName: 'B', totalMinor: 1),
          ShiftReportCategoryLine(categoryName: 'A', totalMinor: 2),
        ],
      );
      const ReportSettingsPolicy settings = ReportSettingsPolicy(
        cashierReportMode: CashierReportMode.percentage,
        visibilityRatio: 0.5,
        maxVisibleTotalMinor: null,
      );

      final projected = service.project(rawReport: uneven, settings: settings);

      expect(projected.visibleTotalMinor, 2);
      expect(projected.visibleCashMinor, 1);
      expect(projected.visibleCardMinor, 1);
      expect(projected.categoryBreakdown, const <CashierProjectedCategoryLine>[
        CashierProjectedCategoryLine(categoryName: 'B', visibleAmountMinor: 1),
        CashierProjectedCategoryLine(categoryName: 'A', visibleAmountMinor: 1),
      ]);
    });
  });
}
