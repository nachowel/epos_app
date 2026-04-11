import '../models/meal_adjustment_profile.dart';
import '../repositories/meal_adjustment_profile_repository.dart';

enum MealAdjustmentValidationSection {
  profile,
  components,
  swaps,
  extras,
  rules,
  references,
  assignments,
  products,
}

enum MealAdjustmentValidationIssueCode {
  negativeFreeSwapLimit,
  negativeSandwichSurcharge,
  negativeBaguetteSurcharge,
  sandwichSauceItemMissing,
  sandwichSauceItemInactive,
  sandwichSauceItemMustBelongToSaucesCategory,
  activeProfileMissingComponents,
  sandwichProfileFreeSwapLimitMustBeZero,
  sandwichProfileComponentsNotSupported,
  sandwichProfilePricingRulesNotSupported,
  missingComponentKey,
  missingComponentDisplayName,
  duplicateComponentKey,
  invalidComponentQuantity,
  defaultItemMissing,
  defaultItemInactive,
  swapItemMissing,
  swapItemInactive,
  extraItemMissing,
  extraItemInactive,
  ruleItemMissing,
  ruleItemInactive,
  swapOptionMatchesDefaultItem,
  duplicateSwapOption,
  duplicateExtraOption,
  invalidExtraPriceDelta,
  missingRuleName,
  invalidRuleCondition,
  invalidExtraRulePriceDelta,
  invalidRemoveOnlyRulePriceDelta,
  duplicateRuleMeaning,
  conflictingRuleMeaning,
  assignedProductMissing,
  assignedProfileMissing,
  breakfastProductAssignmentBlocked,
}

class MealAdjustmentValidationIssue {
  const MealAdjustmentValidationIssue({
    required this.code,
    required this.section,
    this.detail,
    this.componentKey,
    this.itemProductId,
    this.productId,
    this.ruleId,
    this.relatedRuleIds = const <int>[],
  });

  final MealAdjustmentValidationIssueCode code;
  final MealAdjustmentValidationSection section;
  final String? detail;
  final String? componentKey;
  final int? itemProductId;
  final int? productId;
  final int? ruleId;
  final List<int> relatedRuleIds;

  String get dedupeKey {
    return [
      code.name,
      section.name,
      detail ?? '',
      componentKey ?? '',
      '${itemProductId ?? ''}',
      '${productId ?? ''}',
      '${ruleId ?? ''}',
      relatedRuleIds.join(','),
    ].join('|');
  }

  String get message {
    switch (code) {
      case MealAdjustmentValidationIssueCode.negativeFreeSwapLimit:
        return 'Free swap limit cannot be negative.';
      case MealAdjustmentValidationIssueCode.negativeSandwichSurcharge:
        return 'Sandwich surcharge cannot be negative.';
      case MealAdjustmentValidationIssueCode.negativeBaguetteSurcharge:
        return 'Baguette surcharge cannot be negative.';
      case MealAdjustmentValidationIssueCode.sandwichSauceItemMissing:
        return 'Sandwich sauce item ${itemProductId ?? 'unknown'} is missing.';
      case MealAdjustmentValidationIssueCode.sandwichSauceItemInactive:
        return 'Sandwich sauce item ${itemProductId ?? 'unknown'} is inactive.';
      case MealAdjustmentValidationIssueCode
          .sandwichSauceItemMustBelongToSaucesCategory:
        return 'Sandwich sauce item ${itemProductId ?? 'unknown'} must belong to the Sauces category.';
      case MealAdjustmentValidationIssueCode.activeProfileMissingComponents:
        return 'An active profile must contain at least one component.';
      case MealAdjustmentValidationIssueCode
          .sandwichProfileFreeSwapLimitMustBeZero:
        return 'Sandwich profiles do not use free swaps. Set the free swap limit to 0.';
      case MealAdjustmentValidationIssueCode
          .sandwichProfileComponentsNotSupported:
        return 'Sandwich profiles use automatic bread, sauce, and toast choices. Components are not supported.';
      case MealAdjustmentValidationIssueCode
          .sandwichProfilePricingRulesNotSupported:
        return 'Sandwich profiles use fixed bread surcharges. Pricing rules are not supported.';
      case MealAdjustmentValidationIssueCode.missingComponentKey:
        return 'Component key is required.';
      case MealAdjustmentValidationIssueCode.missingComponentDisplayName:
        return 'Component display name is required.';
      case MealAdjustmentValidationIssueCode.duplicateComponentKey:
        return 'Component keys must be unique. Duplicate: ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.invalidComponentQuantity:
        return 'Component quantity must be greater than zero for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.defaultItemMissing:
        if (itemProductId == null || itemProductId! <= 0) {
          return 'Default product is required for ${componentKey ?? 'this component'}.';
        }
        return 'Default item ${itemProductId ?? 'unknown'} is missing for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.defaultItemInactive:
        return 'Default product ${itemProductId ?? 'unknown'} is inactive for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.swapItemMissing:
        if (itemProductId == null || itemProductId! <= 0) {
          return 'Swap option product is required for ${componentKey ?? 'this component'}.';
        }
        return 'Swap item ${itemProductId ?? 'unknown'} is missing for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.swapItemInactive:
        return 'Swap product ${itemProductId ?? 'unknown'} is inactive for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.extraItemMissing:
        return 'Add-in item ${itemProductId ?? 'unknown'} is missing.';
      case MealAdjustmentValidationIssueCode.extraItemInactive:
        return 'Add-in item ${itemProductId ?? 'unknown'} is inactive.';
      case MealAdjustmentValidationIssueCode.ruleItemMissing:
        return 'Pricing rule item ${itemProductId ?? 'unknown'} is missing.';
      case MealAdjustmentValidationIssueCode.ruleItemInactive:
        return 'Pricing rule item ${itemProductId ?? 'unknown'} is inactive.';
      case MealAdjustmentValidationIssueCode.swapOptionMatchesDefaultItem:
        return 'Swap target cannot be the same as the default item for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.duplicateSwapOption:
        return 'Swap options cannot contain duplicate products for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.duplicateExtraOption:
        return 'Add-ins cannot contain duplicate products.';
      case MealAdjustmentValidationIssueCode.invalidExtraPriceDelta:
        return 'Add-ins cannot use negative prices.';
      case MealAdjustmentValidationIssueCode.missingRuleName:
        return 'Pricing rule name is required.';
      case MealAdjustmentValidationIssueCode.invalidRuleCondition:
        return detail == null || detail!.trim().isEmpty
            ? 'Pricing rule condition is structurally invalid.'
            : 'Pricing rule condition is invalid. $detail';
      case MealAdjustmentValidationIssueCode.invalidExtraRulePriceDelta:
        return 'Add-in pricing rules cannot use negative price deltas.';
      case MealAdjustmentValidationIssueCode.invalidRemoveOnlyRulePriceDelta:
        return 'Remove-only pricing rules cannot use positive price deltas.';
      case MealAdjustmentValidationIssueCode.duplicateRuleMeaning:
        return 'Pricing rules cannot duplicate the same semantic meaning.';
      case MealAdjustmentValidationIssueCode.conflictingRuleMeaning:
        return 'Pricing rules cannot conflict on the same semantic meaning.';
      case MealAdjustmentValidationIssueCode.assignedProductMissing:
        return 'Assigned product ${productId ?? 'unknown'} was not found.';
      case MealAdjustmentValidationIssueCode.assignedProfileMissing:
        return 'Assigned meal-adjustment profile ${detail ?? 'unknown'} was not found.';
      case MealAdjustmentValidationIssueCode.breakfastProductAssignmentBlocked:
        return detail == null || detail!.trim().isEmpty
            ? 'Breakfast semantic root products cannot carry a meal-adjustment profile.'
            : detail!;
    }
  }
}

