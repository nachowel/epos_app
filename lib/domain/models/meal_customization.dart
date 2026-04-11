import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'meal_adjustment_profile.dart';
export 'sandwich.dart';

enum MealCustomizationAction { remove, swap, extra, discount }

enum MealComponentSelectionMode { keep, remove, swap }

enum MealCustomizationChargeReason {
  freeSwap,
  paidSwap,
  extraAdd,
  removalDiscount,
  comboDiscount,
}

enum MealCustomizationPersistenceLineKind {
  remove,
  swap,
  extra,
  discount,
  choice,
}

class SandwichCustomizationSelection {
  const SandwichCustomizationSelection({
    this.breadType,
    this.sauceProductIds = const <int>[],
    this.toastOption,
    this.legacySauceLookupKeys = const <String>[],
  });

  final SandwichBreadType? breadType;
  final List<int> sauceProductIds;
  final SandwichToastOption? toastOption;
  final List<String> legacySauceLookupKeys;

  bool get hasLegacySauceSelection => legacySauceLookupKeys.isNotEmpty;

  SandwichCustomizationSelection copyWith({
    Object? breadType = _unsetNullableField,
    List<int>? sauceProductIds,
    Object? toastOption = _unsetNullableField,
    Object? legacySauceLookupKeys = _unsetNullableField,
  }) {
    return SandwichCustomizationSelection(
      breadType: identical(breadType, _unsetNullableField)
          ? this.breadType
          : breadType as SandwichBreadType?,
      sauceProductIds: sauceProductIds ?? this.sauceProductIds,
      toastOption: identical(toastOption, _unsetNullableField)
          ? this.toastOption
          : toastOption as SandwichToastOption?,
      legacySauceLookupKeys:
          identical(legacySauceLookupKeys, _unsetNullableField)
          ? this.legacySauceLookupKeys
          : legacySauceLookupKeys as List<String>,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'bread_type': breadType?.name,
      'sauce_product_ids': List<int>.from(sauceProductIds),
      'toast_option': toastOption?.name,
    };
  }

  factory SandwichCustomizationSelection.fromJson(Map<String, Object?> json) {
    final List<int> parsedSauceProductIds = _sandwichSauceProductIdsFromJson(
      json['sauce_product_ids'],
    );
    final List<String> legacySauceLookupKeys =
        _legacySandwichSauceLookupKeysFromJson(
          json['sauce_types'],
          legacySingleSauce: json['sauce_type'] as String?,
        );
    return SandwichCustomizationSelection(
      breadType: _sandwichBreadTypeFromJson(json['bread_type'] as String?),
      sauceProductIds: parsedSauceProductIds,
      toastOption: _sandwichToastOptionFromJson(
        json['toast_option'] as String?,
      ),
      legacySauceLookupKeys: legacySauceLookupKeys,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SandwichCustomizationSelection &&
        other.breadType == breadType &&
        _listEquals(other.sauceProductIds, sauceProductIds) &&
        other.toastOption == toastOption &&
        _listEquals(other.legacySauceLookupKeys, legacySauceLookupKeys);
  }

  @override
  int get hashCode => Object.hash(
    breadType,
    Object.hashAll(sauceProductIds),
    toastOption,
    Object.hashAll(legacySauceLookupKeys),
  );
}

class MealCustomizationRequest {
  const MealCustomizationRequest({
    required this.productId,
    this.profileId,
    this.removedComponentKeys = const <String>[],
    this.swapSelections = const <MealCustomizationComponentSelection>[],
    this.extraSelections = const <MealCustomizationExtraSelection>[],
    this.sandwichSelection = const SandwichCustomizationSelection(),
  });

  final int productId;
  final int? profileId;
  final List<String> removedComponentKeys;
  final List<MealCustomizationComponentSelection> swapSelections;
  final List<MealCustomizationExtraSelection> extraSelections;
  final SandwichCustomizationSelection sandwichSelection;

