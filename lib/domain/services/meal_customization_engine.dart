import '../models/meal_adjustment_profile.dart';
import '../models/meal_customization.dart';

enum MealCustomizationRequestIssueCode {
  profileMismatch,
  unexpectedSandwichSelectionForStandardProfile,
  missingSandwichBreadChoice,
  unavailableSandwichSauce,
  sandwichToastRequiresSandwichBread,
  unknownRemovedComponent,
  duplicateRemovedComponent,
  removedComponentNotRemovable,
  unknownSwapComponent,
  duplicateSwapSelection,
  invalidSwapTarget,
  invalidSwapQuantity,
  removedAndSwappedComponentConflict,
  unknownExtraItem,
  duplicateExtraSelection,
  invalidExtraQuantity,
}

class MealCustomizationRequestIssue {
  const MealCustomizationRequestIssue({
    required this.code,
    this.componentKey,
    this.itemProductId,
    this.detail,
  });

  final MealCustomizationRequestIssueCode code;
  final String? componentKey;
  final int? itemProductId;
  final String? detail;

  String get message {
    switch (code) {
      case MealCustomizationRequestIssueCode.profileMismatch:
        return 'Request profile does not match the evaluated profile.';
      case MealCustomizationRequestIssueCode
          .unexpectedSandwichSelectionForStandardProfile:
        return 'Sandwich bread, sauce, and toast selections are only allowed for sandwich profiles.';
      case MealCustomizationRequestIssueCode.missingSandwichBreadChoice:
        return 'Bread type is required for sandwich products.';
      case MealCustomizationRequestIssueCode.unavailableSandwichSauce:
        return 'Selected sauce ${detail ?? 'unknown'} is not enabled on this sandwich profile.';
      case MealCustomizationRequestIssueCode.sandwichToastRequiresSandwichBread:
        return 'Toast is only available when Sandwich bread is selected.';
      case MealCustomizationRequestIssueCode.unknownRemovedComponent:
        return 'Removed component ${componentKey ?? 'unknown'} is not configured on the profile.';
      case MealCustomizationRequestIssueCode.duplicateRemovedComponent:
        return 'Removed component ${componentKey ?? 'unknown'} was requested more than once.';
      case MealCustomizationRequestIssueCode.removedComponentNotRemovable:
        return 'Component ${componentKey ?? 'unknown'} cannot be removed.';
      case MealCustomizationRequestIssueCode.unknownSwapComponent:
        return 'Swap component ${componentKey ?? 'unknown'} is not configured on the profile.';
      case MealCustomizationRequestIssueCode.duplicateSwapSelection:
        return 'Swap component ${componentKey ?? 'unknown'} was requested more than once.';
      case MealCustomizationRequestIssueCode.invalidSwapTarget:
        return 'Swap target ${itemProductId ?? 'unknown'} is not allowed for ${componentKey ?? 'unknown'}.';
      case MealCustomizationRequestIssueCode.invalidSwapQuantity:
        return 'Swap quantity is invalid for ${componentKey ?? 'unknown'}.';
      case MealCustomizationRequestIssueCode.removedAndSwappedComponentConflict:
        return 'Component ${componentKey ?? 'unknown'} cannot be removed and swapped in the same request.';
      case MealCustomizationRequestIssueCode.unknownExtraItem:
        return 'Extra item ${itemProductId ?? 'unknown'} is not configured on the profile.';
      case MealCustomizationRequestIssueCode.duplicateExtraSelection:
        return 'Extra item ${itemProductId ?? 'unknown'} was requested more than once.';
      case MealCustomizationRequestIssueCode.invalidExtraQuantity:
        return 'Extra quantity must be greater than zero.';
    }
  }
}

class MealCustomizationRequestRejectedException implements Exception {
  const MealCustomizationRequestRejectedException(this.issues);

  final List<MealCustomizationRequestIssue> issues;

