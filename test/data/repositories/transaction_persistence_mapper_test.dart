import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/mappers/transaction_persistence_mapper.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('TransactionPersistenceMapper', () {
    test('semantic_round_trip_preserves_all_fields', () async {
      final _PersistenceFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      final TransactionLine line = _line(
        transactionId: fixture.transactionId,
        productId: fixture.productId,
        pricingMode: TransactionLinePricingMode.set,
        removalDiscountTotalMinor: 12,
        lineTotalMinor: 612,
      );
      final app_db.TransactionLine persistedLine = await _insertLine(
        fixture,
        line,
      );
      final TransactionLine hydratedLine = fixture.mapper
          .transactionLineFromRow(persistedLine);
      expect(hydratedLine, line.copyWith(id: persistedLine.id));

      final OrderModifier modifier = _modifier(
        transactionLineId: persistedLine.id,
        action: ModifierAction.add,
        itemName: 'Toast',
        extraPriceMinor: 9999,
        chargeReason: ModifierChargeReason.paidSwap,
        itemProductId: fixture.productId,
        sourceGroupId: fixture.groupId,
        quantity: 2,
        unitPriceMinor: 100,
        priceEffectMinor: 200,
        sortKey: 4010,
      );
      final app_db.OrderModifier persistedModifier = await _insertModifier(
        fixture,
        modifier,
      );
      final OrderModifier hydratedModifier = fixture.mapper
          .orderModifierFromRow(persistedModifier);
      expect(hydratedModifier, modifier.copyWith(id: persistedModifier.id));
    });

    test('serializer_does_not_use_extra_price_minor_for_semantics', () {
      const TransactionPersistenceMapper mapper =
          TransactionPersistenceMapper();
      final OrderModifier modifier = _modifier(
        transactionLineId: 7,
        action: ModifierAction.add,
        itemName: 'Toast',
        extraPriceMinor: 9999,
        chargeReason: ModifierChargeReason.extraAdd,
        itemProductId: 203,
        quantity: 2,
        unitPriceMinor: 100,
        priceEffectMinor: 200,
        sortKey: 5010,
      );

      final app_db.OrderModifiersCompanion companion = mapper
          .orderModifierToCompanion(modifier);

      expect(companion.extraPriceMinor.present, isTrue);
      expect(companion.extraPriceMinor.value, 9999);
      expect(companion.chargeReason.present, isTrue);
      expect(companion.chargeReason.value, 'extra_add');
      expect(companion.unitPriceMinor.value, 100);
      expect(companion.priceEffectMinor.value, 200);
      expect(companion.sortKey.value, 5010);
    });

    test('deserializer_does_not_infer_charge_reason', () async {
      final _PersistenceFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);
      final app_db.TransactionLine line = await _insertLine(
        fixture,
        _line(
          transactionId: fixture.transactionId,
          productId: fixture.productId,
        ),
      );

      final int modifierId = await fixture.db
          .into(fixture.db.orderModifiers)
          .insert(
            app_db.OrderModifiersCompanion.insert(
              uuid: 'mod-no-reason',
              transactionLineId: line.id,
              action: 'add',
              itemName: 'Legacy Tea',
              quantity: const Value<int>(1),
              itemProductId: Value<int?>(fixture.productId),
              sourceGroupId: const Value<int?>(null),
              extraPriceMinor: const Value<int>(75),
              chargeReason: const Value<String?>(null),
              unitPriceMinor: const Value<int>(0),
              priceEffectMinor: const Value<int>(0),
              sortKey: const Value<int>(0),
            ),
          );

      final app_db.OrderModifier row = await _findModifierById(
        fixture.db,
        modifierId,
      );
      final OrderModifier modifier = fixture.mapper.orderModifierFromRow(row);

      expect(modifier.chargeReason, isNull);
      expect(modifier.itemProductId, fixture.productId);
      expect(modifier.extraPriceMinor, 75);
      expect(modifier.priceEffectMinor, 0);
      expect(modifier.sortKey, 0);
    });

    test(
      'migrated legacy row preserves copied compatibility values without semantic reclassification',
      () async {
        final _PersistenceFixture fixture = await _createFixture();
        addTearDown(fixture.db.close);
        final app_db.TransactionLine line = await _insertLine(
          fixture,
          _line(
            transactionId: fixture.transactionId,
            productId: fixture.productId,
          ),
        );

        final int modifierId = await fixture.db
            .into(fixture.db.orderModifiers)
            .insert(
              app_db.OrderModifiersCompanion.insert(
                uuid: 'migrated-legacy-mod',
                transactionLineId: line.id,
                action: 'add',
                itemName: 'Migrated Legacy Extra',
                quantity: const Value<int>(1),
                itemProductId: const Value<int?>(null),
                sourceGroupId: const Value<int?>(null),
                extraPriceMinor: const Value<int>(75),
                chargeReason: const Value<String?>(null),
                unitPriceMinor: const Value<int>(75),
                priceEffectMinor: const Value<int>(75),
                sortKey: const Value<int>(0),
              ),
            );

        final OrderModifier modifier = fixture.mapper.orderModifierFromRow(
          await _findModifierById(fixture.db, modifierId),
        );

        expect(modifier.chargeReason, isNull);
        expect(modifier.itemProductId, isNull);
        expect(modifier.quantity, 1);
        expect(modifier.unitPriceMinor, 75);
        expect(modifier.priceEffectMinor, 75);
        expect(modifier.sortKey, 0);
        expect(modifier.extraPriceMinor, 75);
      },
    );

    test(
      'non-semantic compatibility-shaped row preserves null and zero stored values',
      () async {
        final _PersistenceFixture fixture = await _createFixture();
        addTearDown(fixture.db.close);
        final app_db.TransactionLine line = await _insertLine(
          fixture,
          _line(
            transactionId: fixture.transactionId,
            productId: fixture.productId,
          ),
        );

        final int modifierId = await fixture.db
            .into(fixture.db.orderModifiers)
            .insert(
              app_db.OrderModifiersCompanion.insert(
                uuid: 'legacy-mod',
                transactionLineId: line.id,
                action: 'add',
                itemName: 'Legacy Extra',
                quantity: const Value<int>(1),
                itemProductId: const Value<int?>(null),
                sourceGroupId: const Value<int?>(null),
                extraPriceMinor: const Value<int>(75),
                chargeReason: const Value<String?>(null),
                unitPriceMinor: const Value<int>(0),
                priceEffectMinor: const Value<int>(0),
                sortKey: const Value<int>(0),
              ),
            );

        final OrderModifier modifier = fixture.mapper.orderModifierFromRow(
          await _findModifierById(fixture.db, modifierId),
        );

        expect(modifier.chargeReason, isNull);
        expect(modifier.itemProductId, isNull);
        expect(modifier.quantity, 1);
        expect(modifier.unitPriceMinor, 0);
        expect(modifier.priceEffectMinor, 0);
        expect(modifier.sortKey, 0);
        expect(modifier.extraPriceMinor, 75);
      },
    );

    test('sort_key_order_is_preserved', () async {
      final _PersistenceFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);
      final app_db.TransactionLine line = await _insertLine(
        fixture,
        _line(
          transactionId: fixture.transactionId,
          productId: fixture.productId,
          pricingMode: TransactionLinePricingMode.set,
        ),
      );

      final int idA = await _insertModifierId(
        fixture,
        _modifier(
          uuid: 'mod-a',
          transactionLineId: line.id,
          action: ModifierAction.add,
          itemName: 'Late',
          extraPriceMinor: 0,
          chargeReason: ModifierChargeReason.extraAdd,
          itemProductId: fixture.productId,
          quantity: 1,
          unitPriceMinor: 10,
          priceEffectMinor: 10,
          sortKey: 10,
        ),
      );
      final int idB = await _insertModifierId(
        fixture,
        _modifier(
          uuid: 'mod-b',
          transactionLineId: line.id,
          action: ModifierAction.add,
          itemName: 'Early 1',
          extraPriceMinor: 0,
          chargeReason: ModifierChargeReason.extraAdd,
          itemProductId: fixture.productId,
          quantity: 1,
          unitPriceMinor: 20,
          priceEffectMinor: 20,
          sortKey: 5,
        ),
      );
      final int idC = await _insertModifierId(
        fixture,
        _modifier(
          uuid: 'mod-c',
          transactionLineId: line.id,
          action: ModifierAction.add,
          itemName: 'Early 2',
          extraPriceMinor: 0,
          chargeReason: ModifierChargeReason.extraAdd,
          itemProductId: fixture.productId,
          quantity: 1,
          unitPriceMinor: 30,
          priceEffectMinor: 30,
          sortKey: 5,
        ),
      );

      final List<OrderModifier> modifiers = await fixture.repository
          .getModifiersByLine(line.id);

      expect(
        modifiers.map((OrderModifier modifier) => modifier.id).toList(),
        <int>[idB, idC, idA],
      );
      expect(
        modifiers.map((OrderModifier modifier) => modifier.sortKey).toList(),
        <int>[5, 5, 10],
      );
    });

    test('mixed semantic + legacy rows still deserialize safely', () async {
      final _PersistenceFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);
      final app_db.TransactionLine line = await _insertLine(
        fixture,
        _line(
          transactionId: fixture.transactionId,
          productId: fixture.productId,
          pricingMode: TransactionLinePricingMode.set,
        ),
      );

      await _insertModifierId(
        fixture,
        _modifier(
          uuid: 'legacy-mixed',
          transactionLineId: line.id,
          action: ModifierAction.add,
          itemName: 'Legacy Extra',
          extraPriceMinor: 75,
          chargeReason: null,
          itemProductId: null,
          quantity: 1,
          unitPriceMinor: 0,
          priceEffectMinor: 0,
          sortKey: 0,
        ),
      );
      await _insertModifierId(
        fixture,
        _modifier(
          uuid: 'semantic-mixed',
          transactionLineId: line.id,
          action: ModifierAction.choice,
          itemName: 'Tea',
          extraPriceMinor: 9999,
          chargeReason: ModifierChargeReason.includedChoice,
          itemProductId: fixture.productId,
          sourceGroupId: fixture.groupId,
          quantity: 2,
          unitPriceMinor: 150,
          priceEffectMinor: 0,
          sortKey: 11,
        ),
      );

      final List<OrderModifier> modifiers = await fixture.repository
          .getModifiersByLine(line.id);
      final OrderModifier legacy = modifiers.first;
      final OrderModifier semantic = modifiers.last;

      expect(legacy.chargeReason, isNull);
      expect(legacy.itemProductId, isNull);
      expect(legacy.extraPriceMinor, 75);
      expect(legacy.priceEffectMinor, 0);

      expect(semantic.chargeReason, ModifierChargeReason.includedChoice);
      expect(semantic.itemProductId, fixture.productId);
      expect(semantic.quantity, 2);
      expect(semantic.unitPriceMinor, 150);
      expect(semantic.priceEffectMinor, 0);
      expect(semantic.sortKey, 11);
    });

    test('null / optional fields handled correctly', () {
      const TransactionPersistenceMapper mapper =
          TransactionPersistenceMapper();
      final OrderModifier modifier = _modifier(
        transactionLineId: 5,
        action: ModifierAction.remove,
        itemName: 'Beans',
        extraPriceMinor: 0,
        chargeReason: null,
        itemProductId: null,
        sourceGroupId: null,
        quantity: 1,
        unitPriceMinor: 0,
        priceEffectMinor: 0,
        sortKey: 0,
      );

      final app_db.OrderModifiersCompanion companion = mapper
          .orderModifierToCompanion(modifier);

      expect(companion.chargeReason.present, isTrue);
      expect(companion.chargeReason.value, isNull);
      expect(companion.itemProductId.present, isTrue);
      expect(companion.itemProductId.value, isNull);
      expect(companion.sourceGroupId.present, isTrue);
      expect(companion.sourceGroupId.value, isNull);
      expect(companion.quantity.value, 1);
      expect(companion.sortKey.value, 0);
    });

    test('idempotent round-trip (serialize→deserialize→serialize)', () async {
      final _PersistenceFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      final TransactionLine line = _line(
        transactionId: fixture.transactionId,
        productId: fixture.productId,
        pricingMode: TransactionLinePricingMode.set,
        removalDiscountTotalMinor: 9,
        lineTotalMinor: 409,
      );
      final app_db.TransactionLinesCompanion firstLineCompanion = fixture.mapper
          .transactionLineToCompanion(line);
      final TransactionLine lineRoundTrip = fixture.mapper
          .transactionLineFromRow(await _insertLine(fixture, line));
      final app_db.TransactionLinesCompanion secondLineCompanion = fixture
          .mapper
          .transactionLineToCompanion(lineRoundTrip);

      expect(
        _transactionLineCompanionValues(firstLineCompanion),
        _transactionLineCompanionValues(secondLineCompanion),
      );

      final OrderModifier modifier = _modifier(
        transactionLineId: lineRoundTrip.id,
        action: ModifierAction.add,
        itemName: 'Toast',
        extraPriceMinor: 555,
        chargeReason: ModifierChargeReason.extraAdd,
        itemProductId: fixture.productId,
        sourceGroupId: fixture.groupId,
        quantity: 2,
        unitPriceMinor: 100,
        priceEffectMinor: 200,
        sortKey: 88,
      );
      final app_db.OrderModifiersCompanion firstModifierCompanion = fixture
          .mapper
          .orderModifierToCompanion(modifier);
      final OrderModifier modifierRoundTrip = fixture.mapper
          .orderModifierFromRow(await _insertModifier(fixture, modifier));
      final app_db.OrderModifiersCompanion secondModifierCompanion = fixture
          .mapper
          .orderModifierToCompanion(modifierRoundTrip);

      expect(
        _orderModifierCompanionValues(firstModifierCompanion),
        _orderModifierCompanionValues(secondModifierCompanion),
      );
    });
  });
}

