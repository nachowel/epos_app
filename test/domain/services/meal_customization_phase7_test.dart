import 'package:drift/drift.dart' show QueryRow, ResultSetImplementation, Variable;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/models/meal_insights.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/meal_adjustment_profile_validation_service.dart';
import 'package:epos_app/domain/services/meal_customization_engine.dart';
import 'package:epos_app/domain/services/meal_insights_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // A. SUGGESTION CACHE
  // ─────────────────────────────────────────────────────────────────────────
  group('Suggestion cache', () {
    test('cache hit avoids second query', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final MealInsightsService insights = MealInsightsService(
        transactionRepository: txRepo,
        productRepository: ProductRepository(db),
        suggestionCacheTtl: const Duration(minutes: 5),
      );

      // Create an order with meal customization to have data.
      final order = await service.createOrder(currentUser: f.user);
      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      final Map<int, String> names = <int, String>{
        f.mealProductId: 'Burger Meal',
      };

      // First load → cache miss, queries DB.
      final List<MealQuickSuggestion> first =
          await insights.loadSuggestionsForProduct(
        productId: f.mealProductId,
        productNamesById: names,
      );

      // Second load → cache hit, no query.
      expect(insights.hasCachedSuggestions(f.mealProductId), isTrue);
      final List<MealQuickSuggestion> second =
          await insights.loadSuggestionsForProduct(
        productId: f.mealProductId,
        productNamesById: names,
      );

      // Same result.
      expect(second.length, first.length);
      if (first.isNotEmpty) {
        expect(second.first.label, first.first.label);
      }
    });

    test('cache invalidation clears entries', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final MealInsightsService insights = MealInsightsService(
        transactionRepository: txRepo,
        productRepository: ProductRepository(db),
      );

      final order = await service.createOrder(currentUser: f.user);
      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      await insights.loadSuggestionsForProduct(
        productId: f.mealProductId,
        productNamesById: <int, String>{f.mealProductId: 'Burger Meal'},
      );
      expect(insights.hasCachedSuggestions(f.mealProductId), isTrue);

      insights.invalidateSuggestionCache();
      expect(insights.hasCachedSuggestions(f.mealProductId), isFalse);
    });

    test('very short TTL causes reload on next call', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      // 1ms TTL → expires almost immediately.
      final MealInsightsService insights = MealInsightsService(
        transactionRepository: txRepo,
        productRepository: ProductRepository(db),
        suggestionCacheTtl: const Duration(milliseconds: 1),
      );

      final order = await service.createOrder(currentUser: f.user);
      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      await insights.loadSuggestionsForProduct(
        productId: f.mealProductId,
        productNamesById: <int, String>{f.mealProductId: 'Burger Meal'},
      );
      // Wait for TTL to expire.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(insights.hasCachedSuggestions(f.mealProductId), isFalse);
    });

    test('prefetch warms cache for multiple products', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final MealInsightsService insights = MealInsightsService(
        transactionRepository: txRepo,
        productRepository: ProductRepository(db),
      );

      final order = await service.createOrder(currentUser: f.user);
      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      expect(insights.hasCachedSuggestions(f.mealProductId), isFalse);

      await insights.prefetchSuggestions(
        productIds: <int>[f.mealProductId],
        productNamesById: <int, String>{f.mealProductId: 'Burger Meal'},
      );

      expect(insights.hasCachedSuggestions(f.mealProductId), isTrue);
    });

    test('invalidate single product leaves others cached', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final MealInsightsService insights = MealInsightsService(
        transactionRepository: txRepo,
        productRepository: ProductRepository(db),
      );

      final order = await service.createOrder(currentUser: f.user);
      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      // Create a second meal product.
      final int otherProductId = await insertProduct(
        db,
        categoryId: f.categoryId,
        name: 'Other Meal',
        priceMinor: 800,
      );

      final Map<int, String> names = <int, String>{
        f.mealProductId: 'Burger Meal',
        otherProductId: 'Other Meal',
      };

      await insights.prefetchSuggestions(
        productIds: <int>[f.mealProductId, otherProductId],
        productNamesById: names,
      );

      expect(insights.hasCachedSuggestions(f.mealProductId), isTrue);
      expect(insights.hasCachedSuggestions(otherProductId), isTrue);

      insights.invalidateSuggestionCacheForProduct(f.mealProductId);
      expect(insights.hasCachedSuggestions(f.mealProductId), isFalse);
      expect(insights.hasCachedSuggestions(otherProductId), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // B. SNAPSHOT LIFECYCLE CLEANUP
  // ─────────────────────────────────────────────────────────────────────────
  group('Snapshot lifecycle cleanup', () {
    test('no orphan after line merge', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final order = await service.createOrder(currentUser: f.user);
      final request = f.buildRequest(removeSide: true);

      for (int i = 0; i < 3; i++) {
        await service.addProductToOrder(
          transactionId: order.id,
          productId: f.mealProductId,
          mealCustomizationRequest: request,
        );
      }

      // Single grouped line with qty=3. Single snapshot row.
      final List<TransactionLine> lines = await _getLines(db, order.id);
      expect(lines, hasLength(1));
      expect(lines.single.quantity, 3);

      // No orphans.
      final int orphanCount =
          await txRepo.cleanupOrphanMealCustomizationSnapshots();
      expect(orphanCount, 0);
    });

    test('no orphan after line delete', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final order = await service.createOrder(currentUser: f.user);

      final TransactionLine line = await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      expect(
        await txRepo.getMealCustomizationSnapshotByLine(line.id),
        isNotNull,
      );

      await txRepo.deleteDraftLineCompletely(line.id);

      // Snapshot cleaned up during delete.
      expect(
        await txRepo.getMealCustomizationSnapshotByLine(line.id),
        isNull,
      );

      // No orphans.
      final int orphanCount =
          await txRepo.cleanupOrphanMealCustomizationSnapshots();
      expect(orphanCount, 0);
    });

    test('cleanup is idempotent', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final order = await service.createOrder(currentUser: f.user);

      final TransactionLine line = await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      // Force-delete line to create orphan.
      await db.customUpdate(
        'DELETE FROM transaction_lines WHERE id = ?',
        variables: <Variable<Object>>[Variable<int>(line.id)],
        updates: <ResultSetImplementation<dynamic, dynamic>>{},
      );

      final int first =
          await txRepo.cleanupOrphanMealCustomizationSnapshots();
      expect(first, 1);

      final int second =
          await txRepo.cleanupOrphanMealCustomizationSnapshots();
      expect(second, 0);

      // Third call still returns 0 — idempotent.
      final int third =
          await txRepo.cleanupOrphanMealCustomizationSnapshots();
      expect(third, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // C. CONCURRENT EDIT — STALE DETECTION
  // ─────────────────────────────────────────────────────────────────────────
  group('Concurrent edit stale detection', () {
    test('stale timestamp throws StaleMealCustomizationEditException', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final order = await service.createOrder(currentUser: f.user);

      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      final List<TransactionLine> lines = await _getLines(db, order.id);
      final int lineId = lines.single.id;

      // Use a stale timestamp (well in the past).
      final DateTime staleTime = DateTime(2020, 1, 1);

      await expectLater(
        service.editMealCustomizationLine(
          transactionLineId: lineId,
          request: f.buildRequest(removeSide: true, extraQuantity: 1),
          expectedTransactionUpdatedAt: staleTime,
        ),
        throwsA(isA<StaleMealCustomizationEditException>()),
      );
    });

    test('no data corruption after stale rejection', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final order = await service.createOrder(currentUser: f.user);

      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      final List<TransactionLine> before = await _getLines(db, order.id);
      final int lineId = before.single.id;
      final int qtyBefore = before.single.quantity;

      try {
        await service.editMealCustomizationLine(
          transactionLineId: lineId,
          request: f.buildRequest(removeSide: true, extraQuantity: 2),
          expectedTransactionUpdatedAt: DateTime(2020, 1, 1),
        );
      } on StaleMealCustomizationEditException {
        // Expected.
      }

      // Data unchanged.
      final List<TransactionLine> after = await _getLines(db, order.id);
      expect(after, hasLength(1));
      expect(after.single.quantity, qtyBefore);
      expect(
        await txRepo.getMealCustomizationSnapshotByLine(lineId),
        isNotNull,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // D. ADMIN LEGACY METRICS
  // ─────────────────────────────────────────────────────────────────────────
  group('Admin legacy metrics', () {
    test('legacy count aggregation by product', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final order = await service.createOrder(currentUser: f.user);

      // Create 3 legacy lines for the meal product.
      for (int i = 0; i < 3; i++) {
        final TransactionLine line = await txRepo.addLine(
          transactionId: order.id,
          productId: f.mealProductId,
          quantity: 1,
        );
        await _insertLegacyMealModifier(db, line.id);
      }

      final Map<int, int> counts =
          await txRepo.getLegacyMealCustomizationLineCountsByProduct();

      expect(counts.containsKey(f.mealProductId), isTrue);
      expect(counts[f.mealProductId], 3);
    });

    test('product-level breakdown separates products', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final order = await service.createOrder(currentUser: f.user);

      // Second product.
      final int otherProductId = await insertProduct(
        db,
        categoryId: f.categoryId,
        name: 'Chicken Meal',
        priceMinor: 900,
      );

      // 2 legacy lines for meal product, 1 for other product.
      for (int i = 0; i < 2; i++) {
        final TransactionLine line = await txRepo.addLine(
          transactionId: order.id,
          productId: f.mealProductId,
          quantity: 1,
        );
        await _insertLegacyMealModifier(db, line.id);
      }
      final TransactionLine otherLine = await txRepo.addLine(
        transactionId: order.id,
        productId: otherProductId,
        quantity: 1,
      );
      await _insertLegacyMealModifier(db, otherLine.id);

      final Map<int, int> counts =
          await txRepo.getLegacyMealCustomizationLineCountsByProduct();

      expect(counts[f.mealProductId], 2);
      expect(counts[otherProductId], 1);
    });

    test('snapshot-backed lines are not counted as legacy', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final TransactionRepository txRepo = TransactionRepository(db);
      final order = await service.createOrder(currentUser: f.user);

      // Add a snapshot-backed line.
      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );

      final Map<int, int> counts =
          await txRepo.getLegacyMealCustomizationLineCountsByProduct();

      // Snapshot-backed lines should not appear in legacy counts.
      expect(counts.containsKey(f.mealProductId), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // E. ANALYTICS MODELS
  // ─────────────────────────────────────────────────────────────────────────
  group('Analytics models', () {
    test('MealRevenueBreakdown.fromTotals calculates net correctly', () {
      final MealRevenueBreakdown breakdown = MealRevenueBreakdown.fromTotals(
        baseMinor: 1000,
        extrasMinor: 200,
        paidSwapsMinor: 50,
        discountsMinor: 100,
      );

      expect(breakdown.baseMinor, 1000);
      expect(breakdown.extrasMinor, 200);
      expect(breakdown.paidSwapsMinor, 50);
      expect(breakdown.discountsMinor, 100);
      expect(breakdown.netMinor, 1150); // 1000 + 200 + 50 - 100
    });

    test('MealRevenueBreakdown equality', () {
      final MealRevenueBreakdown a = MealRevenueBreakdown.fromTotals(
        baseMinor: 500,
        extrasMinor: 100,
        paidSwapsMinor: 0,
        discountsMinor: 50,
      );
      final MealRevenueBreakdown b = MealRevenueBreakdown.fromTotals(
        baseMinor: 500,
        extrasMinor: 100,
        paidSwapsMinor: 0,
        discountsMinor: 50,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('MealRuleImpactSummary equality', () {
      const MealRuleImpactSummary a = MealRuleImpactSummary(
        ruleId: 1,
        ruleType: 'removeOnly',
        applicationCount: 10,
        totalImpactMinor: -500,
      );
      const MealRuleImpactSummary b = MealRuleImpactSummary(
        ruleId: 1,
        ruleType: 'removeOnly',
        applicationCount: 10,
        totalImpactMinor: -500,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // F. REGRESSION
  // ─────────────────────────────────────────────────────────────────────────
  group('Regression — existing flows unbroken', () {
    test('normal product add still works', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final order = await service.createOrder(currentUser: f.user);

      final int plainProductId = await insertProduct(
        db,
        categoryId: f.categoryId,
        name: 'Water',
        priceMinor: 200,
      );
      final TransactionLine line = await service.addProductToOrder(
        transactionId: order.id,
        productId: plainProductId,
      );
      expect(line.quantity, 1);
      expect(line.lineTotalMinor, 200);
    });

    test('meal grouping still works', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final order = await service.createOrder(currentUser: f.user);
      final request = f.buildRequest(removeSide: true);

      final TransactionLine first = await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: request,
      );
      final TransactionLine second = await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: request,
      );

      expect(second.id, first.id);
      final List<TransactionLine> lines = await _getLines(db, order.id);
      expect(lines, hasLength(1));
      expect(lines.single.quantity, 2);
    });

    test('edit-all with current timestamp succeeds', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _Fixture f = await _seedFixture(db);
      final OrderService service = _buildService(db, f.repository);
      final order = await service.createOrder(currentUser: f.user);

      await service.addProductToOrder(
        transactionId: order.id,
        productId: f.mealProductId,
        mealCustomizationRequest: f.buildRequest(removeSide: true),
      );
      final Transaction tx = (await service.getOrderById(order.id))!;
      final List<TransactionLine> lines = await _getLines(db, order.id);

      final TransactionLine updated = await service.editMealCustomizationLine(
        transactionLineId: lines.single.id,
        request: f.buildRequest(removeSide: true, extraQuantity: 1),
        expectedTransactionUpdatedAt: tx.updatedAt,
      );

      expect(updated.id, lines.single.id);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

OrderService _buildService(
  dynamic db,
  DriftMealAdjustmentProfileRepository repository,
) {
  return OrderService(
    shiftSessionService: ShiftSessionService(ShiftRepository(db)),
    transactionRepository: TransactionRepository(db),
    transactionStateRepository: TransactionStateRepository(db),
    productRepository: ProductRepository(db),
    mealAdjustmentProfileRepository: repository,
    mealAdjustmentProfileValidationService:
        MealAdjustmentProfileValidationService(repository: repository),
  );
}

Future<List<TransactionLine>> _getLines(dynamic db, int transactionId) async {
  final List<QueryRow> rows = await db.customSelect(
    '''
    SELECT id, uuid, transaction_id, product_id, product_name,
           unit_price_minor, quantity, line_total_minor,
           pricing_mode, removal_discount_total_minor
    FROM transaction_lines
    WHERE transaction_id = ?
    ORDER BY id ASC
    ''',
    variables: <Variable<Object>>[Variable<int>(transactionId)],
  ).get();
  return rows
      .map(
        (QueryRow row) => TransactionLine(
          id: row.read<int>('id'),
          uuid: row.read<String>('uuid'),
          transactionId: row.read<int>('transaction_id'),
          productId: row.read<int>('product_id'),
          productName: row.read<String>('product_name'),
          unitPriceMinor: row.read<int>('unit_price_minor'),
          quantity: row.read<int>('quantity'),
          lineTotalMinor: row.read<int>('line_total_minor'),
        ),
      )
      .toList(growable: false);
}

Future<void> _insertLegacyMealModifier(dynamic db, int lineId) async {
  await db.customUpdate(
    '''
    INSERT INTO order_modifiers (
      uuid, transaction_line_id, action, item_name,
      price_effect_minor, quantity, sort_key,
      extra_price_minor, unit_price_minor,
      charge_reason
    ) VALUES (
      'legacy-mod-p7-$lineId', ?, 'remove', 'Fries',
      0, 1, 0,
      0, 0,
      'removal_discount'
    )
    ''',
    variables: <Variable<Object>>[Variable<int>(lineId)],
    updates: <ResultSetImplementation<dynamic, dynamic>>{},
  );
}

Future<_Fixture> _seedFixture(dynamic db) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: cashierId);
  final int categoryId = await insertCategory(db, name: 'Meals');
  final int mealProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Burger Meal',
    priceMinor: 1000,
  );
  final int mainDefaultId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Chicken Fillet',
    priceMinor: 0,
  );
  final int mainSwapId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Beef Patty',
    priceMinor: 0,
  );
  final int altSwapId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Fish Fillet',
    priceMinor: 0,
  );
  final int sideDefaultId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Fries',
    priceMinor: 0,
  );
  final int extraId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Cheese',
    priceMinor: 0,
  );

  final DriftMealAdjustmentProfileRepository repository =
      DriftMealAdjustmentProfileRepository(db);
  final int profileId = await repository.saveProfileDraft(
    MealAdjustmentProfileDraft(
      name: 'Burger meal profile',
      freeSwapLimit: 0,
      isActive: true,
      components: <MealAdjustmentComponentDraft>[
        MealAdjustmentComponentDraft(
          componentKey: 'main',
          displayName: 'Main',
          defaultItemProductId: mainDefaultId,
          quantity: 1,
          canRemove: true,
          sortOrder: 0,
          isActive: true,
          swapOptions: <MealAdjustmentComponentOptionDraft>[
            MealAdjustmentComponentOptionDraft(
              optionItemProductId: mainSwapId,
              fixedPriceDeltaMinor: 50,
              sortOrder: 0,
              isActive: true,
            ),
            MealAdjustmentComponentOptionDraft(
              optionItemProductId: altSwapId,
              fixedPriceDeltaMinor: 100,
              sortOrder: 1,
              isActive: true,
            ),
          ],
        ),
        MealAdjustmentComponentDraft(
          componentKey: 'side',
          displayName: 'Side',
          defaultItemProductId: sideDefaultId,
          quantity: 1,
          canRemove: true,
          sortOrder: 1,
          isActive: true,
        ),
      ],
      extraOptions: <MealAdjustmentExtraOptionDraft>[
        MealAdjustmentExtraOptionDraft(
          itemProductId: extraId,
          fixedPriceDeltaMinor: 100,
          sortOrder: 0,
          isActive: true,
        ),
      ],
      pricingRules: <MealAdjustmentPricingRuleDraft>[
        MealAdjustmentPricingRuleDraft(
          name: 'No side discount',
          ruleType: MealAdjustmentPricingRuleType.removeOnly,
          priceDeltaMinor: -50,
          priority: 0,
          isActive: true,
          conditions: const <MealAdjustmentPricingRuleConditionDraft>[
            MealAdjustmentPricingRuleConditionDraft(
              conditionType:
                  MealAdjustmentPricingRuleConditionType.removedComponent,
              componentKey: 'side',
              quantity: 1,
            ),
          ],
        ),
      ],
    ),
  );
  await repository.assignProfileToProduct(
    productId: mealProductId,
    profileId: profileId,
  );

  return _Fixture(
    repository: repository,
    user: User(
      id: cashierId,
      name: 'Cashier',
      pin: null,
      password: null,
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime.now(),
    ),
    categoryId: categoryId,
    mealProductId: mealProductId,
    profileId: profileId,
    mainSwapId: mainSwapId,
    altSwapId: altSwapId,
    extraId: extraId,
  );
}

class _Fixture {
  const _Fixture({
    required this.repository,
    required this.user,
    required this.categoryId,
    required this.mealProductId,
    required this.profileId,
    required this.mainSwapId,
    required this.altSwapId,
    required this.extraId,
  });

  final DriftMealAdjustmentProfileRepository repository;
  final User user;
  final int categoryId;
  final int mealProductId;
  final int profileId;
  final int mainSwapId;
  final int altSwapId;
  final int extraId;

  MealCustomizationRequest buildRequest({
    bool removeSide = false,
    int? swapTargetItemProductId,
    int extraQuantity = 0,
  }) {
    return MealCustomizationRequest(
      productId: mealProductId,
      profileId: profileId,
      removedComponentKeys: removeSide
          ? const <String>['side']
          : const <String>[],
      swapSelections: swapTargetItemProductId == null
          ? const <MealCustomizationComponentSelection>[]
          : <MealCustomizationComponentSelection>[
              MealCustomizationComponentSelection(
                componentKey: 'main',
                targetItemProductId: swapTargetItemProductId,
              ),
            ],
      extraSelections: extraQuantity <= 0
          ? const <MealCustomizationExtraSelection>[]
          : <MealCustomizationExtraSelection>[
              MealCustomizationExtraSelection(
                itemProductId: extraId,
                quantity: extraQuantity,
              ),
            ],
    );
  }
}
