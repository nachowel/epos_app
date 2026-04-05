enum MealAdjustmentComponentOptionType { swap }

enum MealAdjustmentPricingRuleType { removeOnly, combo, swap, extra }

enum MealAdjustmentPricingRuleConditionType {
  removedComponent,
  swapToItem,
  extraItem,
}

enum MealAdjustmentHealthStatus { valid, incomplete, invalid }

class MealAdjustmentProfile {
  const MealAdjustmentProfile({
    required this.id,
    required this.name,
    this.description,
    required this.freeSwapLimit,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.components = const <MealAdjustmentComponent>[],
    this.extraOptions = const <MealAdjustmentExtraOption>[],
    this.pricingRules = const <MealAdjustmentPricingRule>[],
  });

  final int id;
  final String name;
  final String? description;
  final int freeSwapLimit;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MealAdjustmentComponent> components;
  final List<MealAdjustmentExtraOption> extraOptions;
  final List<MealAdjustmentPricingRule> pricingRules;

  MealAdjustmentProfile copyWith({
    int? id,
    String? name,
    Object? description = _unsetNullableField,
    int? freeSwapLimit,
    bool? isActive,
    Object? createdAt = _unsetNullableField,
    Object? updatedAt = _unsetNullableField,
    List<MealAdjustmentComponent>? components,
    List<MealAdjustmentExtraOption>? extraOptions,
    List<MealAdjustmentPricingRule>? pricingRules,
  }) {
    return MealAdjustmentProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _unsetNullableField)
          ? this.description
          : description as String?,
      freeSwapLimit: freeSwapLimit ?? this.freeSwapLimit,
      isActive: isActive ?? this.isActive,
      createdAt: identical(createdAt, _unsetNullableField)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _unsetNullableField)
          ? this.updatedAt
          : updatedAt as DateTime?,
      components: components ?? this.components,
      extraOptions: extraOptions ?? this.extraOptions,
      pricingRules: pricingRules ?? this.pricingRules,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealAdjustmentProfile &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.freeSwapLimit == freeSwapLimit &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        _listEquals(other.components, components) &&
        _listEquals(other.extraOptions, extraOptions) &&
        _listEquals(other.pricingRules, pricingRules);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    freeSwapLimit,
    isActive,
    createdAt,
    updatedAt,
    Object.hashAll(components),
    Object.hashAll(extraOptions),
    Object.hashAll(pricingRules),
  );
}

class MealAdjustmentProfileDraft {
  const MealAdjustmentProfileDraft({
    this.id,
    required this.name,
    this.description,
    required this.freeSwapLimit,
    required this.isActive,
    this.components = const <MealAdjustmentComponentDraft>[],
    this.extraOptions = const <MealAdjustmentExtraOptionDraft>[],
    this.pricingRules = const <MealAdjustmentPricingRuleDraft>[],
  });

  final int? id;
  final String name;
  final String? description;
  final int freeSwapLimit;
  final bool isActive;
  final List<MealAdjustmentComponentDraft> components;
  final List<MealAdjustmentExtraOptionDraft> extraOptions;
  final List<MealAdjustmentPricingRuleDraft> pricingRules;

  MealAdjustmentProfileDraft copyWith({
    Object? id = _unsetNullableField,
    String? name,
    Object? description = _unsetNullableField,
    int? freeSwapLimit,
    bool? isActive,
    List<MealAdjustmentComponentDraft>? components,
    List<MealAdjustmentExtraOptionDraft>? extraOptions,
    List<MealAdjustmentPricingRuleDraft>? pricingRules,
  }) {
    return MealAdjustmentProfileDraft(
      id: identical(id, _unsetNullableField) ? this.id : id as int?,
      name: name ?? this.name,
      description: identical(description, _unsetNullableField)
          ? this.description
          : description as String?,
      freeSwapLimit: freeSwapLimit ?? this.freeSwapLimit,
      isActive: isActive ?? this.isActive,
      components: components ?? this.components,
      extraOptions: extraOptions ?? this.extraOptions,
      pricingRules: pricingRules ?? this.pricingRules,
    );
  }

  /// Creates a duplicate draft with no id and a modified name.
  MealAdjustmentProfileDraft duplicate({String? nameSuffix}) {
    final String suffix = nameSuffix ?? ' (copy)';
    return copyWith(
      id: null,
      name: '$name$suffix',
    );
  }

