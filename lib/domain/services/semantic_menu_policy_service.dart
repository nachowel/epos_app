import '../models/breakfast_rebuild.dart';
import '../models/product.dart';
import '../models/semantic_product_configuration.dart';

class SemanticMenuPolicyService {
  const SemanticMenuPolicyService();

  SemanticMenuValidationResult validateDraft({
    required ProductMenuConfigurationProfile profile,
    required SemanticProductConfigurationDraft configuration,
    required Map<int, Product> productsById,
    required Set<int> setRootProductIds,
    required Set<int> choiceMemberProductIds,
  }) {
    final List<String> errors = <String>[];
    final List<String> warnings = <String>[];
    final Set<int> setItemIds = <int>{};
    final Set<int> extraItemIds = <int>{};
    final Set<int> choiceMemberIds = <int>{};
    final Set<String> groupNames = <String>{};
    final Product? rootProduct = productsById[configuration.productId];

    if (rootProduct == null) {
      errors.add('The selected set product no longer exists.');
    }

    if (profile.hasLegacyFlatConfig && configuration.hasSemanticStructure) {
      errors.add(
        'Remove legacy flat modifiers before saving a semantic set configuration.',
      );
    }
    if (configuration.hasSemanticStructure &&
        choiceMemberProductIds.contains(configuration.productId)) {
      errors.add(
        'This product is already used as a choice option in another set and cannot become a set root.',
      );
    }
    if (configuration.hasSemanticStructure && configuration.setItems.isEmpty) {
      errors.add('Semantic set products must contain at least one set item.');
    }

    for (final SemanticSetItemDraft item in configuration.setItems) {
      final Product? product = productsById[item.itemProductId];
      if (product == null) {
        errors.add('Set items must reference real products.');
        continue;
      }
      if (item.itemProductId == configuration.productId) {
        errors.add('A set product cannot reference itself as a set item.');
      }
      if (item.defaultQuantity <= 0) {
        errors.add('Set item quantity must be greater than zero.');
      }
      if (item.sortOrder < 0) {
        errors.add('Set item sort order cannot be negative.');
      }
      if (!setItemIds.add(item.itemProductId)) {
        errors.add('Set items cannot contain duplicate products.');
      }
      if (setRootProductIds.contains(item.itemProductId)) {
        errors.add('A semantic set root cannot be used as a set item.');
      }
      if (choiceMemberProductIds.contains(item.itemProductId)) {
        errors.add(
          'Products already used as choice members cannot be configured as set items.',
        );
      }
    }

    for (final SemanticChoiceGroupDraft group in configuration.choiceGroups) {
      final String trimmedName = group.name.trim();
      if (trimmedName.isEmpty) {
        errors.add('Choice group name is required.');
      } else if (!groupNames.add(trimmedName.toLowerCase())) {
        errors.add('Choice group names must be unique per product.');
      }
      if (group.minSelect < 0) {
        errors.add('Choice group minimum selection cannot be negative.');
      }
      if (group.maxSelect <= 0) {
        errors.add('Choice group maximum selection must be greater than zero.');
      }
      if (group.maxSelect < group.minSelect) {
        errors.add(
          'Choice group maximum selection must be greater than or equal to minimum selection.',
        );
      }
      if (group.includedQuantity <= 0) {
        errors.add('Choice group included quantity must be greater than zero.');
      }
      if (group.includedQuantity > group.maxSelect) {
        errors.add(
          'Choice group included quantity must be less than or equal to maximum selection.',
        );
      }
      if (group.sortOrder < 0) {
        errors.add('Choice group sort order cannot be negative.');
      }
      if (group.members.isEmpty) {
        errors.add('Choice groups must contain at least one member.');
      }
      if (group.maxSelect > 1) {
        errors.add(
          'This choice group allows more than one selection. POS currently supports one selection per group.',
        );
      }

      final Set<int> memberIds = <int>{};
      for (final SemanticChoiceMemberDraft member in group.members) {
        final Product? product = productsById[member.itemProductId];
        if (product == null) {
          errors.add('Choice members must reference real products.');
          continue;
        }
        if (member.itemProductId == configuration.productId) {
          errors.add('A set product cannot be added as a choice member.');
        }
        if (!memberIds.add(member.itemProductId)) {
          errors.add('Choice groups cannot contain duplicate member products.');
        }
        if (setRootProductIds.contains(member.itemProductId)) {
          errors.add('A semantic set root cannot be used as a choice member.');
        }
        if (setItemIds.contains(member.itemProductId)) {
          errors.add(
            'A product cannot be both a removable set item and a choice member in the same semantic configuration.',
          );
        }
        choiceMemberIds.add(member.itemProductId);
      }
    }

    for (final SemanticExtraItemDraft extra in configuration.extras) {
      final Product? product = productsById[extra.itemProductId];
      if (product == null) {
        errors.add('Extras must reference real products.');
        continue;
      }
      if (extra.itemProductId == configuration.productId) {
        errors.add('A set product cannot be added as an extra.');
      }
      if (extra.sortOrder < 0) {
        errors.add('Extra sort order cannot be negative.');
      }
      if (!extraItemIds.add(extra.itemProductId)) {
        errors.add('Extras cannot contain duplicate products.');
      }
      if (setRootProductIds.contains(extra.itemProductId)) {
        errors.add('A semantic set root cannot be used as an extra.');
      }
      if (setItemIds.contains(extra.itemProductId)) {
        errors.add(
          'A product cannot be both an included item and an extra in the same semantic configuration.',
        );
      }
      if (choiceMemberIds.contains(extra.itemProductId)) {
        errors.add(
          'A product cannot be both a required choice option and an extra in the same semantic configuration.',
        );
      }
    }

    if (configuration.choiceGroups.isNotEmpty &&
        !configuration.choiceGroups.any(
          (SemanticChoiceGroupDraft group) => group.minSelect > 0,
        )) {
      warnings.add(
        'Configured choice groups are all optional. Confirm that this product does not require a mandatory choice.',
      );
    }
    if (configuration.choiceGroups.any(
      (SemanticChoiceGroupDraft group) => group.maxSelect > 1,
    )) {
      warnings.add('POS currently supports one selection per choice group.');
    }

    return SemanticMenuValidationResult(
      errors: List<String>.unmodifiable(errors.toSet().toList(growable: false)),
      warnings: List<String>.unmodifiable(
        warnings.toSet().toList(growable: false),
      ),
    );
  }

