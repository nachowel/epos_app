import 'package:drift/drift.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/analytics_repository.dart';
import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:epos_app/domain/models/analytics/category_product_analytics_section.dart';
import 'package:epos_app/domain/models/analytics/daily_revenue_point.dart';
import 'package:epos_app/domain/models/analytics/overview_metrics.dart';
import 'package:epos_app/domain/models/analytics/payment_split_summary.dart';
import 'package:epos_app/domain/models/analytics/product_analytics_item.dart';
import 'package:epos_app/domain/models/analytics/revenue_metrics.dart';
import 'package:epos_app/domain/models/analytics/top_product_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('DriftAnalyticsRepository', () {
    late AppDatabase db;
    late DriftAnalyticsRepository repository;
    late _CatalogFixture fixture;

    setUp(() async {
      db = createTestDatabase();
      repository = DriftAnalyticsRepository(db);
      fixture = await _CatalogFixture.create(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('includes only paid transactions in overview metrics', () async {
      await fixture.addOrder(
        uuid: 'paid-cash',
        status: 'paid',
        totalAmountMinor: 1000,
        paidAt: DateTime(2026, 4, 10, 9),
        paymentMethod: 'cash',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.coffeeId,
            productName: 'Coffee',
            lineTotalMinor: 1000,
            quantity: 1,
            unitPriceMinor: 1000,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'paid-card',
        status: 'paid',
        totalAmountMinor: 2000,
        paidAt: DateTime(2026, 4, 10, 12),
        paymentMethod: 'card',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.burgerId,
            productName: 'Burger',
            lineTotalMinor: 2000,
            quantity: 2,
            unitPriceMinor: 1000,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'draft-order',
        status: 'draft',
        totalAmountMinor: 500,
        updatedAt: DateTime(2026, 4, 10, 13),
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.teaId,
            productName: 'Tea',
            lineTotalMinor: 500,
            quantity: 1,
            unitPriceMinor: 500,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'sent-order',
        status: 'sent',
        totalAmountMinor: 700,
        updatedAt: DateTime(2026, 4, 10, 14),
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.friesId,
            productName: 'Fries',
            lineTotalMinor: 700,
            quantity: 1,
            unitPriceMinor: 700,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'cancelled-order',
        status: 'cancelled',
        totalAmountMinor: 900,
        updatedAt: DateTime(2026, 4, 10, 15),
        cancelledAt: DateTime(2026, 4, 10, 15),
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.saladId,
            productName: 'Salad',
            lineTotalMinor: 900,
            quantity: 1,
            unitPriceMinor: 900,
          ),
        ],
      );

      final OverviewMetrics metrics = await repository.getOverviewMetrics(
        _dayRange(2026, 4, 10),
      );

      expect(metrics.totalRevenueMinor, 3000);
      expect(metrics.orderCount, 2);
      expect(metrics.averageOrderValueMinor, 1500);
      expect(metrics.topProductsPreview, const <TopProductSummary>[
        TopProductSummary(
          productId: 3,
          productName: 'Burger',
          revenueMinor: 2000,
          quantityCount: 2,
        ),
        TopProductSummary(
          productId: 1,
          productName: 'Coffee',
          revenueMinor: 1000,
          quantityCount: 1,
        ),
      ]);
      expect(
        metrics.paymentSplitSummary,
        const PaymentSplitSummary(
          cashRevenueMinor: 1000,
          cardRevenueMinor: 2000,
          totalRevenueMinor: 3000,
          cashOrderCount: 1,
          cardOrderCount: 1,
        ),
      );
    });

    test(
      'excludes paid transactions outside the paid_at date window',
      () async {
        await fixture.addOrder(
          uuid: 'paid-previous-day',
          status: 'paid',
          totalAmountMinor: 1200,
          paidAt: DateTime(2026, 4, 9, 18),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.teaId,
              productName: 'Tea',
              lineTotalMinor: 1200,
              quantity: 2,
              unitPriceMinor: 600,
            ),
          ],
        );
        await fixture.addOrder(
          uuid: 'paid-current-day',
          status: 'paid',
          totalAmountMinor: 800,
          paidAt: DateTime(2026, 4, 10, 10),
          paymentMethod: 'card',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.coffeeId,
              productName: 'Coffee',
              lineTotalMinor: 800,
              quantity: 1,
              unitPriceMinor: 800,
            ),
          ],
        );

        final OverviewMetrics metrics = await repository.getOverviewMetrics(
          _dayRange(2026, 4, 10),
        );

        expect(metrics.totalRevenueMinor, 800);
        expect(metrics.orderCount, 1);
        expect(metrics.topProductsPreview, const <TopProductSummary>[
          TopProductSummary(
            productId: 1,
            productName: 'Coffee',
            revenueMinor: 800,
            quantityCount: 1,
          ),
        ]);
      },
    );

    test('returns paid-only revenue metrics from transaction totals', () async {
      await fixture.addOrder(
        uuid: 'revenue-paid-1',
        status: 'paid',
        totalAmountMinor: 1200,
        paidAt: DateTime(2026, 4, 10, 9),
        paymentMethod: 'cash',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.coffeeId,
            productName: 'Coffee',
            lineTotalMinor: 1200,
            quantity: 1,
            unitPriceMinor: 1200,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'revenue-paid-2',
        status: 'paid',
        totalAmountMinor: 1800,
        paidAt: DateTime(2026, 4, 10, 11),
        paymentMethod: 'card',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.burgerId,
            productName: 'Burger',
            lineTotalMinor: 1800,
            quantity: 1,
            unitPriceMinor: 1800,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'revenue-sent',
        status: 'sent',
        totalAmountMinor: 9999,
        updatedAt: DateTime(2026, 4, 10, 12),
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.teaId,
            productName: 'Tea',
            lineTotalMinor: 9999,
            quantity: 1,
            unitPriceMinor: 9999,
          ),
        ],
      );

      expect(
        await repository.getRevenueMetrics(_dayRange(2026, 4, 10)),
        const RevenueMetrics(
          totalRevenueMinor: 3000,
          orderCount: 2,
          averageOrderValueMinor: 1500,
        ),
      );
    });

    test(
      'returns ordered daily paid revenue series grouped by paid_at',
      () async {
        await fixture.addOrder(
          uuid: 'series-day-1a',
          status: 'paid',
          totalAmountMinor: 1000,
          paidAt: DateTime(2026, 4, 10, 9),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.coffeeId,
              productName: 'Coffee',
              lineTotalMinor: 1000,
              quantity: 1,
              unitPriceMinor: 1000,
            ),
          ],
        );
        await fixture.addOrder(
          uuid: 'series-day-1b',
          status: 'paid',
          totalAmountMinor: 500,
          paidAt: DateTime(2026, 4, 10, 14),
          paymentMethod: 'card',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.teaId,
              productName: 'Tea',
              lineTotalMinor: 500,
              quantity: 1,
              unitPriceMinor: 500,
            ),
          ],
        );
        await fixture.addOrder(
          uuid: 'series-day-3',
          status: 'paid',
          totalAmountMinor: 2200,
          paidAt: DateTime(2026, 4, 12, 10),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.burgerId,
              productName: 'Burger',
              lineTotalMinor: 2200,
              quantity: 2,
              unitPriceMinor: 1100,
            ),
          ],
        );
        await fixture.addOrder(
          uuid: 'series-outside-window',
          status: 'paid',
          totalAmountMinor: 999,
          paidAt: DateTime(2026, 4, 13, 9),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.saladId,
              productName: 'Salad',
              lineTotalMinor: 999,
              quantity: 1,
              unitPriceMinor: 999,
            ),
          ],
        );

        expect(
          await repository.getDailyRevenueSeries(
            AnalyticsDateRange.explicit(
              startInclusive: DateTime(2026, 4, 10),
              endExclusive: DateTime(2026, 4, 13),
            ),
          ),
          <DailyRevenuePoint>[
            DailyRevenuePoint(
              date: DateTime(2026, 4, 10),
              revenueMinor: 1500,
              orderCount: 2,
            ),
            DailyRevenuePoint(
              date: DateTime(2026, 4, 12),
              revenueMinor: 2200,
              orderCount: 1,
            ),
          ],
        );
      },
    );

    test('returns payment split for cash-only datasets', () async {
      await fixture.addOrder(
        uuid: 'cash-1',
        status: 'paid',
        totalAmountMinor: 800,
        paidAt: DateTime(2026, 4, 10, 9),
        paymentMethod: 'cash',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.coffeeId,
            productName: 'Coffee',
            lineTotalMinor: 800,
            quantity: 1,
            unitPriceMinor: 800,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'cash-2',
        status: 'paid',
        totalAmountMinor: 900,
        paidAt: DateTime(2026, 4, 10, 11),
        paymentMethod: 'cash',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.teaId,
            productName: 'Tea',
            lineTotalMinor: 900,
            quantity: 1,
            unitPriceMinor: 900,
          ),
        ],
      );

      expect(
        await repository.getPaymentSplit(_dayRange(2026, 4, 10)),
        const PaymentSplitSummary(
          cashRevenueMinor: 1700,
          cardRevenueMinor: 0,
          totalRevenueMinor: 1700,
          cashOrderCount: 2,
          cardOrderCount: 0,
        ),
      );
    });

    test('returns payment split for card-only datasets', () async {
      await fixture.addOrder(
        uuid: 'card-1',
        status: 'paid',
        totalAmountMinor: 1000,
        paidAt: DateTime(2026, 4, 10, 9),
        paymentMethod: 'card',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.burgerId,
            productName: 'Burger',
            lineTotalMinor: 1000,
            quantity: 1,
            unitPriceMinor: 1000,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'card-2',
        status: 'paid',
        totalAmountMinor: 1100,
        paidAt: DateTime(2026, 4, 10, 13),
        paymentMethod: 'card',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.saladId,
            productName: 'Salad',
            lineTotalMinor: 1100,
            quantity: 1,
            unitPriceMinor: 1100,
          ),
        ],
      );

      expect(
        await repository.getPaymentSplit(_dayRange(2026, 4, 10)),
        const PaymentSplitSummary(
          cashRevenueMinor: 0,
          cardRevenueMinor: 2100,
          totalRevenueMinor: 2100,
          cashOrderCount: 0,
          cardOrderCount: 2,
        ),
      );
    });

    test('returns payment split for mixed payment datasets', () async {
      await fixture.addOrder(
        uuid: 'mixed-cash',
        status: 'paid',
        totalAmountMinor: 900,
        paidAt: DateTime(2026, 4, 10, 9),
        paymentMethod: 'cash',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.coffeeId,
            productName: 'Coffee',
            lineTotalMinor: 900,
            quantity: 1,
            unitPriceMinor: 900,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'mixed-card',
        status: 'paid',
        totalAmountMinor: 1300,
        paidAt: DateTime(2026, 4, 10, 10),
        paymentMethod: 'card',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.burgerId,
            productName: 'Burger',
            lineTotalMinor: 1300,
            quantity: 1,
            unitPriceMinor: 1300,
          ),
        ],
      );

      expect(
        await repository.getPaymentSplit(_dayRange(2026, 4, 10)),
        const PaymentSplitSummary(
          cashRevenueMinor: 900,
          cardRevenueMinor: 1300,
          totalRevenueMinor: 2200,
          cashOrderCount: 1,
          cardOrderCount: 1,
        ),
      );
    });

    test(
      'includes custom sale in financial totals and payment split but excludes it from analytics rollups',
      () async {
        await fixture.addOrder(
          uuid: 'custom-financial-cash',
          status: 'paid',
          totalAmountMinor: 1100,
          paidAt: DateTime(2026, 4, 10, 9),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.customSaleProductId,
              productName: 'Custom Sale',
              lineTotalMinor: 1100,
              quantity: 1,
              unitPriceMinor: 1100,
            ),
          ],
        );
        await fixture.addOrder(
          uuid: 'custom-financial-card',
          status: 'paid',
          totalAmountMinor: 2000,
          paidAt: DateTime(2026, 4, 10, 10),
          paymentMethod: 'card',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.burgerId,
              productName: 'Burger',
              lineTotalMinor: 2000,
              quantity: 1,
              unitPriceMinor: 2000,
            ),
          ],
        );

        final OverviewMetrics metrics = await repository.getOverviewMetrics(
          _dayRange(2026, 4, 10),
        );
        final List<CategoryProductAnalyticsSection> categories =
            await repository.getCategoryProductSections(_dayRange(2026, 4, 10));

        expect(metrics.totalRevenueMinor, 3100);
        expect(
          metrics.paymentSplitSummary,
          const PaymentSplitSummary(
            cashRevenueMinor: 1100,
            cardRevenueMinor: 2000,
            totalRevenueMinor: 3100,
            cashOrderCount: 1,
            cardOrderCount: 1,
          ),
        );
        expect(metrics.customSalesRevenueMinor, 1100);
        expect(metrics.customSalesCount, 1);
        expect(metrics.customSalesAverageValueMinor, 1100);
        expect(metrics.topProductsPreview, const <TopProductSummary>[
          TopProductSummary(
            productId: 3,
            productName: 'Burger',
            revenueMinor: 2000,
            quantityCount: 1,
          ),
        ]);
        expect(categories, const <CategoryProductAnalyticsSection>[
          CategoryProductAnalyticsSection(
            categoryId: 2,
            categoryName: 'Food',
            totalRevenueMinor: 2000,
            products: <ProductAnalyticsItem>[
              ProductAnalyticsItem(
                productId: 3,
                productName: 'Burger',
                revenueMinor: 2000,
                quantityCount: 1,
              ),
            ],
          ),
        ]);
      },
    );

    test(
      'excludes only the real custom product even when a normal product is named Custom Sale',
      () async {
        await fixture.addOrder(
          uuid: 'custom-name-real',
          status: 'paid',
          totalAmountMinor: 950,
          paidAt: DateTime(2026, 4, 10, 9),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.customSaleProductId,
              productName: 'Custom Sale',
              lineTotalMinor: 950,
              quantity: 1,
              unitPriceMinor: 950,
            ),
          ],
        );
        await fixture.addOrder(
          uuid: 'custom-name-normal',
          status: 'paid',
          totalAmountMinor: 1250,
          paidAt: DateTime(2026, 4, 10, 11),
          paymentMethod: 'card',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.namedLikeCustomProductId,
              productName: 'Custom Sale',
              lineTotalMinor: 1250,
              quantity: 1,
              unitPriceMinor: 1250,
            ),
          ],
        );

        expect(
          await repository.getTopProductsOverall(_dayRange(2026, 4, 10)),
          <TopProductSummary>[
            TopProductSummary(
              productId: fixture.namedLikeCustomProductId,
              productName: 'Custom Sale',
              revenueMinor: 1250,
              quantityCount: 1,
            ),
          ],
        );

        final OverviewMetrics metrics = await repository.getOverviewMetrics(
          _dayRange(2026, 4, 10),
        );
        expect(metrics.totalRevenueMinor, 2200);
        expect(metrics.customSalesRevenueMinor, 950);
        expect(metrics.customSalesCount, 1);
      },
    );

    test(
      'custom-only periods stay in revenue series while product analytics remain empty',
      () async {
        await fixture.addOrder(
          uuid: 'custom-only-day-1',
          status: 'paid',
          totalAmountMinor: 500,
          paidAt: DateTime(2026, 4, 10, 9),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.customSaleProductId,
              productName: 'Custom Sale',
              lineTotalMinor: 500,
              quantity: 1,
              unitPriceMinor: 500,
            ),
          ],
        );
        await fixture.addOrder(
          uuid: 'custom-only-day-2',
          status: 'paid',
          totalAmountMinor: 700,
          paidAt: DateTime(2026, 4, 11, 9),
          paymentMethod: 'card',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.customSaleProductId,
              productName: 'Custom Sale',
              lineTotalMinor: 700,
              quantity: 1,
              unitPriceMinor: 700,
            ),
          ],
        );

        expect(
          await repository.getRevenueMetrics(
            AnalyticsDateRange.explicit(
              startInclusive: DateTime(2026, 4, 10),
              endExclusive: DateTime(2026, 4, 12),
            ),
          ),
          const RevenueMetrics(
            totalRevenueMinor: 1200,
            orderCount: 2,
            averageOrderValueMinor: 600,
          ),
        );
        expect(
          await repository.getDailyRevenueSeries(
            AnalyticsDateRange.explicit(
              startInclusive: DateTime(2026, 4, 10),
              endExclusive: DateTime(2026, 4, 12),
            ),
          ),
          <DailyRevenuePoint>[
            DailyRevenuePoint(
              date: DateTime(2026, 4, 10),
              revenueMinor: 500,
              orderCount: 1,
            ),
            DailyRevenuePoint(
              date: DateTime(2026, 4, 11),
              revenueMinor: 700,
              orderCount: 1,
            ),
          ],
        );
        expect(
          await repository.getTopProductsOverall(
            AnalyticsDateRange.explicit(
              startInclusive: DateTime(2026, 4, 10),
              endExclusive: DateTime(2026, 4, 12),
            ),
          ),
          isEmpty,
        );
        expect(
          await repository.getCategoryProductSections(
            AnalyticsDateRange.explicit(
              startInclusive: DateTime(2026, 4, 10),
              endExclusive: DateTime(2026, 4, 12),
            ),
          ),
          isEmpty,
        );
      },
    );

    test(
      'custom sales count is based on line count rather than quantity sum',
      () async {
        final int transactionId = await fixture.addOrder(
          uuid: 'custom-line-count',
          status: 'paid',
          totalAmountMinor: 1800,
          paidAt: DateTime(2026, 4, 10, 15),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.customSaleProductId,
              productName: 'Custom Sale',
              lineTotalMinor: 1800,
              quantity: 3,
              unitPriceMinor: 600,
            ),
          ],
        );
        await (db.update(db.transactionLines)
              ..where((tbl) => tbl.transactionId.equals(transactionId)))
            .write(const TransactionLinesCompanion(quantity: Value<int>(3)));

        final OverviewMetrics metrics = await repository.getOverviewMetrics(
          _dayRange(2026, 4, 10),
        );

        expect(metrics.customSalesRevenueMinor, 1800);
        expect(metrics.customSalesCount, 1);
        expect(metrics.customSalesAverageValueMinor, 1800);
      },
    );

    test('sorts top products by revenue desc and applies limit', () async {
      await fixture.addOrder(
        uuid: 'top-products-1',
        status: 'paid',
        totalAmountMinor: 3000,
        paidAt: DateTime(2026, 4, 10, 9),
        paymentMethod: 'cash',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.burgerId,
            productName: 'Burger',
            lineTotalMinor: 3000,
            quantity: 2,
            unitPriceMinor: 1500,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'top-products-2',
        status: 'paid',
        totalAmountMinor: 1500,
        paidAt: DateTime(2026, 4, 10, 11),
        paymentMethod: 'card',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.teaId,
            productName: 'Tea',
            lineTotalMinor: 1500,
            quantity: 3,
            unitPriceMinor: 500,
          ),
        ],
      );
      await fixture.addOrder(
        uuid: 'top-products-3',
        status: 'paid',
        totalAmountMinor: 1500,
        paidAt: DateTime(2026, 4, 10, 12),
        paymentMethod: 'cash',
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.coffeeId,
            productName: 'Coffee',
            lineTotalMinor: 1500,
            quantity: 2,
            unitPriceMinor: 750,
          ),
        ],
      );

      expect(
        await repository.getTopProductsOverall(
          _dayRange(2026, 4, 10),
          limit: 2,
        ),
        const <TopProductSummary>[
          TopProductSummary(
            productId: 3,
            productName: 'Burger',
            revenueMinor: 3000,
            quantityCount: 2,
          ),
          TopProductSummary(
            productId: 2,
            productName: 'Tea',
            revenueMinor: 1500,
            quantityCount: 3,
          ),
        ],
      );
    });

    test('returns category product sections sorted by revenue desc', () async {
      await _seedCategoryAnalyticsDataset(fixture);

      expect(
        await repository.getCategoryProductSections(_dayRange(2026, 4, 10)),
        const <CategoryProductAnalyticsSection>[
          CategoryProductAnalyticsSection(
            categoryId: 2,
            categoryName: 'Food',
            totalRevenueMinor: 4500,
            products: <ProductAnalyticsItem>[
              ProductAnalyticsItem(
                productId: 3,
                productName: 'Burger',
                revenueMinor: 3000,
                quantityCount: 2,
              ),
              ProductAnalyticsItem(
                productId: 4,
                productName: 'Fries',
                revenueMinor: 1200,
                quantityCount: 2,
              ),
              ProductAnalyticsItem(
                productId: 5,
                productName: 'Salad',
                revenueMinor: 300,
                quantityCount: 1,
              ),
            ],
          ),
          CategoryProductAnalyticsSection(
            categoryId: 1,
            categoryName: 'Beverages',
            totalRevenueMinor: 2500,
            products: <ProductAnalyticsItem>[
              ProductAnalyticsItem(
                productId: 2,
                productName: 'Tea',
                revenueMinor: 1500,
                quantityCount: 3,
              ),
              ProductAnalyticsItem(
                productId: 1,
                productName: 'Coffee',
                revenueMinor: 1000,
                quantityCount: 1,
              ),
            ],
          ),
        ],
      );
    });

    test(
      'applies per-category product limits without changing totals',
      () async {
        await _seedCategoryAnalyticsDataset(fixture);

        expect(
          await repository.getCategoryProductSections(
            _dayRange(2026, 4, 10),
            perCategoryLimit: 1,
          ),
          const <CategoryProductAnalyticsSection>[
            CategoryProductAnalyticsSection(
              categoryId: 2,
              categoryName: 'Food',
              totalRevenueMinor: 4500,
              products: <ProductAnalyticsItem>[
                ProductAnalyticsItem(
                  productId: 3,
                  productName: 'Burger',
                  revenueMinor: 3000,
                  quantityCount: 2,
                ),
              ],
            ),
            CategoryProductAnalyticsSection(
              categoryId: 1,
              categoryName: 'Beverages',
              totalRevenueMinor: 2500,
              products: <ProductAnalyticsItem>[
                ProductAnalyticsItem(
                  productId: 2,
                  productName: 'Tea',
                  revenueMinor: 1500,
                  quantityCount: 3,
                ),
              ],
            ),
          ],
        );
      },
    );

    test(
      'uses transaction line snapshots for product names and revenue',
      () async {
        await fixture.addOrder(
          uuid: 'snapshot-order',
          status: 'paid',
          totalAmountMinor: 1500,
          paidAt: DateTime(2026, 4, 10, 14),
          paymentMethod: 'cash',
          lines: <_SoldLine>[
            fixture.line(
              productId: fixture.coffeeId,
              productName: 'Archived Coffee',
              lineTotalMinor: 1500,
              quantity: 1,
              unitPriceMinor: 1500,
            ),
          ],
        );
        await (db.update(
          db.products,
        )..where((tbl) => tbl.id.equals(fixture.coffeeId))).write(
          const ProductsCompanion(
            name: Value<String>('Live Coffee'),
            priceMinor: Value<int>(9999),
          ),
        );

        expect(
          await repository.getTopProductsOverall(_dayRange(2026, 4, 10)),
          const <TopProductSummary>[
            TopProductSummary(
              productId: 1,
              productName: 'Archived Coffee',
              revenueMinor: 1500,
              quantityCount: 1,
            ),
          ],
        );
      },
    );

    test('keeps payment split rooted in payments rows', () async {
      await fixture.addOrder(
        uuid: 'payment-source-order',
        status: 'paid',
        totalAmountMinor: 3000,
        paidAt: DateTime(2026, 4, 10, 15),
        paymentMethod: 'cash',
        paymentAmountMinor: 2500,
        lines: <_SoldLine>[
          fixture.line(
            productId: fixture.coffeeId,
            productName: 'Coffee',
            lineTotalMinor: 3000,
            quantity: 1,
            unitPriceMinor: 3000,
          ),
        ],
      );

      final AnalyticsDateRange range = _dayRange(2026, 4, 10);
      final PaymentSplitSummary split = await repository.getPaymentSplit(range);
      final OverviewMetrics overview = await repository.getOverviewMetrics(
        range,
      );

      expect(
        split,
        const PaymentSplitSummary(
          cashRevenueMinor: 2500,
          cardRevenueMinor: 0,
          totalRevenueMinor: 2500,
          cashOrderCount: 1,
          cardOrderCount: 0,
        ),
      );
      expect(overview.totalRevenueMinor, 3000);
    });
  });
}

