import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/models/analytics/analytics_period.dart';
import '../sync/supabase_edge_function_invoker.dart';

class RevenueAnalyticsSnapshot {
  const RevenueAnalyticsSnapshot({
    required this.generatedAt,
    required this.timezone,
    required this.todayRevenueMinor,
    required this.yesterdayRevenueMinor,
    required this.thisWeekRevenueMinor,
    required this.lastWeekRevenueMinor,
    required this.thisMonthRevenueMinor,
    required this.lastMonthRevenueMinor,
    required this.thisWeekOrderCount,
    required this.lastWeekOrderCount,
    required this.dailyTrend,
    required this.weeklySummary,
    required this.hourlyDistribution,
    this.periodWindow,
    this.comparisonWindow,
    this.periodRevenueMinor,
    this.previousPeriodRevenueMinor,
    this.periodOrderCount,
    this.previousPeriodOrderCount,
    this.periodAverageOrderValueMinor,
    this.previousPeriodAverageOrderValueMinor,
    this.periodCashRevenueMinor,
    this.periodCardRevenueMinor,
    this.previousPeriodCashRevenueMinor,
    this.previousPeriodCardRevenueMinor,
    this.periodCancelledOrderCount,
    this.previousPeriodCancelledOrderCount,
    this.todayOrderCount,
    this.yesterdayOrderCount,
    this.thisMonthOrderCount,
    this.lastMonthOrderCount,
    this.thisWeekAverageOrderValueMinor,
    this.lastWeekAverageOrderValueMinor,
    this.thisMonthAverageOrderValueMinor,
    this.lastMonthAverageOrderValueMinor,
    this.thisWeekCashRevenueMinor,
    this.thisWeekCardRevenueMinor,
    this.lastWeekCashRevenueMinor,
    this.lastWeekCardRevenueMinor,
    this.thisMonthCashRevenueMinor,
    this.thisMonthCardRevenueMinor,
    this.lastMonthCashRevenueMinor,
    this.lastMonthCardRevenueMinor,
    this.thisWeekCancelledOrderCount,
    this.lastWeekCancelledOrderCount,
    this.thisMonthCancelledOrderCount,
    this.lastMonthCancelledOrderCount,
    this.daypartDistribution = const <RevenueAnalyticsDaypartPoint>[],
    this.topProductsCurrentPeriod = const <RevenueAnalyticsTopProductPoint>[],
    this.topProductsPreviousPeriod = const <RevenueAnalyticsTopProductPoint>[],
    this.dataQualityNotes = const <String>[],
  });

