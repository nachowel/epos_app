enum AnalyticsDateRangePreset {
  today,
  thisWeek,
  lastWeek,
  last2Weeks,
  thisMonth,
  explicit,
}

const List<AnalyticsDateRangePreset> kAnalyticsOverviewPresets =
    <AnalyticsDateRangePreset>[
      AnalyticsDateRangePreset.today,
      AnalyticsDateRangePreset.thisWeek,
      AnalyticsDateRangePreset.thisMonth,
    ];

const List<AnalyticsDateRangePreset> kAnalyticsDetailPresets =
    <AnalyticsDateRangePreset>[
      AnalyticsDateRangePreset.thisWeek,
      AnalyticsDateRangePreset.lastWeek,
      AnalyticsDateRangePreset.last2Weeks,
      AnalyticsDateRangePreset.thisMonth,
    ];

/// Local analytics are resolved in the civil timezone used by reporting.
///
/// The current analytics/reporting contract uses Europe/London civil-day
/// boundaries. Callers that build preset windows must pass a [now] value that
/// is already expressed in that timezone.
const String kAnalyticsTimeZoneId = 'Europe/London';

/// Paid analytics always filter by `transactions.paid_at`.
///
/// Date ranges use `[startInclusive, endExclusive)` boundaries.
class AnalyticsDateRange {
  AnalyticsDateRange.preset({
    required this.preset,
    required this.startInclusive,
    required this.endExclusive,
  }) : assert(preset != AnalyticsDateRangePreset.explicit),
       assert(!endExclusive.isBefore(startInclusive));

  AnalyticsDateRange.explicit({
    required this.startInclusive,
    required this.endExclusive,
  }) : preset = AnalyticsDateRangePreset.explicit,
       assert(!endExclusive.isBefore(startInclusive));

