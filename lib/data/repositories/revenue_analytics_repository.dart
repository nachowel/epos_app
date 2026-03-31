import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/exceptions.dart';
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

  static void _validateDailyTrend(List<RevenueAnalyticsDailyPoint> points) {
    if (points.length != 14) {
      throw const FormatException(
        'Revenue analytics daily_trend must contain exactly 14 buckets.',
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
    if (points.length != 6) {
      throw const FormatException(
        'Revenue analytics weekly_summary must contain exactly 6 buckets.',
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

abstract class RevenueAnalyticsRepository {
  Future<RevenueAnalyticsSnapshot> fetchRevenueAnalytics();
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
    final SupabaseClient? client = _client;
    if (client == null) {
      throw ValidationException(
        'Supabase revenue analytics is not configured for this build.',
      );
    }

    try {
      final SupabaseEdgeFunctionResponse response = await _functionInvoker
          .invoke(
            functionName: functionName,
            body: const <String, Object?>{},
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