  factory RevenueAnalyticsSnapshot.fromJson(Map<String, Object?> json) {
    final DateTime generatedAt = _readDateTime(json, 'generated_at');
    final String timezone = _readString(json, 'timezone');

    final List<RevenueAnalyticsDailyPoint> dailyTrend = _readList(
      json,
      'daily_trend',
      (Map<String, Object?> item) => RevenueAnalyticsDailyPoint.fromJson(item),
    );
    final List<RevenueAnalyticsWeeklyPoint> weeklySummary = _readList(
      json,
      'weekly_summary',
      (Map<String, Object?> item) => RevenueAnalyticsWeeklyPoint.fromJson(item),
    );
    final List<RevenueAnalyticsHourlyPoint> hourlyDistribution = _readList(
      json,
      'hourly_distribution',
      (Map<String, Object?> item) => RevenueAnalyticsHourlyPoint.fromJson(item),
    );

    _validateDailyTrend(dailyTrend);
    _validateWeeklySummary(weeklySummary);
    _validateHourlyDistribution(hourlyDistribution);

    final List<RevenueAnalyticsDaypartPoint> daypartDistribution =
        _readOptionalList(
          json,
          'daypart_distribution',
          (Map<String, Object?> item) =>
              RevenueAnalyticsDaypartPoint.fromJson(item),
        );
    _validateDaypartDistribution(daypartDistribution);

    return RevenueAnalyticsSnapshot(
      generatedAt: generatedAt,
      timezone: timezone,
      todayRevenueMinor: _readInt(json, 'today_total_minor'),
      yesterdayRevenueMinor: _readInt(json, 'yesterday_total_minor'),
      thisWeekRevenueMinor: _readInt(json, 'this_week_total_minor'),
      lastWeekRevenueMinor: _readInt(json, 'last_week_total_minor'),
      thisMonthRevenueMinor: _readInt(json, 'this_month_total_minor'),
      lastMonthRevenueMinor: _readInt(json, 'last_month_total_minor'),
      thisWeekOrderCount: _readInt(json, 'this_week_order_count'),
      lastWeekOrderCount: _readInt(json, 'last_week_order_count'),
      dailyTrend: dailyTrend,
      weeklySummary: weeklySummary,
      hourlyDistribution: hourlyDistribution,
      periodWindow: _readOptionalPeriodWindow(json, 'period'),
      comparisonWindow: _readOptionalComparisonWindow(json, 'comparison_period'),
      periodRevenueMinor: _readOptionalInt(json, 'period_total_minor'),
      previousPeriodRevenueMinor: _readOptionalInt(
        json,
        'previous_period_total_minor',
      ),
      periodOrderCount: _readOptionalInt(json, 'period_order_count'),
      previousPeriodOrderCount: _readOptionalInt(
        json,
        'previous_period_order_count',
      ),
      periodAverageOrderValueMinor: _readOptionalInt(
        json,
        'period_average_order_value_minor',
      ),
      previousPeriodAverageOrderValueMinor: _readOptionalInt(
        json,
        'previous_period_average_order_value_minor',
      ),
      periodCashRevenueMinor: _readOptionalInt(
        json,
        'period_cash_revenue_minor',
      ),
      periodCardRevenueMinor: _readOptionalInt(
        json,
        'period_card_revenue_minor',
      ),
      previousPeriodCashRevenueMinor: _readOptionalInt(
        json,
        'previous_period_cash_revenue_minor',
      ),
      previousPeriodCardRevenueMinor: _readOptionalInt(
        json,
        'previous_period_card_revenue_minor',
      ),
      periodCancelledOrderCount: _readOptionalInt(
        json,
        'period_cancelled_order_count',
      ),
      previousPeriodCancelledOrderCount: _readOptionalInt(
        json,
        'previous_period_cancelled_order_count',
      ),
      todayOrderCount: _readOptionalInt(json, 'today_order_count'),
      yesterdayOrderCount: _readOptionalInt(json, 'yesterday_order_count'),
      thisMonthOrderCount: _readOptionalInt(json, 'this_month_order_count'),
      lastMonthOrderCount: _readOptionalInt(json, 'last_month_order_count'),
      thisWeekAverageOrderValueMinor: _readOptionalInt(
        json,
        'this_week_average_order_value_minor',
      ),
      lastWeekAverageOrderValueMinor: _readOptionalInt(
        json,
        'last_week_average_order_value_minor',
      ),
      thisMonthAverageOrderValueMinor: _readOptionalInt(
        json,
        'this_month_average_order_value_minor',
      ),
      lastMonthAverageOrderValueMinor: _readOptionalInt(
        json,
        'last_month_average_order_value_minor',
      ),
      thisWeekCashRevenueMinor: _readOptionalInt(
        json,
        'this_week_cash_revenue_minor',
      ),
      thisWeekCardRevenueMinor: _readOptionalInt(
        json,
        'this_week_card_revenue_minor',
      ),
      lastWeekCashRevenueMinor: _readOptionalInt(
        json,
        'last_week_cash_revenue_minor',
      ),
      lastWeekCardRevenueMinor: _readOptionalInt(
        json,
        'last_week_card_revenue_minor',
      ),
      thisMonthCashRevenueMinor: _readOptionalInt(
        json,
        'this_month_cash_revenue_minor',
      ),
      thisMonthCardRevenueMinor: _readOptionalInt(
        json,
        'this_month_card_revenue_minor',
      ),
      lastMonthCashRevenueMinor: _readOptionalInt(
        json,
        'last_month_cash_revenue_minor',
      ),
      lastMonthCardRevenueMinor: _readOptionalInt(
        json,
        'last_month_card_revenue_minor',
      ),
      thisWeekCancelledOrderCount: _readOptionalInt(
        json,
        'this_week_cancelled_order_count',
      ),
      lastWeekCancelledOrderCount: _readOptionalInt(
        json,
        'last_week_cancelled_order_count',
      ),
      thisMonthCancelledOrderCount: _readOptionalInt(
        json,
        'this_month_cancelled_order_count',
      ),
      lastMonthCancelledOrderCount: _readOptionalInt(
        json,
        'last_month_cancelled_order_count',
      ),
      daypartDistribution: daypartDistribution,
      topProductsCurrentPeriod: _readOptionalList(
        json,
        'top_products_current_period',
        (Map<String, Object?> item) =>
            RevenueAnalyticsTopProductPoint.fromJson(item),
      ),
      topProductsPreviousPeriod: _readOptionalList(
        json,
        'top_products_previous_period',
        (Map<String, Object?> item) =>
            RevenueAnalyticsTopProductPoint.fromJson(item),
      ),
      dataQualityNotes: _readOptionalStringList(json, 'data_quality_notes'),
    );
  }

