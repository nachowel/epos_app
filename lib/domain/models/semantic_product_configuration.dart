import 'product.dart';
import 'breakfast_extra_preset.dart';

enum ProductMenuConfigType { standard, legacyFlat, semanticSet, mixed }

class ProductMenuConfigurationProfile {
  const ProductMenuConfigurationProfile({
    required this.productId,
    required this.flatModifierCount,
    required this.setItemCount,
    required this.choiceGroupCount,
    required this.choiceMemberCount,
    this.extraPoolCount = 0,
  });

  final int productId;
  final int flatModifierCount;
  final int setItemCount;
  final int choiceGroupCount;
  final int choiceMemberCount;
  final int extraPoolCount;

  bool get hasLegacyFlatConfig => flatModifierCount > 0;
  bool get hasSemanticSetConfig =>
      setItemCount > 0 ||
      choiceGroupCount > 0 ||
      choiceMemberCount > 0 ||
      extraPoolCount > 0;

  ProductMenuConfigType get type {
    if (hasLegacyFlatConfig && hasSemanticSetConfig) {
      return ProductMenuConfigType.mixed;
    }
    if (hasSemanticSetConfig) {
      return ProductMenuConfigType.semanticSet;
    }
    if (hasLegacyFlatConfig) {
      return ProductMenuConfigType.legacyFlat;
    }
    return ProductMenuConfigType.standard;
  }
}

class SemanticProductConfigurationDraft {
  const SemanticProductConfigurationDraft({
    required this.productId,
    required this.setItems,
    required this.choiceGroups,
    this.extras = const <SemanticExtraItemDraft>[],
  });

  final int productId;
  final List<SemanticSetItemDraft> setItems;
  final List<SemanticChoiceGroupDraft> choiceGroups;
  final List<SemanticExtraItemDraft> extras;

  bool get hasSemanticStructure =>
      setItems.isNotEmpty || choiceGroups.isNotEmpty || extras.isNotEmpty;
}

class SemanticSetItemDraft {
  const SemanticSetItemDraft({
    this.id,
    required this.itemProductId,
    required this.itemName,
    required this.defaultQuantity,
    required this.isRemovable,
    required this.sortOrder,
  });

  final int? id;
  final int itemProductId;
  final String itemName;
  final int defaultQuantity;
  final bool isRemovable;
  final int sortOrder;

  SemanticSetItemDraft copyWith({
    Object? id = _unsetNullableField,
    int? itemProductId,
    String? itemName,
    int? defaultQuantity,
    bool? isRemovable,
    int? sortOrder,
  }) {
    return SemanticSetItemDraft(
      id: identical(id, _unsetNullableField) ? this.id : id as int?,
      itemProductId: itemProductId ?? this.itemProductId,
      itemName: itemName ?? this.itemName,
      defaultQuantity: defaultQuantity ?? this.defaultQuantity,
      isRemovable: isRemovable ?? this.isRemovable,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class SemanticChoiceGroupDraft {
  const SemanticChoiceGroupDraft({
    this.id,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.includedQuantity,
    required this.sortOrder,
    required this.members,
    this.explicitNoneLabel,
  });

  final int? id;
  final String name;
  final int minSelect;
  final int maxSelect;
  final int includedQuantity;
  final int sortOrder;
  final List<SemanticChoiceMemberDraft> members;
  final String? explicitNoneLabel;

  SemanticChoiceGroupDraft copyWith({
    Object? id = _unsetNullableField,
    String? name,
    int? minSelect,
    int? maxSelect,
    int? includedQuantity,
    int? sortOrder,
    List<SemanticChoiceMemberDraft>? members,
    Object? explicitNoneLabel = _unsetNullableField,
  }) {
    return SemanticChoiceGroupDraft(
      id: identical(id, _unsetNullableField) ? this.id : id as int?,
      name: name ?? this.name,
      minSelect: minSelect ?? this.minSelect,
      maxSelect: maxSelect ?? this.maxSelect,
      includedQuantity: includedQuantity ?? this.includedQuantity,
      sortOrder: sortOrder ?? this.sortOrder,
      members: members ?? this.members,
      explicitNoneLabel: identical(explicitNoneLabel, _unsetNullableField)
          ? this.explicitNoneLabel
          : explicitNoneLabel as String?,
    );
  }
}

class SemanticChoiceMemberDraft {
  const SemanticChoiceMemberDraft({
    this.id,
    required this.itemProductId,
    required this.itemName,
    required this.position,
  });

  final int? id;
  final int itemProductId;
  final String itemName;
  final int position;

  SemanticChoiceMemberDraft copyWith({
    Object? id = _unsetNullableField,
    int? itemProductId,
    String? itemName,
    int? position,
  }) {
    return SemanticChoiceMemberDraft(
      id: identical(id, _unsetNullableField) ? this.id : id as int?,
      itemProductId: itemProductId ?? this.itemProductId,
      itemName: itemName ?? this.itemName,
      position: position ?? this.position,
    );
  }
}

class SemanticExtraItemDraft {
  const SemanticExtraItemDraft({
    this.id,
    required this.itemProductId,
    required this.itemName,
    required this.sortOrder,
  });

  final int? id;
  final int itemProductId;
  final String itemName;
  final int sortOrder;

  SemanticExtraItemDraft copyWith({
    Object? id = _unsetNullableField,
    int? itemProductId,
    String? itemName,
    int? sortOrder,
  }) {
    return SemanticExtraItemDraft(
      id: identical(id, _unsetNullableField) ? this.id : id as int?,
      itemProductId: itemProductId ?? this.itemProductId,
      itemName: itemName ?? this.itemName,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class SemanticProductConfigurationEditorData {
  const SemanticProductConfigurationEditorData({
    required this.rootProduct,
    required this.profile,
    required this.availableProducts,
    required this.availableSetItemProducts,
    required this.extraPresets,
    required this.configuration,
    required this.validationResult,
  });

  final Product rootProduct;
  final ProductMenuConfigurationProfile profile;
  final List<Product> availableProducts;
  final List<Product> availableSetItemProducts;
  final List<BreakfastExtraPreset> extraPresets;
  final SemanticProductConfigurationDraft configuration;
  final SemanticMenuValidationResult validationResult;

  SemanticProductConfigurationEditorData copyWith({
    Product? rootProduct,
    ProductMenuConfigurationProfile? profile,
    List<Product>? availableProducts,
    List<Product>? availableSetItemProducts,
    List<BreakfastExtraPreset>? extraPresets,
    SemanticProductConfigurationDraft? configuration,
    SemanticMenuValidationResult? validationResult,
  }) {
    return SemanticProductConfigurationEditorData(
      rootProduct: rootProduct ?? this.rootProduct,
      profile: profile ?? this.profile,
      availableProducts: availableProducts ?? this.availableProducts,
      availableSetItemProducts:
          availableSetItemProducts ?? this.availableSetItemProducts,
      extraPresets: extraPresets ?? this.extraPresets,
      configuration: configuration ?? this.configuration,
      validationResult: validationResult ?? this.validationResult,
    );
  }
}

class SemanticMenuValidationResult {
  const SemanticMenuValidationResult({
    this.errors = const <String>[],
    this.warnings = const <String>[],
  });

  final List<String> errors;
  final List<String> warnings;

  bool get canSave => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

class SemanticProductConfigurationValidationException implements Exception {
  const SemanticProductConfigurationValidationException(this.errors);

  final List<String> errors;

  String get message => errors.join('\n');

  @override
  String toString() => message;
}

const Object _unsetNullableField = Object();
