import 'package:epos_app/domain/models/breakfast_cooking_instruction.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/domain/services/breakfast_cooking_instruction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const BreakfastCookingInstructionService service =
      BreakfastCookingInstructionService();

  test(
    'buildPersistedRecords uses effective kept quantity for included items',
    () {
      final List<BreakfastCookingInstructionRecord> records = service
          .buildPersistedRecords(
            transactionLineId: 10,
            configuration: _configuration,
            requestedState: const BreakfastRequestedState(
              removedSetItems: <BreakfastRemovedSetItemRequest>[
                BreakfastRemovedSetItemRequest(itemProductId: 101, quantity: 1),
              ],
              cookingInstructions: <BreakfastCookingInstructionRequest>[
                BreakfastCookingInstructionRequest(
                  itemProductId: 101,
                  instructionCode: 'runny',
                  instructionLabel: 'Runny',
                ),
              ],
            ),
            createUuid: () => 'instruction-uuid',
          );

      expect(records, hasLength(1));
      expect(records.single.itemProductId, 101);
      expect(records.single.appliedQuantity, 1);
      expect(records.single.kitchenLabel, 'Egg x1 - RUNNY');
    },
  );

  test(
    'sanitizeRequestedState clears instruction when item is no longer present',
    () {
      final BreakfastRequestedState state = service.sanitizeRequestedState(
        configuration: _configuration,
        requestedState: const BreakfastRequestedState(
          removedSetItems: <BreakfastRemovedSetItemRequest>[
            BreakfastRemovedSetItemRequest(itemProductId: 101, quantity: 2),
          ],
          cookingInstructions: <BreakfastCookingInstructionRequest>[
            BreakfastCookingInstructionRequest(
              itemProductId: 101,
              instructionCode: 'runny',
              instructionLabel: 'Runny',
            ),
          ],
        ),
      );

      expect(state.cookingInstructions, isEmpty);
    },
  );

  test('buildTargets exposes bacon once it is added as an extra', () {
    final List<BreakfastCookingInstructionTarget> targets = service
        .buildTargets(
          configuration: _configuration,
          requestedState: const BreakfastRequestedState(
            addedProducts: <BreakfastAddedProductRequest>[
              BreakfastAddedProductRequest(itemProductId: 102, quantity: 1),
            ],
            cookingInstructions: <BreakfastCookingInstructionRequest>[
              BreakfastCookingInstructionRequest(
                itemProductId: 102,
                instructionCode: 'crispy',
                instructionLabel: 'Crispy',
              ),
            ],
          ),
        );

    final BreakfastCookingInstructionTarget bacon = targets.singleWhere(
      (BreakfastCookingInstructionTarget target) => target.itemProductId == 102,
    );
    expect(bacon.quantity, 1);
    expect(bacon.selectedInstructionCode, 'crispy');
    expect(
      bacon.options.map(
        (BreakfastCookingInstructionOption option) => option.code,
      ),
      containsAll(<String>['soft', 'crispy', 'extra_crispy']),
    );
  });
}

const BreakfastSetConfiguration _configuration = BreakfastSetConfiguration(
  setRootProductId: 1,
  setItems: <BreakfastSetItemConfig>[
    BreakfastSetItemConfig(
      setItemId: 1,
      itemProductId: 101,
      itemName: 'Egg',
      defaultQuantity: 2,
      isRemovable: true,
      sortOrder: 1,
    ),
  ],
  choiceGroups: <BreakfastChoiceGroupConfig>[],
  extras: <BreakfastExtraItemConfig>[
    BreakfastExtraItemConfig(
      productModifierId: 1,
      itemProductId: 102,
      itemName: 'Bacon',
      sortOrder: 2,
    ),
  ],
  menuSettings: BreakfastMenuSettings(freeSwapLimit: 2, maxSwaps: 4),
  catalogProductsById: <int, BreakfastCatalogProduct>{
    101: BreakfastCatalogProduct(id: 101, name: 'Egg', priceMinor: 120),
    102: BreakfastCatalogProduct(id: 102, name: 'Bacon', priceMinor: 150),
  },
);