Future<_PersistenceFixture> _createFixture() async {
  final app_db.AppDatabase db = createTestDatabase();
  final int categoryId = await insertCategory(db, name: 'Breakfast');
  final int productId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Toast',
    priceMinor: 100,
  );
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: cashierId);
  final int transactionId = await insertTransaction(
    db,
    uuid: 'tx-persist',
    shiftId: shiftId,
    userId: cashierId,
    status: 'draft',
    totalAmountMinor: 400,
  );
  final int groupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: productId,
          name: 'Test Group',
          minSelect: const Value<int>(0),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );

  return _PersistenceFixture(
    db: db,
    mapper: const TransactionPersistenceMapper(),
    repository: TransactionRepository(db),
    productId: productId,
    transactionId: transactionId,
    groupId: groupId,
  );
}

TransactionLine _line({
  String uuid = 'line-persist',
  required int transactionId,
  required int productId,
  TransactionLinePricingMode pricingMode = TransactionLinePricingMode.standard,
  int removalDiscountTotalMinor = 0,
  int lineTotalMinor = 400,
}) {
  return TransactionLine(
    id: 0,
    uuid: uuid,
    transactionId: transactionId,
    productId: productId,
    productName: 'Toast',
    unitPriceMinor: 100,
    quantity: 1,
    lineTotalMinor: lineTotalMinor,
    pricingMode: pricingMode,
    removalDiscountTotalMinor: removalDiscountTotalMinor,
  );
}

