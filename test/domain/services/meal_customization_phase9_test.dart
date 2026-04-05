import 'package:epos_app/data/database/app_database.dart'
    hide MealAdjustmentProfile, MealAdjustmentComponentOption;
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/models/meal_optimization.dart';
import 'package:epos_app/domain/services/meal_customization_engine.dart';
import 'package:epos_app/domain/services/meal_optimization_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:epos_app/data/database/app_database.dart' as db;

import '../../support/test_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

MealCustomizationResolvedSnapshot _makeSnapshot({
  int productId = 1,
  int profileId = 1,
  List<MealCustomizationSemanticAction> componentActions =
      const <MealCustomizationSemanticAction>[],
  List<MealCustomizationSemanticAction> extraActions =
      const <MealCustomizationSemanticAction>[],
  List<MealCustomizationSemanticAction> discounts =
      const <MealCustomizationSemanticAction>[],
  int totalAdjustmentMinor = 0,
  int freeSwapCountUsed = 0,
  int paidSwapCountUsed = 0,
}) {
  return MealCustomizationResolvedSnapshot(
    productId: productId,
    profileId: profileId,
    resolvedComponentActions: componentActions,
    resolvedExtraActions: extraActions,
    triggeredDiscounts: discounts,
    totalAdjustmentMinor: totalAdjustmentMinor,
    freeSwapCountUsed: freeSwapCountUsed,
    paidSwapCountUsed: paidSwapCountUsed,
  );
}

/// Inserts a persisted snapshot record via the engine, returning a realistic
/// snapshot that the test can persist to the in-memory database.
Future<int> _persistSnapshot(
  TransactionRepository repo,
  int transactionId,
  int productId,
  MealCustomizationResolvedSnapshot snapshot,
) async {
  final line = await repo.addLine(
    transactionId: transactionId,
    productId: productId,
    quantity: 1,
  );
  await repo.replaceMealCustomizationLineSnapshot(
    transactionLineId: line.id,
    snapshot: snapshot,
  );
  return line.id;
}

Future<void> _markTransactionPaid(AppDatabase db, int transactionId) async {
  await (db.update(db.transactions)
        ..where((t) => t.id.equals(transactionId)))
      .write(
        const TransactionsCompanion(
          status: drift.Value('paid'),
        ),
      );
}

