enum AnalyticsPeriodType { preset, custom }

enum AnalyticsPresetPeriod { today, thisWeek, thisMonth, last14Days }

enum AnalyticsComparisonMode {
  baselineSummary,
  previousEquivalentPeriod,
  momentumView,
}

class AnalyticsPeriodSelection {
  const AnalyticsPeriodSelection.preset(this.preset)
    : type = AnalyticsPeriodType.preset,
      start = null,
      end = null;

  const AnalyticsPeriodSelection.custom({
    required this.start,
    required this.end,
  }) : type = AnalyticsPeriodType.custom,
       preset = null;

  final AnalyticsPeriodType type;
  final AnalyticsPresetPeriod? preset;
  final DateTime? start;
  final DateTime? end;

  bool get isCustom => type == AnalyticsPeriodType.custom;

  String get queryValue => switch (preset) {
    AnalyticsPresetPeriod.today => 'today',
    AnalyticsPresetPeriod.thisWeek => 'this_week',
    AnalyticsPresetPeriod.thisMonth => 'this_month',
    AnalyticsPresetPeriod.last14Days => 'last_14_days',
    null => 'custom',
  };

  String get label => switch (preset) {
    AnalyticsPresetPeriod.today => 'Today',
    AnalyticsPresetPeriod.thisWeek => 'This Week',
    AnalyticsPresetPeriod.thisMonth => 'This Month',
    AnalyticsPresetPeriod.last14Days => 'Last 14 Days',
    null => 'Custom Range',
  };

  Map<String, String> toQueryParameters() {
    if (isCustom) {
      return <String, String>{
        'p': 'custom',
        if (start != null) 'start': _formatDate(start!),
        if (end != null) 'end': _formatDate(end!),
      };
    }
    return <String, String>{'p': queryValue};
  }

  Map<String, Object?> toRequestBody() {
    if (isCustom) {
      return <String, Object?>{
        'period_type': 'custom',
        'start_date': _formatDate(start!),
        'end_date': _formatDate(end!),
      };
    }
    return <String, Object?>{
      'period_type': 'preset',
      'preset': queryValue,
    };
  }

  static AnalyticsPeriodSelection fallback() {
    return const AnalyticsPeriodSelection.preset(
      AnalyticsPresetPeriod.thisWeek,
    );
  }

  static AnalyticsPeriodSelection fromQueryParameters(
    Map<String, String> queryParameters,
  ) {
    final String? rawPeriod = queryParameters['p'];
    if (rawPeriod == null || rawPeriod.trim().isEmpty) {
      return fallback();
    }
    if (rawPeriod == 'custom') {
      final DateTime? start = _tryParseDate(queryParameters['start']);
      final DateTime? end = _tryParseDate(queryParameters['end']);
      if (start == null || end == null || end.isBefore(start)) {
        return fallback();
      }
      return AnalyticsPeriodSelection.custom(start: start, end: end);
    }
    final AnalyticsPresetPeriod? preset = _presetFromQuery(rawPeriod);
    if (preset == null) {
      return fallback();
    }
    return AnalyticsPeriodSelection.preset(preset);
  }

  static AnalyticsPresetPeriod? _presetFromQuery(String value) {
    return switch (value) {
      'today' => AnalyticsPresetPeriod.today,
      'this_week' => AnalyticsPresetPeriod.thisWeek,
      'this_month' => AnalyticsPresetPeriod.thisMonth,
      'last_14_days' => AnalyticsPresetPeriod.last14Days,
      _ => null,
    };
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static String _formatDate(DateTime value) {
    final DateTime normalized = DateTime.utc(value.year, value.month, value.day);
    return normalized.toIso8601String().split('T').first;
  }

  @override
  bool operator ==(Object other) {
    return other is AnalyticsPeriodSelection &&
        other.type == type &&
        other.preset == preset &&
        _isSameDay(other.start, start) &&
        _isSameDay(other.end, end);
  }

  @override
  int get hashCode => Object.hash(
    type,
    preset,
    start?.year,
    start?.month,
    start?.day,
    end?.year,
    end?.month,
    end?.day,
  );

  static bool _isSameDay(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return left == right;
    }
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

String analyticsComparisonModeQueryValue(AnalyticsComparisonMode mode) {
  return switch (mode) {
    AnalyticsComparisonMode.baselineSummary => 'baseline',
    AnalyticsComparisonMode.previousEquivalentPeriod => 'previous',
    AnalyticsComparisonMode.momentumView => 'momentum',
  };
}

AnalyticsComparisonMode analyticsComparisonModeFromQuery(String? value) {
  return switch (value) {
    'previous' => AnalyticsComparisonMode.previousEquivalentPeriod,
    'momentum' => AnalyticsComparisonMode.momentumView,
    _ => AnalyticsComparisonMode.baselineSummary,
  };
}