Future<void> _seedCategoryAnalyticsDataset(_CatalogFixture fixture) async {
  await fixture.addOrder(
    uuid: 'category-food-1',
    status: 'paid',
    totalAmountMinor: 4200,
    paidAt: DateTime(2026, 4, 10, 10),
    paymentMethod: 'cash',
    lines: <_SoldLine>[
      fixture.line(
        productId: fixture.burgerId,
        productName: 'Burger',
        lineTotalMinor: 3000,
        quantity: 2,
        unitPriceMinor: 1500,
      ),
      fixture.line(
        productId: fixture.friesId,
        productName: 'Fries',
        lineTotalMinor: 1200,
        quantity: 2,
        unitPriceMinor: 600,
      ),
    ],
  );
  await fixture.addOrder(
    uuid: 'category-drinks',
    status: 'paid',
    totalAmountMinor: 2500,
    paidAt: DateTime(2026, 4, 10, 11),
    paymentMethod: 'card',
    lines: <_SoldLine>[
      fixture.line(
        productId: fixture.teaId,
        productName: 'Tea',
        lineTotalMinor: 1500,
        quantity: 3,
        unitPriceMinor: 500,
      ),
      fixture.line(
        productId: fixture.coffeeId,
        productName: 'Coffee',
        lineTotalMinor: 1000,
        quantity: 1,
        unitPriceMinor: 1000,
      ),
    ],
  );
  await fixture.addOrder(
    uuid: 'category-food-2',
    status: 'paid',
    totalAmountMinor: 300,
    paidAt: DateTime(2026, 4, 10, 13),
    paymentMethod: 'cash',
    lines: <_SoldLine>[
      fixture.line(
        productId: fixture.saladId,
        productName: 'Salad',
        lineTotalMinor: 300,
        quantity: 1,
        unitPriceMinor: 300,
      ),
    ],
  );
}

