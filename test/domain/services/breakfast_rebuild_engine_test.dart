import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/services/breakfast_rebuild_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const BreakfastRebuildEngine engine = BreakfastRebuildEngine();

  group('BreakfastRebuildEngine', () {
    test('remove only is reportable', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(
                itemProductId: _beansId,
                quantity: 1,
              ),
            ],
          ),
        ),
      );

      expect(result.validationErrors, isEmpty);
      expect(result.classifiedModifiers, hasLength(1));
      expect(
        result.classifiedModifiers.single,
        _classified(
          kind: BreakfastModifierKind.setRemove,
          action: ModifierAction.remove,
          itemProductId: _beansId,
          quantity: 1,
          unitPriceMinor: 0,
          priceEffectMinor: 0,
          displayName: 'Beans',
          chargeReason: null,
        ),
      );
      expect(result.lineSnapshot.pricingMode, TransactionLinePricingMode.set);
      expect(result.lineSnapshot.modifierTotalMinor, 0);
      expect(result.lineSnapshot.lineTotalMinor, 400);
      expect(result.rebuildMetadata.replacementCount, 0);
      expect(result.rebuildMetadata.unmatchedRemovalCount, 1);
    });

    test('invalid non-set engine input is rejected', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(pricingMode: TransactionLinePricingMode.standard),
      );

      expect(
        result.validationErrors,
        contains(BreakfastEditErrorCode.invalidPricingMode),
      );
      expect(result.classifiedModifiers, isEmpty);
      expect(
        result.lineSnapshot.pricingMode,
        TransactionLinePricingMode.standard,
      );
      expect(result.lineSnapshot.modifierTotalMinor, 0);
      expect(result.lineSnapshot.lineTotalMinor, 400);
    });

    test('first replacement free', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(
                itemProductId: _eggId,
                quantity: 1,
              ),
            ],
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(
                itemProductId: _beansId,
                quantity: 1,
              ),
            ],
          ),
        ),
      );

      final BreakfastClassifiedModifier freeSwap = result.classifiedModifiers
          .singleWhere(
            (BreakfastClassifiedModifier row) =>
                row.chargeReason == ModifierChargeReason.freeSwap,
          );

      expect(result.validationErrors, isEmpty);
      expect(freeSwap.quantity, 1);
      expect(freeSwap.itemProductId, _beansId);
      expect(freeSwap.priceEffectMinor, 0);
      expect(result.lineSnapshot.modifierTotalMinor, 0);
      expect(result.lineSnapshot.lineTotalMinor, 400);
      expect(result.rebuildMetadata.replacementCount, 1);
      expect(result.rebuildMetadata.unmatchedRemovalCount, 0);
    });

    test('second replacement free', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(
                itemProductId: _eggId,
                quantity: 1,
              ),
              BreakfastRemovedSetItemRequest(
                itemProductId: _baconId,
                quantity: 1,
              ),
            ],
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(
                itemProductId: _beansId,
                quantity: 1,
              ),
              BreakfastAddedProductRequest(
                itemProductId: _sausageId,
                quantity: 1,
              ),
            ],
          ),
        ),
      );

      final Iterable<BreakfastClassifiedModifier> freeSwaps = result
          .classifiedModifiers
          .where(
            (BreakfastClassifiedModifier row) =>
                row.chargeReason == ModifierChargeReason.freeSwap,
          );

      expect(result.validationErrors, isEmpty);
      expect(freeSwaps, hasLength(2));
      expect(
        freeSwaps.every(
          (BreakfastClassifiedModifier row) => row.priceEffectMinor == 0,
        ),
        isTrue,
      );
      expect(result.rebuildMetadata.replacementCount, 2);
      expect(result.rebuildMetadata.unmatchedRemovalCount, 0);
    });

    test('third replacement paid', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(
                itemProductId: _eggId,
                quantity: 1,
              ),
              BreakfastRemovedSetItemRequest(
                itemProductId: _baconId,
                quantity: 1,
              ),
              BreakfastRemovedSetItemRequest(
                itemProductId: _sausageId,
                quantity: 1,
              ),
            ],
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(
                itemProductId: _beansId,
                quantity: 3,
              ),
            ],
          ),
        ),
      );

      final BreakfastClassifiedModifier paidSwap = result.classifiedModifiers
          .singleWhere(
            (BreakfastClassifiedModifier row) =>
                row.chargeReason == ModifierChargeReason.paidSwap,
          );

      expect(result.validationErrors, isEmpty);
      expect(paidSwap.itemProductId, _beansId);
      expect(paidSwap.quantity, 1);
      expect(paidSwap.unitPriceMinor, 80);
      expect(paidSwap.priceEffectMinor, 80);
      expect(result.pricingBreakdown.paidSwapTotalMinor, 80);
      expect(result.lineSnapshot.modifierTotalMinor, 80);
      expect(result.lineSnapshot.lineTotalMinor, 480);
    });

    test('choice within allowance', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            chosenGroups: <BreakfastChosenGroupRequest>[
              BreakfastChosenGroupRequest(
                groupId: _hotDrinkGroupId,
                selectedItemProductId: _teaId,
                requestedQuantity: 1,
              ),
            ],
          ),
        ),
      );

      expect(result.validationErrors, isEmpty);
      expect(result.classifiedModifiers, hasLength(1));
      expect(
        result.classifiedModifiers.single,
        _classified(
          kind: BreakfastModifierKind.choiceIncluded,
          action: ModifierAction.choice,
          itemProductId: _teaId,
          quantity: 1,
          unitPriceMinor: 150,
          priceEffectMinor: 0,
          displayName: 'Tea',
          chargeReason: ModifierChargeReason.includedChoice,
          sourceGroupId: _hotDrinkGroupId,
        ),
      );
    });

    test('explicit none choice persists as zero-price semantic row', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            chosenGroups: <BreakfastChosenGroupRequest>[
              BreakfastChosenGroupRequest(
                groupId: _hotDrinkGroupId,
                selectedItemProductId: null,
                requestedQuantity: 1,
              ),
            ],
          ),
        ),
      );

      expect(result.validationErrors, isEmpty);
      expect(result.classifiedModifiers, hasLength(1));
      expect(
        result.classifiedModifiers.single,
        isA<BreakfastClassifiedModifier>()
            .having(
              (BreakfastClassifiedModifier row) => row.action,
              'action',
              ModifierAction.choice,
            )
            .having(
              (BreakfastClassifiedModifier row) => row.chargeReason,
              'chargeReason',
              ModifierChargeReason.includedChoice,
            )
            .having(
              (BreakfastClassifiedModifier row) => row.itemProductId,
              'itemProductId',
              isNull,
            )
            .having(
              (BreakfastClassifiedModifier row) => row.displayName,
              'displayName',
              breakfastNoneChoiceDisplayName,
            )
            .having(
              (BreakfastClassifiedModifier row) => row.unitPriceMinor,
              'unitPriceMinor',
              0,
            )
            .having(
              (BreakfastClassifiedModifier row) => row.priceEffectMinor,
              'priceEffectMinor',
              0,
            ),
      );
      expect(result.lineSnapshot.lineTotalMinor, 400);
    });

    test(
      'toast or bread rejects quantities above the single selection limit',
      () {
        final BreakfastRebuildResult result = engine.rebuild(
          _input(
            requestedState: const BreakfastRequestedState(
              chosenGroups: <BreakfastChosenGroupRequest>[
                BreakfastChosenGroupRequest(
                  groupId: _toastBreadGroupId,
                  selectedItemProductId: _toastId,
                  requestedQuantity: 2,
                ),
              ],
            ),
          ),
        );

        expect(
          result.validationErrors,
          contains(BreakfastEditErrorCode.invalidChoiceQuantity),
        );
        expect(result.classifiedModifiers, isEmpty);
      },
    );

    test('choice product never consumes swap pool', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(
                itemProductId: _eggId,
                quantity: 1,
              ),
            ],
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(itemProductId: _teaId, quantity: 1),
            ],
          ),
        ),
      );

      expect(result.validationErrors, isEmpty);
      expect(
        result.classifiedModifiers.any(
          (BreakfastClassifiedModifier row) =>
              row.chargeReason == ModifierChargeReason.freeSwap ||
              row.chargeReason == ModifierChargeReason.paidSwap,
        ),
        isFalse,
      );
      expect(
        result.classifiedModifiers
            .singleWhere(
              (BreakfastClassifiedModifier row) =>
                  row.chargeReason == ModifierChargeReason.extraAdd,
            )
            .itemProductId,
        _teaId,
      );
      expect(result.rebuildMetadata.replacementCount, 0);
      expect(result.rebuildMetadata.unmatchedRemovalCount, 1);
      expect(result.lineSnapshot.modifierTotalMinor, 150);
    });

    test('explicit none is rejected for required toast or bread', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            chosenGroups: <BreakfastChosenGroupRequest>[
              BreakfastChosenGroupRequest(
                groupId: _toastBreadGroupId,
                selectedItemProductId: null,
                requestedQuantity: 1,
              ),
            ],
          ),
        ),
      );

      expect(
        result.validationErrors,
        contains(BreakfastEditErrorCode.invalidChoiceQuantity),
      );
      expect(result.classifiedModifiers, isEmpty);
    });

    test('mixed toast/bread invalid', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            chosenGroups: <BreakfastChosenGroupRequest>[
              BreakfastChosenGroupRequest(
                groupId: _toastBreadGroupId,
                selectedItemProductId: _toastId,
                requestedQuantity: 1,
              ),
              BreakfastChosenGroupRequest(
                groupId: _toastBreadGroupId,
                selectedItemProductId: _breadId,
                requestedQuantity: 1,
              ),
            ],
          ),
        ),
      );

      expect(
        result.validationErrors,
        contains(BreakfastEditErrorCode.invalidChoiceGroup),
      );
      expect(result.classifiedModifiers, isEmpty);
    });

    test('remove quantity exceeds default invalid', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(
                itemProductId: _eggId,
                quantity: 2,
              ),
            ],
          ),
        ),
      );

      expect(
        result.validationErrors,
        contains(BreakfastEditErrorCode.removeQuantityExceedsDefault),
      );
      expect(result.classifiedModifiers, isEmpty);
    });

    test('stable rebuild same input same output', () {
      final BreakfastRebuildInput input = _input(
        requestedState: const BreakfastRequestedState(
          removedSetItems: <BreakfastRemovedSetItemRequest>[
            BreakfastRemovedSetItemRequest(itemProductId: _eggId, quantity: 1),
            BreakfastRemovedSetItemRequest(
              itemProductId: _baconId,
              quantity: 1,
            ),
            BreakfastRemovedSetItemRequest(
              itemProductId: _sausageId,
              quantity: 1,
            ),
          ],
          addedProducts: <BreakfastAddedProductRequest>[
            BreakfastAddedProductRequest(
              itemProductId: _beansId,
              quantity: 3,
              orderHint: 10,
            ),
          ],
          chosenGroups: <BreakfastChosenGroupRequest>[
            BreakfastChosenGroupRequest(
              groupId: _toastBreadGroupId,
              selectedItemProductId: _toastId,
              requestedQuantity: 1,
            ),
          ],
        ),
      );

      final BreakfastRebuildResult first = engine.rebuild(input);
      final BreakfastRebuildResult second = engine.rebuild(input);

      expect(first, second);
    });

    test('zero quantity ignored', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(
                itemProductId: _eggId,
                quantity: 0,
              ),
            ],
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(
                itemProductId: _beansId,
                quantity: 0,
              ),
            ],
            chosenGroups: <BreakfastChosenGroupRequest>[
              BreakfastChosenGroupRequest(
                groupId: _hotDrinkGroupId,
                selectedItemProductId: _teaId,
                requestedQuantity: 0,
              ),
            ],
          ),
        ),
      );

      expect(result.validationErrors, isEmpty);
      expect(result.classifiedModifiers, isEmpty);
      expect(result.lineSnapshot.modifierTotalMinor, 0);
      expect(result.lineSnapshot.lineTotalMinor, 400);
    });

    test('fold keeps free_swap and paid_swap separate', () {
      final BreakfastRebuildResult result = engine.rebuild(
        _input(
          requestedState: const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(
                itemProductId: _eggId,
                quantity: 1,
              ),
              BreakfastRemovedSetItemRequest(
                itemProductId: _baconId,
                quantity: 1,
              ),
              BreakfastRemovedSetItemRequest(
                itemProductId: _sausageId,
                quantity: 1,
              ),
            ],
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(
                itemProductId: _beansId,
                quantity: 3,
              ),
            ],
          ),
        ),
      );

      final List<BreakfastClassifiedModifier> beanRows = result
          .classifiedModifiers
          .where(
            (BreakfastClassifiedModifier row) => row.itemProductId == _beansId,
          )
          .toList(growable: false);

      expect(beanRows, hasLength(2));
      expect(beanRows.first.chargeReason, ModifierChargeReason.freeSwap);
      expect(beanRows.first.quantity, 2);
      expect(beanRows[1].chargeReason, ModifierChargeReason.paidSwap);
      expect(beanRows[1].quantity, 1);
    });
  });
}

