import 'package:epos_app/data/repositories/auth_lockout_store.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/domain/models/analytics/analytics_export.dart';
import 'package:epos_app/domain/models/analytics/analytics_period.dart';
import 'package:epos_app/domain/models/analytics/analytics_snapshot.dart';
import 'package:epos_app/domain/models/analytics/insight.dart';
import 'package:epos_app/domain/models/analytics/saved_analytics_view.dart';
import 'package:epos_app/domain/models/daily_revenue_point.dart';
import 'package:epos_app/domain/models/hourly_distribution.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/revenue_comparison.dart';
import 'package:epos_app/domain/models/revenue_insights.dart';
import 'package:epos_app/domain/models/revenue_intelligence_inputs.dart';
import 'package:epos_app/domain/models/revenue_summary.dart';
import 'package:epos_app/domain/models/semantic_sales_analytics.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/models/weekly_revenue_point.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/admin_revenue_analytics_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/admin/admin_revenue_analytics_screen.dart';
import 'package:epos_app/presentation/screens/admin/widgets/admin_revenue_analytics_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AdminRevenueAnalyticsScreen', () {
    testWidgets('renders loading skeleton while analytics are loading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: const AdminRevenueAnalyticsState(
            summary: null,
            isLoading: true,
            errorMessage: null,
            periodSelection: AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisWeek,
            ),
            savedViews: <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(adminAnalyticsLoadingKey), findsOneWidget);
    });

    testWidgets('renders error state with retry action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: const AdminRevenueAnalyticsState(
            summary: null,
            isLoading: false,
            errorMessage: 'Owner analytics request failed.',
            periodSelection: AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisWeek,
            ),
            savedViews: <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(adminAnalyticsErrorKey), findsOneWidget);
      expect(find.text('Yeniden Dene'), findsOneWidget);
    });

    testWidgets(
      'renders simplified dashboard with data notes and limited insights',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          await _buildApp(
            analyticsState: AdminRevenueAnalyticsState(
              summary: _sampleSummary(),
              isLoading: false,
              errorMessage: null,
              periodSelection: const AnalyticsPeriodSelection.preset(
                AnalyticsPresetPeriod.thisWeek,
              ),
              savedViews: const <SavedAnalyticsView>[],
              selectedSavedViewId: null,
              lastExport: null,
              isPrintViewOpen: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(adminAnalyticsDashboardKey), findsOneWidget);
        expect(find.text('Ciro Paneli'), findsOneWidget);
        expect(find.text('Toplam Ciro'), findsOneWidget);
        expect(find.text('Son 14 Gün Trendi'), findsOneWidget);
        expect(find.text('Öne Çıkan İçgörüler'), findsOneWidget);
        expect(find.text('Veri Notları'), findsOneWidget);
        expect(find.byKey(adminAnalyticsSecondaryInsightsKey), findsOneWidget);
        expect(find.text('Öne Çıkan Ürün'), findsNothing);
        expect(find.text('Legacy summary should stay hidden'), findsNothing);
        expect(find.text('Detay Odağı'), findsNothing);
        expect(find.text('Today'), findsNothing);
        expect(find.text('Comparison'), findsNothing);
        expect(find.text('Payment Mix'), findsNothing);
        expect(find.textContaining('Oluşturulma:'), findsOneWidget);
        expect(
          find.text('İade verileri uzaktan analiz sistemine dahil değildir.'),
          findsNothing,
        );
      },
    );

    testWidgets('renders semantic analytics insight section for admins', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AdminRevenueAnalyticsState(
            summary: _sampleSummary(
              semanticSalesAnalytics: _sampleSemanticSalesAnalytics(),
            ),
            isLoading: false,
            errorMessage: null,
            periodSelection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisWeek,
            ),
            savedViews: const <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(adminAnalyticsSemanticSectionKey), findsOneWidget);
      expect(find.text('Menü Davranışı'), findsOneWidget);
      expect(find.text('Ürün Performansı'), findsOneWidget);
      expect(find.text('Seçim Dağılımı'), findsOneWidget);
      expect(find.text('Ek Gelir'), findsOneWidget);
      expect(find.text('Öne Çıkan Varyantlar'), findsOneWidget);
      expect(find.textContaining('Set 5 Breakfast'), findsOneWidget);
      expect(find.textContaining('Drink Choice: Tea'), findsOneWidget);
      expect(find.textContaining('Hash Brown eklendi'), findsOneWidget);
    });

    testWidgets(
      'hides semantic section cleanly when no semantic analytics exist',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          await _buildApp(
            analyticsState: AdminRevenueAnalyticsState(
              summary: _sampleSummary(),
              isLoading: false,
              errorMessage: null,
              periodSelection: const AnalyticsPeriodSelection.preset(
                AnalyticsPresetPeriod.thisWeek,
              ),
              savedViews: const <SavedAnalyticsView>[],
              selectedSavedViewId: null,
              lastExport: null,
              isPrintViewOpen: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(adminAnalyticsSemanticSectionKey), findsNothing);
        expect(find.text('Menü Davranışı'), findsNothing);
      },
    );

    testWidgets(
      'renders localized fallback labels and historical semantic notes',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          await _buildApp(
            analyticsState: AdminRevenueAnalyticsState(
              summary: _sampleSummary(
                semanticSalesAnalytics: _sampleFallbackSemanticSalesAnalytics(),
              ),
              isLoading: false,
              errorMessage: null,
              periodSelection: const AnalyticsPeriodSelection.preset(
                AnalyticsPresetPeriod.thisWeek,
              ),
              savedViews: const <SavedAnalyticsView>[],
              selectedSavedViewId: null,
              lastExport: null,
              isPrintViewOpen: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Arşiv grup #501: Ürün #31'),
          findsOneWidget,
        );
        expect(find.textContaining('Ürün #45 çıkarıldı'), findsOneWidget);
        expect(
          find.textContaining('arşivlenmiş grup kimliğiyle gösteriliyor'),
          findsOneWidget,
        );
      },
    );

    testWidgets('period control reloads provider and printable summary opens', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late _FakeAdminRevenueAnalyticsNotifier notifier;
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AdminRevenueAnalyticsState(
            summary: _sampleSummary(),
            isLoading: false,
            errorMessage: null,
            periodSelection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisWeek,
            ),
            savedViews: const <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
          onNotifierCreated: (_FakeAdminRevenueAnalyticsNotifier value) {
            notifier = value;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Bu Ay'));
      await tester.pumpAndSettle();
      expect(
        notifier.requestedSelections.last,
        const AnalyticsPeriodSelection.preset(AnalyticsPresetPeriod.thisMonth),
      );

      await tester.tap(find.text('İşlemler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yazdırma Görünümü'));
      await tester.pumpAndSettle();
      expect(find.text('EPOS Analiz Raporu'), findsOneWidget);
    });

    testWidgets('deep link restores period and comparison mode from route', (
      WidgetTester tester,
    ) async {
      late _FakeAdminRevenueAnalyticsNotifier notifier;

      await tester.pumpWidget(
        await _buildRouterApp(
          analyticsState: AdminRevenueAnalyticsState(
            summary: _sampleSummary(
              selection: const AnalyticsPeriodSelection.preset(
                AnalyticsPresetPeriod.thisMonth,
              ),
            ),
            isLoading: false,
            errorMessage: null,
            periodSelection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisMonth,
            ),
            savedViews: const <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
          initialLocation: '/admin/analytics?p=this_month&mode=previous',
          onNotifierCreated: (_FakeAdminRevenueAnalyticsNotifier value) {
            notifier = value;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        notifier.requestedSelections,
        contains(
          const AnalyticsPeriodSelection.preset(
            AnalyticsPresetPeriod.thisMonth,
          ),
        ),
      );
      expect(find.text('Ciro Paneli'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Bu Ay'), findsOneWidget);
    });

    testWidgets('saved view can be created and deleted from the dashboard', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late _FakeAdminRevenueAnalyticsNotifier notifier;
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AdminRevenueAnalyticsState(
            summary: _sampleSummary(),
            isLoading: false,
            errorMessage: null,
            periodSelection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisWeek,
            ),
            savedViews: const <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
          onNotifierCreated: (_FakeAdminRevenueAnalyticsNotifier value) {
            notifier = value;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('İşlemler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Görünümü Kaydet'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Weekly Focus');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(notifier.state.savedViews, hasLength(1));
      expect(notifier.state.savedViews.first.name, 'Weekly Focus');

      await tester.tap(find.text('İşlemler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kayıtlı Görünümler (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Focus'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(notifier.state.savedViews, isEmpty);
    });

    test('builds shareable snapshot text without raw debug output', () {
      final String text = buildAdminAnalyticsSnapshotText(
        summary: _sampleSummary(
          selection: const AnalyticsPeriodSelection.preset(
            AnalyticsPresetPeriod.thisMonth,
          ),
        ),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisMonth,
        ),
        comparisonMode: AnalyticsComparisonMode.momentumView,
        selectedInsight: const Insight(
          code: 'top_product_current_period',
          severity: InsightSeverity.info,
          title: 'Top Product Mover',
          message: 'Top current product is Flat White, replacing Cappuccino.',
          evidence: <String, dynamic>{'current_product_name': 'Flat White'},
        ),
      );

      expect(text, contains('EPOS Analiz Özeti'));
      expect(text, contains('Bu Ay (1 → Bugün)'));
      expect(text, contains('Karşılaştırma: İvme'));
      expect(text, contains('Trend: Son 14 Gün'));
      expect(text, contains('Öne Çıkan İçgörü: Öne Çıkan Ürün'));
      expect(
        text,
        contains(
          'Veri Notu: Ürün hareketleri, kararlı ürün kimlikleri eksik olduğu için ad bazlı gruplanmıştır.',
        ),
      );
      expect(text, isNot(contains('current_product_name')));
    });

    test('payment mix becomes unavailable instead of 0% / 0%', () {
      final AnalyticsSnapshot snapshot = buildAdminAnalyticsSnapshot(
        summary: _sampleSummaryWithUnavailablePaymentMix(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );

      final AnalyticsSnapshotKpi paymentMix = snapshot.kpis.firstWhere(
        (AnalyticsSnapshotKpi kpi) => kpi.title == 'Ödeme Dağılımı',
      );

      expect(paymentMix.value, 'Ödeme dağılımı mevcut değil');
      expect(
        paymentMix.supportingLabel,
        contains('ödeme dağılımı verisi dönmedi'),
      );
      expect(paymentMix.value, isNot(contains('0% cash / 0% card')));
    });

    testWidgets(
      'custom range uses absolute primary message and selected range trend',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          await _buildApp(
            analyticsState: AdminRevenueAnalyticsState(
              summary: _sampleCustomSummary(),
              isLoading: false,
              errorMessage: null,
              periodSelection: AnalyticsPeriodSelection.custom(
                start: DateTime.utc(2026, 3, 1),
                end: DateTime.utc(2026, 4, 1),
              ),
              savedViews: const <SavedAnalyticsView>[],
              selectedSavedViewId: null,
              lastExport: null,
              isPrintViewOpen: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Özel Aralık: 1 Mar 2026 - 1 Nis 2026'),
          findsOneWidget,
        );
        expect(find.text('Seçili Aralık Trendi'), findsOneWidget);
        expect(
          find.text(
            'Seçili dönemde 23 tamamlanmış siparişten £468.00 ciro elde edildi.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Önceki eşdeğer dönemde ödenmiş ciro bulunmuyor.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('payment mix shows amount and share when breakdown exists', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AdminRevenueAnalyticsState(
            summary: _sampleSummary(),
            isLoading: false,
            errorMessage: null,
            periodSelection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisWeek,
            ),
            savedViews: const <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nakit'), findsOneWidget);
      expect(find.text('Kart'), findsOneWidget);
      expect(find.text('£4,720.00 · %37.9'), findsOneWidget);
      expect(find.text('£7,730.00 · %62.1'), findsOneWidget);
      expect(find.text('%18.3 artış · geçen haftaya göre'), findsOneWidget);
      expect(
        find.textContaining('geçen haftaya göre · geçen haftaya göre'),
        findsNothing,
      );
    });

    test('builds share link with current state only', () {
      final String link = buildAdminAnalyticsShareLink(
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisMonth,
        ),
        comparisonMode: AnalyticsComparisonMode.previousEquivalentPeriod,
        selectedInsightCode: 'period_revenue_delta',
        selectedTrendDate: DateTime.utc(2026, 3, 31),
        selectedDaypart: 'lunch',
        selectedMoverId: 'current::flat-white',
      );

      expect(
        link,
        '/admin/analytics?p=this_month&mode=previous&insight=period_revenue_delta&trend=2026-03-31&daypart=lunch&mover=current%3A%3Aflat-white',
      );
    });

    test('builds structured export for print and text surfaces', () {
      final AnalyticsExport export = buildAdminAnalyticsExport(
        summary: _sampleSummary(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );

      expect(export.title, 'EPOS Analiz Raporu');
      expect(export.periodLabel, 'Bu Hafta (Pzt → Bugün)');
      expect(export.kpis, contains('Toplam Ciro'));
      expect(export.highlights, isNotEmpty);
      expect(export.notes, isNotEmpty);
    });

    test('snapshot keeps only high-signal insights up to three items', () {
      final AnalyticsSnapshot snapshot = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );

      expect(snapshot.insights.length, lessThanOrEqualTo(3));
      expect(
        snapshot.insights.any(
          (Insight insight) => insight.title == 'Top Product Mover',
        ),
        isFalse,
      );
    });

    test('kpi comparison labels use preset-specific reference copy', () {
      AnalyticsSnapshot snapshot = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(
          selection: const AnalyticsPeriodSelection.preset(
            AnalyticsPresetPeriod.today,
          ),
        ),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.today,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      expect(snapshot.kpis.first.supportingLabel, '%18.3 artış · düne göre');

      snapshot = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(
          selection: const AnalyticsPeriodSelection.preset(
            AnalyticsPresetPeriod.thisWeek,
          ),
        ),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      expect(
        snapshot.kpis.first.supportingLabel,
        '%18.3 artış · geçen haftaya göre',
      );

      snapshot = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(
          selection: const AnalyticsPeriodSelection.preset(
            AnalyticsPresetPeriod.thisMonth,
          ),
        ),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisMonth,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      expect(
        snapshot.kpis.first.supportingLabel,
        '%18.3 artış · geçen aya göre',
      );

      snapshot = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(
          selection: AnalyticsPeriodSelection.custom(
            start: DateTime.utc(2026, 3, 1),
            end: DateTime.utc(2026, 3, 31),
          ),
        ),
        periodSelection: AnalyticsPeriodSelection.custom(
          start: DateTime.utc(2026, 3, 1),
          end: DateTime.utc(2026, 3, 31),
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      expect(
        snapshot.kpis.first.supportingLabel,
        '%18.3 artış · önceki eşdeğer döneme göre',
      );
    });

    test('kpi comparison labels harden no-baseline and flat states', () {
      final AnalyticsSnapshot noBaselineSnapshot = buildAdminAnalyticsSnapshot(
        summary: _copySummary(
          _sampleSummary(),
          selectedPeriodSummary: _copySelectedPeriodSummary(
            _sampleSummary().selectedPeriodSummary,
            revenue: const RevenueComparison(
              currentValue: 0,
              previousValue: 0,
              metricFormat: RevenueMetricFormat.currencyMinor,
            ),
          ),
        ),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      expect(
        noBaselineSnapshot.kpis.first.supportingLabel,
        'Karşılaştırma verisi yok',
      );

      final AnalyticsSnapshot flatSnapshot = buildAdminAnalyticsSnapshot(
        summary: _copySummary(
          _sampleSummary(
            selection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisMonth,
            ),
          ),
          selectedPeriodSummary: _copySelectedPeriodSummary(
            _sampleSummary(
              selection: const AnalyticsPeriodSelection.preset(
                AnalyticsPresetPeriod.thisMonth,
              ),
            ).selectedPeriodSummary,
            revenue: const RevenueComparison(
              currentValue: 1000,
              previousValue: 1000,
              metricFormat: RevenueMetricFormat.currencyMinor,
            ),
          ),
        ),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisMonth,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      expect(
        flatSnapshot.kpis.first.supportingLabel,
        'Değişim yok · geçen aya göre',
      );
      expect(
        flatSnapshot.kpis.first.supportingLabel,
        isNot(contains('geçen aya göre · geçen aya göre')),
      );
    });

    testWidgets(
      'zero baseline and zero current use honest zero-state message',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          await _buildApp(
            analyticsState: AdminRevenueAnalyticsState(
              summary: _sampleZeroRevenueNoBaselineSummary(),
              isLoading: false,
              errorMessage: null,
              periodSelection: const AnalyticsPeriodSelection.preset(
                AnalyticsPresetPeriod.thisWeek,
              ),
              savedViews: const <SavedAnalyticsView>[],
              selectedSavedViewId: null,
              lastExport: null,
              isPrintViewOpen: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Seçili dönemde tamamlanmış sipariş bulunmuyor.'),
          findsOneWidget,
        );
        expect(
          find.text('Önceki eşdeğer dönemde de ödenmiş ciro bulunmuyor.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('zero current with previous revenue keeps drop context honest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AdminRevenueAnalyticsState(
            summary: _sampleDroppedToZeroSummary(),
            isLoading: false,
            errorMessage: null,
            periodSelection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisWeek,
            ),
            savedViews: const <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Seçili dönemde ödenmiş ciro oluşmadı.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Önceki eşdeğer dönemde £620.00 ciro ve 14 tamamlanmış sipariş vardı.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Flat'), findsNothing);
    });

    test(
      'payment mix missing stays unavailable while inconsistent becomes incomplete',
      () {
        AnalyticsSnapshot snapshot = buildAdminAnalyticsSnapshot(
          summary: _sampleSummaryWithUnavailablePaymentMix(),
          periodSelection: const AnalyticsPeriodSelection.preset(
            AnalyticsPresetPeriod.thisWeek,
          ),
          comparisonMode: AnalyticsComparisonMode.baselineSummary,
          selectedInsight: null,
        );
        expect(
          snapshot.kpis
              .firstWhere((kpi) => kpi.title == 'Ödeme Dağılımı')
              .value,
          'Ödeme dağılımı mevcut değil',
        );

        snapshot = buildAdminAnalyticsSnapshot(
          summary: _sampleSummaryWithInconsistentPaymentMix(),
          periodSelection: const AnalyticsPeriodSelection.preset(
            AnalyticsPresetPeriod.thisWeek,
          ),
          comparisonMode: AnalyticsComparisonMode.baselineSummary,
          selectedInsight: null,
        );
        expect(
          snapshot.kpis
              .firstWhere((kpi) => kpi.title == 'Ödeme Dağılımı')
              .value,
          'Ödeme dağılımı eksik',
        );
      },
    );

    test('payment mix handles cash-only and card-only states', () {
      AnalyticsSnapshot snapshot = buildAdminAnalyticsSnapshot(
        summary: _sampleSummaryWithCashOnlyMix(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      expect(
        snapshot.kpis.firstWhere((kpi) => kpi.title == 'Ödeme Dağılımı').value,
        '£12,450.00 · %100 | £0.00 · %0',
      );

      snapshot = buildAdminAnalyticsSnapshot(
        summary: _sampleSummaryWithCardOnlyMix(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      expect(
        snapshot.kpis.firstWhere((kpi) => kpi.title == 'Ödeme Dağılımı').value,
        '£0.00 · %0 | £12,450.00 · %100',
      );
    });

    testWidgets(
      'selected day chip is absent until a valid trend selection exists',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          await _buildApp(
            analyticsState: AdminRevenueAnalyticsState(
              summary: _sampleSummary(),
              isLoading: false,
              errorMessage: null,
              periodSelection: const AnalyticsPeriodSelection.preset(
                AnalyticsPresetPeriod.thisWeek,
              ),
              savedViews: const <SavedAnalyticsView>[],
              selectedSavedViewId: null,
              lastExport: null,
              isPrintViewOpen: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Seçili Gün:'), findsNothing);
        expect(find.textContaining('null'), findsNothing);
        expect(find.textContaining('NaN'), findsNothing);
      },
    );

    testWidgets('data notes panel caps visible notes at three items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AdminRevenueAnalyticsState(
            summary: _sampleSummaryWithManyNotes(),
            isLoading: false,
            errorMessage: null,
            periodSelection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisWeek,
            ),
            savedViews: const <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('• note one'), findsOneWidget);
      expect(find.text('• note two'), findsOneWidget);
      expect(find.text('• note three'), findsOneWidget);
      expect(find.text('• note four'), findsNothing);
    });

    testWidgets('veri notlari urun diliyle Turkce gorunur', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AdminRevenueAnalyticsState(
            summary: _sampleCustomSummary(),
            isLoading: false,
            errorMessage: null,
            periodSelection: AnalyticsPeriodSelection.custom(
              start: DateTime.utc(2026, 3, 1),
              end: DateTime.utc(2026, 4, 1),
            ),
            savedViews: const <SavedAnalyticsView>[],
            selectedSavedViewId: null,
            lastExport: null,
            isPrintViewOpen: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Veri Notları'), findsOneWidget);
      expect(
        find.textContaining(
          'İade verileri uzaktan analiz sistemine dahil değildir.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('refunds not available in remote analytics'),
        findsNothing,
      );
    });

    test('same input keeps stable insight ordering', () {
      final List<String> first = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      ).insights.map((Insight insight) => insight.code).toList(growable: false);

      final List<String> second = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      ).insights.map((Insight insight) => insight.code).toList(growable: false);

      expect(second, first);
    });

    test('focused insight selection stays stable for same input', () {
      final AnalyticsSnapshot first = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );
      final AnalyticsSnapshot second = buildAdminAnalyticsSnapshot(
        summary: _sampleSummary(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        comparisonMode: AnalyticsComparisonMode.baselineSummary,
        selectedInsight: null,
      );

      expect(second.insights.first.code, first.insights.first.code);
      expect(second.insights.first.title, first.insights.first.title);
    });
  });
}

Future<Widget> _buildApp({
  required AdminRevenueAnalyticsState analyticsState,
  void Function(_FakeAdminRevenueAnalyticsNotifier notifier)? onNotifierCreated,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: <Override>[
      authNotifierProvider.overrideWith(
        (Ref ref) => _FakeAuthNotifier(ref, prefs),
      ),
      shiftNotifierProvider.overrideWith((Ref ref) => _FakeShiftNotifier(ref)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      adminRevenueAnalyticsNotifierProvider.overrideWith((Ref ref) {
        final _FakeAdminRevenueAnalyticsNotifier notifier =
            _FakeAdminRevenueAnalyticsNotifier(ref, analyticsState);
        onNotifierCreated?.call(notifier);
        return notifier;
      }),
    ],
    child: MaterialApp(
      home: const AdminRevenueAnalyticsScreen(
        initialPeriodSelection: AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisWeek,
        ),
        initialComparisonMode: AnalyticsComparisonMode.baselineSummary,
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

Future<Widget> _buildRouterApp({
  required AdminRevenueAnalyticsState analyticsState,
  required String initialLocation,
  void Function(_FakeAdminRevenueAnalyticsNotifier notifier)? onNotifierCreated,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/analytics',
        builder: (_, GoRouterState state) => AdminRevenueAnalyticsScreen(
          initialPeriodSelection: AnalyticsPeriodSelection.fromQueryParameters(
            state.uri.queryParameters,
          ),
          initialComparisonMode: analyticsComparisonModeFromQuery(
            state.uri.queryParameters['mode'],
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: <Override>[
      authNotifierProvider.overrideWith(
        (Ref ref) => _FakeAuthNotifier(ref, prefs),
      ),
      shiftNotifierProvider.overrideWith((Ref ref) => _FakeShiftNotifier(ref)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      adminRevenueAnalyticsNotifierProvider.overrideWith((Ref ref) {
        final _FakeAdminRevenueAnalyticsNotifier notifier =
            _FakeAdminRevenueAnalyticsNotifier(ref, analyticsState);
        onNotifierCreated?.call(notifier);
        return notifier;
      }),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(Ref ref, SharedPreferences prefs)
    : super(ref, AuthLockoutStore(prefs)) {
    state = AuthState(
      currentUser: User(
        id: 1,
        name: 'Admin',
        pin: '1234',
        password: null,
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      ),
      isLoading: false,
      errorMessage: null,
      failedAttempts: 0,
      lockedUntil: null,
    );
  }
}

class _FakeShiftNotifier extends ShiftNotifier {
  _FakeShiftNotifier(super.ref);

  @override
  Future<void> refreshOpenShift() async {
    state = const ShiftState.initial();
  }

  @override
  Future<void> loadRecentShifts() async {
    state = const ShiftState.initial();
  }
}

class _FakeAdminRevenueAnalyticsNotifier extends AdminRevenueAnalyticsNotifier {
  _FakeAdminRevenueAnalyticsNotifier(
    super.ref,
    AdminRevenueAnalyticsState initial,
  ) : super() {
    state = initial;
  }

  final List<AnalyticsPeriodSelection> requestedSelections =
      <AnalyticsPeriodSelection>[];

  @override
  Future<void> initialize({AnalyticsPeriodSelection? selection}) async {
    if (selection != null) {
      requestedSelections.add(selection);
      state = state.copyWith(periodSelection: selection);
    }
  }

  @override
  Future<void> load({AnalyticsPeriodSelection? selection}) async {
    if (selection != null) {
      requestedSelections.add(selection);
      state = state.copyWith(periodSelection: selection);
    }
  }

  @override
  Future<void> setPeriodSelection(AnalyticsPeriodSelection selection) async {
    requestedSelections.add(selection);
    state = state.copyWith(periodSelection: selection);
  }

  @override
  Future<void> ensurePeriodSelection(AnalyticsPeriodSelection selection) async {
    requestedSelections.add(selection);
    state = state.copyWith(periodSelection: selection);
  }

  @override
  Future<SavedAnalyticsView> saveCurrentView({
    required String name,
    required AnalyticsComparisonMode comparisonMode,
  }) async {
    final SavedAnalyticsView view = SavedAnalyticsView.create(
      id: 'view-${state.savedViews.length + 1}',
      name: name,
      periodSelection: state.periodSelection,
      comparisonMode: comparisonMode,
      createdAt: DateTime.utc(2026, 4, 1, 10),
    );
    state = state.copyWith(
      savedViews: <SavedAnalyticsView>[view, ...state.savedViews],
      selectedSavedViewId: view.id,
    );
    return view;
  }

  @override
  Future<SavedAnalyticsView?> applySavedView(String id) async {
    for (final SavedAnalyticsView view in state.savedViews) {
      if (view.id == id) {
        state = state.copyWith(
          periodSelection: view.periodSelection,
          selectedSavedViewId: id,
        );
        requestedSelections.add(view.periodSelection);
        return view;
      }
    }
    return null;
  }

  @override
  Future<void> deleteSavedView(String id) async {
    state = state.copyWith(
      savedViews: state.savedViews
          .where((SavedAnalyticsView view) => view.id != id)
          .toList(growable: false),
      selectedSavedViewId: state.selectedSavedViewId == id
          ? null
          : state.selectedSavedViewId,
    );
  }
}

RevenueSummary _sampleSummary({
  AnalyticsPeriodSelection selection = const AnalyticsPeriodSelection.preset(
    AnalyticsPresetPeriod.thisWeek,
  ),
  SemanticSalesAnalytics semanticSalesAnalytics =
      const SemanticSalesAnalytics.empty(),
}) {
  final RevenueSelectedPeriodSummary selectedPeriodSummary =
      RevenueSelectedPeriodSummary(
        selection: selection,
        startDate: DateTime(2026, 3, 24),
        endDate: DateTime(2026, 3, 31),
        comparisonStartDate: DateTime(2026, 3, 16),
        comparisonEndDate: DateTime(2026, 3, 23),
        dayCount: 8,
        revenue: const RevenueComparison(
          currentValue: 1245000,
          previousValue: 1052000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        orderCount: const RevenueComparison(
          currentValue: 68,
          previousValue: 57,
          metricFormat: RevenueMetricFormat.count,
        ),
        averageOrderValue: const RevenueComparison(
          currentValue: 1840,
          previousValue: 1690,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cancelledOrderCount: const RevenueComparison(
          currentValue: 3,
          previousValue: 5,
          metricFormat: RevenueMetricFormat.count,
        ),
        paymentMix: RevenuePaymentMixComparison(
          cashRevenue: const RevenueComparison(
            currentValue: 472000,
            previousValue: 420000,
            metricFormat: RevenueMetricFormat.currencyMinor,
          ),
          cardRevenue: const RevenueComparison(
            currentValue: 773000,
            previousValue: 632000,
            metricFormat: RevenueMetricFormat.currencyMinor,
          ),
        ),
      );

  return RevenueSummary(
    generatedAt: DateTime(2026, 4, 1, 9, 30),
    timezone: 'Europe/London',
    todayRevenue: const RevenueComparison(
      currentValue: 245000,
      previousValue: 198000,
      metricFormat: RevenueMetricFormat.currencyMinor,
    ),
    thisWeekRevenue: const RevenueComparison(
      currentValue: 1245000,
      previousValue: 1052000,
      metricFormat: RevenueMetricFormat.currencyMinor,
    ),
    thisMonthRevenue: const RevenueComparison(
      currentValue: 4860000,
      previousValue: 4520000,
      metricFormat: RevenueMetricFormat.currencyMinor,
    ),
    averageOrderValueCurrentWeek: const RevenueComparison(
      currentValue: 1840,
      previousValue: 1690,
      metricFormat: RevenueMetricFormat.currencyMinor,
    ),
    dailyTrend: <DailyRevenuePoint>[
      DailyRevenuePoint(
        date: DateTime(2026, 3, 30),
        revenueMinor: 94000,
        orderCount: 6,
      ),
      DailyRevenuePoint(
        date: DateTime(2026, 3, 31),
        revenueMinor: 110000,
        orderCount: 8,
      ),
    ],
    weeklySummary: <WeeklyRevenuePoint>[
      WeeklyRevenuePoint(
        weekStart: DateTime(2026, 3, 24),
        revenueMinor: 1052000,
        orderCount: 57,
      ),
      WeeklyRevenuePoint(
        weekStart: DateTime(2026, 3, 31),
        revenueMinor: 1245000,
        orderCount: 68,
      ),
    ],
    hourlyDistribution: List<HourlyDistribution>.generate(24, (int hour) {
      return HourlyDistribution(
        hour: hour,
        revenueMinor: hour == 13 ? 480000 : 0,
        orderCount: hour == 13 ? 12 : 0,
      );
    }),
    insights: RevenueInsights(
      weeklyPerformance: 'Legacy summary should stay hidden',
      revenueMomentum: 'Legacy summary should stay hidden',
      strongestDay: 'Legacy summary should stay hidden',
      weakestDay: 'Legacy summary should stay hidden',
      peakHours: 'Legacy summary should stay hidden',
      lowHours: 'Legacy summary should stay hidden',
      topHourConcentration: 'Legacy summary should stay hidden',
      distributionBalance: 'Legacy summary should stay hidden',
      structuredInsights: const <Insight>[
        Insight(
          code: 'period_revenue_delta',
          severity: InsightSeverity.positive,
          title: 'This Week Revenue',
          message:
              'this week is 18.4% higher than the previous equivalent period.',
          evidence: <String, dynamic>{
            'current_value': 1245000,
            'previous_value': 1052000,
            'absolute_change': 193000,
            'percentage_change': 18.4,
          },
        ),
        Insight(
          code: 'revenue_momentum_14d',
          severity: InsightSeverity.positive,
          title: '14-Day Revenue Momentum',
          message: 'Revenue has increased over the last 14 days by 22.4%.',
          evidence: <String, dynamic>{'percentage_change': 22.4},
        ),
        Insight(
          code: 'period_order_count_delta',
          severity: InsightSeverity.info,
          title: 'Order Count',
          message: 'Orders are 19.3% above the previous equivalent period.',
          evidence: <String, dynamic>{
            'current_value': 68,
            'previous_value': 57,
            'absolute_change': 11,
            'percentage_change': 19.3,
          },
        ),
        Insight(
          code: 'period_average_order_value_delta',
          severity: InsightSeverity.positive,
          title: 'Average Order Value',
          message: 'Ticket size is 8.9% higher than the previous period.',
          evidence: <String, dynamic>{
            'current_value': 1840,
            'previous_value': 1690,
            'absolute_change': 150,
            'percentage_change': 8.9,
          },
        ),
        Insight(
          code: 'peak_hours',
          severity: InsightSeverity.info,
          title: 'Peak Hour',
          message: '13:00 remains the strongest revenue hour.',
          evidence: <String, dynamic>{
            'start_hour': 13,
            'end_hour_exclusive': 14,
            'revenue_minor': 480000,
          },
        ),
        Insight(
          code: 'top_product_current_period',
          severity: InsightSeverity.info,
          title: 'Top Product Mover',
          message: 'Top current product is Flat White, replacing Cappuccino.',
          evidence: <String, dynamic>{'current_product_name': 'Flat White'},
        ),
        Insight(
          code: 'data_quality_product_movers_name_based',
          severity: InsightSeverity.warning,
          title: 'Data Quality',
          message:
              'product mover aggregation is name-based because stable mirrored product identifiers were unavailable for part of the dataset',
          evidence: <String, dynamic>{'note': 'name-based'},
        ),
      ],
    ),
    intelligenceInputs: RevenueIntelligenceInputs(
      todayOrderCount: const RevenueComparison(
        currentValue: 13,
        previousValue: 11,
        metricFormat: RevenueMetricFormat.count,
      ),
      monthOrderCount: const RevenueComparison(
        currentValue: 286,
        previousValue: 264,
        metricFormat: RevenueMetricFormat.count,
      ),
      averageOrderValueThisWeek: const RevenueComparison(
        currentValue: 1840,
        previousValue: 1690,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      averageOrderValueThisMonth: const RevenueComparison(
        currentValue: 1790,
        previousValue: 1710,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      thisWeekPaymentMix: RevenuePaymentMixComparison(
        cashRevenue: const RevenueComparison(
          currentValue: 472000,
          previousValue: 420000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: const RevenueComparison(
          currentValue: 773000,
          previousValue: 632000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
      thisMonthPaymentMix: RevenuePaymentMixComparison(
        cashRevenue: const RevenueComparison(
          currentValue: 1830000,
          previousValue: 1760000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: const RevenueComparison(
          currentValue: 3030000,
          previousValue: 2760000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
      thisWeekCancelledOrderCount: const RevenueComparison(
        currentValue: 3,
        previousValue: 5,
        metricFormat: RevenueMetricFormat.count,
      ),
      thisMonthCancelledOrderCount: const RevenueComparison(
        currentValue: 16,
        previousValue: 18,
        metricFormat: RevenueMetricFormat.count,
      ),
      daypartDistribution: <RevenueDaypartPoint>[
        RevenueDaypartPoint(
          daypart: 'breakfast',
          orderCount: 9,
          revenueMinor: 128000,
        ),
        RevenueDaypartPoint(
          daypart: 'lunch',
          orderCount: 22,
          revenueMinor: 392000,
        ),
      ],
      topProductsCurrentPeriod: const <RevenueProductMover>[
        RevenueProductMover(
          productKey: 'flat-white',
          productName: 'Flat White',
          quantitySold: 34,
          revenueMinor: 149600,
        ),
      ],
      topProductsPreviousPeriod: const <RevenueProductMover>[
        RevenueProductMover(
          productKey: 'cappuccino',
          productName: 'Cappuccino',
          quantitySold: 31,
          revenueMinor: 136400,
        ),
      ],
      dataQualityNotes: const <String>[
        'product mover aggregation is name-based because stable mirrored product identifiers were unavailable for part of the dataset',
      ],
    ),
    selectedPeriodSummary: selectedPeriodSummary,
    semanticSalesAnalytics: semanticSalesAnalytics,
  );
}

RevenueSummary _sampleSummaryWithUnavailablePaymentMix() {
  final RevenueSummary base = _sampleSummary();
  final RevenueSelectedPeriodSummary selected = base.selectedPeriodSummary;

  return RevenueSummary(
    generatedAt: base.generatedAt,
    timezone: base.timezone,
    todayRevenue: base.todayRevenue,
    thisWeekRevenue: base.thisWeekRevenue,
    thisMonthRevenue: base.thisMonthRevenue,
    averageOrderValueCurrentWeek: base.averageOrderValueCurrentWeek,
    dailyTrend: base.dailyTrend,
    weeklySummary: base.weeklySummary,
    hourlyDistribution: base.hourlyDistribution,
    insights: base.insights,
    intelligenceInputs: base.intelligenceInputs,
    selectedPeriodSummary: RevenueSelectedPeriodSummary(
      selection: selected.selection,
      startDate: selected.startDate,
      endDate: selected.endDate,
      comparisonStartDate: selected.comparisonStartDate,
      comparisonEndDate: selected.comparisonEndDate,
      dayCount: selected.dayCount,
      revenue: selected.revenue,
      orderCount: selected.orderCount,
      averageOrderValue: selected.averageOrderValue,
      cancelledOrderCount: selected.cancelledOrderCount,
      paymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 0,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 0,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
    ),
    semanticSalesAnalytics: base.semanticSalesAnalytics,
  );
}

RevenueSummary _sampleSummaryWithInconsistentPaymentMix() {
  final RevenueSummary base = _sampleSummary();
  return _copySummary(
    base,
    selectedPeriodSummary: _copySelectedPeriodSummary(
      base.selectedPeriodSummary,
      paymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 100000,
          previousValue: 420000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 120000,
          previousValue: 632000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
    ),
  );
}

RevenueSummary _sampleSummaryWithCashOnlyMix() {
  final RevenueSummary base = _sampleSummary();
  return _copySummary(
    base,
    selectedPeriodSummary: _copySelectedPeriodSummary(
      base.selectedPeriodSummary,
      paymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 1245000,
          previousValue: 420000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 0,
          previousValue: 632000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
    ),
  );
}

RevenueSummary _sampleSummaryWithCardOnlyMix() {
  final RevenueSummary base = _sampleSummary();
  return _copySummary(
    base,
    selectedPeriodSummary: _copySelectedPeriodSummary(
      base.selectedPeriodSummary,
      paymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 0,
          previousValue: 420000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 1245000,
          previousValue: 632000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
    ),
  );
}

RevenueSummary _sampleZeroRevenueNoBaselineSummary() {
  final RevenueSummary base = _sampleSummary();
  return _copySummary(
    base,
    selectedPeriodSummary: _copySelectedPeriodSummary(
      base.selectedPeriodSummary,
      revenue: const RevenueComparison(
        currentValue: 0,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      orderCount: const RevenueComparison(
        currentValue: 0,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.count,
      ),
      averageOrderValue: const RevenueComparison(
        currentValue: 0,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      paymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 0,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 0,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
    ),
  );
}

RevenueSummary _sampleDroppedToZeroSummary() {
  final RevenueSummary base = _sampleSummary();
  return _copySummary(
    base,
    selectedPeriodSummary: _copySelectedPeriodSummary(
      base.selectedPeriodSummary,
      revenue: const RevenueComparison(
        currentValue: 0,
        previousValue: 62000,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      orderCount: const RevenueComparison(
        currentValue: 0,
        previousValue: 14,
        metricFormat: RevenueMetricFormat.count,
      ),
      averageOrderValue: const RevenueComparison(
        currentValue: 0,
        previousValue: 4429,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      paymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 0,
          previousValue: 32000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 0,
          previousValue: 30000,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
    ),
  );
}

RevenueSummary _sampleSummaryWithManyNotes() {
  final RevenueSummary base = _sampleSummary();
  return _copySummary(
    base,
    intelligenceInputs: RevenueIntelligenceInputs(
      todayOrderCount: base.intelligenceInputs.todayOrderCount,
      monthOrderCount: base.intelligenceInputs.monthOrderCount,
      averageOrderValueThisWeek:
          base.intelligenceInputs.averageOrderValueThisWeek,
      averageOrderValueThisMonth:
          base.intelligenceInputs.averageOrderValueThisMonth,
      thisWeekPaymentMix: base.intelligenceInputs.thisWeekPaymentMix,
      thisMonthPaymentMix: base.intelligenceInputs.thisMonthPaymentMix,
      thisWeekCancelledOrderCount:
          base.intelligenceInputs.thisWeekCancelledOrderCount,
      thisMonthCancelledOrderCount:
          base.intelligenceInputs.thisMonthCancelledOrderCount,
      daypartDistribution: base.intelligenceInputs.daypartDistribution,
      topProductsCurrentPeriod:
          base.intelligenceInputs.topProductsCurrentPeriod,
      topProductsPreviousPeriod:
          base.intelligenceInputs.topProductsPreviousPeriod,
      dataQualityNotes: const <String>[
        'note one',
        'note two',
        'note three',
        'note four',
      ],
    ),
  );
}

RevenueSummary _copySummary(
  RevenueSummary base, {
  RevenueSelectedPeriodSummary? selectedPeriodSummary,
  RevenueInsights? insights,
  RevenueIntelligenceInputs? intelligenceInputs,
}) {
  return RevenueSummary(
    generatedAt: base.generatedAt,
    timezone: base.timezone,
    todayRevenue: base.todayRevenue,
    thisWeekRevenue: base.thisWeekRevenue,
    thisMonthRevenue: base.thisMonthRevenue,
    averageOrderValueCurrentWeek: base.averageOrderValueCurrentWeek,
    dailyTrend: base.dailyTrend,
    weeklySummary: base.weeklySummary,
    hourlyDistribution: base.hourlyDistribution,
    insights: insights ?? base.insights,
    intelligenceInputs: intelligenceInputs ?? base.intelligenceInputs,
    selectedPeriodSummary: selectedPeriodSummary ?? base.selectedPeriodSummary,
    semanticSalesAnalytics: base.semanticSalesAnalytics,
  );
}

RevenueSelectedPeriodSummary _copySelectedPeriodSummary(
  RevenueSelectedPeriodSummary base, {
  RevenueComparison? revenue,
  RevenueComparison? orderCount,
  RevenueComparison? averageOrderValue,
  RevenueComparison? cancelledOrderCount,
  RevenuePaymentMixComparison? paymentMix,
}) {
  return RevenueSelectedPeriodSummary(
    selection: base.selection,
    startDate: base.startDate,
    endDate: base.endDate,
    comparisonStartDate: base.comparisonStartDate,
    comparisonEndDate: base.comparisonEndDate,
    dayCount: base.dayCount,
    revenue: revenue ?? base.revenue,
    orderCount: orderCount ?? base.orderCount,
    averageOrderValue: averageOrderValue ?? base.averageOrderValue,
    cancelledOrderCount: cancelledOrderCount ?? base.cancelledOrderCount,
    paymentMix: paymentMix ?? base.paymentMix,
  );
}

RevenueSummary _sampleCustomSummary() {
  final AnalyticsPeriodSelection selection = AnalyticsPeriodSelection.custom(
    start: DateTime.utc(2026, 3, 1),
    end: DateTime.utc(2026, 4, 1),
  );
  return RevenueSummary(
    generatedAt: DateTime(2026, 4, 1, 20, 30),
    timezone: 'Europe/London',
    todayRevenue: const RevenueComparison(
      currentValue: 46800,
      previousValue: 0,
      metricFormat: RevenueMetricFormat.currencyMinor,
    ),
    thisWeekRevenue: const RevenueComparison(
      currentValue: 46800,
      previousValue: 0,
      metricFormat: RevenueMetricFormat.currencyMinor,
    ),
    thisMonthRevenue: const RevenueComparison(
      currentValue: 46800,
      previousValue: 0,
      metricFormat: RevenueMetricFormat.currencyMinor,
    ),
    averageOrderValueCurrentWeek: const RevenueComparison(
      currentValue: 2035,
      previousValue: 0,
      metricFormat: RevenueMetricFormat.currencyMinor,
    ),
    dailyTrend: <DailyRevenuePoint>[
      DailyRevenuePoint(
        date: DateTime(2026, 3, 30),
        revenueMinor: 14200,
        orderCount: 7,
      ),
      DailyRevenuePoint(
        date: DateTime(2026, 4, 1),
        revenueMinor: 32600,
        orderCount: 16,
      ),
    ],
    weeklySummary: <WeeklyRevenuePoint>[
      WeeklyRevenuePoint(
        weekStart: DateTime(2026, 3, 1),
        revenueMinor: 46800,
        orderCount: 23,
      ),
    ],
    hourlyDistribution: List<HourlyDistribution>.generate(24, (int hour) {
      return HourlyDistribution(
        hour: hour,
        revenueMinor: hour == 13 ? 18000 : 0,
        orderCount: hour == 13 ? 8 : 0,
      );
    }),
    insights: RevenueInsights(
      weeklyPerformance:
          'Custom Range is higher than the previous equivalent period, which had no paid revenue.',
      revenueMomentum: 'Revenue has increased over the last 14 days.',
      strongestDay: 'Strongest day is 1 Apr with £326.00.',
      weakestDay: 'Weakest day is 30 Mar with £142.00.',
      peakHours: '13:00 remains the strongest revenue hour.',
      lowHours: 'No low hour insight.',
      topHourConcentration: 'No concentration insight.',
      distributionBalance: 'No balance insight.',
      structuredInsights: const <Insight>[
        Insight(
          code: 'period_revenue_delta',
          severity: InsightSeverity.positive,
          title: 'Selected Period Revenue',
          message:
              'Custom Range is higher than the previous equivalent period, which had no paid revenue.',
          evidence: <String, dynamic>{
            'current_value': 46800,
            'previous_value': 0,
            'absolute_change': 46800,
          },
        ),
      ],
    ),
    intelligenceInputs: RevenueIntelligenceInputs(
      todayOrderCount: const RevenueComparison(
        currentValue: 23,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.count,
      ),
      monthOrderCount: const RevenueComparison(
        currentValue: 23,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.count,
      ),
      averageOrderValueThisWeek: const RevenueComparison(
        currentValue: 2035,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      averageOrderValueThisMonth: const RevenueComparison(
        currentValue: 2035,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      thisWeekPaymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 35100,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 11700,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
      thisMonthPaymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 35100,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 11700,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
      thisWeekCancelledOrderCount: const RevenueComparison(
        currentValue: 0,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.count,
      ),
      thisMonthCancelledOrderCount: const RevenueComparison(
        currentValue: 0,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.count,
      ),
      daypartDistribution: const <RevenueDaypartPoint>[],
      topProductsCurrentPeriod: const <RevenueProductMover>[],
      topProductsPreviousPeriod: const <RevenueProductMover>[],
      dataQualityNotes: const <String>[
        'refunds not available in remote analytics',
      ],
    ),
    selectedPeriodSummary: RevenueSelectedPeriodSummary(
      selection: selection,
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2026, 4, 1),
      comparisonStartDate: DateTime(2026, 1, 28),
      comparisonEndDate: DateTime(2026, 2, 28),
      dayCount: 32,
      revenue: const RevenueComparison(
        currentValue: 46800,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      orderCount: const RevenueComparison(
        currentValue: 23,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.count,
      ),
      averageOrderValue: const RevenueComparison(
        currentValue: 2035,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      cancelledOrderCount: const RevenueComparison(
        currentValue: 0,
        previousValue: 0,
        metricFormat: RevenueMetricFormat.count,
      ),
      paymentMix: const RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue: 35100,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue: 11700,
          previousValue: 0,
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
    ),
    semanticSalesAnalytics: const SemanticSalesAnalytics.empty(),
  );
}

SemanticSalesAnalytics _sampleSemanticSalesAnalytics() {
  return const SemanticSalesAnalytics(
    rootProducts: <SemanticRootProductAnalytics>[
      SemanticRootProductAnalytics(
        rootProductId: 10,
        rootProductName: 'Set 5 Breakfast',
        quantitySold: 18,
        revenueMinor: 126000,
      ),
    ],
    choiceSelections: <SemanticChoiceSelectionAnalytics>[
      SemanticChoiceSelectionAnalytics(
        rootProductId: 10,
        rootProductName: 'Set 5 Breakfast',
        groupId: 501,
        groupName: 'Drink Choice',
        itemProductId: 31,
        itemName: 'Tea',
        selectionCount: 12,
        totalSelectedQuantity: 12,
        distributionPercent: 66.7,
        trend: <SemanticAnalyticsTrendPoint>[],
      ),
    ],
    addedItems: <SemanticItemBehaviorAnalytics>[
      SemanticItemBehaviorAnalytics(
        rootProductId: 10,
        rootProductName: 'Set 5 Breakfast',
        itemProductId: 44,
        itemName: 'Hash Brown',
        occurrenceCount: 7,
        totalQuantity: 7,
        revenueMinor: 1400,
        percentageOfRootSales: 38.9,
      ),
    ],
    removedItems: <SemanticItemBehaviorAnalytics>[
      SemanticItemBehaviorAnalytics(
        rootProductId: 10,
        rootProductName: 'Set 5 Breakfast',
        itemProductId: 45,
        itemName: 'Beans',
        occurrenceCount: 9,
        totalQuantity: 9,
        revenueMinor: 0,
        percentageOfRootSales: 50,
      ),
    ],
    chargeReasonBreakdown: <SemanticChargeReasonAnalytics>[
      SemanticChargeReasonAnalytics(
        chargeReason: ModifierChargeReason.extraAdd,
        eventCount: 7,
        totalQuantity: 7,
        revenueMinor: 1400,
      ),
      SemanticChargeReasonAnalytics(
        chargeReason: ModifierChargeReason.paidSwap,
        eventCount: 2,
        totalQuantity: 2,
        revenueMinor: 300,
      ),
      SemanticChargeReasonAnalytics(
        chargeReason: ModifierChargeReason.freeSwap,
        eventCount: 5,
        totalQuantity: 5,
        revenueMinor: 0,
      ),
    ],
    bundleVariants: <SemanticBundleVariantAnalytics>[
      SemanticBundleVariantAnalytics(
        rootProductId: 10,
        rootProductName: 'Set 5 Breakfast',
        variantKey: 'variant-1',
        orderCount: 8,
        revenueMinor: 56000,
        chosenItemProductIds: <int>[31],
        chosenItemNames: <String>['Tea'],
        removedItemProductIds: <int>[45],
        removedItemNames: <String>['Beans'],
        addedItemProductIds: <int>[44],
        addedItemNames: <String>['Hash Brown'],
      ),
    ],
  );
}

SemanticSalesAnalytics _sampleFallbackSemanticSalesAnalytics() {
  return const SemanticSalesAnalytics(
    rootProducts: <SemanticRootProductAnalytics>[
      SemanticRootProductAnalytics(
        rootProductId: 10,
        rootProductName: 'Set 5 Breakfast',
        quantitySold: 4,
        revenueMinor: 28000,
      ),
    ],
    choiceSelections: <SemanticChoiceSelectionAnalytics>[
      SemanticChoiceSelectionAnalytics(
        rootProductId: 10,
        rootProductName: 'Set 5 Breakfast',
        groupId: 501,
        groupName: 'Group #501',
        itemProductId: 31,
        itemName: 'Product 31',
        selectionCount: 3,
        totalSelectedQuantity: 3,
        distributionPercent: 75,
        trend: <SemanticAnalyticsTrendPoint>[],
      ),
    ],
    removedItems: <SemanticItemBehaviorAnalytics>[
      SemanticItemBehaviorAnalytics(
        rootProductId: 10,
        rootProductName: 'Set 5 Breakfast',
        itemProductId: 45,
        itemName: 'Product 45',
        occurrenceCount: 2,
        totalQuantity: 2,
        revenueMinor: 0,
        percentageOfRootSales: 50,
      ),
    ],
    dataQualityNotes: <String>[
      'Choice-group analytics for root product 10 are using archived group 501 from persisted semantic modifiers because the current configuration no longer contains that group.',
    ],
  );
}
