import '../../core/errors/exceptions.dart';
import '../models/breakfast_rebuild.dart';
import '../models/order_modifier.dart';

class BreakfastRebuildEngine {
  const BreakfastRebuildEngine();

  BreakfastRebuildResult rebuild(BreakfastRebuildInput input) {
    final List<BreakfastEditErrorCode> rootErrors = _validateRootAssumptions(
      input,
    );
    if (rootErrors.isNotEmpty) {
      return _errorResult(input: input, validationErrors: rootErrors);
    }

    final List<_DefaultUnit> defaultUnits = _expandSetItems(
      input.setConfiguration.setItems,
    );
    final _RemovalResult removalResult = _applyRemovals(
      defaultUnits: defaultUnits,
      requestedRemovals: input.requestedState.removedSetItems,
    );
    final _ChoiceResult choiceResult = _classifyChoices(
      configuration: input.setConfiguration,
      requestedChoices: input.requestedState.chosenGroups,
    );

    final List<BreakfastEditErrorCode> errors = <BreakfastEditErrorCode>[
      ...removalResult.errors,
      ...choiceResult.errors,
    ];
    if (errors.isNotEmpty) {
      return _errorResult(input: input, validationErrors: errors);
    }

    final List<_DefaultUnit> pendingReplacementUnits =
        List<_DefaultUnit>.from(removalResult.removedUnits);
    final List<_AddUnit> addUnits = _expandAddedProducts(
      requestedAdds: input.requestedState.addedProducts,
      configuration: input.setConfiguration,
    );

    int replacementCounter = 0;
    final List<BreakfastClassifiedModifier> addRows =
        <BreakfastClassifiedModifier>[];
    for (final _AddUnit addUnit in addUnits) {
      final bool isChoiceCapable = input.setConfiguration.choiceCapableProductIds
          .contains(addUnit.itemProductId);
      final bool isSwapEligible = input.setConfiguration.swapEligibleProductIds
          .contains(addUnit.itemProductId);

      if (isChoiceCapable || !isSwapEligible) {
        addRows.add(
          _buildAddRow(
            addUnit: addUnit,
            kind: BreakfastModifierKind.extraAdd,
            chargeReason: ModifierChargeReason.extraAdd,
          ),
        );
        continue;
      }

      if (pendingReplacementUnits.isNotEmpty) {
        pendingReplacementUnits.removeAt(0);
        replacementCounter += 1;
        if (replacementCounter <= input.setConfiguration.menuSettings.freeSwapLimit) {
          addRows.add(
            _buildAddRow(
              addUnit: addUnit,
              kind: BreakfastModifierKind.freeSwap,
              chargeReason: ModifierChargeReason.freeSwap,
              priceEffectMinor: 0,
            ),
          );
        } else {
          addRows.add(
            _buildAddRow(
              addUnit: addUnit,
              kind: BreakfastModifierKind.paidSwap,
              chargeReason: ModifierChargeReason.paidSwap,
            ),
          );
        }
        continue;
      }

      addRows.add(
        _buildAddRow(
          addUnit: addUnit,
          kind: BreakfastModifierKind.extraAdd,
          chargeReason: ModifierChargeReason.extraAdd,
        ),
      );
    }

    final List<BreakfastClassifiedModifier> foldedRows =
        _foldRows(<BreakfastClassifiedModifier>[
          ...removalResult.rows,
          ...choiceResult.rows,
          ...addRows,
        ]);
    final BreakfastPricingBreakdown breakdown = _computeTotals(
      input: input,
      rows: foldedRows,
    );

    return BreakfastRebuildResult(
      lineSnapshot: BreakfastLineSnapshot(
        baseUnitPriceMinor: input.transactionLine.baseUnitPriceMinor,
        removalDiscountTotalMinor: breakdown.removalDiscountTotalMinor,
        modifierTotalMinor:
            breakdown.extraAddTotalMinor + breakdown.paidSwapTotalMinor,
        lineTotalMinor: breakdown.finalLineTotalMinor,
      ),
      classifiedModifiers: _stableOutputSort(foldedRows),
      pricingBreakdown: breakdown,
      validationErrors: const <BreakfastEditErrorCode>[],
      rebuildMetadata: BreakfastRebuildMetadata(
        replacementCount: replacementCounter,
        unmatchedRemovalCount: pendingReplacementUnits.length,
      ),
    );
  }