  final DateTime generatedAt;
  final String timezone;
  final int todayRevenueMinor;
  final int yesterdayRevenueMinor;
  final int thisWeekRevenueMinor;
  final int lastWeekRevenueMinor;
  final int thisMonthRevenueMinor;
  final int lastMonthRevenueMinor;
  final int thisWeekOrderCount;
  final int lastWeekOrderCount;
  final List<RevenueAnalyticsDailyPoint> dailyTrend;
  final List<RevenueAnalyticsWeeklyPoint> weeklySummary;
  final List<RevenueAnalyticsHourlyPoint> hourlyDistribution;
  final RevenueAnalyticsPeriodWindow? periodWindow;
  final RevenueAnalyticsComparisonWindow? comparisonWindow;
  final int? periodRevenueMinor;
  final int? previousPeriodRevenueMinor;
  final int? periodOrderCount;
  final int? previousPeriodOrderCount;
  final int? periodAverageOrderValueMinor;
  final int? previousPeriodAverageOrderValueMinor;
  final int? periodCashRevenueMinor;
  final int? periodCardRevenueMinor;
  final int? previousPeriodCashRevenueMinor;
  final int? previousPeriodCardRevenueMinor;
  final int? periodCancelledOrderCount;
  final int? previousPeriodCancelledOrderCount;
  final int? todayOrderCount;
  final int? yesterdayOrderCount;
  final int? thisMonthOrderCount;
  final int? lastMonthOrderCount;
  final int? thisWeekAverageOrderValueMinor;
  final int? lastWeekAverageOrderValueMinor;
  final int? thisMonthAverageOrderValueMinor;
  final int? lastMonthAverageOrderValueMinor;
  final int? thisWeekCashRevenueMinor;
  final int? thisWeekCardRevenueMinor;
  final int? lastWeekCashRevenueMinor;
  final int? lastWeekCardRevenueMinor;
  final int? thisMonthCashRevenueMinor;
  final int? thisMonthCardRevenueMinor;
  final int? lastMonthCashRevenueMinor;
  final int? lastMonthCardRevenueMinor;
  final int? thisWeekCancelledOrderCount;
  final int? lastWeekCancelledOrderCount;
  final int? thisMonthCancelledOrderCount;
  final int? lastMonthCancelledOrderCount;
  final List<RevenueAnalyticsDaypartPoint> daypartDistribution;
  final List<RevenueAnalyticsTopProductPoint> topProductsCurrentPeriod;
  final List<RevenueAnalyticsTopProductPoint> topProductsPreviousPeriod;
  final List<String> dataQualityNotes;