class MealAdjustmentValidationResult {
  const MealAdjustmentValidationResult({
    this.blockingErrors = const <MealAdjustmentValidationIssue>[],
    this.warnings = const <MealAdjustmentValidationIssue>[],
  });

  final List<MealAdjustmentValidationIssue> blockingErrors;
  final List<MealAdjustmentValidationIssue> warnings;

  bool get canSave => blockingErrors.isEmpty;
  bool get isValid => canSave;

  Set<MealAdjustmentValidationSection> get affectedSections =>
      <MealAdjustmentValidationSection>{
        ...blockingErrors.map(
          (MealAdjustmentValidationIssue issue) => issue.section,
        ),
        ...warnings.map((MealAdjustmentValidationIssue issue) => issue.section),
      };

  MealAdjustmentHealthStatus get healthStatus {
    if (blockingErrors.isNotEmpty) {
      return MealAdjustmentHealthStatus.invalid;
    }
    if (warnings.isNotEmpty) {
      return MealAdjustmentHealthStatus.incomplete;
    }
    return MealAdjustmentHealthStatus.valid;
  }

  String get message {
    final Iterable<String> lines = blockingErrors
        .map((MealAdjustmentValidationIssue issue) => issue.message)
        .followedBy(
          warnings.map((MealAdjustmentValidationIssue issue) => issue.message),
        );
    return lines.join('\n');
  }
}

class MealAdjustmentProfileValidationException implements Exception {
  const MealAdjustmentProfileValidationException(this.validationResult);

  final MealAdjustmentValidationResult validationResult;

  String get message => validationResult.message;

  @override
  String toString() => message;
}

class MealAdjustmentBrokenReference {
  const MealAdjustmentBrokenReference({
    required this.section,
    required this.itemProductId,
    required this.isMissing,
    required this.isInactive,
    this.componentKey,
    this.ruleId,
  });

  final MealAdjustmentValidationSection section;
  final int itemProductId;
  final bool isMissing;
  final bool isInactive;
  final String? componentKey;
  final int? ruleId;
}

class MealAdjustmentConflictingRule {
  const MealAdjustmentConflictingRule({
    required this.ruleIds,
    required this.semanticMeaningKey,
  });

  final List<int> ruleIds;
  final String semanticMeaningKey;
}

