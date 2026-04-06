import '../../core/errors/exceptions.dart';
import '../models/breakfast_rebuild.dart';
import '../models/order_modifier.dart';
import '../models/transaction_line.dart';

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
    final _ChoiceNormalizationResult normalizedChoices =
        _normalizeChoiceSelections(
          configuration: input.setConfiguration,
          requestedChoices: input.requestedState.chosenGroups,
        );

    final List<BreakfastEditErrorCode> validationErrors = _dedupeErrors(
      <BreakfastEditErrorCode>[
        ...removalResult.errors,
        ...normalizedChoices.errors,
      ],
    );
    if (validationErrors.isNotEmpty) {
      return _errorResult(input: input, validationErrors: validationErrors);
    }

    final _ChoiceClassificationResult choiceResult = _classifyChoices(
      configuration: input.setConfiguration,
      normalizedChoices: normalizedChoices.choices,
    );
    if (choiceResult.errors.isNotEmpty) {
      return _errorResult(
        input: input,
        validationErrors: _dedupeErrors(choiceResult.errors),
      );
    }

    final List<_DefaultUnit> pendingReplacementUnits = List<_DefaultUnit>.from(
      removalResult.removedUnits,
    )..sort(_compareDefaultUnits);
    final List<_AddUnit> addUnits = _expandAddedProducts(
      requestedAdds: input.requestedState.addedProducts,
      configuration: input.setConfiguration,
    );

    int replacementCounter = 0;
    final List<BreakfastClassifiedModifier> classifiedAddRows =
        <BreakfastClassifiedModifier>[];
    for (final _AddUnit addUnit in addUnits) {
      final bool isChoiceCapable = input
          .setConfiguration
          .choiceCapableProductIds
          .contains(addUnit.itemProductId);
      if (isChoiceCapable) {
        classifiedAddRows.add(
          _buildAddRow(
            addUnit: addUnit,
            kind: BreakfastModifierKind.extraAdd,
            chargeReason: ModifierChargeReason.extraAdd,
            sortKey: _extraAddSortKey(addUnit.sequence),
          ),
        );
        continue;
      }

      if (pendingReplacementUnits.isNotEmpty) {
        pendingReplacementUnits.removeAt(0);
        replacementCounter += 1;
        final bool isFreeSwap =
            replacementCounter <=
            input.setConfiguration.menuSettings.freeSwapLimit;
        classifiedAddRows.add(
          _buildAddRow(
            addUnit: addUnit,
            kind: isFreeSwap
                ? BreakfastModifierKind.freeSwap
                : BreakfastModifierKind.paidSwap,
            chargeReason: isFreeSwap
                ? ModifierChargeReason.freeSwap
                : ModifierChargeReason.paidSwap,
            priceEffectMinor: isFreeSwap ? 0 : addUnit.unitPriceMinor,
            sortKey: isFreeSwap
                ? _freeSwapSortKey(addUnit.sequence)
                : _paidSwapSortKey(addUnit.sequence),
          ),
        );
        continue;
      }

      classifiedAddRows.add(
        _buildAddRow(
          addUnit: addUnit,
          kind: BreakfastModifierKind.extraAdd,
          chargeReason: ModifierChargeReason.extraAdd,
          sortKey: _extraAddSortKey(addUnit.sequence),
        ),
      );
    }

    final List<BreakfastClassifiedModifier> foldedRows = _stableOutputSort(
      _foldRows(<BreakfastClassifiedModifier>[
        ...removalResult.rows,
        ...choiceResult.rows,
        ...classifiedAddRows,
      ]),
    );
    _assertChoicePoolIsolation(
      configuration: input.setConfiguration,
      rows: foldedRows,
    );
    final BreakfastPricingBreakdown pricingBreakdown = _computeTotals(
      input: input,
      rows: foldedRows,
    );

    return BreakfastRebuildResult(
      lineSnapshot: BreakfastLineSnapshot(
        pricingMode: TransactionLinePricingMode.set,
        baseUnitPriceMinor: input.transactionLine.baseUnitPriceMinor,
        removalDiscountTotalMinor: pricingBreakdown.removalDiscountTotalMinor,
        modifierTotalMinor:
            pricingBreakdown.extraAddTotalMinor +
            pricingBreakdown.paidSwapTotalMinor,
        lineTotalMinor: pricingBreakdown.finalLineTotalMinor,
      ),
      classifiedModifiers: foldedRows,
      pricingBreakdown: pricingBreakdown,
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
    if (input.transactionLine.pricingMode != TransactionLinePricingMode.set) {
      errors.add(BreakfastEditErrorCode.invalidPricingMode);
    }
    if (input.transactionLine.rootProductId !=
        input.setConfiguration.setRootProductId) {
      errors.add(BreakfastEditErrorCode.rootNotSetProduct);
    }

    final Set<int> setItemProductIds = input.setConfiguration.setItems
        .map((BreakfastSetItemConfig item) => item.itemProductId)
        .toSet();
    final Set<int> knownProductIds = input
        .setConfiguration
        .catalogProductsById
        .keys
        .toSet();
    final Set<int> knownGroupIds = input.setConfiguration.choiceGroups
        .map((BreakfastChoiceGroupConfig group) => group.groupId)
        .toSet();

    for (final BreakfastRemovedSetItemRequest removal
        in input.requestedState.removedSetItems) {
      if (removal.quantity < 0) {
        errors.add(BreakfastEditErrorCode.negativeQuantity);
      }
      if (removal.quantity > 0 &&
          !setItemProductIds.contains(removal.itemProductId)) {
        errors.add(BreakfastEditErrorCode.unknownRequestedEntity);
      }
    }
    for (final BreakfastAddedProductRequest add
        in input.requestedState.addedProducts) {
      if (add.quantity < 0) {
        errors.add(BreakfastEditErrorCode.negativeQuantity);
      }
      if (add.quantity > 0 && !knownProductIds.contains(add.itemProductId)) {
        errors.add(BreakfastEditErrorCode.unknownProduct);
      }
    }
    for (final BreakfastChosenGroupRequest choice
        in input.requestedState.chosenGroups) {
      if (choice.requestedQuantity < 0) {
        errors.add(BreakfastEditErrorCode.negativeQuantity);
      }
      if (!knownGroupIds.contains(choice.groupId)) {
        errors.add(BreakfastEditErrorCode.invalidChoiceGroup);
      }
      final int? selectedItemProductId = choice.selectedItemProductId;
      if (selectedItemProductId != null &&
          !knownProductIds.contains(selectedItemProductId)) {
        errors.add(BreakfastEditErrorCode.unknownProduct);
      }
    }
    return errors.toList(growable: false);
  }

  List<_DefaultUnit> _expandSetItems(List<BreakfastSetItemConfig> setItems) {
    final List<BreakfastSetItemConfig> sortedSetItems =
        List<BreakfastSetItemConfig>.from(setItems)..sort((
          BreakfastSetItemConfig a,
          BreakfastSetItemConfig b,
        ) {
          final int sortCompare = a.sortOrder.compareTo(b.sortOrder);
          if (sortCompare != 0) {
            return sortCompare;
          }
          final int productCompare = a.itemProductId.compareTo(b.itemProductId);
          if (productCompare != 0) {
            return productCompare;
          }
          return a.setItemId.compareTo(b.setItemId);
        });

    final List<_DefaultUnit> result = <_DefaultUnit>[];
    for (final BreakfastSetItemConfig item in sortedSetItems) {
      for (
        int unitIndex = 0;
        unitIndex < item.defaultQuantity;
        unitIndex += 1
      ) {
        result.add(
          _DefaultUnit(
            setItemId: item.setItemId,
            itemProductId: item.itemProductId,
            itemName: item.itemName,
            unitIndex: unitIndex,
            sortOrder: item.sortOrder,
            isRemovable: item.isRemovable,
          ),
        );
      }
    }
    return result;
  }

  _RemovalResult _applyRemovals({
    required List<_DefaultUnit> defaultUnits,
    required List<BreakfastRemovedSetItemRequest> requestedRemovals,
  }) {
    final Map<int, int> requestedQuantityByProduct = <int, int>{};
    for (final BreakfastRemovedSetItemRequest removal in requestedRemovals) {
      if (removal.quantity <= 0) {
        continue;
      }
      requestedQuantityByProduct.update(
        removal.itemProductId,
        (int quantity) => quantity + removal.quantity,
        ifAbsent: () => removal.quantity,
      );
    }

    final List<int> sortedProductIds =
        requestedQuantityByProduct.keys.toList(growable: false)
          ..sort((int a, int b) {
            final _DefaultUnit? firstA = _firstUnitForProduct(defaultUnits, a);
            final _DefaultUnit? firstB = _firstUnitForProduct(defaultUnits, b);
            final int sortA = firstA?.sortOrder ?? 1 << 20;
            final int sortB = firstB?.sortOrder ?? 1 << 20;
            final int sortCompare = sortA.compareTo(sortB);
            if (sortCompare != 0) {
              return sortCompare;
            }
            return a.compareTo(b);
          });

    final List<BreakfastClassifiedModifier> rows =
        <BreakfastClassifiedModifier>[];
    final List<_DefaultUnit> removedUnits = <_DefaultUnit>[];
    final List<BreakfastEditErrorCode> errors = <BreakfastEditErrorCode>[];

    for (final int itemProductId in sortedProductIds) {
      final int requestedQuantity = requestedQuantityByProduct[itemProductId]!;
      final List<_DefaultUnit> candidates =
          defaultUnits
              .where(
                (_DefaultUnit unit) =>
                    unit.itemProductId == itemProductId &&
                    unit.isRemovable &&
                    !unit.isRemoved,
              )
              .toList(growable: false)
            ..sort(_compareDefaultUnits);
      if (candidates.length < requestedQuantity) {
        errors.add(BreakfastEditErrorCode.removeQuantityExceedsDefault);
        continue;
      }

      final List<_DefaultUnit> matchedUnits = candidates
          .take(requestedQuantity)
          .toList(growable: false);
      for (final _DefaultUnit unit in matchedUnits) {
        unit.isRemoved = true;
        removedUnits.add(unit);
      }
      final _DefaultUnit firstUnit = matchedUnits.first;
      rows.add(
        BreakfastClassifiedModifier(
          kind: BreakfastModifierKind.setRemove,
          action: ModifierAction.remove,
          itemProductId: itemProductId,
          displayName: firstUnit.itemName,
          quantity: requestedQuantity,
          unitPriceMinor: 0,
          priceEffectMinor: 0,
          sortKey: _removeSortKey(firstUnit),
          sourceSetItemId: firstUnit.setItemId,
        ),
      );
    }

    return _RemovalResult(
      rows: rows,
      removedUnits: removedUnits,
      errors: errors,
    );
  }

  _ChoiceNormalizationResult _normalizeChoiceSelections({
    required BreakfastSetConfiguration configuration,
    required List<BreakfastChosenGroupRequest> requestedChoices,
  }) {
    final Map<int, List<BreakfastChosenGroupRequest>> requestsByGroupId =
        <int, List<BreakfastChosenGroupRequest>>{};
    for (final BreakfastChosenGroupRequest choice in requestedChoices) {
      requestsByGroupId
          .putIfAbsent(choice.groupId, () => <BreakfastChosenGroupRequest>[])
          .add(choice);
    }

    final List<int> sortedGroupIds = requestsByGroupId.keys.toList()
      ..sort((int a, int b) {
        final BreakfastChoiceGroupConfig? groupA = configuration.findGroup(a);
        final BreakfastChoiceGroupConfig? groupB = configuration.findGroup(b);
        final int sortA = groupA?.sortOrder ?? 1 << 20;
        final int sortB = groupB?.sortOrder ?? 1 << 20;
        final int sortCompare = sortA.compareTo(sortB);
        if (sortCompare != 0) {
          return sortCompare;
        }
        return a.compareTo(b);
      });

    final List<_NormalizedChoiceSelection> normalized =
        <_NormalizedChoiceSelection>[];
    final List<BreakfastEditErrorCode> errors = <BreakfastEditErrorCode>[];

    for (final int groupId in sortedGroupIds) {
      final BreakfastChoiceGroupConfig? group = configuration.findGroup(
        groupId,
      );
      if (group == null) {
        errors.add(BreakfastEditErrorCode.invalidChoiceGroup);
        continue;
      }

      final List<BreakfastChosenGroupRequest> activeSelections =
          requestsByGroupId[groupId]!
              .where(
                (BreakfastChosenGroupRequest request) =>
                    request.selectedItemProductId != null &&
                    request.requestedQuantity > 0,
              )
              .toList(growable: false);
      final List<BreakfastChosenGroupRequest> explicitNoneSelections =
          requestsByGroupId[groupId]!
              .where(
                (BreakfastChosenGroupRequest request) => request.isExplicitNone,
              )
              .toList(growable: false);
      if (activeSelections.isEmpty && explicitNoneSelections.isEmpty) {
        continue;
      }
      if (activeSelections.isNotEmpty && explicitNoneSelections.isNotEmpty) {
        errors.add(BreakfastEditErrorCode.invalidChoiceGroup);
        continue;
      }
      if (explicitNoneSelections.isNotEmpty) {
        if (group.minSelect > 0) {
          errors.add(BreakfastEditErrorCode.invalidChoiceQuantity);
          continue;
        }
        final int noneQuantity = explicitNoneSelections.fold<int>(
          0,
          (int total, BreakfastChosenGroupRequest request) =>
              total + request.requestedQuantity,
        );
        if (noneQuantity != 1) {
          errors.add(BreakfastEditErrorCode.invalidChoiceQuantity);
          continue;
        }
        normalized.add(
          _NormalizedChoiceSelection(
            group: group,
            selectedItemProductId: null,
            displayName: breakfastNoneChoiceDisplayName,
            requestedQuantity: noneQuantity,
          ),
        );
        continue;
      }

      final Set<int> distinctProductIds = activeSelections
          .map(
            (BreakfastChosenGroupRequest request) =>
                request.selectedItemProductId!,
          )
          .toSet();
      if (distinctProductIds.length > 1) {
        errors.add(
          group.includedQuantity > 1
              ? BreakfastEditErrorCode.mixedToastBreadNotSupported
              : BreakfastEditErrorCode.invalidChoiceGroup,
        );
        continue;
      }

      final int selectedItemProductId = distinctProductIds.single;
      final BreakfastChoiceGroupMemberConfig? member = group.findMember(
        selectedItemProductId,
      );
      if (member == null) {
        errors.add(BreakfastEditErrorCode.choiceMemberNotAllowed);
        continue;
      }

      final int requestedQuantity = activeSelections.fold<int>(
        0,
        (int total, BreakfastChosenGroupRequest request) =>
            total + request.requestedQuantity,
      );
      if (_isInvalidChoiceQuantity(group, requestedQuantity)) {
        errors.add(BreakfastEditErrorCode.invalidChoiceQuantity);
        continue;
      }

      normalized.add(
        _NormalizedChoiceSelection(
          group: group,
          selectedItemProductId: selectedItemProductId,
          displayName: member.displayName,
          requestedQuantity: requestedQuantity,
        ),
      );
    }

    return _ChoiceNormalizationResult(choices: normalized, errors: errors);
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
    if (group.minSelect > 0 &&
        group.maxSelect == 1 &&
        group.includedQuantity == 1 &&
        requestedQuantity > 1) {
      return true;
    }
    return requestedQuantity < group.includedQuantity;
  }

  _ChoiceClassificationResult _classifyChoices({
    required BreakfastSetConfiguration configuration,
    required List<_NormalizedChoiceSelection> normalizedChoices,
  }) {
    final List<BreakfastClassifiedModifier> rows =
        <BreakfastClassifiedModifier>[];
    final List<BreakfastEditErrorCode> errors = <BreakfastEditErrorCode>[];

    for (final _NormalizedChoiceSelection choice in normalizedChoices) {
      if (choice.isExplicitNone) {
        rows.add(
          BreakfastClassifiedModifier(
            kind: BreakfastModifierKind.choiceIncluded,
            action: ModifierAction.choice,
            chargeReason: ModifierChargeReason.includedChoice,
            itemProductId: null,
            displayName: choice.displayName,
            quantity: choice.requestedQuantity,
            unitPriceMinor: 0,
            priceEffectMinor: 0,
            sortKey: _explicitNoneChoiceSortKey(choice.group.sortOrder),
            sourceGroupId: choice.group.groupId,
          ),
        );
        continue;
      }

      final BreakfastCatalogProduct? product = configuration.findCatalogProduct(
        choice.selectedItemProductId!,
      );
      if (product == null) {
        errors.add(BreakfastEditErrorCode.unknownProduct);
        continue;
      }
      final int selectedItemProductId = choice.selectedItemProductId!;

      final int includedQuantity =
          choice.requestedQuantity < choice.group.includedQuantity
          ? choice.requestedQuantity
          : choice.group.includedQuantity;
      final int overflowQuantity = choice.requestedQuantity - includedQuantity;

      if (includedQuantity > 0) {
        rows.add(
          BreakfastClassifiedModifier(
            kind: BreakfastModifierKind.choiceIncluded,
            action: ModifierAction.choice,
            chargeReason: ModifierChargeReason.includedChoice,
            itemProductId: selectedItemProductId,
            displayName: choice.displayName,
            quantity: includedQuantity,
            unitPriceMinor: product.priceMinor,
            priceEffectMinor: 0,
            sortKey: _includedChoiceSortKey(
              choice.group.sortOrder,
              selectedItemProductId,
            ),
            sourceGroupId: choice.group.groupId,
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
            displayName: choice.displayName,
            quantity: overflowQuantity,
            unitPriceMinor: product.priceMinor,
            priceEffectMinor: product.priceMinor * overflowQuantity,
            sortKey: _choiceOverflowSortKey(
              choice.group.sortOrder,
              selectedItemProductId,
            ),
            sourceGroupId: choice.group.groupId,
          ),
        );
      }
    }

    return _ChoiceClassificationResult(rows: rows, errors: errors);
  }

  List<_AddUnit> _expandAddedProducts({
    required List<BreakfastAddedProductRequest> requestedAdds,
    required BreakfastSetConfiguration configuration,
  }) {
    final List<BreakfastAddedProductRequest> sortedAdds =
        List<BreakfastAddedProductRequest>.from(requestedAdds)..sort((
          BreakfastAddedProductRequest a,
          BreakfastAddedProductRequest b,
        ) {
          final int orderCompare = a.orderHint.compareTo(b.orderHint);
          if (orderCompare != 0) {
            return orderCompare;
          }
          final int productCompare = a.itemProductId.compareTo(b.itemProductId);
          if (productCompare != 0) {
            return productCompare;
          }
          return a.quantity.compareTo(b.quantity);
        });

    final List<_AddUnit> result = <_AddUnit>[];
    int sequence = 0;
    for (final BreakfastAddedProductRequest add in sortedAdds) {
      if (add.quantity <= 0) {
        continue;
      }
      final BreakfastCatalogProduct? product = configuration.findCatalogProduct(
        add.itemProductId,
      );
      if (product == null) {
        continue;
      }
      for (int unitIndex = 0; unitIndex < add.quantity; unitIndex += 1) {
        result.add(
          _AddUnit(
            itemProductId: add.itemProductId,
            displayName: product.name,
            unitPriceMinor: product.priceMinor,
            orderHint: add.orderHint,
            unitIndex: unitIndex,
            sequence: sequence,
          ),
        );
        sequence += 1;
      }
    }
    return result;
  }

  BreakfastClassifiedModifier _buildAddRow({
    required _AddUnit addUnit,
    required BreakfastModifierKind kind,
    required ModifierChargeReason chargeReason,
    required int sortKey,
    int? priceEffectMinor,
  }) {
    return BreakfastClassifiedModifier(
      kind: kind,
      action: ModifierAction.add,
      chargeReason: chargeReason,
      itemProductId: addUnit.itemProductId,
      displayName: addUnit.displayName,
      quantity: 1,
      unitPriceMinor: addUnit.unitPriceMinor,
      priceEffectMinor: priceEffectMinor ?? addUnit.unitPriceMinor,
      sortKey: sortKey,
    );
  }

  List<BreakfastClassifiedModifier> _foldRows(
    List<BreakfastClassifiedModifier> rows,
  ) {
    final List<BreakfastClassifiedModifier> sortedRows = _stableOutputSort(
      rows,
    );
    final Map<_FoldKey, BreakfastClassifiedModifier> folded =
        <_FoldKey, BreakfastClassifiedModifier>{};

    for (final BreakfastClassifiedModifier row in sortedRows) {
      final _FoldKey key = _FoldKey(
        action: row.action,
        chargeReason: row.chargeReason,
        itemProductId: row.itemProductId,
        unitPriceMinor: row.unitPriceMinor,
      );
      final BreakfastClassifiedModifier? existing = folded[key];
      if (existing == null) {
        folded[key] = row;
        continue;
      }

      folded[key] = existing.copyWith(
        quantity: existing.quantity + row.quantity,
        priceEffectMinor: existing.priceEffectMinor + row.priceEffectMinor,
        sortKey: existing.sortKey < row.sortKey
            ? existing.sortKey
            : row.sortKey,
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
        case ModifierChargeReason.comboDiscount:
        case null:
          break;
      }
    }

    final int basePriceMinor =
        input.transactionLine.baseUnitPriceMinor *
        input.transactionLine.lineQuantity;
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
      final int kindCompare = _kindPriority(
        a.kind,
      ).compareTo(_kindPriority(b.kind));
      if (kindCompare != 0) {
        return kindCompare;
      }
      final int sortCompare = a.sortKey.compareTo(b.sortKey);
      if (sortCompare != 0) {
        return sortCompare;
      }
      final int productCompare = (a.itemProductId ?? 0).compareTo(
        b.itemProductId ?? 0,
      );
      if (productCompare != 0) {
        return productCompare;
      }
      final int priceCompare = a.unitPriceMinor.compareTo(b.unitPriceMinor);
      if (priceCompare != 0) {
        return priceCompare;
      }
      return a.displayName.compareTo(b.displayName);
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
        input.transactionLine.baseUnitPriceMinor *
        input.transactionLine.lineQuantity;
    return BreakfastRebuildResult(
      lineSnapshot: BreakfastLineSnapshot(
        pricingMode: input.transactionLine.pricingMode,
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
      validationErrors: _dedupeErrors(validationErrors),
      rebuildMetadata: const BreakfastRebuildMetadata(
        replacementCount: 0,
        unmatchedRemovalCount: 0,
      ),
    );
  }

  List<BreakfastEditErrorCode> _dedupeErrors(
    List<BreakfastEditErrorCode> errors,
  ) {
    return errors.toSet().toList(growable: false);
  }

  void _assertChoicePoolIsolation({
    required BreakfastSetConfiguration configuration,
    required List<BreakfastClassifiedModifier> rows,
  }) {
    final Set<int> choiceCapableProductIds =
        configuration.choiceCapableProductIds;
    for (final BreakfastClassifiedModifier row in rows) {
      final int? itemProductId = row.itemProductId;
      if (row.kind == BreakfastModifierKind.choiceIncluded) {
        if (row.action != ModifierAction.choice ||
            row.chargeReason != ModifierChargeReason.includedChoice) {
          throw StateError(
            'Breakfast rebuild invariant failed: included choice rows must persist action=choice and charge_reason=included_choice.',
          );
        }
      }
      if (itemProductId == null ||
          !choiceCapableProductIds.contains(itemProductId)) {
        continue;
      }
      if (row.kind == BreakfastModifierKind.freeSwap ||
          row.kind == BreakfastModifierKind.paidSwap ||
          row.chargeReason == ModifierChargeReason.freeSwap ||
          row.chargeReason == ModifierChargeReason.paidSwap) {
        throw StateError(
          'Breakfast rebuild invariant failed: choice-capable product $itemProductId entered the swap pool.',
        );
      }
    }
  }

  _DefaultUnit? _firstUnitForProduct(List<_DefaultUnit> units, int productId) {
    for (final _DefaultUnit unit in units) {
      if (unit.itemProductId == productId) {
        return unit;
      }
    }
    return null;
  }

  int _compareDefaultUnits(_DefaultUnit a, _DefaultUnit b) {
    final int sortCompare = a.sortOrder.compareTo(b.sortOrder);
    if (sortCompare != 0) {
      return sortCompare;
    }
    final int productCompare = a.itemProductId.compareTo(b.itemProductId);
    if (productCompare != 0) {
      return productCompare;
    }
    final int setItemCompare = a.setItemId.compareTo(b.setItemId);
    if (setItemCompare != 0) {
      return setItemCompare;
    }
    return a.unitIndex.compareTo(b.unitIndex);
  }

  int _removeSortKey(_DefaultUnit unit) =>
      1000 + (unit.sortOrder * 100) + unit.itemProductId;

  int _includedChoiceSortKey(int groupSortOrder, int itemProductId) =>
      2000 + (groupSortOrder * 100) + itemProductId;

  int _explicitNoneChoiceSortKey(int groupSortOrder) =>
      2000 + (groupSortOrder * 100);

  int _freeSwapSortKey(int sequence) => 3000 + sequence;

  int _paidSwapSortKey(int sequence) => 4000 + sequence;

  int _choiceOverflowSortKey(int groupSortOrder, int itemProductId) =>
      5000 + (groupSortOrder * 100) + itemProductId;

  int _extraAddSortKey(int sequence) => 6000 + sequence;
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

class _NormalizedChoiceSelection {
  const _NormalizedChoiceSelection({
    required this.group,
    required this.selectedItemProductId,
    required this.displayName,
    required this.requestedQuantity,
  });

  final BreakfastChoiceGroupConfig group;
  final int? selectedItemProductId;
  final String displayName;
  final int requestedQuantity;

  bool get isExplicitNone =>
      selectedItemProductId == null && requestedQuantity > 0;
}

class _ChoiceNormalizationResult {
  const _ChoiceNormalizationResult({
    required this.choices,
    required this.errors,
  });

  final List<_NormalizedChoiceSelection> choices;
  final List<BreakfastEditErrorCode> errors;
}

class _ChoiceClassificationResult {
  const _ChoiceClassificationResult({required this.rows, required this.errors});

  final List<BreakfastClassifiedModifier> rows;
  final List<BreakfastEditErrorCode> errors;
}

class _AddUnit {
  const _AddUnit({
    required this.itemProductId,
    required this.displayName,
    required this.unitPriceMinor,
    required this.orderHint,
    required this.unitIndex,
    required this.sequence,
  });

  final int itemProductId;
  final String displayName;
  final int unitPriceMinor;
  final int orderHint;
  final int unitIndex;
  final int sequence;
}

class _FoldKey {
  const _FoldKey({
    required this.action,
    required this.chargeReason,
    required this.itemProductId,
    required this.unitPriceMinor,
  });

  final ModifierAction action;
  final ModifierChargeReason? chargeReason;
  final int? itemProductId;
  final int unitPriceMinor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _FoldKey &&
        other.action == action &&
        other.chargeReason == chargeReason &&
        other.itemProductId == itemProductId &&
        other.unitPriceMinor == unitPriceMinor;
  }

  @override
  int get hashCode =>
      Object.hash(action, chargeReason, itemProductId, unitPriceMinor);
}