  static String _readString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Revenue analytics response is missing $key.');
    }
    return value;
  }

  static DateTime _readDateTime(Map<String, Object?> json, String key) {
    final String rawValue = _readString(json, key);
    return DateTime.parse(rawValue).toUtc();
  }

  static int _readInt(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! num) {
      throw FormatException('Revenue analytics response is missing $key.');
    }
    return value.toInt();
  }

  static int? _readOptionalInt(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! num) {
      throw FormatException(
        'Revenue analytics response contains invalid $key.',
      );
    }
    return value.toInt();
  }

  static List<T> _readList<T>(
    Map<String, Object?> json,
    String key,
    T Function(Map<String, Object?> item) decoder,
  ) {
    final Object? value = json[key];
    if (value is! List) {
      throw FormatException('Revenue analytics response is missing $key.');
    }
    return value
        .map((Object? item) {
          if (item is! Map) {
            throw FormatException(
              'Revenue analytics response contains invalid $key.',
            );
          }
          return decoder(Map<String, Object?>.from(item));
        })
        .toList(growable: false);
  }

  static List<T> _readOptionalList<T>(
    Map<String, Object?> json,
    String key,
    T Function(Map<String, Object?> item) decoder,
  ) {
    final Object? value = json[key];
    if (value == null) {
      return <T>[];
    }
    if (value is! List) {
      throw FormatException(
        'Revenue analytics response contains invalid $key.',
      );
    }
    return value
        .map((Object? item) {
          if (item is! Map) {
            throw FormatException(
              'Revenue analytics response contains invalid $key.',
            );
          }
          return decoder(Map<String, Object?>.from(item));
        })
        .toList(growable: false);
  }

  static RevenueAnalyticsPeriodWindow? _readOptionalPeriodWindow(
    Map<String, Object?> json,
    String key,
  ) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw FormatException(
        'Revenue analytics response contains invalid $key.',
      );
    }
    return RevenueAnalyticsPeriodWindow.fromJson(Map<String, Object?>.from(value));
  }

  static RevenueAnalyticsComparisonWindow? _readOptionalComparisonWindow(
    Map<String, Object?> json,
    String key,
  ) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw FormatException(
        'Revenue analytics response contains invalid $key.',
      );
    }
    return RevenueAnalyticsComparisonWindow.fromJson(
      Map<String, Object?>.from(value),
    );
  }

  static List<String> _readOptionalStringList(
    Map<String, Object?> json,
    String key,
  ) {
    final Object? value = json[key];
    if (value == null) {
      return const <String>[];
    }
    if (value is! List || value.any((Object? item) => item is! String)) {
      throw FormatException(
        'Revenue analytics response contains invalid $key.',
      );
    }
    return value.cast<String>().toList(growable: false);
  }

  static void _validateDailyTrend(List<RevenueAnalyticsDailyPoint> points) {
    if (points.isEmpty) {
      throw const FormatException(
        'Revenue analytics daily_trend must contain at least one bucket.',
      );
    }
    final Set<String> uniqueKeys = points
        .map((RevenueAnalyticsDailyPoint point) => point.dateKey)
        .toSet();
    if (uniqueKeys.length != points.length) {
      throw const FormatException(
        'Revenue analytics daily_trend contains duplicate dates.',
      );
    }
  }

  static void _validateWeeklySummary(List<RevenueAnalyticsWeeklyPoint> points) {
    if (points.isEmpty) {
      throw const FormatException(
        'Revenue analytics weekly_summary must contain at least one bucket.',
      );
    }
    final Set<String> uniqueKeys = points
        .map((RevenueAnalyticsWeeklyPoint point) => point.weekStartKey)
        .toSet();
    if (uniqueKeys.length != points.length) {
      throw const FormatException(
        'Revenue analytics weekly_summary contains duplicate week starts.',
      );
    }
  }

  static void _validateHourlyDistribution(
    List<RevenueAnalyticsHourlyPoint> points,
  ) {
    if (points.length != 24) {
      throw const FormatException(
        'Revenue analytics hourly_distribution must contain exactly 24 buckets.',
      );
    }
    final Set<int> hours = points
        .map((RevenueAnalyticsHourlyPoint point) => point.hour)
        .toSet();
    if (hours.length != 24 ||
        !hours.containsAll(List<int>.generate(24, (int i) => i))) {
      throw const FormatException(
        'Revenue analytics hourly_distribution must cover hours 0-23.',
      );
    }
  }

  static void _validateDaypartDistribution(
    List<RevenueAnalyticsDaypartPoint> points,
  ) {
    if (points.isEmpty) {
      return;
    }
    if (points.length != RevenueAnalyticsDaypartPoint.expectedDayparts.length) {
      throw const FormatException(
        'Revenue analytics daypart_distribution must contain exactly 5 buckets.',
      );
    }
    final Set<String> uniqueKeys = points
        .map((RevenueAnalyticsDaypartPoint point) => point.daypart)
        .toSet();
    if (uniqueKeys.length != points.length ||
        !uniqueKeys.containsAll(RevenueAnalyticsDaypartPoint.expectedDayparts)) {
      throw const FormatException(
        'Revenue analytics daypart_distribution must contain the fixed dayparts.',
      );
    }
  }
}

