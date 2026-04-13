import 'analytics_date_range.dart';
import 'analytics_revenue_preset.dart';

enum AnalyticsDetailPreset { thisWeek, lastWeek, last2Weeks, thisMonth }

String analyticsDetailPresetQueryValue(AnalyticsDetailPreset preset) {
  return switch (preset) {
    AnalyticsDetailPreset.thisWeek => 'this_week',
    AnalyticsDetailPreset.lastWeek => 'last_week',
    AnalyticsDetailPreset.last2Weeks => 'last_2_weeks',
    AnalyticsDetailPreset.thisMonth => 'this_month',
  };
}

String analyticsDetailPresetLabel(AnalyticsDetailPreset preset) {
  return switch (preset) {
    AnalyticsDetailPreset.thisWeek => 'This Week',
    AnalyticsDetailPreset.lastWeek => 'Last Week',
    AnalyticsDetailPreset.last2Weeks => 'Last 2 Weeks',
    AnalyticsDetailPreset.thisMonth => 'This Month',
  };
}

AnalyticsDateRangePreset analyticsDateRangePresetFromDetailPreset(
  AnalyticsDetailPreset preset,
) {
  return switch (preset) {
    AnalyticsDetailPreset.thisWeek => AnalyticsDateRangePreset.thisWeek,
    AnalyticsDetailPreset.lastWeek => AnalyticsDateRangePreset.lastWeek,
    AnalyticsDetailPreset.last2Weeks => AnalyticsDateRangePreset.last2Weeks,
    AnalyticsDetailPreset.thisMonth => AnalyticsDateRangePreset.thisMonth,
  };
}

AnalyticsRevenuePreset analyticsRevenuePresetFromDetailPreset(
  AnalyticsDetailPreset preset,
) {
  return switch (preset) {
    AnalyticsDetailPreset.thisWeek => AnalyticsRevenuePreset.thisWeek,
    AnalyticsDetailPreset.lastWeek => AnalyticsRevenuePreset.lastWeek,
    AnalyticsDetailPreset.last2Weeks => AnalyticsRevenuePreset.last2Weeks,
    AnalyticsDetailPreset.thisMonth => AnalyticsRevenuePreset.thisMonth,
  };
}

AnalyticsDetailPreset analyticsDetailExportPresetFromOverviewPreset(
  AnalyticsDateRangePreset preset,
) {
  return switch (analyticsDetailPresetFromOverviewPreset(preset)) {
    AnalyticsDateRangePreset.thisWeek => AnalyticsDetailPreset.thisWeek,
    AnalyticsDateRangePreset.lastWeek => AnalyticsDetailPreset.lastWeek,
    AnalyticsDateRangePreset.last2Weeks => AnalyticsDetailPreset.last2Weeks,
    AnalyticsDateRangePreset.thisMonth => AnalyticsDetailPreset.thisMonth,
    AnalyticsDateRangePreset.today ||
    AnalyticsDateRangePreset.explicit => AnalyticsDetailPreset.thisWeek,
  };
}
