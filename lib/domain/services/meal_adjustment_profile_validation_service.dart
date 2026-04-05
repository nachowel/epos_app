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
  activeProfileMissingComponents,
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
      case MealAdjustmentValidationIssueCode.activeProfileMissingComponents:
        return 'An active profile must contain at least one component.';
      case MealAdjustmentValidationIssueCode.duplicateComponentKey:
        return 'Component keys must be unique. Duplicate: ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.invalidComponentQuantity:
        return 'Component quantity must be greater than zero for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.defaultItemMissing:
        return 'Default item ${itemProductId ?? 'unknown'} is missing for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.defaultItemInactive:
        return 'Default item ${itemProductId ?? 'unknown'} is inactive for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.swapItemMissing:
        return 'Swap item ${itemProductId ?? 'unknown'} is missing for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.swapItemInactive:
        return 'Swap item ${itemProductId ?? 'unknown'} is inactive for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.extraItemMissing:
        return 'Extra item ${itemProductId ?? 'unknown'} is missing.';
      case MealAdjustmentValidationIssueCode.extraItemInactive:
        return 'Extra item ${itemProductId ?? 'unknown'} is inactive.';
      case MealAdjustmentValidationIssueCode.ruleItemMissing:
        return 'Pricing rule item ${itemProductId ?? 'unknown'} is missing.';
      case MealAdjustmentValidationIssueCode.ruleItemInactive:
        return 'Pricing rule item ${itemProductId ?? 'unknown'} is inactive.';
      case MealAdjustmentValidationIssueCode.swapOptionMatchesDefaultItem:
        return 'Swap target cannot be the same as the default item for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.duplicateSwapOption:
        return 'Swap options cannot contain duplicate products for ${componentKey ?? 'unknown'}.';
      case MealAdjustmentValidationIssueCode.duplicateExtraOption:
        return 'Extra options cannot contain duplicate products.';
      case MealAdjustmentValidationIssueCode.invalidRuleCondition:
        return 'Pricing rule condition is structurally invalid.';
      case MealAdjustmentValidationIssueCode.invalidExtraRulePriceDelta:
        return 'Extra pricing rules cannot use negative price deltas.';
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
        return 'Breakfast semantic products cannot carry a meal-adjustment profile.';
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

    final Set<int> breakfastIds = await _repository
        .loadBreakfastSemanticProductIds(<int>[productId]);
    if (breakfastIds.contains(productId)) {
      blockingErrors.add(
        MealAdjustmentValidationIssue(
          code: MealAdjustmentValidationIssueCode
              .breakfastProductAssignmentBlocked,
          section: MealAdjustmentValidationSection.assignments,
          productId: productId,
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
    final Set<int> breakfastAssignedProductIds =
        draft.id == null || assignedProducts.isEmpty
        ? const <int>{}
        : await _repository.loadBreakfastSemanticProductIds(
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
    if (draft.isActive && draft.components.isEmpty) {
      blockingErrors.add(
        const MealAdjustmentValidationIssue(
          code:
              MealAdjustmentValidationIssueCode.activeProfileMissingComponents,
          section: MealAdjustmentValidationSection.components,
        ),
      );
    }

    blockingErrors.addAll(_validateComponents(draft, references.productsById));
    blockingErrors.addAll(_validateExtras(draft, references.productsById));
    final _RuleValidationArtifacts ruleArtifacts = _validateRules(
      draft,
      references.productsById,
    );
    blockingErrors.addAll(ruleArtifacts.blockingErrors);
    blockingErrors.addAll(
      _validateAssignedProducts(
        assignedProducts: assignedProducts,
        breakfastAssignedProductIds: breakfastAssignedProductIds,
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
                breakfastAssignedProductIds.contains(product.id),
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

  List<MealAdjustmentValidationIssue> _validateComponents(
    MealAdjustmentProfileDraft draft,
    Map<int, MealAdjustmentProductSummary> productsById,
  ) {
    final List<MealAdjustmentValidationIssue> blockingErrors =
        <MealAdjustmentValidationIssue>[];
    final Set<String> seenComponentKeys = <String>{};

    for (final MealAdjustmentComponentDraft component in draft.components) {
      final String normalizedKey = component.componentKey.trim().toLowerCase();
      if (!seenComponentKeys.add(normalizedKey)) {
        blockingErrors.add(
          MealAdjustmentValidationIssue(
            code: MealAdjustmentValidationIssueCode.duplicateComponentKey,
            section: MealAdjustmentValidationSection.components,
            componentKey: component.componentKey,
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

    for (final MealAdjustmentPricingRuleDraft rule in draft.pricingRules) {
      if (!rule.isActive) {
        continue;
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

      for (final MealAdjustmentPricingRuleConditionDraft condition
          in rule.conditions) {
        if (!condition.isStructurallyValid) {
          blockingErrors.add(
            MealAdjustmentValidationIssue(
              code: MealAdjustmentValidationIssueCode.invalidRuleCondition,
              section: MealAdjustmentValidationSection.rules,
              ruleId: rule.id,
              componentKey: condition.componentKey,
              itemProductId: condition.itemProductId,
            ),
          );
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
    required Set<int> breakfastAssignedProductIds,
  }) {
    return assignedProducts
        .where(
          (MealAdjustmentProductSummary product) =>
              breakfastAssignedProductIds.contains(product.id),
        )
        .map(
          (MealAdjustmentProductSummary product) =>
              MealAdjustmentValidationIssue(
                code: MealAdjustmentValidationIssueCode
                    .breakfastProductAssignmentBlocked,
                section: MealAdjustmentValidationSection.assignments,
                productId: product.id,
              ),
        )
        .toList(growable: false);
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