class RevenueAnalyticsPeriodWindow {
  const RevenueAnalyticsPeriodWindow({
    required this.selection,
    required this.startDate,
    required this.endDate,
    required this.dayCount,
  });

  factory RevenueAnalyticsPeriodWindow.fromJson(Map<String, Object?> json) {
    final String typeValue = RevenueAnalyticsSnapshot._readString(json, 'type');
    final AnalyticsPeriodType type = switch (typeValue) {
      'preset' => AnalyticsPeriodType.preset,
      'custom' => AnalyticsPeriodType.custom,
      _ => throw FormatException(
        'Revenue analytics response contains invalid period type: $typeValue.',
      ),
    };
    final DateTime startDate = _readCivilDate(json, 'start_date');
    final DateTime endDate = _readCivilDate(json, 'end_date');
    final int dayCount = RevenueAnalyticsSnapshot._readInt(json, 'day_count');
    final AnalyticsPeriodSelection selection = switch (type) {
      AnalyticsPeriodType.preset => AnalyticsPeriodSelection.preset(
        _readPreset(json, 'preset'),
      ),
      AnalyticsPeriodType.custom => AnalyticsPeriodSelection.custom(
        start: startDate,
        end: endDate,
      ),
    };
    return RevenueAnalyticsPeriodWindow(
      selection: selection,
      startDate: startDate,
      endDate: endDate,
      dayCount: dayCount,
    );
  }

  final AnalyticsPeriodSelection selection;
  final DateTime startDate;
  final DateTime endDate;
  final int dayCount;

  static AnalyticsPresetPeriod _readPreset(
    Map<String, Object?> json,
    String key,
  ) {
    final String rawValue = RevenueAnalyticsSnapshot._readString(json, key);
    return switch (rawValue) {
      'today' => AnalyticsPresetPeriod.today,
      'this_week' => AnalyticsPresetPeriod.thisWeek,
      'this_month' => AnalyticsPresetPeriod.thisMonth,
      'last_14_days' => AnalyticsPresetPeriod.last14Days,
      _ => throw FormatException(
        'Revenue analytics response contains invalid preset: $rawValue.',
      ),
    };
  }

  static DateTime _readCivilDate(Map<String, Object?> json, String key) {
    final String rawValue = RevenueAnalyticsSnapshot._readString(json, key);
    final DateTime parsed = DateTime.parse(rawValue);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}

class RevenueAnalyticsComparisonWindow {
  const RevenueAnalyticsComparisonWindow({
    required this.startDate,
    required this.endDate,
    required this.dayCount,
    required this.basis,
  });