  MealCustomizationRequest copyWith({
    int? productId,
    Object? profileId = _unsetNullableField,
    List<String>? removedComponentKeys,
    List<MealCustomizationComponentSelection>? swapSelections,
    List<MealCustomizationExtraSelection>? extraSelections,
    SandwichCustomizationSelection? sandwichSelection,
  }) {
    return MealCustomizationRequest(
      productId: productId ?? this.productId,
      profileId: identical(profileId, _unsetNullableField)
          ? this.profileId
          : profileId as int?,
      removedComponentKeys: removedComponentKeys ?? this.removedComponentKeys,
      swapSelections: swapSelections ?? this.swapSelections,
      extraSelections: extraSelections ?? this.extraSelections,
      sandwichSelection: sandwichSelection ?? this.sandwichSelection,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationRequest &&
        other.productId == productId &&
        other.profileId == profileId &&
        _listEquals(other.removedComponentKeys, removedComponentKeys) &&
        _listEquals(other.swapSelections, swapSelections) &&
        _listEquals(other.extraSelections, extraSelections) &&
        other.sandwichSelection == sandwichSelection;
  }

  @override
  int get hashCode => Object.hash(
    productId,
    profileId,
    Object.hashAll(removedComponentKeys),
    Object.hashAll(swapSelections),
    Object.hashAll(extraSelections),
    sandwichSelection,
  );
}

class MealCustomizationResolvedSnapshot {
  const MealCustomizationResolvedSnapshot({
    required this.productId,
    required this.profileId,
    this.sandwichSelection,
    this.resolvedComponentActions = const <MealCustomizationSemanticAction>[],
    this.resolvedExtraActions = const <MealCustomizationSemanticAction>[],
    this.triggeredDiscounts = const <MealCustomizationSemanticAction>[],
    this.appliedRules = const <MealCustomizationAppliedRule>[],
    this.totalAdjustmentMinor = 0,
    this.freeSwapCountUsed = 0,
    this.paidSwapCountUsed = 0,
  });

  final int productId;
  final int profileId;
  final SandwichCustomizationSelection? sandwichSelection;
  final List<MealCustomizationSemanticAction> resolvedComponentActions;
  final List<MealCustomizationSemanticAction> resolvedExtraActions;
  final List<MealCustomizationSemanticAction> triggeredDiscounts;
  final List<MealCustomizationAppliedRule> appliedRules;
  final int totalAdjustmentMinor;
  final int freeSwapCountUsed;
  final int paidSwapCountUsed;

  List<MealCustomizationSemanticAction> get actions =>
      <MealCustomizationSemanticAction>[
        ...resolvedComponentActions,
        ...resolvedExtraActions,
        ...triggeredDiscounts,
      ];

  List<int> get appliedRuleIds => appliedRules
      .map((MealCustomizationAppliedRule rule) => rule.ruleId)
      .toList(growable: false);

  String get stableIdentityKey {
    final Map<String, Object?> normalized = <String, Object?>{
      'product_id': productId,
      'profile_id': profileId,
      'sandwich_selection': sandwichSelection?.toJson(),
      'resolved_component_actions': _normalizeActions(resolvedComponentActions),
      'resolved_extra_actions': _normalizeActions(resolvedExtraActions),
      'triggered_discounts': _normalizeActions(triggeredDiscounts),
      'applied_rule_ids': List<int>.from(appliedRuleIds)..sort(),
      'total_adjustment_minor': totalAdjustmentMinor,
    };
    return sha256.convert(utf8.encode(jsonEncode(normalized))).toString();
  }