  MealAdjustmentProfile toRuntimeProfile({required int profileId}) {
    return MealAdjustmentProfile(
      id: profileId,
      name: name,
      description: description,
      freeSwapLimit: freeSwapLimit,
      isActive: isActive,
      components: components
          .asMap()
          .entries
          .map((MapEntry<int, MealAdjustmentComponentDraft> entry) {
            return entry.value.toRuntimeComponent(
              profileId: profileId,
              generatedComponentId: entry.value.id ?? -(entry.key + 1),
            );
          })
          .toList(growable: false),
      extraOptions: extraOptions
          .asMap()
          .entries
          .map((MapEntry<int, MealAdjustmentExtraOptionDraft> entry) {
            return entry.value.toRuntimeExtraOption(
              profileId: profileId,
              generatedExtraId: entry.value.id ?? -(entry.key + 1),
            );
          })
          .toList(growable: false),
      pricingRules: pricingRules
          .asMap()
          .entries
          .map((MapEntry<int, MealAdjustmentPricingRuleDraft> entry) {
            return entry.value.toRuntimeRule(
              profileId: profileId,
              generatedRuleId: entry.value.id ?? -(entry.key + 1),
            );
          })
          .toList(growable: false),
    );
  }
}

class MealAdjustmentComponent {
  const MealAdjustmentComponent({
    required this.id,
    required this.profileId,
    required this.componentKey,
    required this.displayName,
    required this.defaultItemProductId,
    required this.quantity,
    required this.canRemove,
    required this.sortOrder,
    required this.isActive,
    this.swapOptions = const <MealAdjustmentComponentOption>[],
  });

  final int id;
  final int profileId;
  final String componentKey;
  final String displayName;
  final int defaultItemProductId;
  final int quantity;
  final bool canRemove;
  final int sortOrder;
  final bool isActive;
  final List<MealAdjustmentComponentOption> swapOptions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealAdjustmentComponent &&
        other.id == id &&
        other.profileId == profileId &&
        other.componentKey == componentKey &&
        other.displayName == displayName &&
        other.defaultItemProductId == defaultItemProductId &&
        other.quantity == quantity &&
        other.canRemove == canRemove &&
        other.sortOrder == sortOrder &&
        other.isActive == isActive &&
        _listEquals(other.swapOptions, swapOptions);
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    componentKey,
    displayName,
    defaultItemProductId,
    quantity,
    canRemove,
    sortOrder,
    isActive,
    Object.hashAll(swapOptions),
  );
}

class MealAdjustmentComponentDraft {
  const MealAdjustmentComponentDraft({
    this.id,
    required this.componentKey,
    required this.displayName,
    required this.defaultItemProductId,
    required this.quantity,
    required this.canRemove,
    required this.sortOrder,
    required this.isActive,
    this.swapOptions = const <MealAdjustmentComponentOptionDraft>[],
  });

  final int? id;
  final String componentKey;
  final String displayName;
  final int defaultItemProductId;
  final int quantity;
  final bool canRemove;
  final int sortOrder;
  final bool isActive;
  final List<MealAdjustmentComponentOptionDraft> swapOptions;

  MealAdjustmentComponent toRuntimeComponent({
    required int profileId,
    required int generatedComponentId,
  }) {
    return MealAdjustmentComponent(
      id: generatedComponentId,
      profileId: profileId,
      componentKey: componentKey,
      displayName: displayName,
      defaultItemProductId: defaultItemProductId,
      quantity: quantity,
      canRemove: canRemove,
      sortOrder: sortOrder,
      isActive: isActive,
      swapOptions: swapOptions
          .asMap()
          .entries
          .map((MapEntry<int, MealAdjustmentComponentOptionDraft> entry) {
            return entry.value.toRuntimeOption(
              profileComponentId: generatedComponentId,
              generatedOptionId: entry.value.id ?? -(entry.key + 1),
            );
          })
          .toList(growable: false),
    );
  }
}