  factory RevenueAnalyticsComparisonWindow.fromJson(
    Map<String, Object?> json,
  ) {
    return RevenueAnalyticsComparisonWindow(
      startDate: RevenueAnalyticsPeriodWindow._readCivilDate(json, 'start_date'),
      endDate: RevenueAnalyticsPeriodWindow._readCivilDate(json, 'end_date'),
      dayCount: RevenueAnalyticsSnapshot._readInt(json, 'day_count'),
      basis: RevenueAnalyticsSnapshot._readString(json, 'basis'),
    );
  }

  final DateTime startDate;
  final DateTime endDate;
  final int dayCount;
  final String basis;
}

class RevenueAnalyticsDailyPoint {
  const RevenueAnalyticsDailyPoint({
    required this.dateKey,
    required this.revenueMinor,
    required this.orderCount,
  });

  factory RevenueAnalyticsDailyPoint.fromJson(Map<String, Object?> json) {
    return RevenueAnalyticsDailyPoint(
      dateKey: RevenueAnalyticsSnapshot._readString(json, 'date'),
      revenueMinor: RevenueAnalyticsSnapshot._readInt(json, 'revenue_minor'),
      orderCount: RevenueAnalyticsSnapshot._readInt(json, 'order_count'),
    );
  }

  final String dateKey;
  final int revenueMinor;
  final int orderCount;
}

class RevenueAnalyticsWeeklyPoint {
  const RevenueAnalyticsWeeklyPoint({
    required this.weekStartKey,
    required this.revenueMinor,
    required this.orderCount,
  });

  factory RevenueAnalyticsWeeklyPoint.fromJson(Map<String, Object?> json) {
    return RevenueAnalyticsWeeklyPoint(
      weekStartKey: RevenueAnalyticsSnapshot._readString(json, 'week_start'),
      revenueMinor: RevenueAnalyticsSnapshot._readInt(json, 'revenue_minor'),
      orderCount: RevenueAnalyticsSnapshot._readInt(json, 'order_count'),
    );
  }

  final String weekStartKey;
  final int revenueMinor;
  final int orderCount;
}

class RevenueAnalyticsHourlyPoint {
  const RevenueAnalyticsHourlyPoint({
    required this.hour,
    required this.revenueMinor,
    required this.orderCount,
  });

  factory RevenueAnalyticsHourlyPoint.fromJson(Map<String, Object?> json) {
    return RevenueAnalyticsHourlyPoint(
      hour: RevenueAnalyticsSnapshot._readInt(json, 'hour'),
      revenueMinor: RevenueAnalyticsSnapshot._readInt(json, 'revenue_minor'),
      orderCount: RevenueAnalyticsSnapshot._readInt(json, 'order_count'),
    );
  }

  final int hour;
  final int revenueMinor;
  final int orderCount;
}

class RevenueAnalyticsDaypartPoint {
  const RevenueAnalyticsDaypartPoint({
    required this.daypart,
    required this.revenueMinor,
    required this.orderCount,
  });

  static const Set<String> expectedDayparts = <String>{
    'breakfast',
    'lunch',
    'afternoon',
    'evening',
    'late',
  };

  factory RevenueAnalyticsDaypartPoint.fromJson(Map<String, Object?> json) {
    final String daypart = RevenueAnalyticsSnapshot._readString(
      json,
      'daypart',
    );
    if (!expectedDayparts.contains(daypart)) {
      throw FormatException(
        'Revenue analytics response contains invalid daypart: $daypart.',
      );
    }
    return RevenueAnalyticsDaypartPoint(
      daypart: daypart,
      revenueMinor: RevenueAnalyticsSnapshot._readInt(json, 'revenue_minor'),
      orderCount: RevenueAnalyticsSnapshot._readInt(json, 'order_count'),
    );
  }

  final String daypart;
  final int revenueMinor;
  final int orderCount;
}

class RevenueAnalyticsTopProductPoint {
  const RevenueAnalyticsTopProductPoint({
    required this.productKey,
    required this.productName,
    required this.quantitySold,
    required this.revenueMinor,
  });