AnalyticsDateRange _dayRange(int year, int month, int day) {
  return AnalyticsDateRange.explicit(
    startInclusive: DateTime(year, month, day),
    endExclusive: DateTime(year, month, day + 1),
  );
}

class _CatalogFixture {
  _CatalogFixture({
    required this.db,
    required this.userId,
    required this.shiftId,
    required this.beveragesCategoryId,
    required this.foodCategoryId,
    required this.coffeeId,
    required this.teaId,
    required this.burgerId,
    required this.friesId,
    required this.saladId,
    required this.customSaleProductId,
    required this.namedLikeCustomProductId,
  });

  final AppDatabase db;
  final int userId;
  final int shiftId;
  final int beveragesCategoryId;
  final int foodCategoryId;
  final int coffeeId;
  final int teaId;
  final int burgerId;
  final int friesId;
  final int saladId;
  final int customSaleProductId;
  final int namedLikeCustomProductId;

  static Future<_CatalogFixture> create(AppDatabase db) async {
    final int userId = await insertUser(db, name: 'Admin', role: 'admin');
    final int shiftId = await insertShift(db, openedBy: userId);
    final int beveragesCategoryId = await insertCategory(db, name: 'Beverages');
    final int foodCategoryId = await insertCategory(db, name: 'Food');

    return _CatalogFixture(
      db: db,
      userId: userId,
      shiftId: shiftId,
      beveragesCategoryId: beveragesCategoryId,
      foodCategoryId: foodCategoryId,
      coffeeId: await insertProduct(
        db,
        categoryId: beveragesCategoryId,
        name: 'Coffee',
        priceMinor: 1000,
      ),
      teaId: await insertProduct(
        db,
        categoryId: beveragesCategoryId,
        name: 'Tea',
        priceMinor: 500,
      ),
      burgerId: await insertProduct(
        db,
        categoryId: foodCategoryId,
        name: 'Burger',
        priceMinor: 1500,
      ),
      friesId: await insertProduct(
        db,
        categoryId: foodCategoryId,
        name: 'Fries',
        priceMinor: 600,
      ),
      saladId: await insertProduct(
        db,
        categoryId: foodCategoryId,
        name: 'Salad',
        priceMinor: 300,
      ),
      customSaleProductId: await insertProduct(
        db,
        categoryId: foodCategoryId,
        name: 'Custom Sale',
        priceMinor: 0,
        isCustom: true,
      ),
      namedLikeCustomProductId: await insertProduct(
        db,
        categoryId: beveragesCategoryId,
        name: 'Custom Sale',
        priceMinor: 1250,
      ),
    );
  }