class MealAdjustmentComponentOption {
  const MealAdjustmentComponentOption({
    required this.id,
    required this.profileComponentId,
    required this.optionItemProductId,
    this.type = MealAdjustmentComponentOptionType.swap,
    this.fixedPriceDeltaMinor,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final int profileComponentId;
  final int optionItemProductId;
  final MealAdjustmentComponentOptionType type;
  final int? fixedPriceDeltaMinor;
  final int sortOrder;
  final bool isActive;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealAdjustmentComponentOption &&
        other.id == id &&
        other.profileComponentId == profileComponentId &&
        other.optionItemProductId == optionItemProductId &&
        other.type == type &&
        other.fixedPriceDeltaMinor == fixedPriceDeltaMinor &&
        other.sortOrder == sortOrder &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileComponentId,
    optionItemProductId,
    type,
    fixedPriceDeltaMinor,
    sortOrder,
    isActive,
  );
}

class MealAdjustmentComponentOptionDraft {
  const MealAdjustmentComponentOptionDraft({
    this.id,
    required this.optionItemProductId,
    this.type = MealAdjustmentComponentOptionType.swap,
    this.fixedPriceDeltaMinor,
    required this.sortOrder,
    required this.isActive,
  });

  final int? id;
  final int optionItemProductId;
  final MealAdjustmentComponentOptionType type;
  final int? fixedPriceDeltaMinor;
  final int sortOrder;
  final bool isActive;

  MealAdjustmentComponentOption toRuntimeOption({
    required int profileComponentId,
    required int generatedOptionId,
  }) {
    return MealAdjustmentComponentOption(
      id: generatedOptionId,
      profileComponentId: profileComponentId,
      optionItemProductId: optionItemProductId,
      type: type,
      fixedPriceDeltaMinor: fixedPriceDeltaMinor,
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }
}

class MealAdjustmentExtraOption {
  const MealAdjustmentExtraOption({
    required this.id,
    required this.profileId,
    required this.itemProductId,
    required this.fixedPriceDeltaMinor,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final int profileId;
  final int itemProductId;
  final int fixedPriceDeltaMinor;
  final int sortOrder;
  final bool isActive;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealAdjustmentExtraOption &&
        other.id == id &&
        other.profileId == profileId &&
        other.itemProductId == itemProductId &&
        other.fixedPriceDeltaMinor == fixedPriceDeltaMinor &&
        other.sortOrder == sortOrder &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    itemProductId,
    fixedPriceDeltaMinor,
    sortOrder,
    isActive,
  );
}

class MealAdjustmentExtraOptionDraft {
  const MealAdjustmentExtraOptionDraft({
    this.id,
    required this.itemProductId,
    required this.fixedPriceDeltaMinor,
    required this.sortOrder,
    required this.isActive,
  });

  final int? id;
  final int itemProductId;
  final int fixedPriceDeltaMinor;
  final int sortOrder;
  final bool isActive;

  MealAdjustmentExtraOption toRuntimeExtraOption({
    required int profileId,
    required int generatedExtraId,
  }) {
    return MealAdjustmentExtraOption(
      id: generatedExtraId,
      profileId: profileId,
      itemProductId: itemProductId,
      fixedPriceDeltaMinor: fixedPriceDeltaMinor,
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }
}

class MealAdjustmentPricingRule {
  const MealAdjustmentPricingRule({
    required this.id,
    required this.profileId,
    required this.name,
    required this.ruleType,
    required this.priceDeltaMinor,
    required this.priority,
    required this.isActive,
    this.conditions = const <MealAdjustmentPricingRuleCondition>[],
  });

  final int id;
  final int profileId;
  final String name;
  final MealAdjustmentPricingRuleType ruleType;
  final int priceDeltaMinor;
  final int priority;
  final bool isActive;
  final List<MealAdjustmentPricingRuleCondition> conditions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealAdjustmentPricingRule &&
        other.id == id &&
        other.profileId == profileId &&
        other.name == name &&
        other.ruleType == ruleType &&
        other.priceDeltaMinor == priceDeltaMinor &&
        other.priority == priority &&
        other.isActive == isActive &&
        _listEquals(other.conditions, conditions);
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    name,
    ruleType,
    priceDeltaMinor,
    priority,
    isActive,
    Object.hashAll(conditions),
  );
}

class MealAdjustmentPricingRuleDraft {
  const MealAdjustmentPricingRuleDraft({
    this.id,
    required this.name,
    required this.ruleType,
    required this.priceDeltaMinor,
    required this.priority,
    required this.isActive,
    this.conditions = const <MealAdjustmentPricingRuleConditionDraft>[],
  });