  String get message => issues
      .map((MealCustomizationRequestIssue issue) => issue.message)
      .join('\n');

  @override
  String toString() => message;
}

class MealCustomizationEngine {
  const MealCustomizationEngine();

  MealCustomizationResolvedSnapshot evaluate({
    required MealAdjustmentProfile profile,
    required MealCustomizationRequest request,
  }) {
    final _PreparedRequest prepared = _prepareRequest(
      profile: profile,
      request: request,
    );
    if (profile.kind == MealAdjustmentProfileKind.sandwich) {
      return _evaluateSandwich(
        profile: profile,
        request: request,
        prepared: prepared,
      );
    }
    final List<_IndexedRule> activeRules = profile.pricingRules
        .asMap()
        .entries
        .where((MapEntry<int, MealAdjustmentPricingRule> entry) {
          return entry.value.isActive;
        })
        .map(
          (MapEntry<int, MealAdjustmentPricingRule> entry) =>
              _IndexedRule(rule: entry.value, index: entry.key),
        )
        .toList(growable: false);

    final List<MealCustomizationSemanticAction> componentActions =
        <MealCustomizationSemanticAction>[];
    final List<MealCustomizationSemanticAction> extraActions =
        <MealCustomizationSemanticAction>[];
    final List<MealCustomizationSemanticAction> discountActions =
        <MealCustomizationSemanticAction>[];
    final Map<int, MealCustomizationAppliedRule> appliedRulesById =
        <int, MealCustomizationAppliedRule>{};

    for (final MealAdjustmentComponent component
        in prepared.removedComponents) {
      componentActions.add(
        MealCustomizationSemanticAction(
          action: MealCustomizationAction.remove,
          componentKey: component.componentKey,
          itemProductId: component.defaultItemProductId,
          quantity: component.quantity,
        ),
      );
    }

    int freeSwapCountUsed = 0;
    int paidSwapCountUsed = 0;
    final List<String> removedConditionKeys = prepared.removedComponents
        .map(
          (MealAdjustmentComponent component) => _conditionKey(
            MealAdjustmentPricingRuleConditionType.removedComponent,
            componentKey: component.componentKey,
            quantity: component.quantity,
          ),
        )
        .toList(growable: false);
    final List<_PreparedSwapClassification> classifiedSwaps =
        <_PreparedSwapClassification>[];
    final List<String> swapConditionKeys = <String>[];
    for (int index = 0; index < prepared.swapSelections.length; index += 1) {
      final _PreparedSwapSelection swapSelection =
          prepared.swapSelections[index];
      final bool isFreeSwap = index < profile.freeSwapLimit;
      final String conditionKey = _conditionKey(
        MealAdjustmentPricingRuleConditionType.swapToItem,
        componentKey: swapSelection.component.componentKey,
        itemProductId: swapSelection.selection.targetItemProductId,
        quantity: swapSelection.selection.quantity,
      );
      swapConditionKeys.add(conditionKey);
      classifiedSwaps.add(
        _PreparedSwapClassification(
          selection: swapSelection,
          isFreeSwap: isFreeSwap,
          conditionKey: conditionKey,
        ),
      );
      if (isFreeSwap) {
        freeSwapCountUsed += 1;
      } else {
        paidSwapCountUsed += 1;
      }
    }

    final List<_PreparedExtraClassification> classifiedExtras =
        <_PreparedExtraClassification>[];
    final List<String> extraConditionKeys = <String>[];
    for (final _PreparedExtraSelection extraSelection
        in prepared.extraSelections) {
      final String conditionKey = _conditionKey(
        MealAdjustmentPricingRuleConditionType.extraItem,
        itemProductId: extraSelection.selection.itemProductId,
        quantity: extraSelection.selection.quantity,
      );
      extraConditionKeys.add(conditionKey);
      classifiedExtras.add(
        _PreparedExtraClassification(
          selection: extraSelection,
          conditionKey: conditionKey,
        ),
      );
    }

    final List<String> fullSemanticConditionKeys = <String>[
      ...removedConditionKeys,
      ...swapConditionKeys,
      ...extraConditionKeys,
    ]..sort();
    final _IndexedRule? exactComboRule = _selectBestExactRule(
      rules: activeRules,
      ruleType: MealAdjustmentPricingRuleType.combo,
      exactConditionKeys: fullSemanticConditionKeys,
    );
    if (exactComboRule != null) {
      appliedRulesById[exactComboRule.rule.id] = _toAppliedRule(exactComboRule);
      discountActions.add(
        MealCustomizationSemanticAction(
          action: MealCustomizationAction.discount,
          chargeReason: MealCustomizationChargeReason.comboDiscount,
          quantity: 1,
          priceDeltaMinor: exactComboRule.rule.priceDeltaMinor,
          appliedRuleIds: <int>[exactComboRule.rule.id],
        ),
      );
    }

    for (final _PreparedSwapClassification swap in classifiedSwaps) {
      final _IndexedRule? exactSwapRule = swap.isFreeSwap
          ? null
          : _selectBestExactRule(
              rules: activeRules,
              ruleType: MealAdjustmentPricingRuleType.swap,
              exactConditionKeys: <String>[swap.conditionKey],
            );
      final int swapPriceDeltaMinor = swap.isFreeSwap
          ? 0
          : exactSwapRule?.rule.priceDeltaMinor ??
                swap.selection.option.fixedPriceDeltaMinor ??
                0;
      if (exactSwapRule != null) {
        appliedRulesById[exactSwapRule.rule.id] = _toAppliedRule(exactSwapRule);
      }

      componentActions.add(
        MealCustomizationSemanticAction(
          action: MealCustomizationAction.swap,
          chargeReason: swap.isFreeSwap
              ? MealCustomizationChargeReason.freeSwap
              : MealCustomizationChargeReason.paidSwap,
          componentKey: swap.selection.component.componentKey,
          itemProductId: swap.selection.selection.targetItemProductId,
          sourceItemProductId: swap.selection.component.defaultItemProductId,
          quantity: swap.selection.selection.quantity,
          priceDeltaMinor: swapPriceDeltaMinor,
          appliedRuleIds: exactSwapRule == null
              ? const <int>[]
              : <int>[exactSwapRule.rule.id],
        ),
      );
    }

    for (final _PreparedExtraClassification extra in classifiedExtras) {
      final _IndexedRule? exactExtraRule = _selectBestExactRule(
        rules: activeRules,
        ruleType: MealAdjustmentPricingRuleType.extra,
        exactConditionKeys: <String>[extra.conditionKey],
      );
      final int extraPriceDeltaMinor =
          exactExtraRule?.rule.priceDeltaMinor ??
          (extra.selection.option.fixedPriceDeltaMinor *
              extra.selection.selection.quantity);
      if (exactExtraRule != null) {
        appliedRulesById[exactExtraRule.rule.id] = _toAppliedRule(
          exactExtraRule,
        );
      }

      extraActions.add(
        MealCustomizationSemanticAction(
          action: MealCustomizationAction.extra,
          chargeReason: MealCustomizationChargeReason.extraAdd,
          itemProductId: extra.selection.selection.itemProductId,
          quantity: extra.selection.selection.quantity,
          priceDeltaMinor: extraPriceDeltaMinor,
          appliedRuleIds: exactExtraRule == null
              ? const <int>[]
              : <int>[exactExtraRule.rule.id],
        ),
      );
    }

    if (exactComboRule == null) {
      final List<_IndexedRule> removeOnlyRules = _selectMatchingRemoveOnlyRules(
        rules: activeRules,
        removedConditionKeys: removedConditionKeys,
      );
      for (final _IndexedRule removeOnlyRule in removeOnlyRules) {
        appliedRulesById[removeOnlyRule.rule.id] = _toAppliedRule(
          removeOnlyRule,
        );
        discountActions.add(
          MealCustomizationSemanticAction(
            action: MealCustomizationAction.discount,
            chargeReason: MealCustomizationChargeReason.removalDiscount,
            quantity: 1,
            priceDeltaMinor: removeOnlyRule.rule.priceDeltaMinor,
            appliedRuleIds: <int>[removeOnlyRule.rule.id],
          ),
        );
      }
    }

    final List<MealCustomizationAppliedRule> appliedRules =
        appliedRulesById.values.toList(growable: false)
          ..sort(_compareAppliedRules);
    final int totalAdjustmentMinor =
        <MealCustomizationSemanticAction>[
          ...componentActions,
          ...extraActions,
          ...discountActions,
        ].fold<int>(
          0,
          (int total, MealCustomizationSemanticAction action) =>
              total + action.priceDeltaMinor,
        );

    return MealCustomizationResolvedSnapshot(
      productId: request.productId,
      profileId: profile.id,
      sandwichSelection: prepared.sandwichSelection,
      resolvedComponentActions:
          List<MealCustomizationSemanticAction>.unmodifiable(componentActions),
      resolvedExtraActions: List<MealCustomizationSemanticAction>.unmodifiable(
        extraActions,
      ),
      triggeredDiscounts: List<MealCustomizationSemanticAction>.unmodifiable(
        discountActions,
      ),
      appliedRules: List<MealCustomizationAppliedRule>.unmodifiable(
        appliedRules,
      ),
      totalAdjustmentMinor: totalAdjustmentMinor,
      freeSwapCountUsed: freeSwapCountUsed,
      paidSwapCountUsed: paidSwapCountUsed,
    );
  }

