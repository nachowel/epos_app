import 'package:drift/drift.dart' show QueryRow, Variable;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/meal_adjustment_profile_validation_service.dart';
import 'package:epos_app/domain/services/meal_customization_pos_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Meal customization order integration', () {
    test('same customization merges into one grouped line with quantity-aware totals',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _MealFixture fixture = await _seedMealFixture(db);
      final OrderService service = _buildService(db, fixture.repository);
      final TransactionRepository transactionRepository = TransactionRepository(
        db,
      );
      final User user = fixture.cashierUser;
      final order = await service.createOrder(currentUser: user);
      final MealCustomizationRequest request = fixture.buildRequest(
        removeSide: true,
        swapTargetItemProductId: fixture.mainSwapId,
        extraQuantity: 1,
      );

      final TransactionLine firstLine = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: request,
      );
      final TransactionLine secondLine = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: request,
      );

      final List<QueryRow> lineRows = await db.customSelect(
        '''
        SELECT id, quantity, line_total_minor
        FROM transaction_lines
        WHERE transaction_id = ?
        ORDER BY id ASC
        ''',
        variables: <Variable<Object>>[Variable<int>(order.id)],
      ).get();
      final List<OrderModifier> modifiers = await service.getLineModifiers(
        firstLine.id,
      );
      final Transaction? refreshedOrder = await service.getOrderById(order.id);
      final MealCustomizationPersistedSnapshotRecord? snapshotRecord =
          await transactionRepository.getMealCustomizationSnapshotByLine(
            firstLine.id,
          );

      expect(secondLine.id, firstLine.id);
      expect(lineRows, hasLength(1));
      expect(lineRows.single.read<int>('quantity'), 2);
      expect(lineRows.single.read<int>('line_total_minor'), 2200);
      expect(modifiers, hasLength(5));
      expect(snapshotRecord, isNotNull);
      expect(
        snapshotRecord!.customizationKey,
        snapshotRecord.snapshot.stableIdentityKey,
      );
      expect(snapshotRecord.snapshot.totalAdjustmentMinor, 100);
      expect(refreshedOrder, isNotNull);
      expect(refreshedOrder!.modifierTotalMinor, 200);
      expect(refreshedOrder.totalAmountMinor, 2200);
    });

    test('different swap customizations do not merge', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _MealFixture fixture = await _seedMealFixture(db);
      final OrderService service = _buildService(db, fixture.repository);
      final order = await service.createOrder(currentUser: fixture.cashierUser);

      final TransactionLine firstLine = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: fixture.buildRequest(
          removeSide: true,
          swapTargetItemProductId: fixture.mainSwapId,
        ),
      );
      final TransactionLine secondLine = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: fixture.buildRequest(
          removeSide: true,
          swapTargetItemProductId: fixture.altSwapId,
        ),
      );

      final List<QueryRow> lineRows = await db.customSelect(
        '''
        SELECT id, quantity, line_total_minor
        FROM transaction_lines
        WHERE transaction_id = ?
        ORDER BY id ASC
        ''',
        variables: <Variable<Object>>[Variable<int>(order.id)],
      ).get();

      expect(firstLine.id, isNot(secondLine.id));
      expect(lineRows, hasLength(2));
      expect(lineRows.map((QueryRow row) => row.read<int>('quantity')), everyElement(1));
      expect(
        lineRows.map((QueryRow row) => row.read<int>('line_total_minor')).toList(),
        <int>[1000, 1050],
      );
    });

    test('same product default and customized states stay on separate lines',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _MealFixture fixture = await _seedMealFixture(db);
      final OrderService service = _buildService(db, fixture.repository);
      final order = await service.createOrder(currentUser: fixture.cashierUser);

      final TransactionLine defaultLine = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
      );
      final TransactionLine customizedLine = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: fixture.buildRequest(removeSide: true),
      );
      final Transaction? refreshedOrder = await service.getOrderById(order.id);

      expect(defaultLine.id, isNot(customizedLine.id));
      expect(defaultLine.lineTotalMinor, 1000);
      expect(customizedLine.lineTotalMinor, 950);
      expect(refreshedOrder, isNotNull);
      expect(refreshedOrder!.modifierTotalMinor, -50);
      expect(refreshedOrder.totalAmountMinor, 1950);
    });

    test('profile-bound standard product persists resolved semantic snapshot',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
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

      final OrderService service = _buildService(db, repository);
      final user = User(
        id: cashierId,
        name: 'Cashier',
        pin: null,
        password: null,
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final order = await service.createOrder(currentUser: user);
      final line = await service.addProductToOrder(
        transactionId: order.id,
        productId: mealProductId,
        mealCustomizationRequest: MealCustomizationRequest(
          productId: mealProductId,
          profileId: profileId,
          removedComponentKeys: const <String>['side'],
          swapSelections: <MealCustomizationComponentSelection>[
            MealCustomizationComponentSelection(
              componentKey: 'main',
              targetItemProductId: mainSwapId,
            ),
          ],
          extraSelections: <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(itemProductId: extraId, quantity: 1),
          ],
        ),
      );

      final TransactionRepository transactionRepository = TransactionRepository(
        db,
      );
      final refreshedLine = await transactionRepository.getLineById(line.id);
      final modifiers = await service.getLineModifiers(line.id);
      final refreshedOrder = await service.getOrderById(order.id);

      expect(refreshedLine, isNotNull);
      expect(refreshedLine!.lineTotalMinor, 1100);
      expect(refreshedOrder, isNotNull);
      expect(refreshedOrder!.modifierTotalMinor, 100);
      expect(refreshedOrder.totalAmountMinor, 1100);
      expect(modifiers, hasLength(5));
      expect(
        modifiers.map((OrderModifier modifier) => modifier.action),
        <ModifierAction>[
          ModifierAction.remove,
          ModifierAction.remove,
          ModifierAction.add,
          ModifierAction.add,
          ModifierAction.add,
        ],
      );
      expect(
        modifiers.map((OrderModifier modifier) => modifier.chargeReason),
        <ModifierChargeReason?>[
          null,
          null,
          ModifierChargeReason.paidSwap,
          ModifierChargeReason.extraAdd,
          ModifierChargeReason.removalDiscount,
        ],
      );
      expect(
        modifiers.map((OrderModifier modifier) => modifier.priceEffectMinor),
        <int>[0, 0, 50, 100, -50],
      );
    });

    test('invalid assigned profile fails fast at runtime', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Meals');
      final int mealProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Chicken Meal',
        priceMinor: 900,
      );
      final int inactiveDefaultId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Inactive Default',
        priceMinor: 0,
        isActive: false,
      );

      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);
      final int profileId = await repository.saveProfileDraft(
        MealAdjustmentProfileDraft(
          name: 'Broken profile',
          freeSwapLimit: 0,
          isActive: true,
          components: <MealAdjustmentComponentDraft>[
            MealAdjustmentComponentDraft(
              componentKey: 'main',
              displayName: 'Main',
              defaultItemProductId: inactiveDefaultId,
              quantity: 1,
              canRemove: true,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      );
      await repository.assignProfileToProduct(
        productId: mealProductId,
        profileId: profileId,
      );

      final OrderService service = _buildService(db, repository);
      final user = User(
        id: cashierId,
        name: 'Cashier',
        pin: null,
        password: null,
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final order = await service.createOrder(currentUser: user);

      await expectLater(
        service.addProductToOrder(
          transactionId: order.id,
          productId: mealProductId,
        ),
        throwsA(isA<MealCustomizationRuntimeConfigurationException>()),
      );
    });

    test('grouped line decrement contract preserves snapshot until final delete',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _MealFixture fixture = await _seedMealFixture(db);
      final OrderService service = _buildService(db, fixture.repository);
      final TransactionRepository transactionRepository = TransactionRepository(
        db,
      );
      final MealCustomizationPosService posService = MealCustomizationPosService(
        mealAdjustmentProfileRepository: fixture.repository,
        validationService: MealAdjustmentProfileValidationService(
          repository: fixture.repository,
        ),
        productRepository: ProductRepository(db),
      );
      final order = await service.createOrder(currentUser: fixture.cashierUser);
      final MealCustomizationRequest request = fixture.buildRequest(
        removeSide: true,
        swapTargetItemProductId: fixture.mainSwapId,
        extraQuantity: 1,
      );
      final TransactionLine line = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: request,
      );
      await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: request,
      );

      final MealCustomizationPersistedSnapshotRecord initialSnapshot =
          (await transactionRepository.getMealCustomizationSnapshotByLine(
            line.id,
          ))!;
      final MealCustomizationRehydrationResult rehydrated = posService
          .rehydrateSnapshot(
            snapshot: initialSnapshot.snapshot,
            lineQuantity: 2,
          );

      expect(rehydrated.lineQuantity, 2);
      expect(rehydrated.editorState.removedComponentKeys, <String>['side']);
      expect(
        rehydrated.editorState.swapSelections.single.targetItemProductId,
        fixture.mainSwapId,
      );
      expect(
        rehydrated.editorState.extraSelections.single.itemProductId,
        fixture.extraId,
      );

      await transactionRepository.decrementLineQuantityOrDelete(line.id);
      final TransactionLine? decrementedLine = await transactionRepository
          .getLineById(line.id);
      final MealCustomizationPersistedSnapshotRecord? decrementedSnapshot =
          await transactionRepository.getMealCustomizationSnapshotByLine(
            line.id,
          );

      expect(decrementedLine, isNotNull);
      expect(decrementedLine!.quantity, 1);
      expect(decrementedSnapshot, isNotNull);
      expect(
        decrementedSnapshot!.customizationKey,
        initialSnapshot.customizationKey,
      );

      await transactionRepository.decrementLineQuantityOrDelete(line.id);
      expect(await transactionRepository.getLineById(line.id), isNull);
      expect(
        await transactionRepository.getMealCustomizationSnapshotByLine(line.id),
        isNull,
      );
    });

    test(
      'editing a grouped meal line rewrites the persisted snapshot for the full line quantity',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final _MealFixture fixture = await _seedMealFixture(db);
        final OrderService service = _buildService(db, fixture.repository);
        final TransactionRepository transactionRepository = TransactionRepository(
          db,
        );
        final Transaction order = await service.createOrder(
          currentUser: fixture.cashierUser,
        );
        final MealCustomizationRequest initialRequest = fixture.buildRequest(
          removeSide: true,
        );
        final TransactionLine line = await service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.mealProductId,
          mealCustomizationRequest: initialRequest,
        );
        await service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.mealProductId,
          mealCustomizationRequest: initialRequest,
        );
        final Transaction beforeEdit = (await service.getOrderById(order.id))!;

        final TransactionLine updatedLine = await service.editMealCustomizationLine(
          transactionLineId: line.id,
          request: fixture.buildRequest(removeSide: true, extraQuantity: 1),
          expectedTransactionUpdatedAt: beforeEdit.updatedAt,
        );

        final MealCustomizationPersistedSnapshotRecord snapshot =
            (await transactionRepository.getMealCustomizationSnapshotByLine(
              updatedLine.id,
            ))!;
        expect(updatedLine.id, line.id);
        expect(updatedLine.quantity, 2);
        expect(updatedLine.lineTotalMinor, 2100);
        expect(snapshot.snapshot.totalAdjustmentMinor, 50);
        expect(
          snapshot.customizationKey,
          snapshot.snapshot.stableIdentityKey,
        );
        expect(
          snapshot.snapshot.toEditorState().extraSelections,
          <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(
              itemProductId: fixture.extraId,
              quantity: 1,
            ),
          ],
        );
        expect(
          snapshot.snapshot.toEditorState().removedComponentKeys,
          <String>['side'],
        );
      },
    );

    test('editing into an existing semantic identity merges grouped meal lines',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _MealFixture fixture = await _seedMealFixture(db);
      final OrderService service = _buildService(db, fixture.repository);
      final TransactionRepository transactionRepository = TransactionRepository(
        db,
      );
      final Transaction order = await service.createOrder(
        currentUser: fixture.cashierUser,
      );
      final MealCustomizationRequest targetRequest = fixture.buildRequest(
        removeSide: true,
        extraQuantity: 1,
      );
      final MealCustomizationRequest sourceRequest = fixture.buildRequest(
        removeSide: true,
      );
      final TransactionLine targetLine = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: targetRequest,
      );
      final TransactionLine sourceLine = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: sourceRequest,
      );
      final Transaction beforeEdit = (await service.getOrderById(order.id))!;

      final TransactionLine mergedLine = await service.editMealCustomizationLine(
        transactionLineId: sourceLine.id,
        request: targetRequest,
        expectedTransactionUpdatedAt: beforeEdit.updatedAt,
      );

      expect(mergedLine.id, targetLine.id);
      expect(await transactionRepository.getLineById(sourceLine.id), isNull);
      expect(await transactionRepository.getLineById(targetLine.id), isNotNull);
      expect((await transactionRepository.getLineById(targetLine.id))!.quantity, 2);
      expect(
        (await transactionRepository.getLineById(targetLine.id))!.lineTotalMinor,
        2100,
      );
      expect(
        await transactionRepository.getMealCustomizationSnapshotByLine(
          sourceLine.id,
        ),
        isNull,
      );
    });

    test('legacy standard meal lines without snapshot persistence are blocked',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _MealFixture fixture = await _seedMealFixture(db);
      final OrderService service = _buildService(db, fixture.repository);
      final TransactionRepository transactionRepository = TransactionRepository(
        db,
      );
      final Transaction order = await service.createOrder(
        currentUser: fixture.cashierUser,
      );
      final TransactionLine line = await service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.mealProductId,
        mealCustomizationRequest: fixture.buildRequest(removeSide: true),
      );
      final Transaction beforeEdit = (await service.getOrderById(order.id))!;

      await db.customStatement(
        'DELETE FROM meal_customization_line_snapshots WHERE transaction_line_id = ?',
        <Object?>[line.id],
      );

      expect(
        await transactionRepository.isLegacyMealCustomizationLine(line.id),
        isTrue,
      );
      await expectLater(
        service.editMealCustomizationLine(
          transactionLineId: line.id,
          request: fixture.buildRequest(removeSide: false),
          expectedTransactionUpdatedAt: beforeEdit.updatedAt,
        ),
        throwsA(
          isA<MealCustomizationLineNotEditableException>().having(
            (MealCustomizationLineNotEditableException error) => error.reason,
            'reason',
            MealCustomizationEditBlockedReason.legacySnapshotMissing,
          ),
        ),
      );
    });
  });
}

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

Future<_MealFixture> _seedMealFixture(dynamic db) async {
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
    name: 'Veggie Patty',
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

  return _MealFixture(
    repository: repository,
    cashierUser: User(
      id: cashierId,
      name: 'Cashier',
      pin: null,
      password: null,
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime.now(),
    ),
    mealProductId: mealProductId,
    profileId: profileId,
    mainSwapId: mainSwapId,
    altSwapId: altSwapId,
    extraId: extraId,
  );
}

class _MealFixture {
  const _MealFixture({
    required this.repository,
    required this.cashierUser,
    required this.mealProductId,
    required this.profileId,
    required this.mainSwapId,
    required this.altSwapId,
    required this.extraId,
  });

  final DriftMealAdjustmentProfileRepository repository;
  final User cashierUser;
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
      removedComponentKeys: removeSide ? const <String>['side'] : const <String>[],
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