  final int? id;
  final String name;
  final MealAdjustmentPricingRuleType ruleType;
  final int priceDeltaMinor;
  final int priority;
  final bool isActive;
  final List<MealAdjustmentPricingRuleConditionDraft> conditions;

  String get semanticMeaningKey {
    final List<String> conditionKeys =
        conditions
            .map((MealAdjustmentPricingRuleConditionDraft condition) {
              return condition.semanticMeaningKey;
            })
            .toList(growable: false)
          ..sort();
    return '${ruleType.name}|${conditionKeys.join('&')}';
  }

  int get specificityScore {
    final int quantityWeight = conditions.fold<int>(
      0,
      (int total, MealAdjustmentPricingRuleConditionDraft condition) =>
          total + condition.quantity,
    );
    return (conditions.length * 1000) + quantityWeight;
  }

  MealAdjustmentPricingRule toRuntimeRule({
    required int profileId,
    required int generatedRuleId,
  }) {
    return MealAdjustmentPricingRule(
      id: generatedRuleId,
      profileId: profileId,
      name: name,
      ruleType: ruleType,
      priceDeltaMinor: priceDeltaMinor,
      priority: priority,
      isActive: isActive,
      conditions: conditions
          .asMap()
          .entries
          .map((MapEntry<int, MealAdjustmentPricingRuleConditionDraft> entry) {
            return entry.value.toRuntimeCondition(
              ruleId: generatedRuleId,
              generatedConditionId: entry.value.id ?? -(entry.key + 1),
            );
          })
          .toList(growable: false),
    );
  }
}

class MealAdjustmentPricingRuleCondition {
  const MealAdjustmentPricingRuleCondition({
    required this.id,
    required this.ruleId,
    required this.conditionType,
    this.componentKey,
    this.itemProductId,
    required this.quantity,
  });

  final int id;
  final int ruleId;
  final MealAdjustmentPricingRuleConditionType conditionType;
  final String? componentKey;
  final int? itemProductId;
  final int quantity;

  bool get isStructurallyValid {
    final bool hasComponentKey =
        componentKey != null && componentKey!.trim().isNotEmpty;
    switch (conditionType) {
      case MealAdjustmentPricingRuleConditionType.removedComponent:
        return hasComponentKey && itemProductId == null && quantity > 0;
      case MealAdjustmentPricingRuleConditionType.swapToItem:
        return hasComponentKey && itemProductId != null && quantity > 0;
      case MealAdjustmentPricingRuleConditionType.extraItem:
        return !hasComponentKey && itemProductId != null && quantity > 0;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MealAdjustmentPricingRuleCondition &&
        other.id == id &&
        other.ruleId == ruleId &&
        other.conditionType == conditionType &&
        other.componentKey == componentKey &&
        other.itemProductId == itemProductId &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(
    id,
    ruleId,
    conditionType,
    componentKey,
    itemProductId,
    quantity,
  );
}

class MealAdjustmentPricingRuleConditionDraft {
  const MealAdjustmentPricingRuleConditionDraft({
    this.id,
    required this.conditionType,
    this.componentKey,
    this.itemProductId,
    required this.quantity,
  });

  final int? id;
  final MealAdjustmentPricingRuleConditionType conditionType;
  final String? componentKey;
  final int? itemProductId;
  final int quantity;

  String get semanticMeaningKey {
    return '${conditionType.name}|${componentKey ?? ''}|${itemProductId ?? ''}|$quantity';
  }

  bool get isStructurallyValid {
    final bool hasComponentKey =
        componentKey != null && componentKey!.trim().isNotEmpty;
    switch (conditionType) {
      case MealAdjustmentPricingRuleConditionType.removedComponent:
        return hasComponentKey && itemProductId == null && quantity > 0;
      case MealAdjustmentPricingRuleConditionType.swapToItem:
        return hasComponentKey && itemProductId != null && quantity > 0;
      case MealAdjustmentPricingRuleConditionType.extraItem:
        return !hasComponentKey && itemProductId != null && quantity > 0;
    }
  }

  MealAdjustmentPricingRuleCondition toRuntimeCondition({
    required int ruleId,
    required int generatedConditionId,
  }) {
    return MealAdjustmentPricingRuleCondition(
      id: generatedConditionId,
      ruleId: ruleId,
      conditionType: conditionType,
      componentKey: componentKey,
      itemProductId: itemProductId,
      quantity: quantity,
    );
  }
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