class MealAdjustmentProfileHealthSummary {
  const MealAdjustmentProfileHealthSummary({
    required this.profileId,
    required this.healthStatus,
    required this.validationResult,
    this.brokenReferences = const <MealAdjustmentBrokenReference>[],
    this.conflictingRules = const <MealAdjustmentConflictingRule>[],
    this.inactiveItems = const <int>[],
    this.affectedProducts = const <MealAdjustmentProductSummary>[],
    required this.headline,
    required this.body,
  });

  final int? profileId;
  final MealAdjustmentHealthStatus healthStatus;
  final MealAdjustmentValidationResult validationResult;
  final List<MealAdjustmentBrokenReference> brokenReferences;
  final List<MealAdjustmentConflictingRule> conflictingRules;
  final List<int> inactiveItems;
  final List<MealAdjustmentProductSummary> affectedProducts;
  final String headline;
  final String body;
}

class MealAdjustmentProfileValidationService {
  const MealAdjustmentProfileValidationService({
    required MealAdjustmentProfileRepository repository,
  }) : _repository = repository;

  final MealAdjustmentProfileRepository _repository;

  Future<MealAdjustmentValidationResult> validateDraft(
    MealAdjustmentProfileDraft draft,
  ) async {
    final _DraftValidationArtifacts artifacts = await _buildDraftArtifacts(
      draft,
    );
    return artifacts.validationResult;
  }

  Future<MealAdjustmentValidationResult> validateProductAssignment({
    required int productId,
    int? profileId,
  }) async {
    if (profileId == null) {
      return const MealAdjustmentValidationResult();
    }

    final List<MealAdjustmentValidationIssue> blockingErrors =
        <MealAdjustmentValidationIssue>[];
    final Map<int, MealAdjustmentProductSummary> productsById =
        await _repository.loadProductSummariesByIds(<int>[productId]);
    final MealAdjustmentProductSummary? product = productsById[productId];
    if (product == null) {
      return MealAdjustmentValidationResult(
        blockingErrors: <MealAdjustmentValidationIssue>[
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.assignedProductMissing,
            section: MealAdjustmentValidationSection.assignments,
            productId: productId,
          ),
        ],
      );
    }