  MealCustomizationEditorState toEditorState() {
    final List<MealCustomizationComponentState> componentSelections =
        resolvedComponentActions
            .where((MealCustomizationSemanticAction action) {
              return action.componentKey != null &&
                  (action.action == MealCustomizationAction.remove ||
                      action.action == MealCustomizationAction.swap);
            })
            .map((MealCustomizationSemanticAction action) {
              switch (action.action) {
                case MealCustomizationAction.remove:
                  return MealCustomizationComponentState(
                    componentKey: action.componentKey!,
                    mode: MealComponentSelectionMode.remove,
                    quantity: action.quantity,
                  );
                case MealCustomizationAction.swap:
                  return MealCustomizationComponentState(
                    componentKey: action.componentKey!,
                    mode: MealComponentSelectionMode.swap,
                    swapTargetItemProductId: action.itemProductId!,
                    quantity: action.quantity,
                  );
                case MealCustomizationAction.extra:
                case MealCustomizationAction.discount:
                  throw StateError(
                    'Component rehydration received non-component action ${action.action.name}.',
                  );
              }
            })
            .toList(growable: false)
          ..sort(_compareComponentStates);
    final List<MealCustomizationExtraSelection> extraSelections =
        resolvedExtraActions
            .where((MealCustomizationSemanticAction action) {
              return action.action == MealCustomizationAction.extra &&
                  action.itemProductId != null;
            })
            .map(
              (MealCustomizationSemanticAction action) =>
                  MealCustomizationExtraSelection(
                    itemProductId: action.itemProductId!,
                    quantity: action.quantity,
                  ),
            )
            .toList(growable: false);
    return MealCustomizationEditorState(
      componentSelections: componentSelections,
      extraSelections: extraSelections,
      sandwichSelection:
          sandwichSelection ?? const SandwichCustomizationSelection(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'product_id': productId,
      'profile_id': profileId,
      'sandwich_selection': sandwichSelection?.toJson(),
      'resolved_component_actions': resolvedComponentActions
          .map((MealCustomizationSemanticAction action) => action.toJson())
          .toList(growable: false),
      'resolved_extra_actions': resolvedExtraActions
          .map((MealCustomizationSemanticAction action) => action.toJson())
          .toList(growable: false),
      'triggered_discounts': triggeredDiscounts
          .map((MealCustomizationSemanticAction action) => action.toJson())
          .toList(growable: false),
      'applied_rules': appliedRules
          .map((MealCustomizationAppliedRule rule) => rule.toJson())
          .toList(growable: false),
      'total_adjustment_minor': totalAdjustmentMinor,
      'free_swap_count_used': freeSwapCountUsed,
      'paid_swap_count_used': paidSwapCountUsed,
    };
  }

  factory MealCustomizationResolvedSnapshot.fromJson(
    Map<String, Object?> json,
  ) {
    return MealCustomizationResolvedSnapshot(
      productId: json['product_id'] as int,
      profileId: json['profile_id'] as int,
      sandwichSelection: _sandwichSelectionFromJson(json['sandwich_selection']),
      resolvedComponentActions: _semanticActionListFromJson(
        json['resolved_component_actions'],
      ),
      resolvedExtraActions: _semanticActionListFromJson(
        json['resolved_extra_actions'],
      ),
      triggeredDiscounts: _semanticActionListFromJson(
        json['triggered_discounts'],
      ),
      appliedRules: _appliedRuleListFromJson(json['applied_rules']),
      totalAdjustmentMinor: json['total_adjustment_minor'] as int? ?? 0,
      freeSwapCountUsed: json['free_swap_count_used'] as int? ?? 0,
      paidSwapCountUsed: json['paid_swap_count_used'] as int? ?? 0,
    );
  }

  MealCustomizationPersistencePreview toPersistencePreview() {
    final List<MealCustomizationPersistencePreviewLine> lines =
        <MealCustomizationPersistencePreviewLine>[
          ..._sandwichPersistencePreviewLines(),
          ...actions.map(
            (MealCustomizationSemanticAction action) =>
                MealCustomizationPersistencePreviewLine(
                  kind: _mapPersistenceKind(action.action),
                  chargeReason: action.chargeReason,
                  componentKey: action.componentKey,
                  itemProductId: action.itemProductId,
                  sourceItemProductId: action.sourceItemProductId,
                  quantity: action.quantity,
                  priceDeltaMinor: action.priceDeltaMinor,
                  appliedRuleIds: action.appliedRuleIds,
                ),
          ),
        ];
    return MealCustomizationPersistencePreview(
      productId: productId,
      profileId: profileId,
      totalAdjustmentMinor: totalAdjustmentMinor,
      lines: lines,
      appliedRuleIds: appliedRuleIds,
    );
  }

  MealCustomizationReportingSummary toReportingSummary() {
    final List<String> removedComponentKeys = resolvedComponentActions
        .where((MealCustomizationSemanticAction action) {
          return action.action == MealCustomizationAction.remove;
        })
        .map((MealCustomizationSemanticAction action) => action.componentKey!)
        .toList(growable: false);
    final List<int> swappedItemProductIds = resolvedComponentActions
        .where((MealCustomizationSemanticAction action) {
          return action.action == MealCustomizationAction.swap &&
              action.itemProductId != null;
        })
        .map((MealCustomizationSemanticAction action) => action.itemProductId!)
        .toList(growable: false);
    final List<int> extraItemProductIds = resolvedExtraActions
        .where((MealCustomizationSemanticAction action) {
          return action.itemProductId != null;
        })
        .map((MealCustomizationSemanticAction action) => action.itemProductId!)
        .toList(growable: false);
    final int totalDiscountMinor = triggeredDiscounts.fold<int>(
      0,
      (int total, MealCustomizationSemanticAction action) =>
          total + action.priceDeltaMinor,
    );
    return MealCustomizationReportingSummary(
      profileId: profileId,
      removedComponentKeys: removedComponentKeys,
      swappedItemProductIds: swappedItemProductIds,
      extraItemProductIds: extraItemProductIds,
      appliedRuleIds: appliedRuleIds,
      totalAdjustmentMinor: totalAdjustmentMinor,
      totalDiscountMinor: totalDiscountMinor,
      freeSwapCountUsed: freeSwapCountUsed,
      paidSwapCountUsed: paidSwapCountUsed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationResolvedSnapshot &&
        other.productId == productId &&
        other.profileId == profileId &&
        _listEquals(other.resolvedComponentActions, resolvedComponentActions) &&
        _listEquals(other.resolvedExtraActions, resolvedExtraActions) &&
        _listEquals(other.triggeredDiscounts, triggeredDiscounts) &&
        _listEquals(other.appliedRules, appliedRules) &&
        other.sandwichSelection == sandwichSelection &&
        other.totalAdjustmentMinor == totalAdjustmentMinor &&
        other.freeSwapCountUsed == freeSwapCountUsed &&
        other.paidSwapCountUsed == paidSwapCountUsed;
  }

  @override
  int get hashCode => Object.hash(
    productId,
    profileId,
    sandwichSelection,
    Object.hashAll(resolvedComponentActions),
    Object.hashAll(resolvedExtraActions),
    Object.hashAll(triggeredDiscounts),
    Object.hashAll(appliedRules),
    totalAdjustmentMinor,
    freeSwapCountUsed,
    paidSwapCountUsed,
  );

  MealCustomizationPersistenceLineKind _mapPersistenceKind(
    MealCustomizationAction action,
  ) {
    switch (action) {
      case MealCustomizationAction.remove:
        return MealCustomizationPersistenceLineKind.remove;
      case MealCustomizationAction.swap:
        return MealCustomizationPersistenceLineKind.swap;
      case MealCustomizationAction.extra:
        return MealCustomizationPersistenceLineKind.extra;
      case MealCustomizationAction.discount:
        return MealCustomizationPersistenceLineKind.discount;
    }
  }

  List<MealCustomizationPersistencePreviewLine>
  _sandwichPersistencePreviewLines() {
    final SandwichCustomizationSelection? selection = sandwichSelection;
    if (selection == null) {
      return const <MealCustomizationPersistencePreviewLine>[];
    }
    final int sandwichBreadPriceDeltaMinor =
        totalAdjustmentMinor -
        resolvedExtraActions.fold<int>(
          0,
          (int total, MealCustomizationSemanticAction action) =>
              total + action.priceDeltaMinor,
        );
    final List<MealCustomizationPersistencePreviewLine> lines =
        <MealCustomizationPersistencePreviewLine>[];
    final SandwichBreadType? breadType = selection.breadType;
    if (breadType != null) {
      lines.add(
        MealCustomizationPersistencePreviewLine(
          kind: MealCustomizationPersistenceLineKind.choice,
          componentKey: 'sandwich_bread',
          quantity: 1,
          priceDeltaMinor: sandwichBreadPriceDeltaMinor,
        ),
      );
    }
    for (final int sauceProductId in selection.sauceProductIds) {
      lines.add(
        MealCustomizationPersistencePreviewLine(
          kind: MealCustomizationPersistenceLineKind.choice,
          componentKey: 'sandwich_sauce',
          itemProductId: sauceProductId,
          quantity: 1,
          priceDeltaMinor: 0,
        ),
      );
    }
    if (selection.toastOption != null) {
      lines.add(
        MealCustomizationPersistencePreviewLine(
          kind: MealCustomizationPersistenceLineKind.choice,
          componentKey: 'sandwich_toast',
          quantity: 1,
          priceDeltaMinor: 0,
        ),
      );
    }
    return lines;
  }

  List<Map<String, Object?>> _normalizeActions(
    List<MealCustomizationSemanticAction> actions,
  ) {
    final List<Map<String, Object?>> normalized = actions
        .map(
          (MealCustomizationSemanticAction action) => <String, Object?>{
            'action': action.action.name,
            'charge_reason': action.chargeReason?.name,
            'component_key': action.componentKey,
            'item_product_id': action.itemProductId,
            'source_item_product_id': action.sourceItemProductId,
            'quantity': action.quantity,
            'price_delta_minor': action.priceDeltaMinor,
            'applied_rule_ids': List<int>.from(action.appliedRuleIds)..sort(),
          },
        )
        .toList(growable: false);
    normalized.sort(_compareNormalizedMaps);
    return normalized;
  }
}

class MealCustomizationComponentSelection {
  const MealCustomizationComponentSelection({
    required this.componentKey,
    required this.targetItemProductId,
    this.quantity = 1,
  });

  final String componentKey;
  final int targetItemProductId;
  final int quantity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationComponentSelection &&
        other.componentKey == componentKey &&
        other.targetItemProductId == targetItemProductId &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(componentKey, targetItemProductId, quantity);
}

class MealCustomizationComponentState {
  const MealCustomizationComponentState({
    required this.componentKey,
    required this.mode,
    this.swapTargetItemProductId,
    this.quantity = 1,
  }) : assert(
         (mode == MealComponentSelectionMode.swap &&
                 swapTargetItemProductId != null) ||
             (mode != MealComponentSelectionMode.swap &&
                 swapTargetItemProductId == null),
         'Swap target must exist only for swap selections.',
       );

  final String componentKey;
  final MealComponentSelectionMode mode;
  final int? swapTargetItemProductId;
  final int quantity;

  bool get isKeep => mode == MealComponentSelectionMode.keep;
  bool get isRemove => mode == MealComponentSelectionMode.remove;
  bool get isSwap => mode == MealComponentSelectionMode.swap;

  MealCustomizationComponentState copyWith({
    String? componentKey,
    MealComponentSelectionMode? mode,
    Object? swapTargetItemProductId = _unsetNullableField,
    int? quantity,
  }) {
    final MealComponentSelectionMode resolvedMode = mode ?? this.mode;
    final int? resolvedSwapTargetItemProductId =
        identical(swapTargetItemProductId, _unsetNullableField)
        ? (resolvedMode == MealComponentSelectionMode.swap
              ? this.swapTargetItemProductId
              : null)
        : swapTargetItemProductId as int?;
    return MealCustomizationComponentState(
      componentKey: componentKey ?? this.componentKey,
      mode: resolvedMode,
      swapTargetItemProductId: resolvedSwapTargetItemProductId,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MealCustomizationComponentState &&
        other.componentKey == componentKey &&
        other.mode == mode &&
        other.swapTargetItemProductId == swapTargetItemProductId &&
        other.quantity == quantity;
  }

  @override
  int get hashCode =>
      Object.hash(componentKey, mode, swapTargetItemProductId, quantity);
}

class MealCustomizationExtraSelection {
  const MealCustomizationExtraSelection({
    required this.itemProductId,
    this.quantity = 1,
  });

  final int itemProductId;
  final int quantity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationExtraSelection &&
        other.itemProductId == itemProductId &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(itemProductId, quantity);
}

class MealCustomizationSemanticAction {
  const MealCustomizationSemanticAction({
    required this.action,
    this.chargeReason,
    this.componentKey,
    this.itemProductId,
    this.sourceItemProductId,
    this.quantity = 1,
    this.priceDeltaMinor = 0,
    this.appliedRuleIds = const <int>[],
  });

  final MealCustomizationAction action;
  final MealCustomizationChargeReason? chargeReason;
  final String? componentKey;
  final int? itemProductId;
  final int? sourceItemProductId;
  final int quantity;
  final int priceDeltaMinor;
  final List<int> appliedRuleIds;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'action': action.name,
      'charge_reason': chargeReason?.name,
      'component_key': componentKey,
      'item_product_id': itemProductId,
      'source_item_product_id': sourceItemProductId,
      'quantity': quantity,
      'price_delta_minor': priceDeltaMinor,
      'applied_rule_ids': appliedRuleIds,
    };
  }

  factory MealCustomizationSemanticAction.fromJson(Map<String, Object?> json) {
    return MealCustomizationSemanticAction(
      action: MealCustomizationAction.values.byName(json['action'] as String),
      chargeReason: _mealChargeReasonFromJson(json['charge_reason'] as String?),
      componentKey: json['component_key'] as String?,
      itemProductId: json['item_product_id'] as int?,
      sourceItemProductId: json['source_item_product_id'] as int?,
      quantity: json['quantity'] as int? ?? 1,
      priceDeltaMinor: json['price_delta_minor'] as int? ?? 0,
      appliedRuleIds: _intListFromJson(json['applied_rule_ids']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationSemanticAction &&
        other.action == action &&
        other.chargeReason == chargeReason &&
        other.componentKey == componentKey &&
        other.itemProductId == itemProductId &&
        other.sourceItemProductId == sourceItemProductId &&
        other.quantity == quantity &&
        other.priceDeltaMinor == priceDeltaMinor &&
        _listEquals(other.appliedRuleIds, appliedRuleIds);
  }

  @override
  int get hashCode => Object.hash(
    action,
    chargeReason,
    componentKey,
    itemProductId,
    sourceItemProductId,
    quantity,
    priceDeltaMinor,
    Object.hashAll(appliedRuleIds),
  );
}

class MealCustomizationAppliedRule {
  const MealCustomizationAppliedRule({
    required this.ruleId,
    required this.ruleType,
    required this.priceDeltaMinor,
    required this.specificityScore,
    required this.priority,
    required this.conditionKeys,
  });

  final int ruleId;
  final MealAdjustmentPricingRuleType ruleType;
  final int priceDeltaMinor;
  final int specificityScore;
  final int priority;
  final List<String> conditionKeys;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'rule_id': ruleId,
      'rule_type': ruleType.name,
      'price_delta_minor': priceDeltaMinor,
      'specificity_score': specificityScore,
      'priority': priority,
      'condition_keys': conditionKeys,
    };
  }

  factory MealCustomizationAppliedRule.fromJson(Map<String, Object?> json) {
    return MealCustomizationAppliedRule(
      ruleId: json['rule_id'] as int,
      ruleType: _pricingRuleTypeFromJson(json['rule_type'] as String),
      priceDeltaMinor: json['price_delta_minor'] as int? ?? 0,
      specificityScore: json['specificity_score'] as int? ?? 0,
      priority: json['priority'] as int? ?? 0,
      conditionKeys: _stringListFromJson(json['condition_keys']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationAppliedRule &&
        other.ruleId == ruleId &&
        other.ruleType == ruleType &&
        other.priceDeltaMinor == priceDeltaMinor &&
        other.specificityScore == specificityScore &&
        other.priority == priority &&
        _listEquals(other.conditionKeys, conditionKeys);
  }

  @override
  int get hashCode => Object.hash(
    ruleId,
    ruleType,
    priceDeltaMinor,
    specificityScore,
    priority,
    Object.hashAll(conditionKeys),
  );
}

class MealCustomizationPersistencePreviewLine {
  const MealCustomizationPersistencePreviewLine({
    required this.kind,
    this.chargeReason,
    this.componentKey,
    this.itemProductId,
    this.sourceItemProductId,
    required this.quantity,
    required this.priceDeltaMinor,
    this.appliedRuleIds = const <int>[],
  });

  final MealCustomizationPersistenceLineKind kind;
  final MealCustomizationChargeReason? chargeReason;
  final String? componentKey;
  final int? itemProductId;
  final int? sourceItemProductId;
  final int quantity;
  final int priceDeltaMinor;
  final List<int> appliedRuleIds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationPersistencePreviewLine &&
        other.kind == kind &&
        other.chargeReason == chargeReason &&
        other.componentKey == componentKey &&
        other.itemProductId == itemProductId &&
        other.sourceItemProductId == sourceItemProductId &&
        other.quantity == quantity &&
        other.priceDeltaMinor == priceDeltaMinor &&
        _listEquals(other.appliedRuleIds, appliedRuleIds);
  }

  @override
  int get hashCode => Object.hash(
    kind,
    chargeReason,
    componentKey,
    itemProductId,
    sourceItemProductId,
    quantity,
    priceDeltaMinor,
    Object.hashAll(appliedRuleIds),
  );
}

class MealCustomizationPersistencePreview {
  const MealCustomizationPersistencePreview({
    required this.productId,
    required this.profileId,
    required this.totalAdjustmentMinor,
    this.lines = const <MealCustomizationPersistencePreviewLine>[],
    this.appliedRuleIds = const <int>[],
  });

  final int productId;
  final int profileId;
  final int totalAdjustmentMinor;
  final List<MealCustomizationPersistencePreviewLine> lines;
  final List<int> appliedRuleIds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationPersistencePreview &&
        other.productId == productId &&
        other.profileId == profileId &&
        other.totalAdjustmentMinor == totalAdjustmentMinor &&
        _listEquals(other.lines, lines) &&
        _listEquals(other.appliedRuleIds, appliedRuleIds);
  }

  @override
  int get hashCode => Object.hash(
    productId,
    profileId,
    totalAdjustmentMinor,
    Object.hashAll(lines),
    Object.hashAll(appliedRuleIds),
  );
}

class MealCustomizationReportingSummary {
  const MealCustomizationReportingSummary({
    required this.profileId,
    this.removedComponentKeys = const <String>[],
    this.swappedItemProductIds = const <int>[],
    this.extraItemProductIds = const <int>[],
    this.appliedRuleIds = const <int>[],
    required this.totalAdjustmentMinor,
    required this.totalDiscountMinor,
    required this.freeSwapCountUsed,
    required this.paidSwapCountUsed,
  });

