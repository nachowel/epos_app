import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/repositories/meal_adjustment_profile_repository.dart';
import 'package:epos_app/domain/services/meal_adjustment_profile_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealAdjustmentProfileValidationService', () {
    test(
      'blocks breakfast product assignments on validateProductAssignment',
      () async {
        final MealAdjustmentProfileValidationService service =
            MealAdjustmentProfileValidationService(
              repository: _FakeMealAdjustmentProfileRepository(
                profile: const MealAdjustmentProfile(
                  id: 5,
                  name: 'Lunch profile',
                  freeSwapLimit: 1,
                  isActive: true,
                ),
                productsById: <int, MealAdjustmentProductSummary>{
                  77: const MealAdjustmentProductSummary(
                    id: 77,
                    categoryId: 8,
                    categoryName: 'Set Breakfast',
                    name: 'Set 4',
                    isActive: true,
                  ),
                },
                breakfastSemanticProductIds: const <int>{77},
              ),
            );

        final MealAdjustmentValidationResult result = await service
            .validateProductAssignment(productId: 77, profileId: 5);

        expect(result.canSave, isFalse);
        expect(
          result.blockingErrors.single.code,
          MealAdjustmentValidationIssueCode.breakfastProductAssignmentBlocked,
        );
      },
    );

    test('blocks missing and inactive references', () async {
      final MealAdjustmentProfileValidationService service =
          MealAdjustmentProfileValidationService(
            repository: _FakeMealAdjustmentProfileRepository(
              productsById: <int, MealAdjustmentProductSummary>{
                200: const MealAdjustmentProductSummary(
                  id: 200,
                  categoryId: 1,
                  categoryName: 'Mains',
                  name: 'Chicken',
                  isActive: false,
                ),
              },
            ),
          );

      final MealAdjustmentValidationResult result = await service.validateDraft(
        const MealAdjustmentProfileDraft(
          name: 'Broken profile',
          freeSwapLimit: 0,
          isActive: true,
          components: <MealAdjustmentComponentDraft>[
            MealAdjustmentComponentDraft(
              componentKey: 'main',
              displayName: 'Main',
              defaultItemProductId: 200,
              quantity: 1,
              canRemove: true,
              sortOrder: 0,
              isActive: true,
              swapOptions: <MealAdjustmentComponentOptionDraft>[
                MealAdjustmentComponentOptionDraft(
                  optionItemProductId: 201,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          ],
          extraOptions: <MealAdjustmentExtraOptionDraft>[
            MealAdjustmentExtraOptionDraft(
              itemProductId: 202,
              fixedPriceDeltaMinor: 150,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      );

      expect(
        result.blockingErrors.map((MealAdjustmentValidationIssue issue) {
          return issue.code;
        }),
        containsAll(<MealAdjustmentValidationIssueCode>[
          MealAdjustmentValidationIssueCode.defaultItemInactive,
          MealAdjustmentValidationIssueCode.swapItemMissing,
          MealAdjustmentValidationIssueCode.extraItemMissing,
        ]),
      );
    });

    test('blocks invalid signed rule deltas', () async {
      final MealAdjustmentProfileValidationService service =
          MealAdjustmentProfileValidationService(
            repository: _FakeMealAdjustmentProfileRepository(
              productsById: <int, MealAdjustmentProductSummary>{
                100: const MealAdjustmentProductSummary(
                  id: 100,
                  categoryId: 1,
                  categoryName: 'Mains',
                  name: 'Chicken',
                  isActive: true,
                ),
              },
            ),
          );

      final MealAdjustmentValidationResult result = await service.validateDraft(
        const MealAdjustmentProfileDraft(
          name: 'Rule profile',
          freeSwapLimit: 0,
          isActive: true,
          components: <MealAdjustmentComponentDraft>[
            MealAdjustmentComponentDraft(
              componentKey: 'main',
              displayName: 'Main',
              defaultItemProductId: 100,
              quantity: 1,
              canRemove: true,
              sortOrder: 0,
              isActive: true,
            ),
          ],
          pricingRules: <MealAdjustmentPricingRuleDraft>[
            MealAdjustmentPricingRuleDraft(
              name: 'Negative extra',
              ruleType: MealAdjustmentPricingRuleType.extra,
              priceDeltaMinor: -10,
              priority: 0,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleConditionDraft>[
                MealAdjustmentPricingRuleConditionDraft(
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.extraItem,
                  itemProductId: 100,
                  quantity: 1,
                ),
              ],
            ),
            MealAdjustmentPricingRuleDraft(
              name: 'Positive remove',
              ruleType: MealAdjustmentPricingRuleType.removeOnly,
              priceDeltaMinor: 10,
              priority: 0,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleConditionDraft>[
                MealAdjustmentPricingRuleConditionDraft(
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.removedComponent,
                  componentKey: 'main',
                  quantity: 1,
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        result.blockingErrors.map((MealAdjustmentValidationIssue issue) {
          return issue.code;
        }),
        containsAll(<MealAdjustmentValidationIssueCode>[
          MealAdjustmentValidationIssueCode.invalidExtraRulePriceDelta,
          MealAdjustmentValidationIssueCode.invalidRemoveOnlyRulePriceDelta,
        ]),
      );
    });

    test('blocks duplicate and conflicting rule meaning', () async {
      final MealAdjustmentProfileValidationService service =
          MealAdjustmentProfileValidationService(
            repository: _FakeMealAdjustmentProfileRepository(
              productsById: <int, MealAdjustmentProductSummary>{
                100: const MealAdjustmentProductSummary(
                  id: 100,
                  categoryId: 1,
                  categoryName: 'Mains',
                  name: 'Chicken',
                  isActive: true,
                ),
              },
            ),
          );

      final MealAdjustmentValidationResult result = await service.validateDraft(
        const MealAdjustmentProfileDraft(
          name: 'Conflict profile',
          freeSwapLimit: 0,
          isActive: true,
          components: <MealAdjustmentComponentDraft>[
            MealAdjustmentComponentDraft(
              componentKey: 'main',
              displayName: 'Main',
              defaultItemProductId: 100,
              quantity: 1,
              canRemove: true,
              sortOrder: 0,
              isActive: true,
            ),
          ],
          pricingRules: <MealAdjustmentPricingRuleDraft>[
            MealAdjustmentPricingRuleDraft(
              id: 1,
              name: 'Swap A',
              ruleType: MealAdjustmentPricingRuleType.swap,
              priceDeltaMinor: 50,
              priority: 0,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleConditionDraft>[
                MealAdjustmentPricingRuleConditionDraft(
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.swapToItem,
                  componentKey: 'main',
                  itemProductId: 100,
                  quantity: 1,
                ),
              ],
            ),
            MealAdjustmentPricingRuleDraft(
              id: 2,
              name: 'Swap B',
              ruleType: MealAdjustmentPricingRuleType.swap,
              priceDeltaMinor: 75,
              priority: 10,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleConditionDraft>[
                MealAdjustmentPricingRuleConditionDraft(
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.swapToItem,
                  componentKey: 'main',
                  itemProductId: 100,
                  quantity: 1,
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        result.blockingErrors.map((MealAdjustmentValidationIssue issue) {
          return issue.code;
        }),
        containsAll(<MealAdjustmentValidationIssueCode>[
          MealAdjustmentValidationIssueCode.duplicateRuleMeaning,
          MealAdjustmentValidationIssueCode.conflictingRuleMeaning,
        ]),
      );
    });

    test('health summary exposes conflicts and affected products', () async {
      final MealAdjustmentProfileValidationService service =
          MealAdjustmentProfileValidationService(
            repository: _FakeMealAdjustmentProfileRepository(
              assignedProducts: const <MealAdjustmentProductSummary>[
                MealAdjustmentProductSummary(
                  id: 501,
                  categoryId: 1,
                  categoryName: 'Mains',
                  name: 'Burger Meal',
                  isActive: true,
                  mealAdjustmentProfileId: 9,
                ),
              ],
              productsById: <int, MealAdjustmentProductSummary>{
                100: const MealAdjustmentProductSummary(
                  id: 100,
                  categoryId: 1,
                  categoryName: 'Mains',
                  name: 'Chicken',
                  isActive: false,
                ),
              },
            ),
          );

      final MealAdjustmentProfileHealthSummary summary = await service
          .computeHealthSummary(
            const MealAdjustmentProfileDraft(
              id: 9,
              name: 'Invalid profile',
              freeSwapLimit: 0,
              isActive: true,
              components: <MealAdjustmentComponentDraft>[
                MealAdjustmentComponentDraft(
                  componentKey: 'main',
                  displayName: 'Main',
                  defaultItemProductId: 100,
                  quantity: 1,
                  canRemove: true,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          );

      expect(summary.healthStatus, MealAdjustmentHealthStatus.invalid);
      expect(summary.brokenReferences, hasLength(1));
      expect(summary.inactiveItems, <int>[100]);
      expect(summary.affectedProducts.single.id, 501);
    });
  });
}

class _FakeMealAdjustmentProfileRepository
    implements MealAdjustmentProfileRepository {
  const _FakeMealAdjustmentProfileRepository({
    this.profile,
    this.productsById = const <int, MealAdjustmentProductSummary>{},
    this.assignedProducts = const <MealAdjustmentProductSummary>[],
    this.breakfastSemanticProductIds = const <int>{},
  });

  final MealAdjustmentProfile? profile;
  final Map<int, MealAdjustmentProductSummary> productsById;
  final List<MealAdjustmentProductSummary> assignedProducts;
  final Set<int> breakfastSemanticProductIds;

  @override
  Future<bool> assignProfileToProduct({
    required int productId,
    int? profileId,
  }) async {
    return true;
  }

  @override
  Future<MealAdjustmentProfile?> getProfileById(int id) async {
    if (profile?.id == id) {
      return profile;
    }
    return null;
  }

  @override
  Future<List<MealAdjustmentProfile>> listProfiles({
    bool activeOnly = true,
  }) async {
    final MealAdjustmentProfile? value = profile;
    if (value == null) {
      return const <MealAdjustmentProfile>[];
    }
    if (activeOnly && !value.isActive) {
      return const <MealAdjustmentProfile>[];
    }
    return <MealAdjustmentProfile>[value];
  }

  @override
  Future<List<MealAdjustmentProfile>> listProfilesForAdmin() async {
    final MealAdjustmentProfile? value = profile;
    return value == null
        ? const <MealAdjustmentProfile>[]
        : <MealAdjustmentProfile>[value];
  }

  @override
  Future<MealAdjustmentProfileDraft?> loadProfileDraft(int id) async {
    final MealAdjustmentProfile? value = profile;
    if (value?.id != id) {
      return null;
    }
    return MealAdjustmentProfileDraft(
      id: value!.id,
      name: value.name,
      description: value.description,
      freeSwapLimit: value.freeSwapLimit,
      isActive: value.isActive,
      components: value.components
          .map(
            (MealAdjustmentComponent component) => MealAdjustmentComponentDraft(
              id: component.id,
              componentKey: component.componentKey,
              displayName: component.displayName,
              defaultItemProductId: component.defaultItemProductId,
              quantity: component.quantity,
              canRemove: component.canRemove,
              sortOrder: component.sortOrder,
              isActive: component.isActive,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<int> saveProfileDraft(MealAdjustmentProfileDraft draft) async {
    return draft.id ?? 1;
  }

  @override
  Future<List<MealAdjustmentProductSummary>> listProductsByProfile(
    int profileId, {
    bool activeOnly = false,
  }) async {
    return assignedProducts
        .where((MealAdjustmentProductSummary product) {
          return !activeOnly || product.isActive;
        })
        .toList(growable: false);
  }

  @override
  Future<Map<int, MealAdjustmentProductSummary>> loadProductSummariesByIds(
    Iterable<int> productIds,
  ) async {
    final Map<int, MealAdjustmentProductSummary> results =
        <int, MealAdjustmentProductSummary>{};
    for (final int productId in productIds) {
      final MealAdjustmentProductSummary? product = productsById[productId];
      if (product != null) {
        results[productId] = product;
      }
    }
    return results;
  }

  @override
  Future<Set<int>> loadBreakfastSemanticProductIds(
    Iterable<int> productIds,
  ) async {
    return productIds
        .where(
          (int productId) => breakfastSemanticProductIds.contains(productId),
        )
        .toSet();
  }
}
