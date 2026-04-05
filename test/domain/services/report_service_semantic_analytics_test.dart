import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' hide User;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/semantic_sales_analytics.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/meal_adjustment_profile_validation_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('ReportService semantic analytics', () {
    test(
      'aggregates semantic sales by product identity and charge reason',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final _SemanticReportFixture fixture = await _seedSemanticReportFixture(
          db,
        );
        final ReportService service = _makeReportService(db);

        final report = await service.getShiftReport(fixture.shiftId);
        final SemanticSalesAnalytics analytics = report.semanticSalesAnalytics;

        expect(analytics.isEmpty, isFalse);
        expect(
          analytics.dataQualityNotes.any(
            (String note) => note.contains('source group IDs'),
          ),
          isFalse,
        );

        expect(analytics.rootProducts, hasLength(1));
        expect(
          analytics.rootProducts.single.rootProductId,
          fixture.rootProductId,
        );
        expect(analytics.rootProducts.single.quantitySold, 2);
        expect(analytics.rootProducts.single.revenueMinor, 1450);

        final toastChoice = analytics.choiceSelections.singleWhere(
          (SemanticChoiceSelectionAnalytics entry) =>
              entry.groupId == fixture.breadGroupId &&
              entry.itemProductId == fixture.toastProductId,
        );
        final breadChoice = analytics.choiceSelections.singleWhere(
          (SemanticChoiceSelectionAnalytics entry) =>
              entry.groupId == fixture.breadGroupId &&
              entry.itemProductId == fixture.breadProductId,
        );
        final teaChoice = analytics.choiceSelections.singleWhere(
          (SemanticChoiceSelectionAnalytics entry) =>
              entry.groupId == fixture.drinkGroupId &&
              entry.itemProductId == fixture.teaProductId,
        );

        expect(toastChoice.itemName, 'Toast');
        expect(toastChoice.selectionCount, 1);
        expect(toastChoice.distributionPercent, 50);
        expect(toastChoice.trend.single.date, DateTime(2026, 4, 1));
        expect(breadChoice.distributionPercent, 50);
        expect(teaChoice.itemName, 'Tea');

        final beansRemoved = analytics.removedItems.singleWhere(
          (SemanticItemBehaviorAnalytics entry) =>
              entry.itemProductId == fixture.beansProductId,
        );
        expect(beansRemoved.occurrenceCount, 2);
        expect(beansRemoved.totalQuantity, 2);
        expect(beansRemoved.percentageOfRootSales, 100);

        final hashBrownAdds = analytics.addedItems.singleWhere(
          (SemanticItemBehaviorAnalytics entry) =>
              entry.itemProductId == fixture.hashBrownProductId,
        );
        final sausageAdds = analytics.addedItems.singleWhere(
          (SemanticItemBehaviorAnalytics entry) =>
              entry.itemProductId == fixture.sausageProductId,
        );
        expect(hashBrownAdds.occurrenceCount, 2);
        expect(hashBrownAdds.revenueMinor, 200);
        expect(sausageAdds.occurrenceCount, 1);
        expect(sausageAdds.revenueMinor, 50);

        final extraAddBreakdown = analytics.chargeReasonBreakdown.singleWhere(
          (SemanticChargeReasonAnalytics entry) =>
              entry.chargeReason == ModifierChargeReason.extraAdd,
        );
        final paidSwapBreakdown = analytics.chargeReasonBreakdown.singleWhere(
          (SemanticChargeReasonAnalytics entry) =>
              entry.chargeReason == ModifierChargeReason.paidSwap,
        );
        final includedChoiceBreakdown = analytics.chargeReasonBreakdown
            .singleWhere(
              (SemanticChargeReasonAnalytics entry) =>
                  entry.chargeReason == ModifierChargeReason.includedChoice,
            );
        expect(extraAddBreakdown.totalQuantity, 2);
        expect(extraAddBreakdown.revenueMinor, 200);
        expect(paidSwapBreakdown.totalQuantity, 1);
        expect(paidSwapBreakdown.revenueMinor, 50);
        expect(includedChoiceBreakdown.totalQuantity, 4);

        expect(analytics.bundleVariants, hasLength(2));
        expect(
          analytics.bundleVariants.any(
            (SemanticBundleVariantAnalytics variant) =>
                variant.chosenItemProductIds.contains(fixture.toastProductId) &&
                variant.chosenItemProductIds.contains(fixture.teaProductId) &&
                variant.removedItemProductIds.contains(fixture.beansProductId),
          ),
          isTrue,
        );
      },
    );

    test('cashier-visible reports hide semantic analytics payload', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _SemanticReportFixture fixture = await _seedSemanticReportFixture(
        db,
      );
      final ReportService service = _makeReportService(db);

      final masked = await service.getVisibleShiftReport(
        shiftId: fixture.shiftId,
        user: fixture.cashierUser,
      );

      expect(
        masked.semanticSalesAnalytics,
        const SemanticSalesAnalytics.empty(),
      );
    });

    test(
      'analytics prefer persisted source group identity over current configuration',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final _SemanticReportFixture fixture = await _seedSemanticReportFixture(
          db,
        );
        await (db.update(db.productModifiers)
              ..where(
                ($ProductModifiersTable tbl) =>
                    tbl.groupId.equals(fixture.breadGroupId),
              )
              ..where(
                ($ProductModifiersTable tbl) =>
                    tbl.itemProductId.equals(fixture.toastProductId),
              ))
            .write(
              ProductModifiersCompanion(
                groupId: Value<int?>(fixture.drinkGroupId),
              ),
            );

        final ReportService service = _makeReportService(db);
        final report = await service.getShiftReport(fixture.shiftId);

        expect(
          report.semanticSalesAnalytics.choiceSelections.any(
            (SemanticChoiceSelectionAnalytics entry) =>
                entry.groupId == fixture.breadGroupId &&
                entry.itemProductId == fixture.toastProductId,
          ),
          isTrue,
        );
      },
    );

    test(
      'analytics fall back to inference for legacy rows without source group ids',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final _SemanticReportFixture fixture = await _seedSemanticReportFixture(
          db,
          includeSourceGroupIds: false,
        );
        final ReportService service = _makeReportService(db);
        final report = await service.getShiftReport(fixture.shiftId);

        expect(
          report.semanticSalesAnalytics.choiceSelections.any(
            (SemanticChoiceSelectionAnalytics entry) =>
                entry.groupId == fixture.breadGroupId &&
                entry.itemProductId == fixture.toastProductId,
          ),
          isTrue,
        );
        expect(
          report.semanticSalesAnalytics.dataQualityNotes,
          contains(
            contains(
              'Legacy semantic modifier rows without persisted source group IDs',
            ),
          ),
        );
      },
    );

    test(
      'grouped standard meal lines expand quantity for paid swap, extras, and discounts',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final _StandardMealReportFixture fixture =
            await _seedStandardMealReportFixture(
              db,
              freeSwapLimit: 0,
              swapFixedDeltaMinor: 50,
              addGroupedQuantity: 2,
              includeExtra: true,
              removeSide: true,
            );
        final ReportService service = _makeReportService(db);

        final SemanticSalesAnalytics analytics =
            (await service.getShiftReport(fixture.shiftId))
                .semanticSalesAnalytics;
        final SemanticRootProductAnalytics root = analytics.rootProducts
            .singleWhere(
              (SemanticRootProductAnalytics entry) =>
                  entry.rootProductId == fixture.rootProductId,
            );
        final SemanticChargeReasonAnalytics paidSwapBreakdown = analytics
            .chargeReasonBreakdown
            .singleWhere(
              (SemanticChargeReasonAnalytics entry) =>
                  entry.chargeReason == ModifierChargeReason.paidSwap,
            );
        final SemanticChargeReasonAnalytics extraBreakdown = analytics
            .chargeReasonBreakdown
            .singleWhere(
              (SemanticChargeReasonAnalytics entry) =>
                  entry.chargeReason == ModifierChargeReason.extraAdd,
            );
        final SemanticChargeReasonAnalytics discountBreakdown = analytics
            .chargeReasonBreakdown
            .singleWhere(
              (SemanticChargeReasonAnalytics entry) =>
                  entry.chargeReason == ModifierChargeReason.removalDiscount,
            );
        final SemanticMealRevenueAnalytics mealRevenue = analytics
            .mealRevenueBreakdown
            .singleWhere(
              (SemanticMealRevenueAnalytics entry) =>
                  entry.rootProductId == fixture.rootProductId,
            );
        final SemanticMealAppliedRuleAnalytics appliedRule = analytics
            .appliedMealRules
            .single;
        final SemanticBundleVariantAnalytics variant = analytics.bundleVariants
            .singleWhere(
              (SemanticBundleVariantAnalytics entry) =>
                  entry.rootProductId == fixture.rootProductId,
            );

        expect(root.quantitySold, 2);
        expect(root.revenueMinor, 2200);
        expect(paidSwapBreakdown.eventCount, 2);
        expect(paidSwapBreakdown.totalQuantity, 2);
        expect(paidSwapBreakdown.revenueMinor, 100);
        expect(extraBreakdown.eventCount, 2);
        expect(extraBreakdown.totalQuantity, 2);
        expect(extraBreakdown.revenueMinor, 200);
        expect(discountBreakdown.eventCount, 2);
        expect(discountBreakdown.totalQuantity, 2);
        expect(discountBreakdown.revenueMinor, -100);
        expect(mealRevenue.quantitySold, 2);
        expect(mealRevenue.baseRevenueMinor, 2000);
        expect(mealRevenue.extraRevenueMinor, 200);
        expect(mealRevenue.paidSwapRevenueMinor, 100);
        expect(mealRevenue.freeSwapCount, 0);
        expect(mealRevenue.discountTotalMinor, -100);
        expect(mealRevenue.netRevenueMinor, 2200);
        expect(mealRevenue.removeActionCount, 2);
        expect(mealRevenue.swapActionCount, 2);
        expect(mealRevenue.extraActionCount, 2);
        expect(mealRevenue.discountActionCount, 2);
        expect(appliedRule.ruleType, MealAdjustmentPricingRuleType.removeOnly.name);
        expect(appliedRule.applicationCount, 2);
        expect(appliedRule.totalImpactMinor, -100);
        expect(variant.orderCount, 2);
        expect(variant.revenueMinor, 2200);
      },
    );

    test('standard meal free swaps contribute zero revenue in analytics',
        () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _StandardMealReportFixture fixture =
          await _seedStandardMealReportFixture(
            db,
            freeSwapLimit: 1,
            swapFixedDeltaMinor: 50,
            addGroupedQuantity: 1,
            includeExtra: false,
            removeSide: false,
          );
      final ReportService service = _makeReportService(db);

      final SemanticSalesAnalytics analytics =
          (await service.getShiftReport(fixture.shiftId)).semanticSalesAnalytics;
      final SemanticChargeReasonAnalytics freeSwapBreakdown = analytics
          .chargeReasonBreakdown
          .singleWhere(
            (SemanticChargeReasonAnalytics entry) =>
                entry.chargeReason == ModifierChargeReason.freeSwap,
          );
      final SemanticItemBehaviorAnalytics addedSwap = analytics.addedItems
          .singleWhere(
            (SemanticItemBehaviorAnalytics entry) =>
                entry.itemProductId == fixture.swapItemProductId,
          );

      expect(freeSwapBreakdown.eventCount, 1);
      expect(freeSwapBreakdown.totalQuantity, 1);
      expect(freeSwapBreakdown.revenueMinor, 0);
      expect(addedSwap.revenueMinor, 0);
      expect(
        analytics.mealRevenueBreakdown.single.freeSwapCount,
        1,
      );
      expect(
        analytics.mealRevenueBreakdown.single.paidSwapRevenueMinor,
        0,
      );
      expect(analytics.appliedMealRules, isEmpty);
    });

    test(
      'legacy standard meal lines stay in root revenue totals but emit data-quality notes',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final _StandardMealReportFixture fixture =
            await _seedStandardMealReportFixture(
              db,
              freeSwapLimit: 0,
              swapFixedDeltaMinor: 50,
              addGroupedQuantity: 1,
              includeExtra: false,
              removeSide: true,
            );
        await db.customStatement(
          'DELETE FROM meal_customization_line_snapshots WHERE transaction_line_id = ?',
          <Object?>[fixture.transactionLineId],
        );
        final ReportService service = _makeReportService(db);

        final SemanticSalesAnalytics analytics =
            (await service.getShiftReport(fixture.shiftId)).semanticSalesAnalytics;

        expect(
          analytics.rootProducts.singleWhere(
            (SemanticRootProductAnalytics entry) =>
                entry.rootProductId == fixture.rootProductId,
          ).revenueMinor,
          1000,
        );
        expect(analytics.mealRevenueBreakdown, isEmpty);
        expect(analytics.appliedMealRules, isEmpty);
        expect(
          analytics.dataQualityNotes,
          contains(
            contains('Legacy standard meal lines without persisted snapshots'),
          ),
        );
      });
  });
}