  List<BreakfastEditErrorCode> _validateRootAssumptions(
    BreakfastRebuildInput input,
  ) {
    final Set<BreakfastEditErrorCode> errors = <BreakfastEditErrorCode>{};
    if (input.transactionLine.rootProductId !=
        input.setConfiguration.setRootProductId) {
      errors.add(BreakfastEditErrorCode.rootNotSetProduct);
    }
    for (final BreakfastRemovedSetItemRequest removal
        in input.requestedState.removedSetItems) {
      if (removal.quantity < 0) {
        errors.add(BreakfastEditErrorCode.negativeQuantity);
      }
    }
    for (final BreakfastAddedProductRequest add in input.requestedState.addedProducts) {
      if (add.quantity < 0) {
        errors.add(BreakfastEditErrorCode.negativeQuantity);
      }
      if (input.setConfiguration.findCatalogProduct(add.itemProductId) == null) {
        errors.add(BreakfastEditErrorCode.unknownProduct);
      }
    }
    for (final BreakfastChosenGroupRequest choice
        in input.requestedState.chosenGroups) {
      if (choice.requestedQuantity < 0) {
        errors.add(BreakfastEditErrorCode.negativeQuantity);
      }
      if (input.setConfiguration.findGroup(choice.groupId) == null) {
        errors.add(BreakfastEditErrorCode.invalidChoiceGroup);
      }
    }
    return errors.toList(growable: false);
  }

  List<_DefaultUnit> _expandSetItems(List<BreakfastSetItemConfig> setItems) {
    final List<BreakfastSetItemConfig> sortedItems =
        List<BreakfastSetItemConfig>.from(setItems)
          ..sort(
            (BreakfastSetItemConfig a, BreakfastSetItemConfig b) {
              final int sortCompare = a.sortOrder.compareTo(b.sortOrder);
              if (sortCompare != 0) {
                return sortCompare;
              }
              return a.setItemId.compareTo(b.setItemId);
            },
          );
    final List<_DefaultUnit> units = <_DefaultUnit>[];
    for (final BreakfastSetItemConfig item in sortedItems) {
      for (int index = 0; index < item.defaultQuantity; index += 1) {
        units.add(
          _DefaultUnit(
            setItemId: item.setItemId,
            itemProductId: item.itemProductId,
            itemName: item.itemName,
            unitIndex: index,
            sortOrder: item.sortOrder,
            isRemovable: item.isRemovable,
          ),
        );
      }
    }
    return units;
  }

  _RemovalResult _applyRemovals({
    required List<_DefaultUnit> defaultUnits,
    required List<BreakfastRemovedSetItemRequest> requestedRemovals,
  }) {
    final List<BreakfastClassifiedModifier> rows = <BreakfastClassifiedModifier>[];
    final List<BreakfastEditErrorCode> errors = <BreakfastEditErrorCode>[];
    final List<_DefaultUnit> removedUnits = <_DefaultUnit>[];
    int nextSortKey = 1;

    for (final BreakfastRemovedSetItemRequest removal in requestedRemovals) {
      if (removal.quantity == 0) {
        continue;
      }
      final List<_DefaultUnit> candidates =
          defaultUnits
              .where(
                (_DefaultUnit unit) =>
                    unit.itemProductId == removal.itemProductId &&
                    unit.isRemovable &&
                    !unit.isRemoved,
              )
              .toList(growable: false)
            ..sort(
              (_DefaultUnit a, _DefaultUnit b) {
                final int sortCompare = a.sortOrder.compareTo(b.sortOrder);
                if (sortCompare != 0) {
                  return sortCompare;
                }
                return a.unitIndex.compareTo(b.unitIndex);
              },
            );
      if (candidates.length < removal.quantity) {
        errors.add(BreakfastEditErrorCode.removeQuantityExceedsDefault);
        continue;
      }

      for (int index = 0; index < removal.quantity; index += 1) {
        candidates[index].isRemoved = true;
        removedUnits.add(candidates[index]);
      }

      rows.add(
        BreakfastClassifiedModifier(
          kind: BreakfastModifierKind.setRemove,
          action: ModifierAction.remove,
          chargeReason: null,
          itemProductId: removal.itemProductId,
          displayName: candidates.first.itemName,
          quantity: removal.quantity,
          unitPriceMinor: 0,
          priceEffectMinor: 0,
          sortKey: nextSortKey,
          sourceSetItemId: candidates.first.setItemId,
        ),
      );
      nextSortKey += 1;
    }

    return _RemovalResult(
      rows: rows,
      removedUnits: removedUnits,
      errors: errors,
    );
  }