  factory RevenueAnalyticsTopProductPoint.fromJson(Map<String, Object?> json) {
    final Object? productKey = json['product_key'];
    final String normalizedProductKey = switch (productKey) {
      String value when value.trim().isNotEmpty => value,
      num value => value.toInt().toString(),
      _ => throw const FormatException(
        'Revenue analytics response contains invalid product_key.',
      ),
    };
    return RevenueAnalyticsTopProductPoint(
      productKey: normalizedProductKey,
      productName: RevenueAnalyticsSnapshot._readString(json, 'product_name'),
      quantitySold: RevenueAnalyticsSnapshot._readInt(json, 'quantity_sold'),
      revenueMinor: RevenueAnalyticsSnapshot._readInt(json, 'revenue_minor'),
    );
  }

  final String productKey;
  final String productName;
  final int quantitySold;
  final int revenueMinor;
}

abstract class RevenueAnalyticsRepository {
  Future<RevenueAnalyticsSnapshot> fetchRevenueAnalytics();

  Future<RevenueAnalyticsSnapshot> fetchAnalytics({
    required AnalyticsPeriodSelection selection,
  });
}

class SupabaseRevenueAnalyticsRepository implements RevenueAnalyticsRepository {
  SupabaseRevenueAnalyticsRepository({
    required SupabaseClient? client,
    required AppConfig config,
    SupabaseEdgeFunctionInvoker? functionInvoker,
  }) : _client = client,
       _functionInvoker =
           functionInvoker ??
           SupabaseEdgeFunctionInvoker(
             config: config,
             accessTokenProvider: client == null
                 ? null
                 : () => _readAccessToken(client),
           );

  static const String functionName = 'owner-revenue-analytics';

  final SupabaseClient? _client;
  final SupabaseEdgeFunctionInvoker _functionInvoker;

  @override
  Future<RevenueAnalyticsSnapshot> fetchRevenueAnalytics() async {
    return _invokeSnapshot(const <String, Object?>{});
  }

  @override
  Future<RevenueAnalyticsSnapshot> fetchAnalytics({
    required AnalyticsPeriodSelection selection,
  }) async {
    return _invokeSnapshot(selection.toRequestBody());
  }

  Future<RevenueAnalyticsSnapshot> _invokeSnapshot(
    Map<String, Object?> body,
  ) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      throw ValidationException(
        'Supabase revenue analytics is not configured for this build.',
      );
    }

    try {
      final SupabaseEdgeFunctionResponse response = await _functionInvoker.invoke(
        functionName: functionName,
        body: body,
      );
      final Object? data = response.data;
      if (data is! Map) {
        throw DatabaseException(
          'Revenue analytics returned a non-JSON response.',
        );
      }
      return RevenueAnalyticsSnapshot.fromJson(Map<String, Object?>.from(data));
    } on TimeoutException catch (_) {
      throw DatabaseException('Revenue analytics request timed out.');
    } on SocketException catch (_) {
      throw DatabaseException('Revenue analytics service is unreachable.');
    } on SupabaseEdgeFunctionException catch (error) {
      if (error.isAuthHeaderMalformed ||
          error.failure == 'missing_token' ||
          error.failure == 'invalid_token' ||
          error.statusCode == 401) {
        throw UnauthorisedException(
          'Revenue analytics requires a valid Supabase admin session.',
        );
      }
      if (error.failure == 'analytics_access_missing') {
        throw UnauthorisedException(
          'Your Supabase account is not authorized for owner revenue analytics.',
        );
      }
      if (error.failure == 'analytics_access_inactive' ||
          error.statusCode == 403) {
        throw UnauthorisedException(
          'Revenue analytics is restricted to active admin users.',
        );
      }
      throw DatabaseException(error.message);
    } on FormatException catch (error) {
      throw DatabaseException(error.message);
    }
  }

  static Future<String?> _readAccessToken(SupabaseClient client) async {
    try {
      return client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}