  final int profileId;
  final List<String> removedComponentKeys;
  final List<int> swappedItemProductIds;
  final List<int> extraItemProductIds;
  final List<int> appliedRuleIds;
  final int totalAdjustmentMinor;
  final int totalDiscountMinor;
  final int freeSwapCountUsed;
  final int paidSwapCountUsed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealCustomizationReportingSummary &&
        other.profileId == profileId &&
        _listEquals(other.removedComponentKeys, removedComponentKeys) &&
        _listEquals(other.swappedItemProductIds, swappedItemProductIds) &&
        _listEquals(other.extraItemProductIds, extraItemProductIds) &&
        _listEquals(other.appliedRuleIds, appliedRuleIds) &&
        other.totalAdjustmentMinor == totalAdjustmentMinor &&
        other.totalDiscountMinor == totalDiscountMinor &&
        other.freeSwapCountUsed == freeSwapCountUsed &&
        other.paidSwapCountUsed == paidSwapCountUsed;
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    Object.hashAll(removedComponentKeys),
    Object.hashAll(swappedItemProductIds),
    Object.hashAll(extraItemProductIds),
    Object.hashAll(appliedRuleIds),
    totalAdjustmentMinor,
    totalDiscountMinor,
    freeSwapCountUsed,
    paidSwapCountUsed,
  );
}

class MealCustomizationEditorState {
  const MealCustomizationEditorState({
    this.componentSelections = const <MealCustomizationComponentState>[],
    this.extraSelections = const <MealCustomizationExtraSelection>[],
    this.sandwichSelection = const SandwichCustomizationSelection(),
  });

