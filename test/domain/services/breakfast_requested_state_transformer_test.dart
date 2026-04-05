import 'package:epos_app/domain/models/breakfast_line_edit.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/services/breakfast_requested_state_mapper.dart';
import 'package:epos_app/domain/services/breakfast_requested_state_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BreakfastRequestedStateTransformer', () {
    test(
      'setRemovedQuantity and chooseGroup stay deterministic and sorted',
      () {
        const BreakfastRequestedState initial = BreakfastRequestedState(
          removedSetItems: <BreakfastRemovedSetItemRequest>[
            BreakfastRemovedSetItemRequest(itemProductId: 20, quantity: 1),
          ],
          chosenGroups: <BreakfastChosenGroupRequest>[
            BreakfastChosenGroupRequest(
              groupId: 9,
              selectedItemProductId: 91,
              requestedQuantity: 1,
            ),
          ],
        );

        final BreakfastRequestedState removed =
            BreakfastRequestedStateTransformer.setRemovedQuantity(
              currentState: initial,
              itemProductId: 10,
              quantity: 2,
            );
        final BreakfastRequestedState chosen =
            BreakfastRequestedStateTransformer.chooseGroup(
              currentState: removed,
              groupId: 7,
              selectedItemProductId: 71,
              requestedQuantity: 2,
            );
        final BreakfastRequestedState chosenAgain =
            BreakfastRequestedStateTransformer.chooseGroup(
              currentState: removed,
              groupId: 7,
              selectedItemProductId: 71,
              requestedQuantity: 2,
            );

        expect(removed.removedSetItems, const <BreakfastRemovedSetItemRequest>[
          BreakfastRemovedSetItemRequest(itemProductId: 10, quantity: 2),
          BreakfastRemovedSetItemRequest(itemProductId: 20, quantity: 1),
        ]);
        expect(chosen.chosenGroups, const <BreakfastChosenGroupRequest>[
          BreakfastChosenGroupRequest(
            groupId: 7,
            selectedItemProductId: 71,
            requestedQuantity: 2,
          ),
          BreakfastChosenGroupRequest(
            groupId: 9,
            selectedItemProductId: 91,
            requestedQuantity: 1,
          ),
        ]);
        expect(chosenAgain, chosen);
      },
    );

    test('setAddedQuantity preserves order hints deterministically', () {
      const BreakfastRequestedState initial = BreakfastRequestedState(
        addedProducts: <BreakfastAddedProductRequest>[
          BreakfastAddedProductRequest(
            itemProductId: 30,
            quantity: 1,
            orderHint: 3,
          ),
          BreakfastAddedProductRequest(
            itemProductId: 10,
            quantity: 1,
            orderHint: 1,
          ),
        ],
      );

      final BreakfastRequestedState updated =
          BreakfastRequestedStateTransformer.setAddedQuantity(
            currentState: initial,
            itemProductId: 30,
            quantity: 4,
          );
      final BreakfastRequestedState appended =
          BreakfastRequestedStateTransformer.setAddedQuantity(
            currentState: updated,
            itemProductId: 20,
            quantity: 2,
          );

      expect(updated.addedProducts, const <BreakfastAddedProductRequest>[
        BreakfastAddedProductRequest(
          itemProductId: 10,
          quantity: 1,
          orderHint: 1,
        ),
        BreakfastAddedProductRequest(
          itemProductId: 30,
          quantity: 4,
          orderHint: 3,
        ),
      ]);
      expect(appended.addedProducts, const <BreakfastAddedProductRequest>[
        BreakfastAddedProductRequest(
          itemProductId: 10,
          quantity: 1,
          orderHint: 1,
        ),
        BreakfastAddedProductRequest(
          itemProductId: 30,
          quantity: 4,
          orderHint: 3,
        ),
        BreakfastAddedProductRequest(
          itemProductId: 20,
          quantity: 2,
          orderHint: 4,
        ),
      ]);
    });

    test('setRemovedQuantity with zero clears prior removal intent', () {
      const BreakfastRequestedState initial = BreakfastRequestedState(
        removedSetItems: <BreakfastRemovedSetItemRequest>[
          BreakfastRemovedSetItemRequest(itemProductId: 10, quantity: 2),
          BreakfastRemovedSetItemRequest(itemProductId: 20, quantity: 1),
        ],
      );

      final BreakfastRequestedState updated =
          BreakfastRequestedStateTransformer.setRemovedQuantity(
            currentState: initial,
            itemProductId: 10,
            quantity: 0,
          );

      expect(updated.removedSetItems, const <BreakfastRemovedSetItemRequest>[
        BreakfastRemovedSetItemRequest(itemProductId: 20, quantity: 1),
      ]);
    });

    test('assertInvariant rejects malformed requested-state ordering', () {
      expect(
        () => BreakfastRequestedStateTransformer.assertInvariant(
          const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(itemProductId: 20, quantity: 1),
              BreakfastRemovedSetItemRequest(itemProductId: 10, quantity: 1),
            ],
          ),
          source: 'test',
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains(
              'removedSetItems.itemProductId must remain strictly ascending',
            ),
          ),
        ),
      );
    });

    test('assertInvariant rejects duplicate add identity pairs', () {
      expect(
        () => BreakfastRequestedStateTransformer.assertInvariant(
          const BreakfastRequestedState(
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(
                itemProductId: 30,
                quantity: 1,
                orderHint: 3,
              ),
              BreakfastAddedProductRequest(
                itemProductId: 30,
                quantity: 2,
                orderHint: 3,
              ),
            ],
          ),
          source: 'test',
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('duplicate addedProducts.(orderHint,itemProductId) value'),
          ),
        ),
      );
    });

    test(
      'BreakfastLineEdit remains a deterministic wrapper over intent apply',
      () {
        const BreakfastRequestedState initial = BreakfastRequestedState();

        final BreakfastRequestedState first =
            const BreakfastLineEdit.setAddedQuantity(
              itemProductId: 88,
              quantity: 2,
            ).applyTo(initial);
        final BreakfastRequestedState second =
            const BreakfastLineEdit.setAddedQuantity(
              itemProductId: 88,
              quantity: 2,
            ).applyTo(initial);

        expect(first, second);
        expect(first.addedProducts, const <BreakfastAddedProductRequest>[
          BreakfastAddedProductRequest(
            itemProductId: 88,
            quantity: 2,
            orderHint: 0,
          ),
        ]);
      },
    );
  });

  group('BreakfastRequestedStateMapper', () {
    test(
      'strict persisted snapshot reverse mapping emits only remove add and choose intent',
      () {
        final BreakfastRequestedState state =
            BreakfastRequestedStateMapper.fromPersistedSnapshot(
              modifiers: <OrderModifier>[
                _modifier(
                  id: 1,
                  action: ModifierAction.remove,
                  itemProductId: 101,
                  quantity: 1,
                ),
                _modifier(
                  id: 2,
                  action: ModifierAction.choice,
                  chargeReason: ModifierChargeReason.includedChoice,
                  itemProductId: 201,
                  quantity: 2,
                  sourceGroupId: 7,
                  sortKey: 1001,
                ),
                _modifier(
                  id: 3,
                  action: ModifierAction.add,
                  chargeReason: ModifierChargeReason.extraAdd,
                  itemProductId: 201,
                  quantity: 1,
                  sourceGroupId: 7,
                  sortKey: 2001,
                ),
                _modifier(
                  id: 4,
                  action: ModifierAction.add,
                  chargeReason: ModifierChargeReason.freeSwap,
                  itemProductId: 301,
                  quantity: 1,
                  sortKey: 3001,
                ),
                _modifier(
                  id: 5,
                  action: ModifierAction.add,
                  chargeReason: ModifierChargeReason.paidSwap,
                  itemProductId: 401,
                  quantity: 2,
                  sortKey: 4001,
                ),
              ],
            );

        expect(
          state,
          const BreakfastRequestedState(
            removedSetItems: <BreakfastRemovedSetItemRequest>[
              BreakfastRemovedSetItemRequest(itemProductId: 101, quantity: 1),
            ],
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(
                itemProductId: 301,
                quantity: 1,
                orderHint: 3001,
              ),
              BreakfastAddedProductRequest(
                itemProductId: 401,
                quantity: 2,
                orderHint: 4001,
              ),
            ],
            chosenGroups: <BreakfastChosenGroupRequest>[
              BreakfastChosenGroupRequest(
                groupId: 7,
                selectedItemProductId: 201,
                requestedQuantity: 3,
              ),
            ],
          ),
        );
      },
    );

    test(
      'configuration fallback for legacy rows is isolated from the strict reverse mapper',
      () {
        final List<OrderModifier> modifiers = <OrderModifier>[
          _modifier(
            id: 10,
            action: ModifierAction.choice,
            chargeReason: ModifierChargeReason.includedChoice,
            itemProductId: 201,
            quantity: 2,
            sortKey: 1001,
          ),
          _modifier(
            id: 11,
            action: ModifierAction.add,
            chargeReason: ModifierChargeReason.extraAdd,
            itemProductId: 201,
            quantity: 1,
            sortKey: 2001,
          ),
        ];

        final BreakfastRequestedState strict =
            BreakfastRequestedStateMapper.fromPersistedSnapshot(
              modifiers: modifiers,
            );
        final BreakfastRequestedState compatibility =
            BreakfastRequestedStateMapper.fromPersistedSnapshotWithConfigurationFallback(
              modifiers: modifiers,
              configuration: _configurationWithChoiceMember(
                groupId: 7,
                itemProductId: 201,
              ),
            );

        expect(strict.chosenGroups, isEmpty);
        expect(strict.addedProducts, const <BreakfastAddedProductRequest>[
          BreakfastAddedProductRequest(
            itemProductId: 201,
            quantity: 1,
            orderHint: 2001,
          ),
        ]);

        expect(compatibility.chosenGroups, const <BreakfastChosenGroupRequest>[
          BreakfastChosenGroupRequest(
            groupId: 7,
            selectedItemProductId: 201,
            requestedQuantity: 3,
          ),
        ]);
        expect(compatibility.addedProducts, isEmpty);
      },
    );

    test(
      'strict reverse mapping preserves explicit none choice selections',
      () {
        final BreakfastRequestedState state =
            BreakfastRequestedStateMapper.fromPersistedSnapshot(
              modifiers: <OrderModifier>[
                _modifier(
                  id: 20,
                  action: ModifierAction.choice,
                  chargeReason: ModifierChargeReason.includedChoice,
                  itemProductId: null,
                  quantity: 1,
                  sourceGroupId: 8,
                ),
              ],
            );

        expect(state.chosenGroups, const <BreakfastChosenGroupRequest>[
          BreakfastChosenGroupRequest(
            groupId: 8,
            selectedItemProductId: null,
            requestedQuantity: 1,
          ),
        ]);
      },
    );
  });
}