  _ChoiceResult _classifyChoices({
    required BreakfastSetConfiguration configuration,
    required List<BreakfastChosenGroupRequest> requestedChoices,
  }) {
    final List<BreakfastClassifiedModifier> rows = <BreakfastClassifiedModifier>[];
    final List<BreakfastEditErrorCode> errors = <BreakfastEditErrorCode>[];

    for (final BreakfastChosenGroupRequest choice in requestedChoices) {
      final BreakfastChoiceGroupConfig? group = configuration.findGroup(
        choice.groupId,
      );
      if (group == null) {
        errors.add(BreakfastEditErrorCode.invalidChoiceGroup);
        continue;
      }
      final int? selectedItemProductId = choice.selectedItemProductId;
      if (selectedItemProductId == null || choice.requestedQuantity == 0) {
        continue;
      }

      final BreakfastChoiceGroupMemberConfig? member = group.findMember(
        selectedItemProductId,
      );
      if (member == null) {
        errors.add(BreakfastEditErrorCode.choiceMemberNotAllowed);
        continue;
      }
      if (_isInvalidChoiceQuantity(group, choice.requestedQuantity)) {
        errors.add(BreakfastEditErrorCode.invalidChoiceQuantity);
        continue;
      }

      final BreakfastCatalogProduct? catalogProduct =
          configuration.findCatalogProduct(selectedItemProductId);
      if (catalogProduct == null) {
        errors.add(BreakfastEditErrorCode.unknownProduct);
        continue;
      }

      final int includedQuantity = choice.requestedQuantity < group.includedQuantity
          ? choice.requestedQuantity
          : group.includedQuantity;
      final int overflowQuantity = choice.requestedQuantity - includedQuantity;

      if (includedQuantity > 0) {
        rows.add(
          BreakfastClassifiedModifier(
            kind: BreakfastModifierKind.choiceIncluded,
            action: ModifierAction.choice,
            chargeReason: ModifierChargeReason.includedChoice,
            itemProductId: selectedItemProductId,
            displayName: member.displayName,
            quantity: includedQuantity,
            unitPriceMinor: catalogProduct.priceMinor,
            priceEffectMinor: 0,
            sortKey: 1000 + group.sortOrder,
            sourceGroupId: group.groupId,
          ),
        );
      }
      if (overflowQuantity > 0) {
        rows.add(
          BreakfastClassifiedModifier(
            kind: BreakfastModifierKind.extraAdd,
            action: ModifierAction.add,
            chargeReason: ModifierChargeReason.extraAdd,
            itemProductId: selectedItemProductId,
            displayName: member.displayName,
            quantity: overflowQuantity,
            unitPriceMinor: catalogProduct.priceMinor,
            priceEffectMinor: catalogProduct.priceMinor * overflowQuantity,
            sortKey: 2000 + group.sortOrder,
            sourceGroupId: group.groupId,
          ),
        );
      }
    }

    return _ChoiceResult(rows: rows, errors: errors);
  }

  bool _isInvalidChoiceQuantity(
    BreakfastChoiceGroupConfig group,
    int requestedQuantity,
  ) {
    if (requestedQuantity < 0) {
      return true;
    }
    if (requestedQuantity == 0) {
      return false;
    }
    return requestedQuantity < group.includedQuantity;
  }

  List<_AddUnit> _expandAddedProducts({
    required List<BreakfastAddedProductRequest> requestedAdds,
    required BreakfastSetConfiguration configuration,
  }) {
    final List<BreakfastAddedProductRequest> sortedAdds =
        List<BreakfastAddedProductRequest>.from(requestedAdds)
          ..sort(
            (BreakfastAddedProductRequest a, BreakfastAddedProductRequest b) {
              final int orderCompare = a.orderHint.compareTo(b.orderHint);
              if (orderCompare != 0) {
                return orderCompare;
              }
              return a.itemProductId.compareTo(b.itemProductId);
            },
          );

    final List<_AddUnit> units = <_AddUnit>[];
    int nextSortKey = 3000;
    for (final BreakfastAddedProductRequest add in sortedAdds) {
      final BreakfastCatalogProduct? product = configuration.findCatalogProduct(
        add.itemProductId,
      );
      if (product == null) {
        continue;
      }
      for (int index = 0; index < add.quantity; index += 1) {
        units.add(
          _AddUnit(
            itemProductId: add.itemProductId,
            displayName: product.name,
            unitPriceMinor: product.priceMinor,
            sortKey: nextSortKey,
          ),
        );
        nextSortKey += 1;
      }
    }
    return units;
  }