  final List<MealCustomizationComponentState> componentSelections;
  final List<MealCustomizationExtraSelection> extraSelections;
  final SandwichCustomizationSelection sandwichSelection;

  List<String> get removedComponentKeys =>
      componentSelections
          .where(
            (MealCustomizationComponentState selection) =>
                selection.mode == MealComponentSelectionMode.remove,
          )
          .map(
            (MealCustomizationComponentState selection) =>
                selection.componentKey,
          )
          .toList(growable: false)
        ..sort();

  List<MealCustomizationComponentSelection> get swapSelections =>
      componentSelections
          .where(
            (MealCustomizationComponentState selection) =>
                selection.mode == MealComponentSelectionMode.swap,
          )
          .map(
            (MealCustomizationComponentState selection) =>
                MealCustomizationComponentSelection(
                  componentKey: selection.componentKey,
                  targetItemProductId: selection.swapTargetItemProductId!,
                  quantity: selection.quantity,
                ),
          )
          .toList(growable: false)
        ..sort(_compareComponentSelections);

  MealCustomizationComponentState selectionForComponent(String componentKey) {
    for (final MealCustomizationComponentState selection
        in componentSelections) {
      if (selection.componentKey == componentKey) {
        return selection;
      }
    }
    return MealCustomizationComponentState(
      componentKey: componentKey,
      mode: MealComponentSelectionMode.keep,
    );
  }