OrderModifier _modifier({
  required int id,
  required ModifierAction action,
  ModifierChargeReason? chargeReason,
  int? itemProductId,
  int? sourceGroupId,
  int quantity = 1,
  int sortKey = 0,
}) {
  return OrderModifier(
    id: id,
    uuid: 'modifier-$id',
    transactionLineId: 1,
    action: action,
    itemName: 'Item $id',
    extraPriceMinor: 0,
    chargeReason: chargeReason,
    itemProductId: itemProductId,
    sourceGroupId: sourceGroupId,
    quantity: quantity,
    unitPriceMinor: 0,
    priceEffectMinor: 0,
    sortKey: sortKey,
  );
}

BreakfastSetConfiguration _configurationWithChoiceMember({
  required int groupId,
  required int itemProductId,
}) {
  return BreakfastSetConfiguration(
    setRootProductId: 1,
    setItems: const <BreakfastSetItemConfig>[],
    choiceGroups: <BreakfastChoiceGroupConfig>[
      BreakfastChoiceGroupConfig(
        groupId: groupId,
        groupName: 'Tea or Coffee',
        minSelect: 0,
        maxSelect: 1,
        includedQuantity: 1,
        sortOrder: 1,
        members: <BreakfastChoiceGroupMemberConfig>[
          BreakfastChoiceGroupMemberConfig(
            productModifierId: 1,
            itemProductId: itemProductId,
            displayName: 'Tea',
          ),
        ],
      ),
    ],
    extras: const <BreakfastExtraItemConfig>[],
    menuSettings: const BreakfastMenuSettings(freeSwapLimit: 2, maxSwaps: 4),
    catalogProductsById: const <int, BreakfastCatalogProduct>{},
  );
}
