import 'package:epos_app/data/repositories/saved_analytics_view_store.dart';
import 'package:epos_app/domain/models/analytics/analytics_period.dart';
import 'package:epos_app/domain/models/analytics/saved_analytics_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SavedAnalyticsViewStore', () {
    test('save, read, and delete keep state deterministic', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SavedAnalyticsViewStore store = SavedAnalyticsViewStore(prefs);

      final SavedAnalyticsView view = SavedAnalyticsView.create(
        id: 'view-1',
        name: 'Monthly Overview',
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisMonth,
        ),
        comparisonMode: AnalyticsComparisonMode.previousEquivalentPeriod,
        createdAt: DateTime.utc(2026, 4, 1, 10),
      );

      await store.save(view);
      final List<SavedAnalyticsView> saved = await store.readAll();
      expect(saved, hasLength(1));
      expect(saved.first.name, 'Monthly Overview');
      expect(saved.first.periodSelection.label, 'This Month');

      await store.delete('view-1');
      expect(await store.readAll(), isEmpty);
    });

    test('malformed stored payload falls back safely', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'admin_saved_analytics_views_v1': '{"broken":true}',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SavedAnalyticsViewStore store = SavedAnalyticsViewStore(prefs);

      expect(await store.readAll(), isEmpty);
    });
  });
}
