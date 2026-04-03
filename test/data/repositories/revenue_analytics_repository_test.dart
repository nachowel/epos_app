import 'dart:convert';

import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/revenue_analytics_repository.dart';
import 'package:epos_app/data/sync/supabase_edge_function_invoker.dart';
import 'package:epos_app/domain/models/analytics/analytics_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('RevenueAnalyticsSnapshot.fromJson', () {
    test('parses a valid aggregated payload', () {
      final RevenueAnalyticsSnapshot snapshot =
          RevenueAnalyticsSnapshot.fromJson(_validPayload());

      expect(snapshot.todayRevenueMinor, 1000);
      expect(snapshot.yesterdayRevenueMinor, 500);
      expect(snapshot.thisWeekOrderCount, 2);
      expect(snapshot.dailyTrend, hasLength(14));
      expect(snapshot.weeklySummary, hasLength(6));
      expect(snapshot.hourlyDistribution, hasLength(24));
      expect(snapshot.hourlyDistribution.first.hour, 0);
      expect(snapshot.hourlyDistribution.last.hour, 23);
    });

    test('parses an expanded intelligence-ready payload', () {
      final RevenueAnalyticsSnapshot snapshot =
          RevenueAnalyticsSnapshot.fromJson(_expandedPayload());

      expect(snapshot.todayOrderCount, 1);
      expect(snapshot.thisMonthOrderCount, 4);
      expect(snapshot.thisWeekAverageOrderValueMinor, 1500);
      expect(snapshot.thisMonthCashRevenueMinor, 4200);
      expect(snapshot.thisWeekCancelledOrderCount, 2);
      expect(snapshot.daypartDistribution, hasLength(5));
      expect(snapshot.topProductsCurrentPeriod, hasLength(2));
      expect(snapshot.topProductsCurrentPeriod.first.productKey, '11');
      expect(
        snapshot.dataQualityNotes,
        contains('refunds not available in remote analytics'),
      );
    });

    test('legacy payload without additive fields still parses', () {
      final RevenueAnalyticsSnapshot snapshot =
          RevenueAnalyticsSnapshot.fromJson(_validPayload());

      expect(snapshot.todayOrderCount, isNull);
      expect(snapshot.thisMonthCashRevenueMinor, isNull);
      expect(snapshot.daypartDistribution, isEmpty);
      expect(snapshot.topProductsCurrentPeriod, isEmpty);
      expect(snapshot.dataQualityNotes, isEmpty);
    });

    test('missing optional additive fields behaves predictably', () {
      final Map<String, Object?> payload = _expandedPayload()
        ..remove('data_quality_notes')
        ..remove('daypart_distribution')
        ..remove('top_products_current_period')
        ..remove('top_products_previous_period')
        ..remove('this_month_cash_revenue_minor');

      final RevenueAnalyticsSnapshot snapshot =
          RevenueAnalyticsSnapshot.fromJson(payload);

      expect(snapshot.daypartDistribution, isEmpty);
      expect(snapshot.topProductsCurrentPeriod, isEmpty);
      expect(snapshot.topProductsPreviousPeriod, isEmpty);
      expect(snapshot.thisMonthCashRevenueMinor, isNull);
      expect(snapshot.dataQualityNotes, isEmpty);
    });

    test('rejects hourly payloads without full 0-23 coverage', () {
      final Map<String, Object?> payload = _validPayload();
      payload['hourly_distribution'] = List<Map<String, Object?>>.generate(
        23,
        (int hour) => <String, Object?>{
          'hour': hour,
          'revenue_minor': 0,
          'order_count': 0,
        },
      );

      expect(
        () => RevenueAnalyticsSnapshot.fromJson(payload),
        throwsFormatException,
      );
    });

    test('rejects malformed additive contract fields', () {
      final Map<String, Object?> payload = _expandedPayload();
      payload['daypart_distribution'] = 'invalid';

      expect(
        () => RevenueAnalyticsSnapshot.fromJson(payload),
        throwsFormatException,
      );
    });
  });

  test(
    'SupabaseRevenueAnalyticsRepository uses Supabase Bearer auth and omits the internal key header',
    () async {
      late http.Request capturedRequest;
      final MockClient httpClient = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(_validPayload()),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final AppConfig config = AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        internalApiKey: 'internal-key',
      );
      final SupabaseRevenueAnalyticsRepository repository =
          SupabaseRevenueAnalyticsRepository(
            client: SupabaseClient('https://example.supabase.co', 'anon-key'),
            config: config,
            functionInvoker: SupabaseEdgeFunctionInvoker(
              config: config,
              accessTokenProvider: () async => 'header.payload.signature',
              httpClient: httpClient,
            ),
          );

      final RevenueAnalyticsSnapshot snapshot = await repository
          .fetchRevenueAnalytics();

      expect(snapshot.todayRevenueMinor, 1000);
      expect(capturedRequest.headers['apikey'], 'anon-key');
      expect(
        capturedRequest.headers['authorization'],
        'Bearer header.payload.signature',
      );
      expect(
        capturedRequest.headers.containsKey('x-epos-internal-key'),
        isFalse,
      );
    },
  );

  test('fetchAnalytics passes real period request parameters to the edge function', () async {
    late http.Request capturedRequest;
    final MockClient httpClient = MockClient((http.Request request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode(_expandedPayload()),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final AppConfig config = _config();
    final SupabaseRevenueAnalyticsRepository repository =
        SupabaseRevenueAnalyticsRepository(
          client: SupabaseClient('https://example.supabase.co', 'anon-key'),
          config: config,
          functionInvoker: SupabaseEdgeFunctionInvoker(
            config: config,
            accessTokenProvider: () async => 'header.payload.signature',
            httpClient: httpClient,
          ),
        );

    await repository.fetchAnalytics(
      selection: const AnalyticsPeriodSelection.preset(
        AnalyticsPresetPeriod.last14Days,
      ),
    );

    final Map<String, Object?> body = Map<String, Object?>.from(
      jsonDecode(capturedRequest.body) as Map<String, dynamic>,
    );
    expect(body['period_type'], 'preset');
    expect(body['preset'], 'last_14_days');
  });

  test('missing JWT auth is surfaced as unauthorised', () async {
    final SupabaseRevenueAnalyticsRepository
    repository = SupabaseRevenueAnalyticsRepository(
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      config: _config(),
      functionInvoker: _FakeFunctionInvoker(
        const SupabaseEdgeFunctionException(
          statusCode: 401,
          failure: 'missing_token',
          message:
              'Authorization: Bearer <jwt> is required for owner revenue analytics.',
          retryable: false,
        ),
      ),
    );

    await expectLater(
      repository.fetchRevenueAnalytics,
      throwsA(isA<UnauthorisedException>()),
    );
  });

  test('missing analytics allow-list row is surfaced as unauthorised', () async {
    final SupabaseRevenueAnalyticsRepository
    repository = SupabaseRevenueAnalyticsRepository(
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      config: _config(),
      functionInvoker: _FakeFunctionInvoker(
        const SupabaseEdgeFunctionException(
          statusCode: 403,
          failure: 'analytics_access_missing',
          message:
              'Authenticated Supabase user is not authorized for owner revenue analytics.',
          retryable: false,
        ),
      ),
    );

    await expectLater(
      repository.fetchRevenueAnalytics,
      throwsA(isA<UnauthorisedException>()),
    );
  });

  test(
    'active analytics allow-list row success path stays unchanged',
    () async {
      final SupabaseRevenueAnalyticsRepository repository =
          SupabaseRevenueAnalyticsRepository(
            client: SupabaseClient('https://example.supabase.co', 'anon-key'),
            config: _config(),
            functionInvoker: _FakeSuccessFunctionInvoker(_validPayload()),
          );

      final RevenueAnalyticsSnapshot snapshot = await repository
          .fetchRevenueAnalytics();

      expect(snapshot.todayRevenueMinor, 1000);
      expect(snapshot.thisWeekRevenueMinor, 3000);
    },
  );
}

AppConfig _config() {
  return AppConfig.fromValues(
    environment: 'test',
    appVersion: 'test',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'anon-key',
    internalApiKey: 'internal-key',
  );
}

class _FakeFunctionInvoker extends SupabaseEdgeFunctionInvoker {
  _FakeFunctionInvoker(this._error)
    : super(
        config: _config(),
        httpClient: MockClient((http.Request _) async {
          throw StateError('HTTP client should not be used by fake invoker.');
        }),
      );

  final SupabaseEdgeFunctionException _error;

  @override
  Future<SupabaseEdgeFunctionResponse> invoke({
    required String functionName,
    required Object? body,
    Map<String, String> headers = const <String, String>{},
    bool includeInternalKey = false,
    bool includeAuthorization = true,
  }) async {
    throw _error;
  }
}

class _FakeSuccessFunctionInvoker extends SupabaseEdgeFunctionInvoker {
  _FakeSuccessFunctionInvoker(this._payload)
    : super(
        config: _config(),
        httpClient: MockClient((http.Request _) async {
          throw StateError('HTTP client should not be used by fake invoker.');
        }),
      );

  final Map<String, Object?> _payload;

  @override
  Future<SupabaseEdgeFunctionResponse> invoke({
    required String functionName,
    required Object? body,
    Map<String, String> headers = const <String, String>{},
    bool includeInternalKey = false,
    bool includeAuthorization = true,
  }) async {
    return SupabaseEdgeFunctionResponse(
      statusCode: 200,
      data: _payload,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

Map<String, Object?> _validPayload() {
  return <String, Object?>{
    'generated_at': '2026-03-31T12:00:00.000Z',
    'timezone': 'Europe/London',
    'today_total_minor': 1000,
    'yesterday_total_minor': 500,
    'this_week_total_minor': 3000,
    'last_week_total_minor': 2000,
    'this_month_total_minor': 9000,
    'last_month_total_minor': 7000,
    'this_week_order_count': 2,
    'last_week_order_count': 1,
    'daily_trend': List<Map<String, Object?>>.generate(14, (int index) {
      final int day = 18 + index;
      return <String, Object?>{
        'date': '2026-03-${day.toString().padLeft(2, '0')}',
        'revenue_minor': index == 13 ? 1000 : 0,
        'order_count': index == 13 ? 1 : 0,
      };
    }),
    'weekly_summary': const <Map<String, Object?>>[
      {'week_start': '2026-02-23', 'revenue_minor': 0, 'order_count': 0},
      {'week_start': '2026-03-02', 'revenue_minor': 0, 'order_count': 0},
      {'week_start': '2026-03-09', 'revenue_minor': 0, 'order_count': 0},
      {'week_start': '2026-03-16', 'revenue_minor': 0, 'order_count': 0},
      {'week_start': '2026-03-23', 'revenue_minor': 2000, 'order_count': 1},
      {'week_start': '2026-03-30', 'revenue_minor': 3000, 'order_count': 2},
    ],
    'hourly_distribution': List<Map<String, Object?>>.generate(24, (int hour) {
      return <String, Object?>{
        'hour': hour,
        'revenue_minor': hour == 12 ? 1000 : 0,
        'order_count': hour == 12 ? 1 : 0,
      };
    }),
  };
}

Map<String, Object?> _expandedPayload() {
  final Map<String, Object?> payload = _validPayload();
  payload.addAll(<String, Object?>{
    'today_order_count': 1,
    'yesterday_order_count': 0,
    'this_month_order_count': 4,
    'last_month_order_count': 3,
    'this_week_average_order_value_minor': 1500,
    'last_week_average_order_value_minor': 2000,
    'this_month_average_order_value_minor': 1800,
    'last_month_average_order_value_minor': 2100,
    'this_week_cash_revenue_minor': 1000,
    'this_week_card_revenue_minor': 2000,
    'last_week_cash_revenue_minor': 500,
    'last_week_card_revenue_minor': 1500,
    'this_month_cash_revenue_minor': 4200,
    'this_month_card_revenue_minor': 4800,
    'last_month_cash_revenue_minor': 3200,
    'last_month_card_revenue_minor': 3800,
    'this_week_cancelled_order_count': 2,
    'last_week_cancelled_order_count': 1,
    'this_month_cancelled_order_count': 3,
    'last_month_cancelled_order_count': 2,
    'daypart_distribution': const <Map<String, Object?>>[
      {'daypart': 'breakfast', 'revenue_minor': 1000, 'order_count': 1},
      {'daypart': 'lunch', 'revenue_minor': 2000, 'order_count': 1},
      {'daypart': 'afternoon', 'revenue_minor': 0, 'order_count': 0},
      {'daypart': 'evening', 'revenue_minor': 0, 'order_count': 0},
      {'daypart': 'late', 'revenue_minor': 0, 'order_count': 0},
    ],
    'top_products_current_period': const <Map<String, Object?>>[
      {
        'product_key': '11',
        'product_name': 'Flat White',
        'quantity_sold': 3,
        'revenue_minor': 2400,
      },
      {
        'product_key': '12',
        'product_name': 'Burger',
        'quantity_sold': 1,
        'revenue_minor': 1800,
      },
    ],
    'top_products_previous_period': const <Map<String, Object?>>[
      {
        'product_key': '11',
        'product_name': 'Flat White',
        'quantity_sold': 2,
        'revenue_minor': 1600,
      },
    ],
    'data_quality_notes': const <String>[
      'refunds not available in remote analytics',
      'true shift intelligence unavailable because shifts are not mirrored',
    ],
  });
  return payload;
}