  SemanticMenuValidationResult validateRuntime({
    required ProductMenuConfigurationProfile profile,
    required BreakfastSetConfiguration configuration,
  }) {
    final List<String> errors = <String>[];
    final List<String> warnings = <String>[];

    if (profile.hasLegacyFlatConfig && profile.hasSemanticSetConfig) {
      errors.add(
        'This product still has legacy flat modifiers. Remove them before selling it as a semantic bundle.',
      );
    }
    if (configuration.setItems.isEmpty) {
      errors.add('Semantic set products must contain at least one set item.');
    }

    final Set<int> setItemIds = <int>{};
    final Set<int> extraItemIds = <int>{};
    final Set<int> choiceMemberIds = <int>{};
    for (final BreakfastSetItemConfig item in configuration.setItems) {
      if (item.itemProductId == configuration.setRootProductId) {
        errors.add('A set product cannot reference itself as a set item.');
      }
      if (item.defaultQuantity <= 0) {
        errors.add('Set item quantity must be greater than zero.');
      }
      if (!setItemIds.add(item.itemProductId)) {
        errors.add('Set items cannot contain duplicate products.');
      }
    }

    final Set<String> groupNames = <String>{};
    for (final BreakfastChoiceGroupConfig group in configuration.choiceGroups) {
      final String trimmedName = group.groupName.trim();
      if (trimmedName.isEmpty) {
        errors.add('Choice group name is required.');
      } else if (!groupNames.add(trimmedName.toLowerCase())) {
        errors.add('Choice group names must be unique per product.');
      }
      if (group.minSelect < 0) {
        errors.add('Choice group minimum selection cannot be negative.');
      }
      if (group.maxSelect <= 0) {
        errors.add('Choice group maximum selection must be greater than zero.');
      }
      if (group.maxSelect < group.minSelect) {
        errors.add(
          'Choice group maximum selection must be greater than or equal to minimum selection.',
        );
      }
      if (group.includedQuantity <= 0) {
        errors.add('Choice group included quantity must be greater than zero.');
      }
      if (group.includedQuantity > group.maxSelect) {
        errors.add(
          'Choice group included quantity must be less than or equal to maximum selection.',
        );
      }
      if (group.members.isEmpty) {
        errors.add('Choice groups must contain at least one member.');
      }
      if (group.maxSelect > 1) {
        errors.add(
          'This choice group allows more than one selection. POS currently supports one selection per group.',
        );
      }

      final Set<int> memberIds = <int>{};
      for (final BreakfastChoiceGroupMemberConfig member in group.members) {
        if (member.itemProductId == configuration.setRootProductId) {
          errors.add('A set product cannot be added as a choice member.');
        }
        if (!memberIds.add(member.itemProductId)) {
          errors.add('Choice groups cannot contain duplicate member products.');
        }
        if (setItemIds.contains(member.itemProductId)) {
          errors.add(
            'A product cannot be both a removable set item and a choice member in the same semantic configuration.',
          );
        }
        choiceMemberIds.add(member.itemProductId);
      }
    }

    for (final BreakfastExtraItemConfig extra in configuration.extras) {
      if (extra.itemProductId == configuration.setRootProductId) {
        errors.add('A set product cannot be added as an extra.');
      }
      if (extra.sortOrder < 0) {
        errors.add('Extra sort order cannot be negative.');
      }
      if (!extraItemIds.add(extra.itemProductId)) {
        errors.add('Extras cannot contain duplicate products.');
      }
      if (setItemIds.contains(extra.itemProductId)) {
        errors.add(
          'A product cannot be both an included item and an extra in the same semantic configuration.',
        );
      }
      if (choiceMemberIds.contains(extra.itemProductId)) {
        errors.add(
          'A product cannot be both a required choice option and an extra in the same semantic configuration.',
        );
      }
    }

    if (configuration.choiceGroups.isNotEmpty &&
        !configuration.choiceGroups.any(
          (BreakfastChoiceGroupConfig group) => group.minSelect > 0,
        )) {
      warnings.add(
        'Configured choice groups are all optional. Confirm that this product does not require a mandatory choice.',
      );
    }
    if (configuration.choiceGroups.any(
      (BreakfastChoiceGroupConfig group) => group.maxSelect > 1,
    )) {
      warnings.add('POS currently supports one selection per choice group.');
    }

    return SemanticMenuValidationResult(
      errors: List<String>.unmodifiable(errors.toSet().toList(growable: false)),
      warnings: List<String>.unmodifiable(
        warnings.toSet().toList(growable: false),
      ),
    );
  }
}