  _SoldLine line({
    required int productId,
    required String productName,
    required int unitPriceMinor,
    required int quantity,
    required int lineTotalMinor,
  }) {
    return _SoldLine(
      productId: productId,
      productName: productName,
      unitPriceMinor: unitPriceMinor,
      quantity: quantity,
      lineTotalMinor: lineTotalMinor,
    );
  }

  Future<int> addOrder({
    required String uuid,
    required String status,
    required int totalAmountMinor,
    required List<_SoldLine> lines,
    DateTime? paidAt,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? paymentMethod,
    int? paymentAmountMinor,
  }) async {
    final int transactionId = await insertTransaction(
      db,
      uuid: 'tx-$uuid',
      shiftId: shiftId,
      userId: userId,
      status: status,
      totalAmountMinor: totalAmountMinor,
      paidAt: paidAt,
      updatedAt: updatedAt ?? paidAt ?? DateTime(2026, 4, 10),
      cancelledAt: cancelledAt,
    );
    for (final _SoldLine line in lines) {
      await _insertLine(
        db,
        transactionId: transactionId,
        productId: line.productId,
        productName: line.productName,
        unitPriceMinor: line.unitPriceMinor,
        quantity: line.quantity,
        lineTotalMinor: line.lineTotalMinor,
      );
    }
    if (status == 'paid' && paymentMethod != null) {
      await insertPayment(
        db,
        uuid: 'pay-$uuid',
        transactionId: transactionId,
        method: paymentMethod,
        amountMinor: paymentAmountMinor ?? totalAmountMinor,
        paidAt: paidAt ?? DateTime(2026, 4, 10),
      );
    }
    return transactionId;
  }
}

class _SoldLine {
  const _SoldLine({
    required this.productId,
    required this.productName,
    required this.unitPriceMinor,
    required this.quantity,
    required this.lineTotalMinor,
  });

  final int productId;
  final String productName;
  final int unitPriceMinor;
  final int quantity;
  final int lineTotalMinor;
}

int _lineSequence = 0;

Future<int> _insertLine(
  AppDatabase db, {
  required int transactionId,
  required int productId,
  required String productName,
  required int unitPriceMinor,
  required int quantity,
  required int lineTotalMinor,
}) {
  _lineSequence += 1;
  return db
      .into(db.transactionLines)
      .insert(
        TransactionLinesCompanion.insert(
          uuid: 'line-$_lineSequence',
          transactionId: transactionId,
          productId: productId,
          productName: productName,
          unitPriceMinor: unitPriceMinor,
          quantity: Value<int>(quantity),
          lineTotalMinor: lineTotalMinor,
        ),
      );
}