OrderModifier _modifier({
  String uuid = 'modifier-persist',
  required int transactionLineId,
  required ModifierAction action,
  required String itemName,
  required int extraPriceMinor,
  required ModifierChargeReason? chargeReason,
  required int? itemProductId,
  int? sourceGroupId,
  required int quantity,
  required int unitPriceMinor,
  required int priceEffectMinor,
  required int sortKey,
}) {
  return OrderModifier(
    id: 0,
    uuid: uuid,
    transactionLineId: transactionLineId,
    action: action,
    itemName: itemName,
    extraPriceMinor: extraPriceMinor,
    chargeReason: chargeReason,
    itemProductId: itemProductId,
    sourceGroupId: sourceGroupId,
    quantity: quantity,
    unitPriceMinor: unitPriceMinor,
    priceEffectMinor: priceEffectMinor,
    sortKey: sortKey,
  );
}

Future<app_db.TransactionLine> _insertLine(
  _PersistenceFixture fixture,
  TransactionLine line,
) async {
  final int id = await fixture.db
      .into(fixture.db.transactionLines)
      .insert(fixture.mapper.transactionLineToCompanion(line));
  return _findLineById(fixture.db, id);
}

Future<int> _insertModifierId(
  _PersistenceFixture fixture,
  OrderModifier modifier,
) {
  return fixture.db
      .into(fixture.db.orderModifiers)
      .insert(fixture.mapper.orderModifierToCompanion(modifier));
}