    final MealAdjustmentProfile? profile = await _repository.getProfileById(
      profileId,
    );
    if (profile == null) {
      blockingErrors.add(
        MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode.assignedProfileMissing,
          section: MealAdjustmentValidationSection.assignments,
          productId: productId,
          detail: '$profileId',
        ),
      );
    }

    final Set<int> breakfastRootIds = await _repository
        .loadBreakfastSemanticRootProductIds(<int>[productId]);
    if (breakfastRootIds.contains(productId)) {
      blockingErrors.add(
        MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode
              .breakfastProductAssignmentBlocked,
          section: MealAdjustmentValidationSection.assignments,
          productId: productId,
          detail: _buildBreakfastAssignmentConflictMessage(
            productName: product.name,
            profileName: profile?.name,
          ),
        ),
      );
    }

    return MealAdjustmentValidationResult(blockingErrors: blockingErrors);
  }

  Future<MealAdjustmentProfileHealthSummary> computeHealthSummary(
    MealAdjustmentProfileDraft draft,
  ) async {
    final _DraftValidationArtifacts artifacts = await _buildDraftArtifacts(
      draft,
    );
    final MealAdjustmentHealthStatus healthStatus =
        artifacts.validationResult.healthStatus;
    final int blockingCount = artifacts.validationResult.blockingErrors.length;

    return MealAdjustmentProfileHealthSummary(
      profileId: draft.id,
      healthStatus: healthStatus,
      validationResult: artifacts.validationResult,
      brokenReferences: artifacts.brokenReferences,
      conflictingRules: artifacts.conflictingRules,
      inactiveItems: artifacts.inactiveItems,
      affectedProducts: artifacts.assignedProducts,
      headline: _buildHeadline(
        healthStatus: healthStatus,
        blockingCount: blockingCount,
        affectedProductCount: artifacts.assignedProducts.length,
      ),
      body: _buildBody(
        healthStatus: healthStatus,
        brokenReferenceCount: artifacts.brokenReferences.length,
        conflictingRuleCount: artifacts.conflictingRules.length,
        breakfastConflictCount: artifacts.breakfastAssignedProducts.length,
        affectedProductCount: artifacts.assignedProducts.length,
      ),
    );
  }

  Future<_DraftValidationArtifacts> _buildDraftArtifacts(
    MealAdjustmentProfileDraft draft,
  ) async {
    final List<MealAdjustmentValidationIssue> blockingErrors =
        <MealAdjustmentValidationIssue>[];
    final List<MealAdjustmentValidationIssue> warnings =
        <MealAdjustmentValidationIssue>[];
    final List<MealAdjustmentProductSummary> assignedProducts =
        await _loadAssignedProducts(draft);
    final Set<int> breakfastAssignedRootProductIds =
        draft.id == null || assignedProducts.isEmpty
        ? const <int>{}
        : await _repository.loadBreakfastSemanticRootProductIds(
            assignedProducts.map(
              (MealAdjustmentProductSummary product) => product.id,
            ),
          );
    final _ReferenceResolution references = await _loadReferenceResolution(
      draft,
    );

    if (draft.freeSwapLimit < 0) {
      blockingErrors.add(
        const MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode.negativeFreeSwapLimit,
          section: MealAdjustmentValidationSection.profile,
        ),
      );
    }
    if (draft.sandwichSettings.sandwichSurchargeMinor < 0) {
      blockingErrors.add(
        const MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode.negativeSandwichSurcharge,
          section: MealAdjustmentValidationSection.profile,
        ),
      );
    }
    if (draft.sandwichSettings.baguetteSurchargeMinor < 0) {
      blockingErrors.add(
        const MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode.negativeBaguetteSurcharge,
          section: MealAdjustmentValidationSection.profile,
        ),
      );
    }
    if (draft.kind == MealAdjustmentProfileKind.sandwich &&
        draft.freeSwapLimit != 0) {
      blockingErrors.add(
        const MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode
              .sandwichProfileFreeSwapLimitMustBeZero,
          section: MealAdjustmentValidationSection.profile,
        ),
      );
    }
    if (draft.isActive &&
        draft.kind == MealAdjustmentProfileKind.standard &&
        draft.components.isEmpty) {
      blockingErrors.add(
        const MealAdjustmentValidationIssue(
          code:
              MealAdjustmentValidationIssueCode.activeProfileMissingComponents,
          section: MealAdjustmentValidationSection.components,
        ),
      );
    }
    if (draft.kind == MealAdjustmentProfileKind.sandwich &&
        draft.components.isNotEmpty) {
      blockingErrors.add(
        const MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode
              .sandwichProfileComponentsNotSupported,
          section: MealAdjustmentValidationSection.components,
        ),
      );
    }
    if (draft.kind == MealAdjustmentProfileKind.sandwich &&
        draft.pricingRules.isNotEmpty) {
      blockingErrors.add(
        const MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode
              .sandwichProfilePricingRulesNotSupported,
          section: MealAdjustmentValidationSection.rules,
        ),
      );
    }

    if (draft.kind == MealAdjustmentProfileKind.standard) {
      blockingErrors.addAll(
        _validateComponents(draft, references.productsById),
      );
    }
    blockingErrors.addAll(
      _validateSandwichSauces(draft, references.productsById),
    );
    blockingErrors.addAll(_validateExtras(draft, references.productsById));
    final _RuleValidationArtifacts ruleArtifacts =
        draft.kind == MealAdjustmentProfileKind.standard
        ? _validateRules(draft, references.productsById)
        : const _RuleValidationArtifacts(
            blockingErrors: <MealAdjustmentValidationIssue>[],
            conflictingRules: <MealAdjustmentConflictingRule>[],
          );
    blockingErrors.addAll(ruleArtifacts.blockingErrors);
    blockingErrors.addAll(
      _validateAssignedProducts(
        assignedProducts: assignedProducts,
        breakfastAssignedRootProductIds: breakfastAssignedRootProductIds,
        profileName: draft.name,
      ),
    );

    return _DraftValidationArtifacts(
      validationResult: MealAdjustmentValidationResult(
        blockingErrors: _dedupeIssues(blockingErrors),
        warnings: _dedupeIssues(warnings),
      ),
      brokenReferences: _collectBrokenReferences(
        draft,
        references.productsById,
      ),
      conflictingRules: ruleArtifacts.conflictingRules,
      inactiveItems: _collectInactiveItems(references.productsById),
      assignedProducts: assignedProducts,
      breakfastAssignedProducts: assignedProducts
          .where(
            (MealAdjustmentProductSummary product) =>
                breakfastAssignedRootProductIds.contains(product.id),
          )
          .toList(growable: false),
    );
  }

  Future<List<MealAdjustmentProductSummary>> _loadAssignedProducts(
    MealAdjustmentProfileDraft draft,
  ) {
    final int? profileId = draft.id;
    if (profileId == null) {
      return Future<List<MealAdjustmentProductSummary>>.value(
        const <MealAdjustmentProductSummary>[],
      );
    }
    return _repository.listProductsByProfile(profileId);
  }

  Future<_ReferenceResolution> _loadReferenceResolution(
    MealAdjustmentProfileDraft draft,
  ) async {
    final Set<int> referencedProductIds = <int>{};
    referencedProductIds.addAll(draft.sandwichSettings.sauceProductIds);
    for (final MealAdjustmentComponentDraft component in draft.components) {
      referencedProductIds.add(component.defaultItemProductId);
      for (final MealAdjustmentComponentOptionDraft option
          in component.swapOptions) {
        referencedProductIds.add(option.optionItemProductId);
      }
    }
    for (final MealAdjustmentExtraOptionDraft extra in draft.extraOptions) {
      referencedProductIds.add(extra.itemProductId);
    }
    for (final MealAdjustmentPricingRuleDraft rule in draft.pricingRules) {
      for (final MealAdjustmentPricingRuleConditionDraft condition
          in rule.conditions) {
        final int? itemProductId = condition.itemProductId;
        if (itemProductId != null) {
          referencedProductIds.add(itemProductId);
        }
      }
    }

    final Map<int, MealAdjustmentProductSummary> productsById =
        await _repository.loadProductSummariesByIds(referencedProductIds);
    return _ReferenceResolution(productsById: productsById);
  }

  List<MealAdjustmentValidationIssue> _validateSandwichSauces(
    MealAdjustmentProfileDraft draft,
    Map<int, MealAdjustmentProductSummary> productsById,
  ) {
    if (draft.kind != MealAdjustmentProfileKind.sandwich) {
      return const <MealAdjustmentValidationIssue>[];
    }

    final List<MealAdjustmentValidationIssue> blockingErrors =
        <MealAdjustmentValidationIssue>[];
    for (final int sauceProductId in draft.sandwichSettings.sauceProductIds) {
      final MealAdjustmentProductSummary? product =
          productsById[sauceProductId];
      if (product == null) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.sandwichSauceItemMissing,
            section: MealAdjustmentValidationSection.references,
            itemProductId: sauceProductId,
          ),
        );
        continue;
      }
      if (!product.isActive) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.sandwichSauceItemInactive,
            section: MealAdjustmentValidationSection.references,
            itemProductId: sauceProductId,
          ),
        );
      }
      if (!product.isSauceProduct) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode
                .sandwichSauceItemMustBelongToSaucesCategory,
            section: MealAdjustmentValidationSection.references,
            itemProductId: sauceProductId,
          ),
        );
      }
    }
    return blockingErrors;
  }

  List<MealAdjustmentValidationIssue> _validateComponents(
    MealAdjustmentProfileDraft draft,
    Map<int, MealAdjustmentProductSummary> productsById,
  ) {
    final List<MealAdjustmentValidationIssue> blockingErrors =
        <MealAdjustmentValidationIssue>[];
    final Set<String> seenComponentKeys = <String>{};

    for (final MealAdjustmentComponentDraft component in draft.components) {
      final String normalizedKey = component.componentKey.trim().toLowerCase();
      if (normalizedKey.isEmpty) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.missingComponentKey,
            section: MealAdjustmentValidationSection.components,
            detail: 'component:${component.sortOrder}',
          ),
        );
      } else if (!seenComponentKeys.add(normalizedKey)) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.duplicateComponentKey,
            section: MealAdjustmentValidationSection.components,
            componentKey: component.componentKey,
          ),
        );
      }
      if (component.displayName.trim().isEmpty) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.missingComponentDisplayName,
            section: MealAdjustmentValidationSection.components,
            detail: 'component:${component.sortOrder}',
          ),
        );
      }
      if (component.quantity <= 0) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.invalidComponentQuantity,
            section: MealAdjustmentValidationSection.components,
            componentKey: component.componentKey,
          ),
        );
      }

      final MealAdjustmentProductSummary? defaultItem =
          productsById[component.defaultItemProductId];
      if (defaultItem == null) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.defaultItemMissing,
            section: MealAdjustmentValidationSection.references,
            componentKey: component.componentKey,
            itemProductId: component.defaultItemProductId,
          ),
        );
      } else if (!defaultItem.isActive) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.defaultItemInactive,
            section: MealAdjustmentValidationSection.references,
            componentKey: component.componentKey,
            itemProductId: component.defaultItemProductId,
          ),
        );
      }

      final Set<int> seenSwapItems = <int>{};
      for (final MealAdjustmentComponentOptionDraft option
          in component.swapOptions) {
        if (option.optionItemProductId == component.defaultItemProductId) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode
                  .swapOptionMatchesDefaultItem,
              section: MealAdjustmentValidationSection.swaps,
              componentKey: component.componentKey,
              itemProductId: option.optionItemProductId,
            ),
          );
        }
        if (!seenSwapItems.add(option.optionItemProductId)) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode.duplicateSwapOption,
              section: MealAdjustmentValidationSection.swaps,
              componentKey: component.componentKey,
              itemProductId: option.optionItemProductId,
            ),
          );
        }

        final MealAdjustmentProductSummary? swapItem =
            productsById[option.optionItemProductId];
        if (swapItem == null) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode.swapItemMissing,
              section: MealAdjustmentValidationSection.references,
              componentKey: component.componentKey,
              itemProductId: option.optionItemProductId,
            ),
          );
        } else if (!swapItem.isActive) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode.swapItemInactive,
              section: MealAdjustmentValidationSection.references,
              componentKey: component.componentKey,
              itemProductId: option.optionItemProductId,
            ),
          );
        }
      }
    }

    return blockingErrors;
  }

  List<MealAdjustmentValidationIssue> _validateExtras(
    MealAdjustmentProfileDraft draft,
    Map<int, MealAdjustmentProductSummary> productsById,
  ) {
    final List<MealAdjustmentValidationIssue> blockingErrors =
        <MealAdjustmentValidationIssue>[];
    final Set<int> seenExtraItems = <int>{};

    for (final MealAdjustmentExtraOptionDraft extra in draft.extraOptions) {
      if (extra.fixedPriceDeltaMinor < 0) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.invalidExtraPriceDelta,
            section: MealAdjustmentValidationSection.extras,
            itemProductId: extra.itemProductId,
          ),
        );
      }
      if (!seenExtraItems.add(extra.itemProductId)) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.duplicateExtraOption,
            section: MealAdjustmentValidationSection.extras,
            itemProductId: extra.itemProductId,
          ),
        );
      }

      final MealAdjustmentProductSummary? extraItem =
          productsById[extra.itemProductId];
      if (extraItem == null) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.extraItemMissing,
            section: MealAdjustmentValidationSection.references,
            itemProductId: extra.itemProductId,
          ),
        );
      } else if (!extraItem.isActive) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.extraItemInactive,
            section: MealAdjustmentValidationSection.references,
            itemProductId: extra.itemProductId,
          ),
        );
      }
    }

    return blockingErrors;
  }

  _RuleValidationArtifacts _validateRules(
    MealAdjustmentProfileDraft draft,
    Map<int, MealAdjustmentProductSummary> productsById,
  ) {
    final List<MealAdjustmentValidationIssue> blockingErrors =
        <MealAdjustmentValidationIssue>[];
    final Map<String, List<MealAdjustmentPricingRuleDraft>> rulesByMeaning =
        <String, List<MealAdjustmentPricingRuleDraft>>{};
    final Map<String, MealAdjustmentComponentDraft> activeComponentsByKey =
        <String, MealAdjustmentComponentDraft>{
          for (final MealAdjustmentComponentDraft component in draft.components)
            if (component.isActive)
              component.componentKey.trim().toLowerCase(): component,
        };
    final Map<String, Set<int>> activeSwapTargetsByComponentKey =
        <String, Set<int>>{
          for (final MealAdjustmentComponentDraft component in draft.components)
            if (component.isActive)
              component.componentKey.trim().toLowerCase(): component.swapOptions
                  .where(
                    (MealAdjustmentComponentOptionDraft option) =>
                        option.isActive,
                  )
                  .map(
                    (MealAdjustmentComponentOptionDraft option) =>
                        option.optionItemProductId,
                  )
                  .toSet(),
        };
    final Set<int> activeExtraItemIds = draft.extraOptions
        .where((MealAdjustmentExtraOptionDraft extra) => extra.isActive)
        .map((MealAdjustmentExtraOptionDraft extra) => extra.itemProductId)
        .toSet();

    for (final MealAdjustmentPricingRuleDraft rule in draft.pricingRules) {
      if (rule.name.trim().isEmpty) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.missingRuleName,
            section: MealAdjustmentValidationSection.rules,
            ruleId: rule.id,
          ),
        );
      }
      if (rule.ruleType == MealAdjustmentPricingRuleType.extra &&
          rule.priceDeltaMinor < 0) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.invalidExtraRulePriceDelta,
            section: MealAdjustmentValidationSection.rules,
            ruleId: rule.id,
          ),
        );
      }
      if (rule.ruleType == MealAdjustmentPricingRuleType.removeOnly &&
          rule.priceDeltaMinor > 0) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode
                .invalidRemoveOnlyRulePriceDelta,
            section: MealAdjustmentValidationSection.rules,
            ruleId: rule.id,
          ),
        );
      }
      if (rule.conditions.isEmpty) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
            section: MealAdjustmentValidationSection.rules,
            ruleId: rule.id,
            detail: 'At least one condition is required.',
          ),
        );
      }
      final Set<String> seenConditionMeaningKeys = <String>{};

      for (final MealAdjustmentPricingRuleConditionDraft condition
          in rule.conditions) {
        if (!seenConditionMeaningKeys.add(condition.semanticMeaningKey)) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
              section: MealAdjustmentValidationSection.rules,
              ruleId: rule.id,
              componentKey: condition.componentKey,
              itemProductId: condition.itemProductId,
              detail:
                  'Duplicate conditions with the same semantic meaning are not allowed in one rule.',
            ),
          );
          continue;
        }
        if (!condition.isStructurallyValid) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
              section: MealAdjustmentValidationSection.rules,
              ruleId: rule.id,
              componentKey: condition.componentKey,
              itemProductId: condition.itemProductId,
              detail:
                  'Complete the condition fields required by this condition type.',
            ),
          );
          continue;
        }

        final String normalizedComponentKey =
            condition.componentKey?.trim().toLowerCase() ?? '';
        switch (condition.conditionType) {
          case MealAdjustmentPricingRuleConditionType.removedComponent:
            final MealAdjustmentComponentDraft? component =
                activeComponentsByKey[normalizedComponentKey];
            if (component == null) {
              blockingErrors.add(
                MealAdjustmentValidationIssue(
                  code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
                  section: MealAdjustmentValidationSection.rules,
                  ruleId: rule.id,
                  componentKey: condition.componentKey,
                  detail:
                      'Removed-component condition must reference an active profile component.',
                ),
              );
            } else if (!component.canRemove) {
              blockingErrors.add(
                MealAdjustmentValidationIssue(
                  code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
                  section: MealAdjustmentValidationSection.rules,
                  ruleId: rule.id,
                  componentKey: condition.componentKey,
                  detail:
                      'Removed-component condition must reference a removable component.',
                ),
              );
            }
            break;
          case MealAdjustmentPricingRuleConditionType.swapToItem:
            final MealAdjustmentComponentDraft? component =
                activeComponentsByKey[normalizedComponentKey];
            if (component == null) {
              blockingErrors.add(
                MealAdjustmentValidationIssue(
                  code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
                  section: MealAdjustmentValidationSection.rules,
                  ruleId: rule.id,
                  componentKey: condition.componentKey,
                  itemProductId: condition.itemProductId,
                  detail:
                      'Swap condition must reference an active profile component.',
                ),
              );
            } else if (!activeSwapTargetsByComponentKey[normalizedComponentKey]!
                .contains(condition.itemProductId)) {
              blockingErrors.add(
                MealAdjustmentValidationIssue(
                  code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
                  section: MealAdjustmentValidationSection.rules,
                  ruleId: rule.id,
                  componentKey: condition.componentKey,
                  itemProductId: condition.itemProductId,
                  detail:
                      'Swap condition target must be configured as an active swap option for the component.',
                ),
              );
            }
            break;
          case MealAdjustmentPricingRuleConditionType.extraItem:
            if (!activeExtraItemIds.contains(condition.itemProductId)) {
              blockingErrors.add(
                MealAdjustmentValidationIssue(
                  code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
                  section: MealAdjustmentValidationSection.rules,
                  ruleId: rule.id,
                  itemProductId: condition.itemProductId,
                  detail:
                      'Extra-item condition must reference an active profile extra.',
                ),
              );
            }
            break;
        }
        final int? itemProductId = condition.itemProductId;
        if (itemProductId == null) {
          continue;
        }
        final MealAdjustmentProductSummary? item = productsById[itemProductId];
        if (item == null) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode.ruleItemMissing,
              section: MealAdjustmentValidationSection.references,
              ruleId: rule.id,
              itemProductId: itemProductId,
            ),
          );
        } else if (!item.isActive) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode.ruleItemInactive,
              section: MealAdjustmentValidationSection.references,
              ruleId: rule.id,
              itemProductId: itemProductId,
            ),
          );
        }
      }

      rulesByMeaning
          .putIfAbsent(rule.semanticMeaningKey, () {
            return <MealAdjustmentPricingRuleDraft>[];
          })
          .add(rule);
    }

    final List<MealAdjustmentConflictingRule> conflictingRules =
        <MealAdjustmentConflictingRule>[];
    for (final MapEntry<String, List<MealAdjustmentPricingRuleDraft>> entry
        in rulesByMeaning.entries) {
      if (entry.value.length <= 1) {
        continue;
      }
      final List<int> ruleIds =
          entry.value
              .map((MealAdjustmentPricingRuleDraft rule) => rule.id ?? -1)
              .toList(growable: false)
            ..sort();
      conflictingRules.add(
        MealAdjustmentConflictingRule(
          ruleIds: ruleIds,
          semanticMeaningKey: entry.key,
        ),
      );
      blockingErrors.add(
        MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode.duplicateRuleMeaning,
          section: MealAdjustmentValidationSection.rules,
          relatedRuleIds: ruleIds,
          detail: entry.key,
        ),
      );
      blockingErrors.add(
        MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode.conflictingRuleMeaning,
          section: MealAdjustmentValidationSection.rules,
          relatedRuleIds: ruleIds,
          detail: entry.key,
        ),
      );
    }

    return _RuleValidationArtifacts(
      blockingErrors: blockingErrors,
      conflictingRules: conflictingRules,
    );
  }

  List<MealAdjustmentValidationIssue> _validateAssignedProducts({
    required List<MealAdjustmentProductSummary> assignedProducts,
    required Set<int> breakfastAssignedRootProductIds,
    required String profileName,
  }) {
    return assignedProducts
        .where(
          (MealAdjustmentProductSummary product) =>
              breakfastAssignedRootProductIds.contains(product.id),
        )
        .map(
          (MealAdjustmentProductSummary product) =>
              MealAdjustmentValidationIssue(
                code: MealAdjustmentValidationIssueCode
                    .breakfastProductAssignmentBlocked,
                section: MealAdjustmentValidationSection.assignments,
                productId: product.id,
                detail: _buildBreakfastAssignmentConflictMessage(
                  productName: product.name,
                  profileName: profileName,
                ),
              ),
        )
        .toList(growable: false);
  }

  String _buildBreakfastAssignmentConflictMessage({
    required String productName,
    String? profileName,
  }) {
    final String normalizedProfileName =
        profileName == null || profileName.trim().isEmpty
        ? 'this meal-adjustment profile'
        : '"${profileName.trim()}"';
    return 'Product "$productName" cannot use meal-adjustment profile $normalizedProfileName because it is configured as a breakfast semantic root product.';
  }

  List<MealAdjustmentBrokenReference> _collectBrokenReferences(
    MealAdjustmentProfileDraft draft,
    Map<int, MealAdjustmentProductSummary> productsById,
  ) {
    final List<MealAdjustmentBrokenReference> references =
        <MealAdjustmentBrokenReference>[];

    void addReference({
      required MealAdjustmentValidationSection section,
      required int itemProductId,
      String? componentKey,
      int? ruleId,
    }) {
      final MealAdjustmentProductSummary? product = productsById[itemProductId];
      if (product == null) {
        references.add(
          MealAdjustmentBrokenReference(
            section: section,
            itemProductId: itemProductId,
            isMissing: true,
            isInactive: false,
            componentKey: componentKey,
            ruleId: ruleId,
          ),
        );
      } else if (!product.isActive) {
        references.add(
          MealAdjustmentBrokenReference(
            section: section,
            itemProductId: itemProductId,
            isMissing: false,
            isInactive: true,
            componentKey: componentKey,
            ruleId: ruleId,
          ),
        );
      }
    }

    for (final int sauceProductId in draft.sandwichSettings.sauceProductIds) {
      addReference(
        section: MealAdjustmentValidationSection.profile,
        itemProductId: sauceProductId,
      );
    }
    for (final MealAdjustmentComponentDraft component in draft.components) {
      addReference(
        section: MealAdjustmentValidationSection.components,
        itemProductId: component.defaultItemProductId,
        componentKey: component.componentKey,
      );
      for (final MealAdjustmentComponentOptionDraft option
          in component.swapOptions) {
        addReference(
          section: MealAdjustmentValidationSection.swaps,
          itemProductId: option.optionItemProductId,
          componentKey: component.componentKey,
        );
      }
    }
    for (final MealAdjustmentExtraOptionDraft extra in draft.extraOptions) {
      addReference(
        section: MealAdjustmentValidationSection.extras,
        itemProductId: extra.itemProductId,
      );
    }
    for (final MealAdjustmentPricingRuleDraft rule in draft.pricingRules) {
      for (final MealAdjustmentPricingRuleConditionDraft condition
          in rule.conditions) {
        final int? itemProductId = condition.itemProductId;
        if (itemProductId != null) {
          addReference(
            section: MealAdjustmentValidationSection.rules,
            itemProductId: itemProductId,
            componentKey: condition.componentKey,
            ruleId: rule.id,
          );
        }
      }
    }

    return references;
  }

  List<int> _collectInactiveItems(
    Map<int, MealAdjustmentProductSummary> productsById,
  ) {
    return productsById.values
        .where((MealAdjustmentProductSummary product) => !product.isActive)
        .map((MealAdjustmentProductSummary product) => product.id)
        .toSet()
        .toList(growable: false)
      ..sort();
  }

  List<MealAdjustmentValidationIssue> _dedupeIssues(
    List<MealAdjustmentValidationIssue> issues,
  ) {
    final Map<String, MealAdjustmentValidationIssue> deduped =
        <String, MealAdjustmentValidationIssue>{};
    for (final MealAdjustmentValidationIssue issue in issues) {
      deduped[issue.dedupeKey] = issue;
    }
    return deduped.values.toList(growable: false);
  }

  String _buildHeadline({
    required MealAdjustmentHealthStatus healthStatus,
    required int blockingCount,
    required int affectedProductCount,
  }) {
    switch (healthStatus) {
      case MealAdjustmentHealthStatus.valid:
        return affectedProductCount == 0
            ? 'Profile is valid'
            : 'Profile is valid for $affectedProductCount product(s)';
      case MealAdjustmentHealthStatus.incomplete:
        return 'Profile needs attention';
      case MealAdjustmentHealthStatus.invalid:
        return 'Profile is invalid ($blockingCount blocking issue${blockingCount == 1 ? '' : 's'})';
    }
  }

  String _buildBody({
    required MealAdjustmentHealthStatus healthStatus,
    required int brokenReferenceCount,
    required int conflictingRuleCount,
    required int breakfastConflictCount,
    required int affectedProductCount,
  }) {
    switch (healthStatus) {
      case MealAdjustmentHealthStatus.valid:
        return affectedProductCount == 0
            ? 'No blocking issues were found.'
            : 'No blocking issues were found across $affectedProductCount assigned product(s).';
      case MealAdjustmentHealthStatus.incomplete:
        return 'The profile has warnings that should be reviewed before rollout.';
      case MealAdjustmentHealthStatus.invalid:
        return 'The profile has $brokenReferenceCount broken reference(s), $conflictingRuleCount conflicting rule group(s), and $breakfastConflictCount breakfast assignment conflict(s).';
    }
  }
}

class _ReferenceResolution {
  const _ReferenceResolution({required this.productsById});

  final Map<int, MealAdjustmentProductSummary> productsById;
}

class _RuleValidationArtifacts {
  const _RuleValidationArtifacts({
    required this.blockingErrors,
    required this.conflictingRules,
  });

  final List<MealAdjustmentValidationIssue> blockingErrors;
  final List<MealAdjustmentConflictingRule> conflictingRules;
}

class _DraftValidationArtifacts {
  const _DraftValidationArtifacts({
    required this.validationResult,
    required this.brokenReferences,
    required this.conflictingRules,
    required this.inactiveItems,
    required this.assignedProducts,
    required this.breakfastAssignedProducts,
  });

  final MealAdjustmentValidationResult validationResult;
  final List<MealAdjustmentBrokenReference> brokenReferences;
  final List<MealAdjustmentConflictingRule> conflictingRules;
  final List<int> inactiveItems;
  final List<MealAdjustmentProductSummary> assignedProducts;
  final List<MealAdjustmentProductSummary> breakfastAssignedProducts;
}