Future<void> _insertProfile(db.AppDatabase database, int profileId) async {
  await database.into(database.mealAdjustmentProfiles).insert(
    db.MealAdjustmentProfilesCompanion.insert(
      id: drift.Value(profileId),
      name: 'Profile $profileId',
      isActive: const drift.Value(true),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
      freeSwapLimit: const drift.Value(2),
    ),
    mode: drift.InsertMode.insertOrIgnore,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Test setup
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late TransactionRepository transactionRepository;
  late ProductRepository productRepository;
  late MealOptimizationService service;

  // Store IDs set up in setUp
  late int burgerId;
  late int beansId;
  late int peasId;
  late int cheeseId;
  late int transactionId;

  setUp(() async {
    db = createTestDatabase();
    transactionRepository = TransactionRepository(db);
    productRepository = ProductRepository(db);

    service = MealOptimizationService(
      transactionRepository: transactionRepository,
      productRepository: productRepository,
    );

    final int categoryId = await insertCategory(db, name: 'Mains');
    burgerId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Burger',
      priceMinor: 1200,
    );
    beansId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Beans',
      priceMinor: 0,
    );
    peasId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Peas',
      priceMinor: 0,
    );
    cheeseId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Extra Cheese',
      priceMinor: 100,
    );

    // Create a transaction to hang snapshot records off.
    final int userId = await insertUser(db, name: 'Admin', role: 'admin');
    final int shiftId = await insertShift(db, openedBy: userId);
    transactionId = await insertTransaction(
      db,
      uuid: 'tx-test',
      shiftId: shiftId,
      userId: userId,
      status: 'draft',
      totalAmountMinor: 1200,
    );

    await _insertProfile(db, 1);
  });

  tearDown(() async {
    await db.close();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // G. Confidence / data quality
  // ─────────────────────────────────────────────────────────────────────────

  group('G. Confidence thresholds', () {
    test('high confidence when >= 30 orders', () {
      expect(
        confidenceForSampleSize(30),
        InsightConfidence.high,
      );
      expect(
        confidenceForSampleSize(100),
        InsightConfidence.high,
      );
    });

    test('medium confidence when 10–29 orders', () {
      expect(
        confidenceForSampleSize(10),
        InsightConfidence.medium,
      );
      expect(
        confidenceForSampleSize(29),
        InsightConfidence.medium,
      );
    });

    test('low confidence when < 10 orders', () {
      expect(
        confidenceForSampleSize(0),
        InsightConfidence.low,
      );
      expect(
        confidenceForSampleSize(9),
        InsightConfidence.low,
      );
    });

    test('empty database produces empty report without errors', () async {
      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      expect(report.isEmpty, true);
      expect(report.discountLeakage, isEmpty);
      expect(report.upsellOpportunities, isEmpty);
      expect(report.recommendations, isEmpty);
    });

    test('low data case produces Low confidence insight', () async {
      // Insert only 3 snapshots — below medium threshold of 10.
      for (int i = 0; i < 3; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductDiscountLeakage leakage =
          report.discountLeakage.firstWhere((p) => p.productId == burgerId);
      expect(leakage.confidence, InsightConfidence.low);
      expect(
        leakage.insights.any((s) => s.contains('Not enough data')),
        true,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A. Discount leakage
  // ─────────────────────────────────────────────────────────────────────────

  group('A. Discount Leakage', () {
    test('discount frequency is calculated correctly', () async {
      // 30 orders; 20 have a removal discount.
      for (int i = 0; i < 20; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            componentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.remove,
                componentKey: 'beans',
                itemProductId: beansId,
              ),
            ],
            discounts: <MealCustomizationSemanticAction>[
              const MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.removalDiscount,
                priceDeltaMinor: -50,
              ),
            ],
            totalAdjustmentMinor: -50,
          ),
        );
      }
      for (int i = 0; i < 10; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductDiscountLeakage leakage =
          report.discountLeakage.firstWhere((p) => p.productId == burgerId);

      expect(leakage.totalOrders, 30);
      expect(leakage.discountedOrders, 20);
      expect(
        leakage.discountFrequency,
        closeTo(66.67, 0.1),
      );
    });

    test('high removal detected adds highFrequency flag', () async {
      // >40% discount frequency → DiscountLeakageFlag.highFrequency
      for (int i = 0; i < 15; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            componentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.remove,
                componentKey: 'beans',
                itemProductId: beansId,
              ),
            ],
            discounts: <MealCustomizationSemanticAction>[
              const MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.removalDiscount,
                priceDeltaMinor: -100,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 5; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductDiscountLeakage leakage =
          report.discountLeakage.firstWhere((p) => p.productId == burgerId);

      expect(
        leakage.flags.contains(DiscountLeakageFlag.highFrequency),
        isTrue,
      );
    });

    test('combo discount order count is tracked', () async {
      for (int i = 0; i < 10; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            discounts: <MealCustomizationSemanticAction>[
              const MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.comboDiscount,
                priceDeltaMinor: -200,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 5; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductDiscountLeakage leakage =
          report.discountLeakage.firstWhere((p) => p.productId == burgerId);

      expect(leakage.comboDiscountOrders, 10);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // B. Upsell analysis
  // ─────────────────────────────────────────────────────────────────────────

  group('B. Upsell Opportunity', () {
    test('extra attach rate is calculated correctly', () async {
      // 30 orders total; 12 include an extra.
      for (int i = 0; i < 12; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            extraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                chargeReason: MealCustomizationChargeReason.extraAdd,
                itemProductId: cheeseId,
                priceDeltaMinor: 100,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 18; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductUpsellOpportunity upsell =
          report.upsellOpportunities.firstWhere(
        (p) => p.productId == burgerId,
      );

      expect(upsell.totalOrders, 30);
      expect(upsell.ordersWithExtras, 12);
      expect(upsell.extraAttachRate, closeTo(40.0, 0.1));
    });

    test('top extra detection — highest count wins', () async {
      // cheese added 8×, peas added 2×
      for (int i = 0; i < 8; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            extraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                chargeReason: MealCustomizationChargeReason.extraAdd,
                itemProductId: cheeseId,
                priceDeltaMinor: 100,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 2; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            extraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                chargeReason: MealCustomizationChargeReason.extraAdd,
                itemProductId: peasId,
                priceDeltaMinor: 50,
              ),
            ],
          ),
        );
      }
      // Pad to 15 so confidence is medium+
      for (int i = 0; i < 5; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductUpsellOpportunity upsell =
          report.upsellOpportunities.firstWhere(
        (p) => p.productId == burgerId,
      );

      expect(upsell.topExtras, isNotEmpty);
      expect(upsell.topExtras.first.itemProductId, cheeseId);
      expect(upsell.topExtras.first.count, 8);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // C. Swap analysis
  // ─────────────────────────────────────────────────────────────────────────

  group('C. Swap Behavior', () {
    test('top swap pair is correctly identified', () async {
      // beans → peas: 9 times; beans → cheese: 1 time. Pad to 30.
      for (int i = 0; i < 9; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            componentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                chargeReason: MealCustomizationChargeReason.freeSwap,
                componentKey: 'beans',
                sourceItemProductId: beansId,
                itemProductId: peasId,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 1; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            componentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                chargeReason: MealCustomizationChargeReason.paidSwap,
                componentKey: 'beans',
                sourceItemProductId: beansId,
                itemProductId: cheeseId,
                priceDeltaMinor: 100,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 20; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductSwapBehavior behavior = report.swapBehaviors.firstWhere(
        (p) => p.productId == burgerId,
      );

      expect(behavior.topSwapPairs, isNotEmpty);
      final SwapPairStats top = behavior.topSwapPairs.first;
      expect(top.targetItemProductId, peasId);
      expect(top.occurrenceCount, 9);
    });

    test('swap frequency percent is correct', () async {
      // 12 out of 30 orders have a swap.
      for (int i = 0; i < 12; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            componentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                chargeReason: MealCustomizationChargeReason.freeSwap,
                componentKey: 'beans',
                sourceItemProductId: beansId,
                itemProductId: peasId,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 18; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductSwapBehavior behavior = report.swapBehaviors.firstWhere(
        (p) => p.productId == burgerId,
      );

      expect(behavior.topSwapPairs.first.frequencyPercent, closeTo(40.0, 0.1));
    });

    test('free vs paid swap counts are tracked separately', () async {
      for (int i = 0; i < 6; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            componentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                chargeReason: MealCustomizationChargeReason.freeSwap,
                componentKey: 'beans',
                sourceItemProductId: beansId,
                itemProductId: peasId,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 4; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            componentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                chargeReason: MealCustomizationChargeReason.paidSwap,
                componentKey: 'beans',
                sourceItemProductId: beansId,
                itemProductId: cheeseId,
                priceDeltaMinor: 100,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 20; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProductSwapBehavior behavior = report.swapBehaviors.firstWhere(
        (p) => p.productId == burgerId,
      );

      expect(behavior.freeSwapOrders, 6);
      expect(behavior.paidSwapOrders, 4);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // D. Profile performance classification
  // ─────────────────────────────────────────────────────────────────────────

  group('D. Profile Performance', () {
    test('discount-heavy profile classified correctly', () async {
      const int profileId = 42;
      await _insertProfile(db, profileId);
      // 30 orders, each with a big discount and no extra revenue.
      for (int i = 0; i < 30; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            profileId: profileId,
            discounts: <MealCustomizationSemanticAction>[
              const MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.removalDiscount,
                priceDeltaMinor: -200,
              ),
            ],
            totalAdjustmentMinor: -200,
          ),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProfilePerformance? perf =
          report.profilePerformances.cast<ProfilePerformance?>().firstWhere(
            (ProfilePerformance? p) => p!.profileId == profileId,
            orElse: () => null,
          );

      expect(perf, isNotNull);
      expect(perf!.healthLabel, ProfileHealthLabel.discountHeavy);
    });

    test('balanced profile classification when discount ≈ extra', () async {
      const int profileId = 43;
      await _insertProfile(db, profileId);
      for (int i = 0; i < 10; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            profileId: profileId,
            extraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                chargeReason: MealCustomizationChargeReason.extraAdd,
                itemProductId: cheeseId,
                priceDeltaMinor: 100,
              ),
            ],
            discounts: <MealCustomizationSemanticAction>[
              const MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.removalDiscount,
                priceDeltaMinor: -50,
              ),
            ],
            totalAdjustmentMinor: 50,
          ),
        );
      }
      for (int i = 0; i < 20; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            profileId: profileId,
          ),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final ProfilePerformance? perf =
          report.profilePerformances.cast<ProfilePerformance?>().firstWhere(
            (ProfilePerformance? p) => p!.profileId == profileId,
            orElse: () => null,
          );

      expect(perf, isNotNull);
      expect(perf!.healthLabel, ProfileHealthLabel.balanced);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // E. Recommendations (threshold logic)
  // ─────────────────────────────────────────────────────────────────────────

  group('E. Recommendations', () {
    test('high discount frequency triggers reduceDiscount recommendation',
        () async {
      // >40% discount, with combo — triggers reduceDiscount
      for (int i = 0; i < 18; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            discounts: <MealCustomizationSemanticAction>[
              const MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.comboDiscount,
                priceDeltaMinor: -200,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 12; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final bool hasReduceDiscount = report.recommendations.any(
        (MealOptimizationRecommendation r) =>
            r.type == RecommendationType.reduceDiscount &&
            r.affectedProductId == burgerId,
      );
      expect(hasReduceDiscount, isTrue);
    });

    test(
        'low extra attach rate triggers promoteExtra recommendation for medium+ confidence',
        () async {
      // Only 2 out of 30 have extras → 6.67% < 10% threshold AND 30 >= 10 orders.
      for (int i = 0; i < 2; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            extraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                chargeReason: MealCustomizationChargeReason.extraAdd,
                itemProductId: cheeseId,
                priceDeltaMinor: 100,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 28; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }
      await _markTransactionPaid(db, transactionId);

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final bool hasPromoteExtra = report.recommendations.any(
        (MealOptimizationRecommendation r) =>
            r.type == RecommendationType.promoteExtra &&
            r.affectedProductId == burgerId,
      );
      expect(hasPromoteExtra, isTrue);
    });

    test('high frequent swap triggers adjustDefaultComponent', () async {
      // >60% of orders swap beans → peas
      for (int i = 0; i < 22; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            componentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                chargeReason: MealCustomizationChargeReason.freeSwap,
                componentKey: 'beans',
                sourceItemProductId: beansId,
                itemProductId: peasId,
              ),
            ],
          ),
        );
      }
      for (int i = 0; i < 8; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(productId: burgerId),
        );
      }

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final bool hasAdjustDefault = report.recommendations.any(
        (MealOptimizationRecommendation r) =>
            r.type == RecommendationType.adjustDefaultComponent &&
            r.affectedProductId == burgerId,
      );
      expect(hasAdjustDefault, isTrue);
    });

    test('recommendations are deterministic across multiple calls', () async {
      for (int i = 0; i < 30; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            discounts: <MealCustomizationSemanticAction>[
              const MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.comboDiscount,
                priceDeltaMinor: -100,
              ),
            ],
          ),
        );
      }

      final MealOptimizationReport r1 =
          await service.generateReport(lookbackDays: 30);
      final MealOptimizationReport r2 =
          await service.generateReport(lookbackDays: 30);

      // Determinism: same number and types of recommendations.
      expect(r1.recommendations.length, r2.recommendations.length);
      for (int i = 0; i < r1.recommendations.length; i++) {
        expect(r1.recommendations[i].type, r2.recommendations[i].type);
        expect(
          r1.recommendations[i].affectedProductId,
          r2.recommendations[i].affectedProductId,
        );
      }
    });

    test('no recommendations for products with very low data (low confidence)',
        () async {
      // Only 3 orders — confidence is LOW, recommendations should be skipped.
      for (int i = 0; i < 3; i++) {
        await _persistSnapshot(
          transactionRepository,
          transactionId,
          burgerId,
          _makeSnapshot(
            productId: burgerId,
            discounts: <MealCustomizationSemanticAction>[
              const MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.comboDiscount,
                priceDeltaMinor: -200,
              ),
            ],
          ),
        );
      }

      final MealOptimizationReport report =
          await service.generateReport(lookbackDays: 30);
      final bool hasAnyForBurger = report.recommendations.any(
        (MealOptimizationRecommendation r) =>
            r.affectedProductId == burgerId,
      );
      // Low confidence → recommendations suppressed.
      expect(hasAnyForBurger, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Regression
  // ─────────────────────────────────────────────────────────────────────────

  group('Regression', () {
    test('existing meal engine is unaffected', () {
      const MealCustomizationEngine engine = MealCustomizationEngine();

      const MealAdjustmentProfile profile = MealAdjustmentProfile(
        id: 99,
        name: 'Regression Profile',
        freeSwapLimit: 1,
        isActive: true,
        components: <MealAdjustmentComponent>[
          MealAdjustmentComponent(
            id: 1,
            profileId: 99,
            componentKey: 'side',
            displayName: 'Side',
            defaultItemProductId: 2,
            quantity: 1,
            canRemove: true,
            sortOrder: 0,
            isActive: true,
            swapOptions: <MealAdjustmentComponentOption>[
              MealAdjustmentComponentOption(
                id: 10,
                profileComponentId: 1,
                optionItemProductId: 3,
                sortOrder: 0,
                isActive: true,
              ),
            ],
          ),
        ],
      );

      const MealCustomizationRequest request = MealCustomizationRequest(
        productId: 1,
        profileId: 99,
        removedComponentKeys: <String>[],
        swapSelections: <MealCustomizationComponentSelection>[
          MealCustomizationComponentSelection(
            componentKey: 'side',
            targetItemProductId: 3,
          ),
        ],
        extraSelections: <MealCustomizationExtraSelection>[],
      );

      final MealCustomizationResolvedSnapshot snap1 = engine.evaluate(
        profile: profile,
        request: request,
      );
      final MealCustomizationResolvedSnapshot snap2 = engine.evaluate(
        profile: profile,
        request: request,
      );

      // Engine determinism unchanged.
      expect(snap1.stableIdentityKey, snap2.stableIdentityKey);
      expect(snap1.totalAdjustmentMinor, snap2.totalAdjustmentMinor);
    });

    test('report generation does not throw on new empty database', () async {
      // This covers the regression: admin UI loads with no data.
      expect(
        () => service.generateReport(lookbackDays: 30),
        returnsNormally,
      );
    });
  });
}