  /// Resolves the standard analytics preset windows using Europe/London civil
  /// dates and `[startInclusive, endExclusive)` boundaries.
  factory AnalyticsDateRange.resolvePreset({
    required AnalyticsDateRangePreset preset,
    required DateTime now,
  }) {
    assert(preset != AnalyticsDateRangePreset.explicit);
    final DateTime today = startOfCivilDay(now);
    switch (preset) {
      case AnalyticsDateRangePreset.today:
        return AnalyticsDateRange.preset(
          preset: preset,
          startInclusive: today,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case AnalyticsDateRangePreset.thisWeek:
        final int weekdayOffset = today.weekday - DateTime.monday;
        final DateTime weekStart = today.subtract(
          Duration(days: weekdayOffset),
        );
        return AnalyticsDateRange.preset(
          preset: preset,
          startInclusive: weekStart,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case AnalyticsDateRangePreset.lastWeek:
        final int weekdayOffset = today.weekday - DateTime.monday;
        final DateTime thisWeekStart = today.subtract(
          Duration(days: weekdayOffset),
        );
        final DateTime lastWeekStart = thisWeekStart.subtract(
          const Duration(days: 7),
        );
        return AnalyticsDateRange.preset(
          preset: preset,
          startInclusive: lastWeekStart,
          endExclusive: thisWeekStart,
        );
      case AnalyticsDateRangePreset.last2Weeks:
        final DateTime endExclusive = today.add(const Duration(days: 1));
        return AnalyticsDateRange.preset(
          preset: preset,
          startInclusive: DateTime(
            endExclusive.year,
            endExclusive.month,
            endExclusive.day - 14,
          ),
          endExclusive: endExclusive,
        );
      case AnalyticsDateRangePreset.thisMonth:
        return AnalyticsDateRange.preset(
          preset: preset,
          startInclusive: DateTime(today.year, today.month),
          endExclusive: today.add(const Duration(days: 1)),
        );
      case AnalyticsDateRangePreset.explicit:
        throw ArgumentError.value(
          preset,
          'preset',
          'Use AnalyticsDateRange.explicit for explicit ranges.',
        );
    }
  }

  final AnalyticsDateRangePreset preset;
  final DateTime startInclusive;
  final DateTime endExclusive;

  bool get isExplicit => preset == AnalyticsDateRangePreset.explicit;

  bool get isEmpty => !endExclusive.isAfter(startInclusive);

  Duration get duration => endExclusive.difference(startInclusive);

  static DateTime startOfCivilDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  AnalyticsDateRange copyWith({
    AnalyticsDateRangePreset? preset,
    DateTime? startInclusive,
    DateTime? endExclusive,
  }) {
    final AnalyticsDateRangePreset resolvedPreset = preset ?? this.preset;
    final DateTime resolvedStart = startInclusive ?? this.startInclusive;
    final DateTime resolvedEnd = endExclusive ?? this.endExclusive;
    return resolvedPreset == AnalyticsDateRangePreset.explicit
        ? AnalyticsDateRange.explicit(
            startInclusive: resolvedStart,
            endExclusive: resolvedEnd,
          )
        : AnalyticsDateRange.preset(
            preset: resolvedPreset,
            startInclusive: resolvedStart,
            endExclusive: resolvedEnd,
          );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AnalyticsDateRange &&
        other.preset == preset &&
        other.startInclusive == startInclusive &&
        other.endExclusive == endExclusive;
  }

  @override
  int get hashCode => Object.hash(preset, startInclusive, endExclusive);
}

String analyticsDateRangePresetQueryValue(AnalyticsDateRangePreset preset) {
  return switch (preset) {
    AnalyticsDateRangePreset.today => 'today',
    AnalyticsDateRangePreset.thisWeek => 'this_week',
    AnalyticsDateRangePreset.lastWeek => 'last_week',
    AnalyticsDateRangePreset.last2Weeks => 'last_2_weeks',
    AnalyticsDateRangePreset.thisMonth => 'this_month',
    AnalyticsDateRangePreset.explicit => 'explicit',
  };
}

AnalyticsDateRangePreset analyticsDateRangePresetFromQuery(String? value) {
  return switch (value) {
    'today' => AnalyticsDateRangePreset.today,
    'last_week' => AnalyticsDateRangePreset.lastWeek,
    'last_2_weeks' || 'last_14_days' => AnalyticsDateRangePreset.last2Weeks,
    'this_month' => AnalyticsDateRangePreset.thisMonth,
    _ => AnalyticsDateRangePreset.thisWeek,
  };
}

AnalyticsDateRangePreset analyticsDetailPresetFromQuery(String? value) {
  return switch (analyticsDateRangePresetFromQuery(value)) {
    AnalyticsDateRangePreset.today => AnalyticsDateRangePreset.thisWeek,
    AnalyticsDateRangePreset.explicit => AnalyticsDateRangePreset.thisWeek,
    final AnalyticsDateRangePreset preset => preset,
  };
}

AnalyticsDateRangePreset analyticsDetailPresetFromOverviewPreset(
  AnalyticsDateRangePreset preset,
) {
  return switch (preset) {
    AnalyticsDateRangePreset.today => AnalyticsDateRangePreset.thisWeek,
    AnalyticsDateRangePreset.explicit => AnalyticsDateRangePreset.thisWeek,
    final AnalyticsDateRangePreset resolvedPreset => resolvedPreset,
  };
}

String analyticsDateRangePresetLabel(AnalyticsDateRangePreset preset) {
  return switch (preset) {
    AnalyticsDateRangePreset.today => 'Today',
    AnalyticsDateRangePreset.thisWeek => 'This Week',
    AnalyticsDateRangePreset.lastWeek => 'Last Week',
    AnalyticsDateRangePreset.last2Weeks => 'Last 2 Weeks',
    AnalyticsDateRangePreset.thisMonth => 'This Month',
    AnalyticsDateRangePreset.explicit => 'Custom',
  };
}