  BreakfastClassifiedModifier _buildAddRow({
    required _AddUnit addUnit,
    required BreakfastModifierKind kind,
    required ModifierChargeReason chargeReason,
    int? priceEffectMinor,
  }) {
    final int resolvedPriceEffectMinor = priceEffectMinor ?? addUnit.unitPriceMinor;
    return BreakfastClassifiedModifier(
      kind: kind,
      action: ModifierAction.add,
      chargeReason: chargeReason,
      itemProductId: addUnit.itemProductId,
      displayName: addUnit.displayName,
      quantity: 1,
      unitPriceMinor: addUnit.unitPriceMinor,
      priceEffectMinor: resolvedPriceEffectMinor,
      sortKey: addUnit.sortKey,
    );
  }

  List<BreakfastClassifiedModifier> _foldRows(
    List<BreakfastClassifiedModifier> rows,
  ) {
    final Map<_FoldKey, BreakfastClassifiedModifier> folded =
        <_FoldKey, BreakfastClassifiedModifier>{};
    for (final BreakfastClassifiedModifier row in rows) {
      final _FoldKey key = _FoldKey(
        action: row.action,
        chargeReason: row.chargeReason,
        itemProductId: row.itemProductId,
        unitPriceMinor: row.unitPriceMinor,
        displayName: row.displayName,
        sourceGroupId: row.sourceGroupId,
        sourceSetItemId: row.sourceSetItemId,
      );
      final BreakfastClassifiedModifier? existing = folded[key];
      if (existing == null) {
        folded[key] = row;
        continue;
      }
      folded[key] = existing.copyWith(
        quantity: existing.quantity + row.quantity,
        priceEffectMinor: existing.priceEffectMinor + row.priceEffectMinor,
        sortKey: existing.sortKey < row.sortKey ? existing.sortKey : row.sortKey,
      );
    }
    return folded.values.toList(growable: false);
  }

  BreakfastPricingBreakdown _computeTotals({
    required BreakfastRebuildInput input,
    required List<BreakfastClassifiedModifier> rows,
  }) {
    int extraAddTotalMinor = 0;
    int paidSwapTotalMinor = 0;
    for (final BreakfastClassifiedModifier row in rows) {
      switch (row.chargeReason) {
        case ModifierChargeReason.extraAdd:
          extraAddTotalMinor += row.priceEffectMinor;
          break;
        case ModifierChargeReason.paidSwap:
          paidSwapTotalMinor += row.priceEffectMinor;
          break;
        case ModifierChargeReason.freeSwap:
        case ModifierChargeReason.includedChoice:
        case ModifierChargeReason.removalDiscount:
        case null:
          break;
      }
    }
    final int basePriceMinor =
        input.transactionLine.baseUnitPriceMinor * input.transactionLine.lineQuantity;
    final int finalLineTotalMinor =
        basePriceMinor + extraAddTotalMinor + paidSwapTotalMinor;
    return BreakfastPricingBreakdown(
      basePriceMinor: basePriceMinor,
      extraAddTotalMinor: extraAddTotalMinor,
      paidSwapTotalMinor: paidSwapTotalMinor,
      freeSwapTotalMinor: 0,
      includedChoiceTotalMinor: 0,
      removeTotalMinor: 0,
      removalDiscountTotalMinor: 0,
      finalLineTotalMinor: finalLineTotalMinor,
    );
  }

  List<BreakfastClassifiedModifier> _stableOutputSort(
    List<BreakfastClassifiedModifier> rows,
  ) {
    final List<BreakfastClassifiedModifier> sorted =
        List<BreakfastClassifiedModifier>.from(rows);
    sorted.sort((BreakfastClassifiedModifier a, BreakfastClassifiedModifier b) {
      final int kindCompare = _kindPriority(a.kind).compareTo(_kindPriority(b.kind));
      if (kindCompare != 0) {
        return kindCompare;
      }
      final int sortCompare = a.sortKey.compareTo(b.sortKey);
      if (sortCompare != 0) {
        return sortCompare;
      }
      return (a.itemProductId ?? 0).compareTo(b.itemProductId ?? 0);
    });
    return sorted;
  }