ReportService _makeReportService(AppDatabase db) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  return ReportService(
    shiftRepository: shiftRepository,
    shiftSessionService: ShiftSessionService(shiftRepository),
    transactionRepository: TransactionRepository(db),
    paymentRepository: PaymentRepository(db),
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
    settingsRepository: SettingsRepository(db),
    reportVisibilityService: const ReportVisibilityService(),
  );
}

Future<_SemanticReportFixture> _seedSemanticReportFixture(
  AppDatabase db, {
  bool includeSourceGroupIds = true,
}) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: cashierId);
  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int drinkCategoryId = await insertCategory(db, name: 'Drinks');
  final int sideCategoryId = await insertCategory(db, name: 'Sides');

  final int rootProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set Breakfast',
    priceMinor: 600,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int toastProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Toast',
    priceMinor: 90,
  );
  final int breadProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Bread',
    priceMinor: 90,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Coffee',
    priceMinor: 160,
  );
  final int hashBrownProductId = await insertProduct(
    db,
    categoryId: sideCategoryId,
    name: 'Hash Brown',
    priceMinor: 100,
  );
  final int sausageProductId = await insertProduct(
    db,
    categoryId: sideCategoryId,
    name: 'Sausage',
    priceMinor: 50,
  );

  await db
      .into(db.setItems)
      .insert(
        SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: eggProductId,
          sortOrder: const Value<int>(1),
          isRemovable: const Value<bool>(false),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: beansProductId,
          sortOrder: const Value<int>(2),
          isRemovable: const Value<bool>(true),
        ),
      );

  final int breadGroupId = await db
      .into(db.modifierGroups)
      .insert(
        ModifierGroupsCompanion.insert(
          productId: rootProductId,
          name: 'Bread choice',
          minSelect: const Value<int>(1),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );
  final int drinkGroupId = await db
      .into(db.modifierGroups)
      .insert(
        ModifierGroupsCompanion.insert(
          productId: rootProductId,
          name: 'Drink choice',
          minSelect: const Value<int>(1),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(2),
        ),
      );

  Future<void> insertChoiceMember({
    required int groupId,
    required int itemProductId,
    required String name,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          ProductModifiersCompanion.insert(
            productId: rootProductId,
            groupId: Value<int?>(groupId),
            itemProductId: Value<int?>(itemProductId),
            name: name,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertChoiceMember(
    groupId: breadGroupId,
    itemProductId: toastProductId,
    name: 'Toast',
  );
  await insertChoiceMember(
    groupId: breadGroupId,
    itemProductId: breadProductId,
    name: 'Bread',
  );
  await insertChoiceMember(
    groupId: drinkGroupId,
    itemProductId: teaProductId,
    name: 'Tea',
  );
  await insertChoiceMember(
    groupId: drinkGroupId,
    itemProductId: coffeeProductId,
    name: 'Coffee',
  );

  final int transactionOneId = await insertTransaction(
    db,
    uuid: 'semantic-report-tx-1',
    shiftId: shiftId,
    userId: cashierId,
    status: 'paid',
    totalAmountMinor: 750,
    paidAt: DateTime(2026, 4, 1, 9, 0),
  );
  final int transactionTwoId = await insertTransaction(
    db,
    uuid: 'semantic-report-tx-2',
    shiftId: shiftId,
    userId: cashierId,
    status: 'paid',
    totalAmountMinor: 700,
    paidAt: DateTime(2026, 4, 2, 10, 0),
  );

  await insertPayment(
    db,
    uuid: 'semantic-report-payment-1',
    transactionId: transactionOneId,
    method: 'cash',
    amountMinor: 750,
    paidAt: DateTime(2026, 4, 1, 9, 0),
  );
  await insertPayment(
    db,
    uuid: 'semantic-report-payment-2',
    transactionId: transactionTwoId,
    method: 'card',
    amountMinor: 700,
    paidAt: DateTime(2026, 4, 2, 10, 0),
  );

  await _insertSemanticLine(
    db,
    transactionId: transactionOneId,
    lineUuid: 'semantic-line-1',
    rootProductId: rootProductId,
    rootProductName: 'Set Breakfast',
    basePriceMinor: 600,
    lineTotalMinor: 750,
    modifiers: <_TestModifierRow>[
      _TestModifierRow(
        uuid: 'semantic-mod-1',
        action: 'choice',
        itemName: 'Toast text fallback',
        quantity: 1,
        itemProductId: toastProductId,
        sourceGroupId: includeSourceGroupIds ? breadGroupId : null,
        chargeReason: 'included_choice',
        sortKey: 10,
      ),
      _TestModifierRow(
        uuid: 'semantic-mod-2',
        action: 'choice',
        itemName: 'Tea text fallback',
        quantity: 1,
        itemProductId: teaProductId,
        sourceGroupId: includeSourceGroupIds ? drinkGroupId : null,
        chargeReason: 'included_choice',
        sortKey: 11,
      ),
      _TestModifierRow(
        uuid: 'semantic-mod-3',
        action: 'remove',
        itemName: 'Beans text fallback',
        quantity: 1,
        itemProductId: beansProductId,
        sortKey: 12,
      ),
      _TestModifierRow(
        uuid: 'semantic-mod-4',
        action: 'add',
        itemName: 'Hash Brown text fallback',
        quantity: 1,
        itemProductId: hashBrownProductId,
        chargeReason: 'extra_add',
        unitPriceMinor: 100,
        extraPriceMinor: 100,
        priceEffectMinor: 100,
        sortKey: 13,
      ),
      _TestModifierRow(
        uuid: 'semantic-mod-5',
        action: 'add',
        itemName: 'Sausage text fallback',
        quantity: 1,
        itemProductId: sausageProductId,
        chargeReason: 'paid_swap',
        unitPriceMinor: 50,
        extraPriceMinor: 50,
        priceEffectMinor: 50,
        sortKey: 14,
      ),
    ],
  );
  await _insertSemanticLine(
    db,
    transactionId: transactionTwoId,
    lineUuid: 'semantic-line-2',
    rootProductId: rootProductId,
    rootProductName: 'Set Breakfast',
    basePriceMinor: 600,
    lineTotalMinor: 700,
    modifiers: <_TestModifierRow>[
      _TestModifierRow(
        uuid: 'semantic-mod-6',
        action: 'choice',
        itemName: 'Bread text fallback',
        quantity: 1,
        itemProductId: breadProductId,
        sourceGroupId: includeSourceGroupIds ? breadGroupId : null,
        chargeReason: 'included_choice',
        sortKey: 10,
      ),
      _TestModifierRow(
        uuid: 'semantic-mod-7',
        action: 'choice',
        itemName: 'Coffee text fallback',
        quantity: 1,
        itemProductId: coffeeProductId,
        sourceGroupId: includeSourceGroupIds ? drinkGroupId : null,
        chargeReason: 'included_choice',
        sortKey: 11,
      ),
      _TestModifierRow(
        uuid: 'semantic-mod-8',
        action: 'remove',
        itemName: 'Beans text fallback',
        quantity: 1,
        itemProductId: beansProductId,
        sortKey: 12,
      ),
      _TestModifierRow(
        uuid: 'semantic-mod-9',
        action: 'add',
        itemName: 'Hash Brown text fallback',
        quantity: 1,
        itemProductId: hashBrownProductId,
        chargeReason: 'extra_add',
        unitPriceMinor: 100,
        extraPriceMinor: 100,
        priceEffectMinor: 100,
        sortKey: 13,
      ),
    ],
  );

  return _SemanticReportFixture(
    shiftId: shiftId,
    rootProductId: rootProductId,
    breadGroupId: breadGroupId,
    drinkGroupId: drinkGroupId,
    toastProductId: toastProductId,
    breadProductId: breadProductId,
    teaProductId: teaProductId,
    beansProductId: beansProductId,
    hashBrownProductId: hashBrownProductId,
    sausageProductId: sausageProductId,
    cashierUser: User(
      id: cashierId,
      name: 'Cashier',
      pin: null,
      password: null,
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime.now(),
    ),
  );
}

Future<_StandardMealReportFixture> _seedStandardMealReportFixture(
  AppDatabase db, {
  required int freeSwapLimit,
  required int swapFixedDeltaMinor,
  required int addGroupedQuantity,
  required bool includeExtra,
  required bool removeSide,
}) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: cashierId);
  final int categoryId = await insertCategory(db, name: 'Meals');
  final int rootProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Burger Meal',
    priceMinor: 1000,
  );
  final int defaultMainId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Chicken Fillet',
    priceMinor: 0,
  );
  final int swapItemProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Beef Patty',
    priceMinor: 0,
  );
  final int sideProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Fries',
    priceMinor: 0,
  );
  final int extraItemProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Cheese',
    priceMinor: 0,
  );

  final DriftMealAdjustmentProfileRepository repository =
      DriftMealAdjustmentProfileRepository(db);
  final int profileId = await repository.saveProfileDraft(
    MealAdjustmentProfileDraft(
      name: 'Meal analytics profile',
      freeSwapLimit: freeSwapLimit,
      isActive: true,
      components: <MealAdjustmentComponentDraft>[
        MealAdjustmentComponentDraft(
          componentKey: 'main',
          displayName: 'Main',
          defaultItemProductId: defaultMainId,
          quantity: 1,
          canRemove: false,
          sortOrder: 0,
          isActive: true,
          swapOptions: <MealAdjustmentComponentOptionDraft>[
            MealAdjustmentComponentOptionDraft(
              optionItemProductId: swapItemProductId,
              fixedPriceDeltaMinor: swapFixedDeltaMinor,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
        MealAdjustmentComponentDraft(
          componentKey: 'side',
          displayName: 'Side',
          defaultItemProductId: sideProductId,
          quantity: 1,
          canRemove: true,
          sortOrder: 1,
          isActive: true,
        ),
      ],
      extraOptions: includeExtra
          ? <MealAdjustmentExtraOptionDraft>[
              MealAdjustmentExtraOptionDraft(
                itemProductId: extraItemProductId,
                fixedPriceDeltaMinor: 100,
                sortOrder: 0,
                isActive: true,
              ),
            ]
          : const <MealAdjustmentExtraOptionDraft>[],
      pricingRules: removeSide
          ? <MealAdjustmentPricingRuleDraft>[
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
            ]
          : const <MealAdjustmentPricingRuleDraft>[],
    ),
  );
  await repository.assignProfileToProduct(
    productId: rootProductId,
    profileId: profileId,
  );

  final User cashierUser = User(
    id: cashierId,
    name: 'Cashier',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime.now(),
  );
  final OrderService orderService = OrderService(
    shiftSessionService: ShiftSessionService(ShiftRepository(db)),
    transactionRepository: TransactionRepository(db),
    transactionStateRepository: TransactionStateRepository(db),
    productRepository: ProductRepository(db),
    mealAdjustmentProfileRepository: repository,
    mealAdjustmentProfileValidationService:
        MealAdjustmentProfileValidationService(repository: repository),
  );
  final transaction = await orderService.createOrder(currentUser: cashierUser);
  final MealCustomizationRequest request = MealCustomizationRequest(
    productId: rootProductId,
    profileId: profileId,
    removedComponentKeys: removeSide ? const <String>['side'] : const <String>[],
    swapSelections: <MealCustomizationComponentSelection>[
      MealCustomizationComponentSelection(
        componentKey: 'main',
        targetItemProductId: swapItemProductId,
      ),
    ],
    extraSelections: includeExtra
        ? <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(
              itemProductId: extraItemProductId,
              quantity: 1,
            ),
          ]
        : const <MealCustomizationExtraSelection>[],
  );

  for (int index = 0; index < addGroupedQuantity; index++) {
    await orderService.addProductToOrder(
      transactionId: transaction.id,
      productId: rootProductId,
      mealCustomizationRequest: request,
    );
  }

  final transactionRepository = TransactionRepository(db);
  final updatedTransaction = (await transactionRepository.getById(
    transaction.id,
  ))!;
  final DateTime paidAt = DateTime(2026, 4, 3, 12, 0);
  await (db.update(db.transactions)
        ..where(
          ($TransactionsTable table) => table.id.equals(transaction.id),
        ))
      .write(
        TransactionsCompanion(
          status: const Value<String>('paid'),
          paidAt: Value<DateTime>(paidAt),
          updatedAt: Value<DateTime>(paidAt),
        ),
      );
  await insertPayment(
    db,
    uuid: 'meal-report-payment-${transaction.id}',
    transactionId: transaction.id,
    method: 'cash',
    amountMinor: updatedTransaction.totalAmountMinor,
    paidAt: paidAt,
  );

  return _StandardMealReportFixture(
    shiftId: shiftId,
    rootProductId: rootProductId,
    swapItemProductId: swapItemProductId,
    transactionLineId: (await transactionRepository.getLines(transaction.id)).single.id,
  );
}

class _StandardMealReportFixture {
  const _StandardMealReportFixture({
    required this.shiftId,
    required this.rootProductId,
    required this.swapItemProductId,
    required this.transactionLineId,
  });

  final int shiftId;
  final int rootProductId;
  final int swapItemProductId;
  final int transactionLineId;
}

Future<void> _insertSemanticLine(
  AppDatabase db, {
  required int transactionId,
  required String lineUuid,
  required int rootProductId,
  required String rootProductName,
  required int basePriceMinor,
  required int lineTotalMinor,
  required List<_TestModifierRow> modifiers,
}) async {
  final int lineId = await db
      .into(db.transactionLines)
      .insert(
        TransactionLinesCompanion.insert(
          uuid: lineUuid,
          transactionId: transactionId,
          productId: rootProductId,
          productName: rootProductName,
          unitPriceMinor: basePriceMinor,
          quantity: const Value<int>(1),
          lineTotalMinor: lineTotalMinor,
          pricingMode: const Value<String>('set'),
          removalDiscountTotalMinor: const Value<int>(0),
        ),
      );

  for (final _TestModifierRow modifier in modifiers) {
    await db
        .into(db.orderModifiers)
        .insert(
          OrderModifiersCompanion.insert(
            uuid: modifier.uuid,
            transactionLineId: lineId,
            action: modifier.action,
            itemName: modifier.itemName,
            quantity: Value<int>(modifier.quantity),
            itemProductId: Value<int?>(modifier.itemProductId),
            sourceGroupId: Value<int?>(modifier.sourceGroupId),
            extraPriceMinor: Value<int>(modifier.extraPriceMinor),
            chargeReason: Value<String?>(modifier.chargeReason),
            unitPriceMinor: Value<int>(modifier.unitPriceMinor),
            priceEffectMinor: Value<int>(modifier.priceEffectMinor),
            sortKey: Value<int>(modifier.sortKey),
          ),
        );
  }
}

class _TestModifierRow {
  const _TestModifierRow({
    required this.uuid,
    required this.action,
    required this.itemName,
    required this.quantity,
    this.itemProductId,
    this.sourceGroupId,
    this.chargeReason,
    this.extraPriceMinor = 0,
    this.unitPriceMinor = 0,
    this.priceEffectMinor = 0,
    this.sortKey = 0,
  });

  final String uuid;
  final String action;
  final String itemName;
  final int quantity;
  final int? itemProductId;
  final int? sourceGroupId;
  final String? chargeReason;
  final int extraPriceMinor;
  final int unitPriceMinor;
  final int priceEffectMinor;
  final int sortKey;
}

class _SemanticReportFixture {
  const _SemanticReportFixture({
    required this.shiftId,
    required this.rootProductId,
    required this.breadGroupId,
    required this.drinkGroupId,
    required this.toastProductId,
    required this.breadProductId,
    required this.teaProductId,
    required this.beansProductId,
    required this.hashBrownProductId,
    required this.sausageProductId,
    required this.cashierUser,
  });

  final int shiftId;
  final int rootProductId;
  final int breadGroupId;
  final int drinkGroupId;
  final int toastProductId;
  final int breadProductId;
  final int teaProductId;
  final int beansProductId;
  final int hashBrownProductId;
  final int sausageProductId;
  final User cashierUser;
}
