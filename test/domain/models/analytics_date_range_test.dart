import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsDateRange', () {
    test('resolves today using [start, end) civil-day boundaries', () {
      final AnalyticsDateRange range = AnalyticsDateRange.resolvePreset(
        preset: AnalyticsDateRangePreset.today,
        now: DateTime(2026, 4, 10, 18, 45),
      );

      expect(range.startInclusive, DateTime(2026, 4, 10));
      expect(range.endExclusive, DateTime(2026, 4, 11));
      expect(range.isExplicit, isFalse);
    });

    test('resolves this week using monday-start civil boundaries', () {
      final AnalyticsDateRange range = AnalyticsDateRange.resolvePreset(
        preset: AnalyticsDateRangePreset.thisWeek,
        now: DateTime(2026, 4, 10, 18, 45),
      );

      expect(range.startInclusive, DateTime(2026, 4, 6));
      expect(range.endExclusive, DateTime(2026, 4, 11));
    });

    test('resolves last week as the previous full monday-sunday window', () {
      final AnalyticsDateRange range = AnalyticsDateRange.resolvePreset(
        preset: AnalyticsDateRangePreset.lastWeek,
        now: DateTime(2026, 4, 10, 18, 45),
      );

      expect(range.startInclusive, DateTime(2026, 3, 30));
      expect(range.endExclusive, DateTime(2026, 4, 6));
    });

    test('resolves last 2 weeks as a rolling 14-day window', () {
      final AnalyticsDateRange range = AnalyticsDateRange.resolvePreset(
        preset: AnalyticsDateRangePreset.last2Weeks,
        now: DateTime(2026, 4, 10, 18, 45),
      );

      expect(range.startInclusive, DateTime(2026, 3, 28));
      expect(range.endExclusive, DateTime(2026, 4, 11));
    });
  });
}