  int _kindPriority(BreakfastModifierKind kind) {
    switch (kind) {
      case BreakfastModifierKind.setRemove:
        return 0;
      case BreakfastModifierKind.choiceIncluded:
        return 1;
      case BreakfastModifierKind.freeSwap:
        return 2;
      case BreakfastModifierKind.paidSwap:
        return 3;
      case BreakfastModifierKind.extraAdd:
        return 4;
    }
  }

  BreakfastRebuildResult _errorResult({
    required BreakfastRebuildInput input,
    required List<BreakfastEditErrorCode> validationErrors,
  }) {
    final int basePriceMinor =
        input.transactionLine.baseUnitPriceMinor * input.transactionLine.lineQuantity;
    return BreakfastRebuildResult(
      lineSnapshot: BreakfastLineSnapshot(
        baseUnitPriceMinor: input.transactionLine.baseUnitPriceMinor,
        removalDiscountTotalMinor: 0,
        modifierTotalMinor: 0,
        lineTotalMinor: basePriceMinor,
      ),
      classifiedModifiers: const <BreakfastClassifiedModifier>[],
      pricingBreakdown: BreakfastPricingBreakdown(
        basePriceMinor: basePriceMinor,
        extraAddTotalMinor: 0,
        paidSwapTotalMinor: 0,
        freeSwapTotalMinor: 0,
        includedChoiceTotalMinor: 0,
        removeTotalMinor: 0,
        removalDiscountTotalMinor: 0,
        finalLineTotalMinor: basePriceMinor,
      ),
      validationErrors: validationErrors.toSet().toList(growable: false),
      rebuildMetadata: const BreakfastRebuildMetadata(
        replacementCount: 0,
        unmatchedRemovalCount: 0,
      ),
    );
  }
}

class _DefaultUnit {
  _DefaultUnit({
    required this.setItemId,
    required this.itemProductId,
    required this.itemName,
    required this.unitIndex,
    required this.sortOrder,
    required this.isRemovable,
  });

  final int setItemId;
  final int itemProductId;
  final String itemName;
  final int unitIndex;
  final int sortOrder;
  final bool isRemovable;
  bool isRemoved = false;
}

class _RemovalResult {
  const _RemovalResult({
    required this.rows,
    required this.removedUnits,
    required this.errors,
  });

  final List<BreakfastClassifiedModifier> rows;
  final List<_DefaultUnit> removedUnits;
  final List<BreakfastEditErrorCode> errors;
}

class _ChoiceResult {
  const _ChoiceResult({
    required this.rows,
    required this.errors,
  });

  final List<BreakfastClassifiedModifier> rows;
  final List<BreakfastEditErrorCode> errors;
}

class _AddUnit {
  const _AddUnit({
    required this.itemProductId,
    required this.displayName,
    required this.unitPriceMinor,
    required this.sortKey,
  });

  final int itemProductId;
  final String displayName;
  final int unitPriceMinor;
  final int sortKey;
}

class _FoldKey {
  const _FoldKey({
    required this.action,
    required this.chargeReason,
    required this.itemProductId,
    required this.unitPriceMinor,
    required this.displayName,
    required this.sourceGroupId,
    required this.sourceSetItemId,
  });

  final ModifierAction action;
  final ModifierChargeReason? chargeReason;
  final int? itemProductId;
  final int unitPriceMinor;
  final String displayName;
  final int? sourceGroupId;
  final int? sourceSetItemId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _FoldKey &&
        other.action == action &&
        other.chargeReason == chargeReason &&
        other.itemProductId == itemProductId &&
        other.unitPriceMinor == unitPriceMinor &&
        other.displayName == displayName &&
        other.sourceGroupId == sourceGroupId &&
        other.sourceSetItemId == sourceSetItemId;
  }

  @override
  int get hashCode => Object.hash(
    action,
    chargeReason,
    itemProductId,
    unitPriceMinor,
    displayName,
    sourceGroupId,
    sourceSetItemId,
  );
}