const int _setRootId = 10;
const int _eggId = 101;
const int _baconId = 102;
const int _sausageId = 103;
const int _beansId = 104;
const int _teaId = 201;
const int _coffeeId = 202;
const int _toastId = 203;
const int _breadId = 204;
const int _hotDrinkGroupId = 301;
const int _toastBreadGroupId = 302;

BreakfastRebuildInput _input({
  BreakfastRequestedState requestedState = const BreakfastRequestedState(),
  TransactionLinePricingMode pricingMode = TransactionLinePricingMode.set,
}) {
  return BreakfastRebuildInput(
    transactionLine: BreakfastTransactionLineInput(
      lineId: 1,
      lineUuid: 'line-1',
      rootProductId: _setRootId,
      rootProductName: 'Set 4',
      baseUnitPriceMinor: 400,
      lineQuantity: 1,
      pricingMode: pricingMode,
    ),
    setConfiguration: _configuration(),
    requestedState: requestedState,
  );
}

BreakfastSetConfiguration _configuration() {
  const List<BreakfastSetItemConfig> setItems = <BreakfastSetItemConfig>[
    BreakfastSetItemConfig(
      setItemId: 1,
      itemProductId: _eggId,
      itemName: 'Egg',
      defaultQuantity: 1,
      isRemovable: true,
      sortOrder: 1,
    ),
    BreakfastSetItemConfig(
      setItemId: 2,
      itemProductId: _baconId,
      itemName: 'Bacon',
      defaultQuantity: 1,
      isRemovable: true,
      sortOrder: 2,
    ),
    BreakfastSetItemConfig(
      setItemId: 3,
      itemProductId: _sausageId,
      itemName: 'Sausage',
      defaultQuantity: 1,
      isRemovable: true,
      sortOrder: 3,
    ),
    BreakfastSetItemConfig(
      setItemId: 4,
      itemProductId: _beansId,
      itemName: 'Beans',
      defaultQuantity: 1,
      isRemovable: true,
      sortOrder: 4,
    ),
  ];

  const List<BreakfastChoiceGroupConfig> choiceGroups =
      <BreakfastChoiceGroupConfig>[
        BreakfastChoiceGroupConfig(
          groupId: _hotDrinkGroupId,
          groupName: 'Tea or Coffee',
          minSelect: 0,
          maxSelect: 1,
          includedQuantity: 1,
          sortOrder: 1,
          members: <BreakfastChoiceGroupMemberConfig>[
            BreakfastChoiceGroupMemberConfig(
              productModifierId: 11,
              itemProductId: _teaId,
              displayName: 'Tea',
            ),
            BreakfastChoiceGroupMemberConfig(
              productModifierId: 12,
              itemProductId: _coffeeId,
              displayName: 'Coffee',
            ),
          ],
        ),
        BreakfastChoiceGroupConfig(
          groupId: _toastBreadGroupId,
          groupName: 'Toast or Bread',
          minSelect: 1,
          maxSelect: 1,
          includedQuantity: 1,
          sortOrder: 2,
          members: <BreakfastChoiceGroupMemberConfig>[
            BreakfastChoiceGroupMemberConfig(
              productModifierId: 13,
              itemProductId: _toastId,
              displayName: 'Toast',
            ),
            BreakfastChoiceGroupMemberConfig(
              productModifierId: 14,
              itemProductId: _breadId,
              displayName: 'Bread',
            ),
          ],
        ),
      ];

  const List<BreakfastExtraItemConfig> extras = <BreakfastExtraItemConfig>[
    BreakfastExtraItemConfig(
      productModifierId: 21,
      itemProductId: _baconId,
      itemName: 'Bacon',
      sortOrder: 1,
    ),
    BreakfastExtraItemConfig(
      productModifierId: 22,
      itemProductId: _sausageId,
      itemName: 'Sausage',
      sortOrder: 2,
    ),
    BreakfastExtraItemConfig(
      productModifierId: 23,
      itemProductId: _beansId,
      itemName: 'Beans',
      sortOrder: 3,
    ),
  ];

  const Map<int, BreakfastCatalogProduct>
  catalogProductsById = <int, BreakfastCatalogProduct>{
    _eggId: BreakfastCatalogProduct(id: _eggId, name: 'Egg', priceMinor: 120),
    _baconId: BreakfastCatalogProduct(
      id: _baconId,
      name: 'Bacon',
      priceMinor: 150,
    ),
    _sausageId: BreakfastCatalogProduct(
      id: _sausageId,
      name: 'Sausage',
      priceMinor: 180,
    ),
    _beansId: BreakfastCatalogProduct(
      id: _beansId,
      name: 'Beans',
      priceMinor: 80,
    ),
    _teaId: BreakfastCatalogProduct(id: _teaId, name: 'Tea', priceMinor: 150),
    _coffeeId: BreakfastCatalogProduct(
      id: _coffeeId,
      name: 'Coffee',
      priceMinor: 160,
    ),
    _toastId: BreakfastCatalogProduct(
      id: _toastId,
      name: 'Toast',
      priceMinor: 100,
    ),
    _breadId: BreakfastCatalogProduct(
      id: _breadId,
      name: 'Bread',
      priceMinor: 90,
    ),
  };

  return const BreakfastSetConfiguration(
    setRootProductId: _setRootId,
    setItems: setItems,
    choiceGroups: choiceGroups,
    extras: extras,
    menuSettings: BreakfastMenuSettings(freeSwapLimit: 2, maxSwaps: 4),
    catalogProductsById: catalogProductsById,
  );
}