  MealCustomizationRequest toRequest({
    required int productId,
    required int profileId,
  }) {
    return MealCustomizationRequest(
      productId: productId,
      profileId: profileId,
      removedComponentKeys: removedComponentKeys,
      swapSelections: swapSelections,
      extraSelections: extraSelections,
      sandwichSelection: sandwichSelection,
    );
  }

  MealCustomizationEditorState copyWith({
    List<MealCustomizationComponentState>? componentSelections,
    List<MealCustomizationExtraSelection>? extraSelections,
    SandwichCustomizationSelection? sandwichSelection,
  }) {
    return MealCustomizationEditorState(
      componentSelections: componentSelections ?? this.componentSelections,
      extraSelections: extraSelections ?? this.extraSelections,
      sandwichSelection: sandwichSelection ?? this.sandwichSelection,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MealCustomizationEditorState &&
        _listEquals(other.componentSelections, componentSelections) &&
        _listEquals(other.extraSelections, extraSelections) &&
        other.sandwichSelection == sandwichSelection;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(componentSelections),
    Object.hashAll(extraSelections),
    sandwichSelection,
  );
}

class MealCustomizationCartSelection {
  const MealCustomizationCartSelection({
    required this.request,
    required this.snapshot,
    required this.stableIdentityKey,
    required this.summaryLines,
    required this.compactSummary,
    this.displayName,
    required this.perUnitAdjustmentMinor,
    required this.perUnitLineTotalMinor,
  });

