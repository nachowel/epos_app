import 'package:drift/drift.dart';

import '../../domain/models/analytics/category_product_analytics_section.dart';
import '../../domain/models/analytics/analytics_date_range.dart';
import '../../domain/models/analytics/daily_revenue_point.dart';
import '../../domain/models/analytics/overview_metrics.dart';
import '../../domain/models/analytics/payment_split_summary.dart';
import '../../domain/models/analytics/product_analytics_item.dart';
import '../../domain/models/analytics/revenue_metrics.dart';
import '../../domain/models/analytics/top_product_summary.dart';
import '../database/app_database.dart' as db;

abstract class AnalyticsRepository {
  /// Overview revenue is the paid transaction total.
  ///
  /// This contract intentionally uses `transactions.total_amount_minor` so the
  /// overview reflects the reconciled paid order total at transaction
  /// granularity.
  Future<OverviewMetrics> getOverviewMetrics(AnalyticsDateRange range);

  Future<RevenueMetrics> getRevenueMetrics(AnalyticsDateRange range);

  Future<List<DailyRevenuePoint>> getDailyRevenueSeries(
    AnalyticsDateRange range,
  );

  /// Product revenue is aggregated from historical line snapshots.
  ///
  /// This uses `transaction_lines.line_total_minor` and `product_name` as they
  /// were persisted on the order line. It must not be derived from the current
  /// live product catalog.
  ///
  /// Overview revenue and top-product revenue are related but not guaranteed to
  /// match exactly because transaction totals are reconciled at transaction
  /// granularity while product revenue is aggregated at line granularity. Line
  /// snapshots can diverge from transaction totals when modifier/snapshot
  /// behaviour affects the final paid order total outside a single line-total
  /// rollup.
  Future<List<TopProductSummary>> getTopProductsOverall(
    AnalyticsDateRange range, {
    int limit = 3,
  });

  Future<PaymentSplitSummary> getPaymentSplit(AnalyticsDateRange range);

  /// Returns per-category product sections for the paid window.
  ///
  /// Section totals reflect the full category revenue for the window, while the
  /// nested product list can be limited for overview-style previews.
  Future<List<CategoryProductAnalyticsSection>> getCategoryProductSections(
    AnalyticsDateRange range, {
    int perCategoryLimit = 5,
  });
}

class DriftAnalyticsRepository implements AnalyticsRepository {
  const DriftAnalyticsRepository(this._database);

  static const String _paidStatus = 'paid';

  final db.AppDatabase _database;

  @override
  Future<OverviewMetrics> getOverviewMetrics(AnalyticsDateRange range) async {
    final RevenueMetrics revenueMetrics = await getRevenueMetrics(range);
    final List<TopProductSummary> topProductsPreview =
        await getTopProductsOverall(range);
    final PaymentSplitSummary paymentSplitSummary = await getPaymentSplit(
      range,
    );

    return OverviewMetrics(
      totalRevenueMinor: revenueMetrics.totalRevenueMinor,
      orderCount: revenueMetrics.orderCount,
      averageOrderValueMinor: revenueMetrics.averageOrderValueMinor,
      topProductsPreview: topProductsPreview,
      paymentSplitSummary: paymentSplitSummary,
    );
  }

  @override
  Future<RevenueMetrics> getRevenueMetrics(AnalyticsDateRange range) async {
    final QueryRow row = await _database
        .customSelect(
          '''
          SELECT
            COALESCE(SUM(tx.total_amount_minor), 0) AS total_revenue_minor,
            COUNT(*) AS order_count
          FROM transactions tx
          WHERE ${_paidAtWindowWhereClause('tx')}
          ''',
          variables: _paidAtWindowVariables(range),
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.transactions,
          },
        )
        .getSingle();

    final int totalRevenueMinor = row.read<int>('total_revenue_minor');
    final int orderCount = row.read<int>('order_count');