  _PreparedRequest _prepareRequest({
    required MealAdjustmentProfile profile,
    required MealCustomizationRequest request,
  }) {
    final List<MealCustomizationRequestIssue> issues =
        <MealCustomizationRequestIssue>[];
    if (request.profileId != null && request.profileId != profile.id) {
      issues.add(
        const MealCustomizationRequestIssue(
          code: MealCustomizationRequestIssueCode.profileMismatch,
        ),
      );
    }
    final SandwichCustomizationSelection? resolvedSandwichSelection =
        _prepareSandwichSelection(
          profile: profile,
          request: request,
          issues: issues,
        );

    final List<MealAdjustmentComponent> activeComponents =
        profile.components
            .where((MealAdjustmentComponent component) {
              return component.isActive;
            })
            .toList(growable: false)
          ..sort(_compareComponents);
    final Map<String, MealAdjustmentComponent> componentByKey =
        <String, MealAdjustmentComponent>{
          for (final MealAdjustmentComponent component in activeComponents)
            component.componentKey.trim().toLowerCase(): component,
        };
    final Map<String, Set<int>> swapTargetsByComponentKey = <String, Set<int>>{
      for (final MealAdjustmentComponent component in activeComponents)
        component.componentKey.trim().toLowerCase(): component.swapOptions
            .where((MealAdjustmentComponentOption option) => option.isActive)
            .map(
              (MealAdjustmentComponentOption option) =>
                  option.optionItemProductId,
            )
            .toSet(),
    };
    final Map<String, Map<int, MealAdjustmentComponentOption>>
    swapOptionsByComponentKey =
        <String, Map<int, MealAdjustmentComponentOption>>{
          for (final MealAdjustmentComponent component in activeComponents)
            component.componentKey
                .trim()
                .toLowerCase(): <int, MealAdjustmentComponentOption>{
              for (final MealAdjustmentComponentOption option
                  in component.swapOptions.where(
                    (MealAdjustmentComponentOption option) => option.isActive,
                  ))
                option.optionItemProductId: option,
            },
        };
    final Map<int, MealAdjustmentExtraOption> extraOptionsByItemId =
        <int, MealAdjustmentExtraOption>{
          for (final MealAdjustmentExtraOption option
              in profile.extraOptions.where(
                (MealAdjustmentExtraOption option) => option.isActive,
              ))
            option.itemProductId: option,
        };

    final Set<String> seenRemovedKeys = <String>{};
    final List<MealAdjustmentComponent> removedComponents =
        <MealAdjustmentComponent>[];
    for (final String componentKey in request.removedComponentKeys) {
      final String normalizedKey = componentKey.trim().toLowerCase();
      if (!seenRemovedKeys.add(normalizedKey)) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.duplicateRemovedComponent,
            componentKey: componentKey,
          ),
        );
        continue;
      }
      final MealAdjustmentComponent? component = componentByKey[normalizedKey];
      if (component == null) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.unknownRemovedComponent,
            componentKey: componentKey,
          ),
        );
        continue;
      }
      if (!component.canRemove) {
        issues.add(
          MealCustomizationRequestIssue(
            code:
                MealCustomizationRequestIssueCode.removedComponentNotRemovable,
            componentKey: component.componentKey,
          ),
        );
        continue;
      }
      removedComponents.add(component);
    }

    final Set<String> seenSwapKeys = <String>{};
    final List<_PreparedSwapSelection> swapSelections =
        <_PreparedSwapSelection>[];
    for (final MealCustomizationComponentSelection selection
        in request.swapSelections) {
      final String normalizedKey = selection.componentKey.trim().toLowerCase();
      if (!seenSwapKeys.add(normalizedKey)) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.duplicateSwapSelection,
            componentKey: selection.componentKey,
          ),
        );
        continue;
      }
      if (seenRemovedKeys.contains(normalizedKey)) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode
                .removedAndSwappedComponentConflict,
            componentKey: selection.componentKey,
          ),
        );
        continue;
      }

      final MealAdjustmentComponent? component = componentByKey[normalizedKey];
      if (component == null) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.unknownSwapComponent,
            componentKey: selection.componentKey,
          ),
        );
        continue;
      }
      if (selection.quantity <= 0 || selection.quantity > component.quantity) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.invalidSwapQuantity,
            componentKey: component.componentKey,
          ),
        );
        continue;
      }
      if (!swapTargetsByComponentKey[normalizedKey]!.contains(
        selection.targetItemProductId,
      )) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.invalidSwapTarget,
            componentKey: component.componentKey,
            itemProductId: selection.targetItemProductId,
          ),
        );
        continue;
      }

      swapSelections.add(
        _PreparedSwapSelection(
          component: component,
          selection: selection,
          option:
              swapOptionsByComponentKey[normalizedKey]![selection
                  .targetItemProductId]!,
        ),
      );
    }

    final Set<int> seenExtraItemIds = <int>{};
    final List<_PreparedExtraSelection> extraSelections =
        <_PreparedExtraSelection>[];
    for (final MealCustomizationExtraSelection selection
        in request.extraSelections) {
      if (!seenExtraItemIds.add(selection.itemProductId)) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.duplicateExtraSelection,
            itemProductId: selection.itemProductId,
          ),
        );
        continue;
      }
      if (selection.quantity <= 0) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.invalidExtraQuantity,
            itemProductId: selection.itemProductId,
          ),
        );
        continue;
      }
      final MealAdjustmentExtraOption? option =
          extraOptionsByItemId[selection.itemProductId];
      if (option == null) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.unknownExtraItem,
            itemProductId: selection.itemProductId,
          ),
        );
        continue;
      }
      extraSelections.add(
        _PreparedExtraSelection(selection: selection, option: option),
      );
    }

    if (issues.isNotEmpty) {
      throw MealCustomizationRequestRejectedException(
        List<MealCustomizationRequestIssue>.unmodifiable(issues),
      );
    }

    removedComponents.sort(_compareComponents);
    swapSelections.sort(_comparePreparedSwaps);
    extraSelections.sort(_comparePreparedExtras);
    return _PreparedRequest(
      sandwichSelection: resolvedSandwichSelection,
      removedComponents: removedComponents,
      swapSelections: swapSelections,
      extraSelections: extraSelections,
    );
  }

  SandwichCustomizationSelection? _prepareSandwichSelection({
    required MealAdjustmentProfile profile,
    required MealCustomizationRequest request,
    required List<MealCustomizationRequestIssue> issues,
  }) {
    final SandwichCustomizationSelection selection = request.sandwichSelection;
    if (profile.kind != MealAdjustmentProfileKind.sandwich) {
      if (_hasExplicitSandwichSelection(selection)) {
        issues.add(
          const MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode
                .unexpectedSandwichSelectionForStandardProfile,
          ),
        );
      }
      return null;
    }

    final SandwichBreadType? breadType = selection.breadType;
    final List<int> normalizedSauceProductIds =
        normalizeSandwichSauceProductIds(selection.sauceProductIds);
    if (breadType == null) {
      issues.add(
        const MealCustomizationRequestIssue(
          code: MealCustomizationRequestIssueCode.missingSandwichBreadChoice,
        ),
      );
      return null;
    }
    final Set<int> enabledSauceProductIds = profile
        .sandwichSettings
        .sauceProductIds
        .toSet();
    for (final int sauceProductId in normalizedSauceProductIds) {
      if (!enabledSauceProductIds.contains(sauceProductId)) {
        issues.add(
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.unavailableSandwichSauce,
            itemProductId: sauceProductId,
            detail: 'product $sauceProductId',
          ),
        );
      }
    }
    if (selection.toastOption != null &&
        breadType != SandwichBreadType.sandwich) {
      issues.add(
        const MealCustomizationRequestIssue(
          code: MealCustomizationRequestIssueCode
              .sandwichToastRequiresSandwichBread,
        ),
      );
      return null;
    }

    return SandwichCustomizationSelection(
      breadType: breadType,
      sauceProductIds: normalizedSauceProductIds,
      toastOption: breadType == SandwichBreadType.sandwich
          ? (selection.toastOption ?? SandwichToastOption.normal)
          : null,
    );
  }

  bool _hasExplicitSandwichSelection(SandwichCustomizationSelection selection) {
    return selection.breadType != null ||
        selection.sauceProductIds.isNotEmpty ||
        selection.toastOption != null;
  }

  MealCustomizationResolvedSnapshot _evaluateSandwich({
    required MealAdjustmentProfile profile,
    required MealCustomizationRequest request,
    required _PreparedRequest prepared,
  }) {
    final SandwichCustomizationSelection sandwichSelection =
        prepared.sandwichSelection ??
        (throw MealCustomizationRequestRejectedException(const <
          MealCustomizationRequestIssue
        >[
          MealCustomizationRequestIssue(
            code: MealCustomizationRequestIssueCode.missingSandwichBreadChoice,
          ),
        ]));
    final List<MealCustomizationSemanticAction> extraActions =
        <MealCustomizationSemanticAction>[];
    int totalAdjustmentMinor = profile.sandwichSettings.surchargeForBread(
      sandwichSelection.breadType!,
    );
    for (final _PreparedExtraSelection extra in prepared.extraSelections) {
      final int priceDeltaMinor =
          extra.option.fixedPriceDeltaMinor * extra.selection.quantity;
      extraActions.add(
        MealCustomizationSemanticAction(
          action: MealCustomizationAction.extra,
          chargeReason: MealCustomizationChargeReason.extraAdd,
          itemProductId: extra.selection.itemProductId,
          quantity: extra.selection.quantity,
          priceDeltaMinor: priceDeltaMinor,
        ),
      );
      totalAdjustmentMinor += priceDeltaMinor;
    }
    return MealCustomizationResolvedSnapshot(
      productId: request.productId,
      profileId: profile.id,
      sandwichSelection: sandwichSelection,
      resolvedExtraActions: List<MealCustomizationSemanticAction>.unmodifiable(
        extraActions,
      ),
      totalAdjustmentMinor: totalAdjustmentMinor,
    );
  }

  _IndexedRule? _selectBestExactRule({
    required List<_IndexedRule> rules,
    required MealAdjustmentPricingRuleType ruleType,
    required List<String> exactConditionKeys,
  }) {
    final List<String> normalizedKeys = List<String>.from(exactConditionKeys)
      ..sort();
    final List<_IndexedRule> matches =
        rules
            .where((_IndexedRule indexedRule) {
              return indexedRule.rule.ruleType == ruleType &&
                  _conditionListsEqual(
                    indexedRule.conditionKeys,
                    normalizedKeys,
                  );
            })
            .toList(growable: false)
          ..sort(_compareIndexedRules);
    return matches.isEmpty ? null : matches.first;
  }

  List<_IndexedRule> _selectMatchingRemoveOnlyRules({
    required List<_IndexedRule> rules,
    required List<String> removedConditionKeys,
  }) {
    final Map<String, int> removedCounts = _conditionCounts(
      removedConditionKeys,
    );
    final List<_IndexedRule> matches =
        rules
            .where((_IndexedRule indexedRule) {
              if (indexedRule.rule.ruleType !=
                  MealAdjustmentPricingRuleType.removeOnly) {
                return false;
              }
              return _isConditionSubset(
                subset: _conditionCounts(indexedRule.conditionKeys),
                superset: removedCounts,
              );
            })
            .toList(growable: false)
          ..sort(_compareIndexedRules);
    return matches;
  }

  MealCustomizationAppliedRule _toAppliedRule(_IndexedRule indexedRule) {
    return MealCustomizationAppliedRule(
      ruleId: indexedRule.rule.id,
      ruleType: indexedRule.rule.ruleType,
      priceDeltaMinor: indexedRule.rule.priceDeltaMinor,
      specificityScore: indexedRule.specificityScore,
      priority: indexedRule.rule.priority,
      conditionKeys: indexedRule.conditionKeys,
    );
  }

  int _compareComponents(MealAdjustmentComponent a, MealAdjustmentComponent b) {
    final int sortCompare = a.sortOrder.compareTo(b.sortOrder);
    if (sortCompare != 0) {
      return sortCompare;
    }
    final int keyCompare = a.componentKey.compareTo(b.componentKey);
    if (keyCompare != 0) {
      return keyCompare;
    }
    return a.id.compareTo(b.id);
  }

  int _comparePreparedSwaps(
    _PreparedSwapSelection a,
    _PreparedSwapSelection b,
  ) {
    final int componentCompare = _compareComponents(a.component, b.component);
    if (componentCompare != 0) {
      return componentCompare;
    }
    final int itemCompare = a.selection.targetItemProductId.compareTo(
      b.selection.targetItemProductId,
    );
    if (itemCompare != 0) {
      return itemCompare;
    }
    return a.selection.quantity.compareTo(b.selection.quantity);
  }

  int _comparePreparedExtras(
    _PreparedExtraSelection a,
    _PreparedExtraSelection b,
  ) {
    final int sortCompare = a.option.sortOrder.compareTo(b.option.sortOrder);
    if (sortCompare != 0) {
      return sortCompare;
    }
    final int itemCompare = a.selection.itemProductId.compareTo(
      b.selection.itemProductId,
    );
    if (itemCompare != 0) {
      return itemCompare;
    }
    return a.selection.quantity.compareTo(b.selection.quantity);
  }

  int _compareIndexedRules(_IndexedRule a, _IndexedRule b) {
    final int specificityCompare = b.specificityScore.compareTo(
      a.specificityScore,
    );
    if (specificityCompare != 0) {
      return specificityCompare;
    }
    final int priorityCompare = b.rule.priority.compareTo(a.rule.priority);
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    final int idCompare = a.rule.id.compareTo(b.rule.id);
    if (idCompare != 0) {
      return idCompare;
    }
    return a.index.compareTo(b.index);
  }

  int _compareAppliedRules(
    MealCustomizationAppliedRule a,
    MealCustomizationAppliedRule b,
  ) {
    final int specificityCompare = b.specificityScore.compareTo(
      a.specificityScore,
    );
    if (specificityCompare != 0) {
      return specificityCompare;
    }
    final int priorityCompare = b.priority.compareTo(a.priority);
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    return a.ruleId.compareTo(b.ruleId);
  }

  bool _conditionListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  Map<String, int> _conditionCounts(List<String> keys) {
    final Map<String, int> counts = <String, int>{};
    for (final String key in keys) {
      counts.update(key, (int value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  bool _isConditionSubset({
    required Map<String, int> subset,
    required Map<String, int> superset,
  }) {
    for (final MapEntry<String, int> entry in subset.entries) {
      if ((superset[entry.key] ?? 0) < entry.value) {
        return false;
      }
    }
    return true;
  }

  String _conditionKey(
    MealAdjustmentPricingRuleConditionType type, {
    String? componentKey,
    int? itemProductId,
    required int quantity,
  }) {
    return '${type.name}|${componentKey ?? ''}|${itemProductId ?? ''}|$quantity';
  }
}

class _PreparedRequest {
  const _PreparedRequest({
    required this.sandwichSelection,
    required this.removedComponents,
    required this.swapSelections,
    required this.extraSelections,
  });

  final SandwichCustomizationSelection? sandwichSelection;
  final List<MealAdjustmentComponent> removedComponents;
  final List<_PreparedSwapSelection> swapSelections;
  final List<_PreparedExtraSelection> extraSelections;
}

class _PreparedSwapSelection {
  const _PreparedSwapSelection({
    required this.component,
    required this.selection,
    required this.option,
  });

  final MealAdjustmentComponent component;
  final MealCustomizationComponentSelection selection;
  final MealAdjustmentComponentOption option;
}

class _PreparedSwapClassification {
  const _PreparedSwapClassification({
    required this.selection,
    required this.isFreeSwap,
    required this.conditionKey,
  });

  final _PreparedSwapSelection selection;
  final bool isFreeSwap;
  final String conditionKey;
}

class _PreparedExtraSelection {
  const _PreparedExtraSelection({
    required this.selection,
    required this.option,
  });

  final MealCustomizationExtraSelection selection;
  final MealAdjustmentExtraOption option;
}

class _PreparedExtraClassification {
  const _PreparedExtraClassification({
    required this.selection,
    required this.conditionKey,
  });

  final _PreparedExtraSelection selection;
  final String conditionKey;
}

class _IndexedRule {
  _IndexedRule({required this.rule, required this.index})
    : conditionKeys =
          rule.conditions
              .map((_conditionKeyFromRuleCondition))
              .toList(growable: false)
            ..sort(),
      specificityScore = _computeSpecificity(rule);

  final MealAdjustmentPricingRule rule;
  final int index;
  final List<String> conditionKeys;
  final int specificityScore;

  static int _computeSpecificity(MealAdjustmentPricingRule rule) {
    final int quantityWeight = rule.conditions.fold<int>(
      0,
      (int total, MealAdjustmentPricingRuleCondition condition) =>
          total + condition.quantity,
    );
    return (rule.conditions.length * 1000) + quantityWeight;
  }

  static String _conditionKeyFromRuleCondition(
    MealAdjustmentPricingRuleCondition condition,
  ) {
    return '${condition.conditionType.name}|${condition.componentKey ?? ''}|${condition.itemProductId ?? ''}|${condition.quantity}';
  }
}