  final MealCustomizationRequest request;
  final MealCustomizationResolvedSnapshot snapshot;
  final String stableIdentityKey;
  final List<String> summaryLines;
  final String compactSummary;
  final String? displayName;
  final int perUnitAdjustmentMinor;
  final int perUnitLineTotalMinor;
}

class MealCustomizationRehydrationResult {
  const MealCustomizationRehydrationResult({
    required this.editorState,
    required this.snapshot,
    required this.stableIdentityKey,
    required this.lineQuantity,
  });

  final MealCustomizationEditorState editorState;
  final MealCustomizationResolvedSnapshot snapshot;
  final String stableIdentityKey;
  final int lineQuantity;
}

class MealCustomizationPersistedSnapshotRecord {
  const MealCustomizationPersistedSnapshotRecord({
    required this.transactionLineId,
    required this.productId,
    required this.profileId,
    required this.customizationKey,
    required this.snapshot,
  });

  final int transactionLineId;
  final int productId;
  final int profileId;
  final String customizationKey;
  final MealCustomizationResolvedSnapshot snapshot;
}

List<MealCustomizationSemanticAction> _semanticActionListFromJson(
  Object? value,
) {
  final List<Object?> raw = (value as List<Object?>?) ?? const <Object?>[];
  return raw
      .map(
        (Object? entry) => MealCustomizationSemanticAction.fromJson(
          Map<String, Object?>.from(entry! as Map),
        ),
      )
      .toList(growable: false);
}

List<MealCustomizationAppliedRule> _appliedRuleListFromJson(Object? value) {
  final List<Object?> raw = (value as List<Object?>?) ?? const <Object?>[];
  return raw
      .map(
        (Object? entry) => MealCustomizationAppliedRule.fromJson(
          Map<String, Object?>.from(entry! as Map),
        ),
      )
      .toList(growable: false);
}

List<int> _intListFromJson(Object? value) {
  return ((value as List<Object?>?) ?? const <Object?>[])
      .whereType<int>()
      .toList(growable: false);
}

List<String> _stringListFromJson(Object? value) {
  return ((value as List<Object?>?) ?? const <Object?>[])
      .map((Object? entry) => entry as String)
      .toList(growable: false);
}

MealCustomizationChargeReason? _mealChargeReasonFromJson(String? value) {
  if (value == null) {
    return null;
  }
  return MealCustomizationChargeReason.values.byName(value);
}

SandwichCustomizationSelection? _sandwichSelectionFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  return SandwichCustomizationSelection.fromJson(
    Map<String, Object?>.from(value as Map),
  );
}

SandwichBreadType? _sandwichBreadTypeFromJson(String? value) {
  if (value == null) {
    return null;
  }
  return SandwichBreadType.values.byName(value);
}

List<int> _sandwichSauceProductIdsFromJson(Object? value) {
  return normalizeSandwichSauceProductIds(_intListFromJson(value));
}

List<String> _legacySandwichSauceLookupKeysFromJson(
  Object? value, {
  required String? legacySingleSauce,
}) {
  final List<String> rawValues = <String>[
    ...((value as List<Object?>?) ?? const <Object?>[]).whereType<String>(),
    if (legacySingleSauce != null) legacySingleSauce,
  ];
  return normalizeLegacySandwichSauceLookupKeys(rawValues);
}

SandwichToastOption? _sandwichToastOptionFromJson(String? value) {
  if (value == null) {
    return null;
  }
  return SandwichToastOption.values.byName(value);
}

MealAdjustmentPricingRuleType _pricingRuleTypeFromJson(String value) {
  switch (value) {
    case 'removeOnly':
      return MealAdjustmentPricingRuleType.removeOnly;
    case 'combo':
      return MealAdjustmentPricingRuleType.combo;
    case 'swap':
      return MealAdjustmentPricingRuleType.swap;
    case 'extra':
      return MealAdjustmentPricingRuleType.extra;
  }
  throw ArgumentError.value(value, 'value', 'Unknown pricing rule type.');
}

int _compareNormalizedMaps(
  Map<String, Object?> left,
  Map<String, Object?> right,
) {
  final String leftEncoded = jsonEncode(left);
  final String rightEncoded = jsonEncode(right);
  return leftEncoded.compareTo(rightEncoded);
}

int _compareComponentStates(
  MealCustomizationComponentState left,
  MealCustomizationComponentState right,
) {
  final int keyCompare = left.componentKey.compareTo(right.componentKey);
  if (keyCompare != 0) {
    return keyCompare;
  }
  final int modeCompare = left.mode.index.compareTo(right.mode.index);
  if (modeCompare != 0) {
    return modeCompare;
  }
  final int targetCompare = (left.swapTargetItemProductId ?? -1).compareTo(
    right.swapTargetItemProductId ?? -1,
  );
  if (targetCompare != 0) {
    return targetCompare;
  }
  return left.quantity.compareTo(right.quantity);
}

int _compareComponentSelections(
  MealCustomizationComponentSelection left,
  MealCustomizationComponentSelection right,
) {
  final int keyCompare = left.componentKey.compareTo(right.componentKey);
  if (keyCompare != 0) {
    return keyCompare;
  }
  final int itemCompare = left.targetItemProductId.compareTo(
    right.targetItemProductId,
  );
  if (itemCompare != 0) {
    return itemCompare;
  }
  return left.quantity.compareTo(right.quantity);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
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

const Object _unsetNullableField = Object();

/// A quick-action suggestion shown in the POS dialog to speed up common
/// customization patterns. Tapping applies the shortcut to the editor state;
/// the engine evaluation still runs normally.
class MealQuickSuggestion {
  const MealQuickSuggestion({
    required this.label,
    required this.kind,
    this.componentKey,
    this.targetItemProductId,
    this.itemProductId,
    this.quantity = 1,
    required this.usageCount,
  });

  final String label;
  final MealSuggestionActionKind kind;
  final String? componentKey;
  final int? targetItemProductId;
  final int? itemProductId;
  final int quantity;
  final int usageCount;

  @override
  bool operator ==(Object other) {
    return other is MealQuickSuggestion &&
        other.label == label &&
        other.kind == kind &&
        other.componentKey == componentKey &&
        other.targetItemProductId == targetItemProductId &&
        other.itemProductId == itemProductId &&
        other.quantity == quantity &&
        other.usageCount == usageCount;
  }

  @override
  int get hashCode => Object.hash(
    label,
    kind,
    componentKey,
    targetItemProductId,
    itemProductId,
    quantity,
    usageCount,
  );
}

enum MealSuggestionActionKind { swap, remove, addExtra }