Future<app_db.OrderModifier> _insertModifier(
  _PersistenceFixture fixture,
  OrderModifier modifier,
) async {
  final int id = await _insertModifierId(fixture, modifier);
  return _findModifierById(fixture.db, id);
}

Future<app_db.TransactionLine> _findLineById(app_db.AppDatabase db, int id) {
  return (db.select(
    db.transactionLines,
  )..where((app_db.$TransactionLinesTable t) => t.id.equals(id))).getSingle();
}

Future<app_db.OrderModifier> _findModifierById(app_db.AppDatabase db, int id) {
  return (db.select(
    db.orderModifiers,
  )..where((app_db.$OrderModifiersTable t) => t.id.equals(id))).getSingle();
}

Map<String, Object?> _transactionLineCompanionValues(
  app_db.TransactionLinesCompanion companion,
) {
  return <String, Object?>{
    'uuid': companion.uuid.value,
    'transaction_id': companion.transactionId.value,
    'product_id': companion.productId.value,
    'product_name': companion.productName.value,
    'unit_price_minor': companion.unitPriceMinor.value,
    'quantity': companion.quantity.value,
    'line_total_minor': companion.lineTotalMinor.value,
    'pricing_mode': companion.pricingMode.value,
    'removal_discount_total_minor': companion.removalDiscountTotalMinor.value,
  };
}

Map<String, Object?> _orderModifierCompanionValues(
  app_db.OrderModifiersCompanion companion,
) {
  return <String, Object?>{
    'uuid': companion.uuid.value,
    'transaction_line_id': companion.transactionLineId.value,
    'action': companion.action.value,
    'item_name': companion.itemName.value,
    'quantity': companion.quantity.value,
    'item_product_id': companion.itemProductId.value,
    'source_group_id': companion.sourceGroupId.value,
    'extra_price_minor': companion.extraPriceMinor.value,
    'charge_reason': companion.chargeReason.value,
    'unit_price_minor': companion.unitPriceMinor.value,
    'price_effect_minor': companion.priceEffectMinor.value,
    'sort_key': companion.sortKey.value,
  };
}

class _PersistenceFixture {
  const _PersistenceFixture({
    required this.db,
    required this.mapper,
    required this.repository,
    required this.productId,
    required this.transactionId,
    required this.groupId,
  });

  final app_db.AppDatabase db;
  final TransactionPersistenceMapper mapper;
  final TransactionRepository repository;
  final int productId;
  final int transactionId;
  final int groupId;
}