Matcher _classified({
  required BreakfastModifierKind kind,
  required ModifierAction action,
  required int itemProductId,
  required int quantity,
  required int unitPriceMinor,
  required int priceEffectMinor,
  required String displayName,
  required ModifierChargeReason? chargeReason,
  int? sourceGroupId,
}) {
  return isA<BreakfastClassifiedModifier>()
      .having((BreakfastClassifiedModifier row) => row.kind, 'kind', kind)
      .having((BreakfastClassifiedModifier row) => row.action, 'action', action)
      .having(
        (BreakfastClassifiedModifier row) => row.itemProductId,
        'itemProductId',
        itemProductId,
      )
      .having(
        (BreakfastClassifiedModifier row) => row.quantity,
        'quantity',
        quantity,
      )
      .having(
        (BreakfastClassifiedModifier row) => row.unitPriceMinor,
        'unitPriceMinor',
        unitPriceMinor,
      )
      .having(
        (BreakfastClassifiedModifier row) => row.priceEffectMinor,
        'priceEffectMinor',
        priceEffectMinor,
      )
      .having(
        (BreakfastClassifiedModifier row) => row.displayName,
        'displayName',
        displayName,
      )
      .having(
        (BreakfastClassifiedModifier row) => row.chargeReason,
        'chargeReason',
        chargeReason,
      )
      .having(
        (BreakfastClassifiedModifier row) => row.sourceGroupId,
        'sourceGroupId',
        sourceGroupId,
      );
}
