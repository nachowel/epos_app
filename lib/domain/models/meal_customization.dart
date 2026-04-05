import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'meal_adjustment_profile.dart';

enum MealCustomizationAction { remove, swap, extra, discount }

enum MealCustomizationChargeReason {
  freeSwap,
  paidSwap,
  extraAdd,
  removalDiscount,
  comboDiscount,
}

enum MealCustomizationPersistenceLineKind { remove, swap, extra, discount }

class MealCustomizationRequest {
  const MealCustomizationRequest({
    required this.productId,
    this.profileId,
    this.removedComponentKeys = const <String>[],
    this.swapSelections = const <MealCustomizationComponentSelection>[],
    this.extraSelections = const <MealCustomizationExtraSelection>[],
  });

  final int productId;
  final int? profileId;
  final List<String> removedComponentKeys;
  final List<MealCustomizationComponentSelection> swapSelections;
  final List<MealCustomizationExtraSelection> extraSelections;

  MealCustomizationRequest copyWith({
    int? productId,
    Object? profileId = _unsetNullableField,
    List<String>? removedComponentKeys,
    List<MealCustomizationComponentSelection>? swapSelections,
    List<MealCustomizationExtraSelection>? extraSelections,
  }) {
    return MealCustomizationRequest(
      productId: productId ?? this.productId,
      profileId: identical(profileId, _unsetNullableField)
          ? this.profileId
          : profileId as int?,
      removedComponentKeys: removedComponentKeys ?? this.removedComponentKeys,
      swapSelections: swapSelections ?? this.swapSelections,
      extraSelections: extraSelections ?? this.extraSelections,
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
        _listEquals(other.extraSelections, extraSelections);
  }

  @override
  int get hashCode => Object.hash(
    productId,
    profileId,
    Object.hashAll(removedComponentKeys),
    Object.hashAll(swapSelections),
    Object.hashAll(extraSelections),
  );
}

class MealCustomizationResolvedSnapshot {
  const MealCustomizationResolvedSnapshot({
    required this.productId,
    required this.profileId,
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
      'resolved_component_actions': _normalizeActions(resolvedComponentActions),
      'resolved_extra_actions': _normalizeActions(resolvedExtraActions),
      'triggered_discounts': _normalizeActions(triggeredDiscounts),
      'applied_rule_ids': List<int>.from(appliedRuleIds)..sort(),
      'total_adjustment_minor': totalAdjustmentMinor,
    };
    return sha256.convert(utf8.encode(jsonEncode(normalized))).toString();
  }

  MealCustomizationEditorState toEditorState() {
    final List<String> removedComponentKeys = resolvedComponentActions
        .where((MealCustomizationSemanticAction action) {
          return action.action == MealCustomizationAction.remove &&
              action.componentKey != null;
        })
        .map((MealCustomizationSemanticAction action) => action.componentKey!)
        .toList(growable: false);
    final List<MealCustomizationComponentSelection> swapSelections =
        resolvedComponentActions
            .where((MealCustomizationSemanticAction action) {
              return action.action == MealCustomizationAction.swap &&
                  action.componentKey != null &&
                  action.itemProductId != null;
            })
            .map(
              (MealCustomizationSemanticAction action) =>
                  MealCustomizationComponentSelection(
                    componentKey: action.componentKey!,
                    targetItemProductId: action.itemProductId!,
                    quantity: action.quantity,
                  ),
            )
            .toList(growable: false);
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
      removedComponentKeys: removedComponentKeys,
      swapSelections: swapSelections,
      extraSelections: extraSelections,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'product_id': productId,
      'profile_id': profileId,
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

  factory MealCustomizationResolvedSnapshot.fromJson(Map<String, Object?> json) {
    return MealCustomizationResolvedSnapshot(
      productId: json['product_id'] as int,
      profileId: json['profile_id'] as int,
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
    final List<MealCustomizationPersistencePreviewLine> lines = actions
        .map(
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
        )
        .toList(growable: false);
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
        other.totalAdjustmentMinor == totalAdjustmentMinor &&
        other.freeSwapCountUsed == freeSwapCountUsed &&
        other.paidSwapCountUsed == paidSwapCountUsed;
  }

  @override
  int get hashCode => Object.hash(
    productId,
    profileId,
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
      chargeReason: _mealChargeReasonFromJson(
        json['charge_reason'] as String?,
      ),
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
    this.removedComponentKeys = const <String>[],
    this.swapSelections = const <MealCustomizationComponentSelection>[],
    this.extraSelections = const <MealCustomizationExtraSelection>[],
  });

  final List<String> removedComponentKeys;
  final List<MealCustomizationComponentSelection> swapSelections;
  final List<MealCustomizationExtraSelection> extraSelections;

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
    );
  }

  MealCustomizationEditorState copyWith({
    List<String>? removedComponentKeys,
    List<MealCustomizationComponentSelection>? swapSelections,
    List<MealCustomizationExtraSelection>? extraSelections,
  }) {
    return MealCustomizationEditorState(
      removedComponentKeys: removedComponentKeys ?? this.removedComponentKeys,
      swapSelections: swapSelections ?? this.swapSelections,
      extraSelections: extraSelections ?? this.extraSelections,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MealCustomizationEditorState &&
        _listEquals(other.removedComponentKeys, removedComponentKeys) &&
        _listEquals(other.swapSelections, swapSelections) &&
        _listEquals(other.extraSelections, extraSelections);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(removedComponentKeys),
    Object.hashAll(swapSelections),
    Object.hashAll(extraSelections),
  );
}

class MealCustomizationCartSelection {
  const MealCustomizationCartSelection({
    required this.request,
    required this.snapshot,
    required this.stableIdentityKey,
    required this.summaryLines,
    required this.compactSummary,
    required this.perUnitAdjustmentMinor,
    required this.perUnitLineTotalMinor,
  });

  final MealCustomizationRequest request;
  final MealCustomizationResolvedSnapshot snapshot;
  final String stableIdentityKey;
  final List<String> summaryLines;
  final String compactSummary;
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
      .map((Object? entry) => entry as int)
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

int _compareNormalizedMaps(Map<String, Object?> left, Map<String, Object?> right) {
  final String leftEncoded = jsonEncode(left);
  final String rightEncoded = jsonEncode(right);
  return leftEncoded.compareTo(rightEncoded);
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
    label, kind, componentKey, targetItemProductId,
    itemProductId, quantity, usageCount,
  );
}

enum MealSuggestionActionKind { swap, remove, addExtra }