    return RevenueMetrics(
      totalRevenueMinor: totalRevenueMinor,
      orderCount: orderCount,
      averageOrderValueMinor: orderCount == 0
          ? 0
          : totalRevenueMinor ~/ orderCount,
    );
  }

  @override
  Future<List<DailyRevenuePoint>> getDailyRevenueSeries(
    AnalyticsDateRange range,
  ) async {
    final List<QueryRow> rows = await _database
        .customSelect(
          '''
          SELECT
            tx.paid_at AS paid_at_value,
            tx.total_amount_minor AS revenue_minor
          FROM transactions tx
          WHERE ${_paidAtWindowWhereClause('tx')}
          ORDER BY tx.paid_at ASC
          ''',
          variables: _paidAtWindowVariables(range),
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.transactions,
          },
        )
        .get();

    final Map<DateTime, _DailyRevenueAccumulator> groupedByDay =
        <DateTime, _DailyRevenueAccumulator>{};
    for (final QueryRow row in rows) {
      final DateTime paidAt = _parsePaidAtValue(row.data['paid_at_value']);
      final DateTime day = AnalyticsDateRange.startOfCivilDay(paidAt);
      final _DailyRevenueAccumulator accumulator =
          groupedByDay[day] ?? _DailyRevenueAccumulator(date: day);
      accumulator.revenueMinor += row.read<int>('revenue_minor');
      accumulator.orderCount += 1;
      groupedByDay[day] = accumulator;
    }

    final List<DateTime> orderedDays = groupedByDay.keys.toList()..sort();
    return orderedDays
        .map((DateTime day) => groupedByDay[day]!.toPoint())
        .toList(growable: false);
  }

  @override
  Future<List<TopProductSummary>> getTopProductsOverall(
    AnalyticsDateRange range, {
    int limit = 3,
  }) async {
    if (limit <= 0) {
      return const <TopProductSummary>[];
    }

    final List<QueryRow> rows = await _database
        .customSelect(
          '''
          SELECT
            tl.product_id,
            tl.product_name,
            COALESCE(SUM(tl.line_total_minor), 0) AS revenue_minor,
            COALESCE(SUM(tl.quantity), 0) AS quantity_count
          FROM transaction_lines tl
          INNER JOIN transactions tx ON tx.id = tl.transaction_id
          WHERE ${_paidAtWindowWhereClause('tx')}
          GROUP BY tl.product_id, tl.product_name
          ORDER BY revenue_minor DESC,
                   quantity_count DESC,
                   lower(trim(tl.product_name)) ASC,
                   tl.product_id ASC
          LIMIT ?
          ''',
          variables: <Variable<Object>>[
            ..._paidAtWindowVariables(range),
            Variable<int>(limit),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.transactionLines,
            _database.transactions,
          },
        )
        .get();

    return rows
        .map(
          (QueryRow row) => TopProductSummary(
            productId: row.read<int>('product_id'),
            productName: row.read<String>('product_name'),
            revenueMinor: row.read<int>('revenue_minor'),
            quantityCount: row.read<int>('quantity_count'),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PaymentSplitSummary> getPaymentSplit(AnalyticsDateRange range) async {
    // Payment split stays rooted in the payments table. The current POS flow
    // does not support split payments, so each paid payment row maps to one
    // paid order and both revenue and order counts can be taken directly from
    // persisted payment rows instead of inferring from transaction totals.
    final QueryRow row = await _database
        .customSelect(
          '''
          SELECT
            COALESCE(SUM(CASE WHEN p.method = 'cash' THEN p.amount_minor ELSE 0 END), 0) AS cash_revenue_minor,
            COALESCE(SUM(CASE WHEN p.method = 'card' THEN p.amount_minor ELSE 0 END), 0) AS card_revenue_minor,
            COALESCE(SUM(CASE WHEN p.method = 'cash' THEN 1 ELSE 0 END), 0) AS cash_order_count,
            COALESCE(SUM(CASE WHEN p.method = 'card' THEN 1 ELSE 0 END), 0) AS card_order_count
          FROM payments p
          INNER JOIN transactions tx ON tx.id = p.transaction_id
          WHERE ${_paidAtWindowWhereClause('tx')}
          ''',
          variables: _paidAtWindowVariables(range),
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.payments,
            _database.transactions,
          },
        )
        .getSingle();

    final int cashRevenueMinor = row.read<int>('cash_revenue_minor');
    final int cardRevenueMinor = row.read<int>('card_revenue_minor');

    return PaymentSplitSummary(
      cashRevenueMinor: cashRevenueMinor,
      cardRevenueMinor: cardRevenueMinor,
      totalRevenueMinor: cashRevenueMinor + cardRevenueMinor,
      cashOrderCount: row.read<int>('cash_order_count'),
      cardOrderCount: row.read<int>('card_order_count'),
    );
  }

  @override
  Future<List<CategoryProductAnalyticsSection>> getCategoryProductSections(
    AnalyticsDateRange range, {
    int perCategoryLimit = 5,
  }) async {
    if (perCategoryLimit <= 0) {
      return const <CategoryProductAnalyticsSection>[];
    }

    final List<QueryRow> rows = await _database
        .customSelect(
          '''
          SELECT
            c.id AS category_id,
            c.name AS category_name,
            tl.product_id,
            tl.product_name,
            COALESCE(SUM(tl.line_total_minor), 0) AS revenue_minor,
            COALESCE(SUM(tl.quantity), 0) AS quantity_count
          FROM transaction_lines tl
          INNER JOIN transactions tx ON tx.id = tl.transaction_id
          INNER JOIN products p ON p.id = tl.product_id
          INNER JOIN categories c ON c.id = p.category_id
          WHERE ${_paidAtWindowWhereClause('tx')}
          GROUP BY c.id, c.name, tl.product_id, tl.product_name
          ORDER BY c.id ASC,
                   revenue_minor DESC,
                   quantity_count DESC,
                   lower(trim(tl.product_name)) ASC,
                   tl.product_id ASC
          ''',
          variables: _paidAtWindowVariables(range),
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.transactionLines,
            _database.transactions,
            _database.products,
            _database.categories,
          },
        )
        .get();

    final Map<int, _CategorySectionAccumulator> sectionsByCategoryId =
        <int, _CategorySectionAccumulator>{};
    for (final QueryRow row in rows) {
      final int categoryId = row.read<int>('category_id');
      final _CategorySectionAccumulator accumulator = sectionsByCategoryId
          .putIfAbsent(
            categoryId,
            () => _CategorySectionAccumulator(
              categoryId: categoryId,
              categoryName: row.read<String>('category_name'),
            ),
          );

      final ProductAnalyticsItem item = ProductAnalyticsItem(
        productId: row.read<int>('product_id'),
        productName: row.read<String>('product_name'),
        revenueMinor: row.read<int>('revenue_minor'),
        quantityCount: row.read<int>('quantity_count'),
      );
      accumulator.totalRevenueMinor += item.revenueMinor;
      if (accumulator.products.length < perCategoryLimit) {
        accumulator.products.add(item);
      }
    }

    final List<CategoryProductAnalyticsSection> sections = sectionsByCategoryId
        .values
        .map(
          (_CategorySectionAccumulator accumulator) =>
              CategoryProductAnalyticsSection(
                categoryId: accumulator.categoryId,
                categoryName: accumulator.categoryName,
                totalRevenueMinor: accumulator.totalRevenueMinor,
                products: List<ProductAnalyticsItem>.unmodifiable(
                  accumulator.products,
                ),
              ),
        )
        .toList(growable: false);

    sections.sort(_compareCategorySections);
    return sections;
  }

  String _paidAtWindowWhereClause(String transactionAlias) {
    return '''
      $transactionAlias.status = ?
      AND $transactionAlias.paid_at IS NOT NULL
      AND $transactionAlias.paid_at >= ?
      AND $transactionAlias.paid_at < ?
    ''';
  }

  List<Variable<Object>> _paidAtWindowVariables(AnalyticsDateRange range) {
    return <Variable<Object>>[
      Variable<String>(_paidStatus),
      Variable<DateTime>(range.startInclusive),
      Variable<DateTime>(range.endExclusive),
    ];
  }

  int _compareCategorySections(
    CategoryProductAnalyticsSection left,
    CategoryProductAnalyticsSection right,
  ) {
    final int revenueComparison = right.totalRevenueMinor.compareTo(
      left.totalRevenueMinor,
    );
    if (revenueComparison != 0) {
      return revenueComparison;
    }
    final int nameComparison = left.categoryName.toLowerCase().compareTo(
      right.categoryName.toLowerCase(),
    );
    if (nameComparison != 0) {
      return nameComparison;
    }
    return left.categoryId.compareTo(right.categoryId);
  }

  DateTime _parsePaidAtValue(Object? rawValue) {
    if (rawValue is DateTime) {
      return rawValue;
    }
    if (rawValue is int) {
      return _dateTimeFromEpoch(rawValue);
    }
    if (rawValue is String) {
      final DateTime? parsedDateTime = DateTime.tryParse(rawValue);
      if (parsedDateTime != null) {
        return parsedDateTime;
      }
      final int? parsedEpoch = int.tryParse(rawValue);
      if (parsedEpoch != null) {
        return _dateTimeFromEpoch(parsedEpoch);
      }
    }
    throw StateError('Unsupported analytics paid_at value: $rawValue');
  }

  DateTime _dateTimeFromEpoch(int value) {
    return value >= 100000000000
        ? DateTime.fromMillisecondsSinceEpoch(value)
        : DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
}

class _CategorySectionAccumulator {
  _CategorySectionAccumulator({
    required this.categoryId,
    required this.categoryName,
  });

  final int categoryId;
  final String categoryName;
  final List<ProductAnalyticsItem> products = <ProductAnalyticsItem>[];
  int totalRevenueMinor = 0;
}

class _DailyRevenueAccumulator {
  _DailyRevenueAccumulator({required this.date});

  final DateTime date;
  int revenueMinor = 0;
  int orderCount = 0;

  DailyRevenuePoint toPoint() {
    return DailyRevenuePoint(
      date: date,
      revenueMinor: revenueMinor,
      orderCount: orderCount,
    );
  }
}
