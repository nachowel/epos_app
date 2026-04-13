enum AnalyticsRevenuePreset { thisWeek, lastWeek, last2Weeks, thisMonth }

String analyticsRevenuePresetQueryValue(AnalyticsRevenuePreset preset) {
  return switch (preset) {
    AnalyticsRevenuePreset.thisWeek => 'this_week',
    AnalyticsRevenuePreset.lastWeek => 'last_week',
    AnalyticsRevenuePreset.last2Weeks => 'last_2_weeks',
    AnalyticsRevenuePreset.thisMonth => 'this_month',
  };
}

String analyticsRevenuePresetLabel(AnalyticsRevenuePreset preset) {
  return switch (preset) {
    AnalyticsRevenuePreset.thisWeek => 'This Week',
    AnalyticsRevenuePreset.lastWeek => 'Last Week',
    AnalyticsRevenuePreset.last2Weeks => 'Last 2 Weeks',
    AnalyticsRevenuePreset.thisMonth => 'This Month',
  };
}

AnalyticsRevenuePreset analyticsRevenuePresetFromQuery(String? value) {
  return switch (value) {
    'last_week' => AnalyticsRevenuePreset.lastWeek,
    'last_2_weeks' || 'last_14_days' => AnalyticsRevenuePreset.last2Weeks,
    'this_month' => AnalyticsRevenuePreset.thisMonth,
    _ => AnalyticsRevenuePreset.thisWeek,
  };
}

String analyticsRevenueComparisonLabel(AnalyticsRevenuePreset preset) {
  return switch (preset) {
    AnalyticsRevenuePreset.thisWeek => 'Compared to last week',
    AnalyticsRevenuePreset.lastWeek => 'Compared to previous week',
    AnalyticsRevenuePreset.last2Weeks => 'Compared to prior 2-week window',
    AnalyticsRevenuePreset.thisMonth => 'Compared to last month',
  };
}
