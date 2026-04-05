import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart'
    hide MealAdjustmentProfile, MealAdjustmentComponentOption;
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/models/meal_insights.dart';
import 'package:epos_app/domain/repositories/meal_adjustment_profile_repository.dart';
import 'package:epos_app/domain/services/meal_adjustment_admin_service.dart';
import 'package:epos_app/domain/services/meal_adjustment_profile_validation_service.dart';
import 'package:epos_app/domain/services/meal_customization_engine.dart';
import 'package:epos_app/domain/services/meal_insights_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftMealAdjustmentProfileRepository profileRepository;
  late MealAdjustmentProfileValidationService validationService;
  late MealAdjustmentAdminService adminService;
  late TransactionRepository transactionRepository;
  late ProductRepository productRepository;

  setUp(() async {
    db = createTestDatabase();
    profileRepository = DriftMealAdjustmentProfileRepository(db);
    validationService = MealAdjustmentProfileValidationService(
      repository: profileRepository,
    );
    adminService = MealAdjustmentAdminService(
      repository: profileRepository,
      validationService: validationService,
      engine: const MealCustomizationEngine(),
    );
    transactionRepository = TransactionRepository(db);
    productRepository = ProductRepository(db);

    final int categoryId = await insertCategory(db, name: 'Mains');
    await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Burger',
      priceMinor: 1200,
    );
    await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Fries',
      priceMinor: 500,
    );
    await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Salad',
      priceMinor: 600,
    );
    await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Bacon',
      priceMinor: 300,
    );
  });

  tearDown(() async {
    await db.close();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A. Admin Profile Builder — service layer
  // ─────────────────────────────────────────────────────────────────────────

  group('A. Admin Profile Builder', () {
    test('creates a new profile draft with inactive status', () async {
      final int profileId = await profileRepository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'Test Profile',
          freeSwapLimit: 2,
          isActive: false,
        ),
      );
      expect(profileId, greaterThan(0));
      final MealAdjustmentProfile? loaded = await profileRepository
          .getProfileById(profileId);
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Test Profile');
      expect(loaded.freeSwapLimit, 2);
      expect(loaded.isActive, false);
    });

    test('listAllProfiles returns all profiles including inactive', () async {
      await profileRepository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'Active Profile',
          freeSwapLimit: 0,
          isActive: true,
        ),
      );
      await profileRepository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'Archived Profile',
          freeSwapLimit: 0,
          isActive: false,
        ),
      );

      final List<MealAdjustmentProfile> all = await adminService
          .listAllProfiles();
      expect(all.length, 2);
    });

    test('duplicateProfile creates copy with (copy) suffix and no id', () async {
      final int originalId = await profileRepository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'Original',
          description: 'Desc',
          freeSwapLimit: 1,
          isActive: true,
          components: <MealAdjustmentComponentDraft>[
            MealAdjustmentComponentDraft(
              componentKey: 'main',
              displayName: 'Main Item',
              defaultItemProductId: 1,
              quantity: 1,
              canRemove: true,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      );

      final int duplicateId = await adminService.duplicateProfile(originalId);
      expect(duplicateId, isNot(originalId));

      final MealAdjustmentProfileDraft? duplicated = await profileRepository
          .loadProfileDraft(duplicateId);
      expect(duplicated, isNotNull);
      expect(duplicated!.name, 'Original (copy)');
      expect(duplicated.components.length, 1);
      expect(duplicated.components.first.componentKey, 'main');
    });

    test('archiveProfile sets isActive to false', () async {
      final int profileId = await profileRepository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'To Archive',
          freeSwapLimit: 0,
          isActive: true,
        ),
      );

      await adminService.archiveProfile(profileId);

      final MealAdjustmentProfile? archived = await profileRepository
          .getProfileById(profileId);
      expect(archived, isNotNull);
      expect(archived!.isActive, false);
    });

    test('deleteProfile removes profile when no products assigned', () async {
      final int profileId = await profileRepository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'To Delete',
          freeSwapLimit: 0,
          isActive: false,
        ),
      );

      final bool deleted = await adminService.deleteProfile(profileId);
      expect(deleted, true);

      final MealAdjustmentProfile? loaded = await profileRepository
          .getProfileById(profileId);
      expect(loaded, isNull);
    });

    test('deleteProfile throws when products are assigned', () async {
      final int profileId = await profileRepository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'In Use',
          freeSwapLimit: 0,
          isActive: true,
        ),
      );
      // Assign a product to this profile.
      await profileRepository.assignProfileToProduct(
        productId: 1,
        profileId: profileId,
      );

      expect(
        () => adminService.deleteProfile(profileId),
        throwsA(isA<MealAdjustmentProfileInUseException>()),
      );
    });

    test('deleteProfile unassigns products before deleting', () async {
      final int profileId = await profileRepository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'Cascade Test',
          freeSwapLimit: 0,
          isActive: true,
        ),
      );
      await profileRepository.assignProfileToProduct(
        productId: 1,
        profileId: profileId,
      );

      // Direct repo delete (bypasses admin in-use check) — verifies cascade.
      final bool deleted = await profileRepository.deleteProfile(profileId);
      expect(deleted, true);

      // Product should have null profile now.
      final Map<int, MealAdjustmentProductSummary> summaries =
          await profileRepository.loadProductSummariesByIds(<int>[1]);
      expect(summaries[1]?.mealAdjustmentProfileId, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A. Draft copyWith / duplicate
  // ─────────────────────────────────────────────────────────────────────────

  group('A. MealAdjustmentProfileDraft copyWith', () {
    test('copyWith preserves original values when no override', () {
      const MealAdjustmentProfileDraft draft = MealAdjustmentProfileDraft(
        id: 10,
        name: 'Test',
        description: 'Desc',
        freeSwapLimit: 3,
        isActive: true,
      );

      final MealAdjustmentProfileDraft copy = draft.copyWith();
      expect(copy.id, 10);
      expect(copy.name, 'Test');
      expect(copy.description, 'Desc');
      expect(copy.freeSwapLimit, 3);
      expect(copy.isActive, true);
    });

    test('copyWith can set id to null', () {
      const MealAdjustmentProfileDraft draft = MealAdjustmentProfileDraft(
        id: 10,
        name: 'Test',
        freeSwapLimit: 0,
        isActive: true,
      );

      final MealAdjustmentProfileDraft copy = draft.copyWith(id: null);
      expect(copy.id, isNull);
    });

    test('duplicate creates copy with modified name', () {
      const MealAdjustmentProfileDraft draft = MealAdjustmentProfileDraft(
        id: 10,
        name: 'Burger Profile',
        freeSwapLimit: 2,
        isActive: true,
      );

      final MealAdjustmentProfileDraft dup = draft.duplicate();
      expect(dup.id, isNull);
      expect(dup.name, 'Burger Profile (copy)');
      expect(dup.freeSwapLimit, 2);
    });

    test('duplicate with custom suffix', () {
      const MealAdjustmentProfileDraft draft = MealAdjustmentProfileDraft(
        id: 10,
        name: 'Lunch Combo',
        freeSwapLimit: 1,
        isActive: true,
      );

      final MealAdjustmentProfileDraft dup =
          draft.duplicate(nameSuffix: ' v2');
      expect(dup.name, 'Lunch Combo v2');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // D. Prefetch Hardening
  // ─────────────────────────────────────────────────────────────────────────

  group('D. Prefetch Hardening', () {
    test('prefetch skips products not in productNamesById (visibility scope)',
        () async {
      final MealInsightsService service = MealInsightsService(
        transactionRepository: transactionRepository,
        productRepository: productRepository,
        suggestionCacheTtl: const Duration(minutes: 5),
        maxCacheSize: 50,
      );

      // Only productId 1 is in the names map; productId 2 is not.
      await service.prefetchSuggestions(
        productIds: <int>[1, 2],
        productNamesById: <int, String>{1: 'Burger'},
      );

      expect(service.hasCachedSuggestions(1), true);
      expect(service.hasCachedSuggestions(2), false);
    });

    test('prefetch skips already cached non-expired entries', () async {
      final MealInsightsService service = MealInsightsService(
        transactionRepository: transactionRepository,
        productRepository: productRepository,
        suggestionCacheTtl: const Duration(minutes: 5),
        maxCacheSize: 50,
      );

      final Map<int, String> names = <int, String>{1: 'Burger'};

      // First prefetch.
      await service.prefetchSuggestions(
        productIds: <int>[1],
        productNamesById: names,
      );
      expect(service.hasCachedSuggestions(1), true);

      // Second call — should skip since entry is still valid.
      await service.prefetchSuggestions(
        productIds: <int>[1],
        productNamesById: names,
      );
      expect(service.currentCacheSize, 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // E. Cache Guardrails
  // ─────────────────────────────────────────────────────────────────────────

  group('E. Cache Guardrails', () {
    test('cache evicts oldest entries when exceeding maxCacheSize', () async {
      final MealInsightsService service = MealInsightsService(
        transactionRepository: transactionRepository,
        productRepository: productRepository,
        suggestionCacheTtl: const Duration(minutes: 5),
        maxCacheSize: 3,
      );

      final Map<int, String> names = <int, String>{
        1: 'Burger',
        2: 'Fries',
        3: 'Salad',
        4: 'Bacon',
      };

      // Fill cache with 4 products (max is 3).
      await service.prefetchSuggestions(
        productIds: <int>[1, 2, 3, 4],
        productNamesById: names,
      );

      expect(service.currentCacheSize, 3);
      // Product 1 (oldest) should have been evicted.
      expect(service.hasCachedSuggestions(1), false);
      // Products 2, 3, 4 should remain.
      expect(service.hasCachedSuggestions(2), true);
      expect(service.hasCachedSuggestions(3), true);
      expect(service.hasCachedSuggestions(4), true);
    });

    test('TTL and size work together — expired entries get replaced', () async {
      final MealInsightsService service = MealInsightsService(
        transactionRepository: transactionRepository,
        productRepository: productRepository,
        suggestionCacheTtl: const Duration(milliseconds: 1),
        maxCacheSize: 2,
      );

      final Map<int, String> names = <int, String>{1: 'Burger', 2: 'Fries'};

      await service.prefetchSuggestions(
        productIds: <int>[1],
        productNamesById: names,
      );
      expect(service.currentCacheSize, 1);

      // Wait for TTL to expire.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(service.hasCachedSuggestions(1), false);

      // Now adding 2 fresh entries should replace expired entry.
      await service.prefetchSuggestions(
        productIds: <int>[1, 2],
        productNamesById: names,
      );
      expect(service.currentCacheSize, 2);
      expect(service.hasCachedSuggestions(1), true);
      expect(service.hasCachedSuggestions(2), true);
    });

    test('currentCacheSize reports accurate count', () async {
      final MealInsightsService service = MealInsightsService(
        transactionRepository: transactionRepository,
        productRepository: productRepository,
        suggestionCacheTtl: const Duration(minutes: 5),
        maxCacheSize: 50,
      );

      expect(service.currentCacheSize, 0);

      await service.prefetchSuggestions(
        productIds: <int>[1, 2],
        productNamesById: <int, String>{1: 'Burger', 2: 'Fries'},
      );

      expect(service.currentCacheSize, 2);

      service.invalidateSuggestionCacheForProduct(1);
      expect(service.currentCacheSize, 1);

      service.invalidateSuggestionCache();
      expect(service.currentCacheSize, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // B. Pricing Rule Explanation (deterministic)
  // ─────────────────────────────────────────────────────────────────────────

  group('B. Pricing rule semantic meaning key', () {
    test('semanticMeaningKey is deterministic for same rule structure', () {
      const MealAdjustmentPricingRuleDraft rule1 =
          MealAdjustmentPricingRuleDraft(
            name: 'Rule A',
            ruleType: MealAdjustmentPricingRuleType.swap,
            priceDeltaMinor: 100,
            priority: 0,
            isActive: true,
            conditions: <MealAdjustmentPricingRuleConditionDraft>[
              MealAdjustmentPricingRuleConditionDraft(
                conditionType:
                    MealAdjustmentPricingRuleConditionType.swapToItem,
                componentKey: 'main',
                itemProductId: 2,
                quantity: 1,
              ),
            ],
          );
      const MealAdjustmentPricingRuleDraft rule2 =
          MealAdjustmentPricingRuleDraft(
            name: 'Rule B',
            ruleType: MealAdjustmentPricingRuleType.swap,
            priceDeltaMinor: 200,
            priority: 1,
            isActive: true,
            conditions: <MealAdjustmentPricingRuleConditionDraft>[
              MealAdjustmentPricingRuleConditionDraft(
                conditionType:
                    MealAdjustmentPricingRuleConditionType.swapToItem,
                componentKey: 'main',
                itemProductId: 2,
                quantity: 1,
              ),
            ],
          );

      expect(rule1.semanticMeaningKey, rule2.semanticMeaningKey);
    });

    test('different condition structure produces different meaning key', () {
      const MealAdjustmentPricingRuleDraft ruleSwap =
          MealAdjustmentPricingRuleDraft(
            name: 'Swap Rule',
            ruleType: MealAdjustmentPricingRuleType.swap,
            priceDeltaMinor: 100,
            priority: 0,
            isActive: true,
            conditions: <MealAdjustmentPricingRuleConditionDraft>[
              MealAdjustmentPricingRuleConditionDraft(
                conditionType:
                    MealAdjustmentPricingRuleConditionType.swapToItem,
                componentKey: 'main',
                itemProductId: 2,
                quantity: 1,
              ),
            ],
          );
      const MealAdjustmentPricingRuleDraft ruleExtra =
          MealAdjustmentPricingRuleDraft(
            name: 'Extra Rule',
            ruleType: MealAdjustmentPricingRuleType.extra,
            priceDeltaMinor: 100,
            priority: 0,
            isActive: true,
            conditions: <MealAdjustmentPricingRuleConditionDraft>[
              MealAdjustmentPricingRuleConditionDraft(
                conditionType:
                    MealAdjustmentPricingRuleConditionType.extraItem,
                itemProductId: 4,
                quantity: 1,
              ),
            ],
          );

      expect(
        ruleSwap.semanticMeaningKey,
        isNot(ruleExtra.semanticMeaningKey),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // F. Validation clarity — section counts
  // ─────────────────────────────────────────────────────────────────────────

  group('F. Validation section counts', () {
    test('validation result correctly reports affected sections', () async {
      // Profile with negative free swap limit (profile section error)
      // and active but empty components (components section error).
      const MealAdjustmentProfileDraft draft = MealAdjustmentProfileDraft(
        name: 'Bad Profile',
        freeSwapLimit: -1,
        isActive: true,
      );

      final MealAdjustmentValidationResult result =
          await validationService.validateDraft(draft);

      expect(result.canSave, false);
      expect(result.blockingErrors.length, greaterThanOrEqualTo(2));
      expect(
        result.affectedSections,
        containsAll(<MealAdjustmentValidationSection>[
          MealAdjustmentValidationSection.profile,
          MealAdjustmentValidationSection.components,
        ]),
      );
    });

    test('health summary provides headline and body', () async {
      const MealAdjustmentProfileDraft draft = MealAdjustmentProfileDraft(
        name: 'Valid Profile',
        freeSwapLimit: 0,
        isActive: false,
      );

      final MealAdjustmentProfileHealthSummary summary =
          await validationService.computeHealthSummary(draft);

      expect(summary.healthStatus, MealAdjustmentHealthStatus.valid);
      expect(summary.headline, isNotEmpty);
      expect(summary.body, isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Regression — Phase 6 + 7 contracts
  // ─────────────────────────────────────────────────────────────────────────

  group('Regression', () {
    test('engine determinism preserved after Phase 8 changes', () {
      // Ensure MealCustomizationEngine still evaluates deterministically.
      const MealCustomizationEngine engine = MealCustomizationEngine();

      const MealAdjustmentProfile profile = MealAdjustmentProfile(
        id: 1,
        name: 'Burger Combo',
        freeSwapLimit: 1,
        isActive: true,
        components: <MealAdjustmentComponent>[
          MealAdjustmentComponent(
            id: 1,
            profileId: 1,
            componentKey: 'side',
            displayName: 'Side',
            defaultItemProductId: 2,
            quantity: 1,
            canRemove: true,
            sortOrder: 0,
            isActive: true,
            swapOptions: <MealAdjustmentComponentOption>[
              MealAdjustmentComponentOption(
                id: 1,
                profileComponentId: 1,
                optionItemProductId: 3,
                sortOrder: 0,
                isActive: true,
              ),
            ],
          ),
        ],
      );

      const MealCustomizationRequest request = MealCustomizationRequest(
        productId: 1,
        profileId: 1,
        removedComponentKeys: <String>[],
        swapSelections: <MealCustomizationComponentSelection>[
          MealCustomizationComponentSelection(
            componentKey: 'side',
            targetItemProductId: 3,
          ),
        ],
        extraSelections: <MealCustomizationExtraSelection>[],
      );

      final MealCustomizationResolvedSnapshot snapshot1 = engine.evaluate(
        profile: profile,
        request: request,
      );
      final MealCustomizationResolvedSnapshot snapshot2 = engine.evaluate(
        profile: profile,
        request: request,
      );

      expect(snapshot1.stableIdentityKey, snapshot2.stableIdentityKey);
      expect(snapshot1.totalAdjustmentMinor, snapshot2.totalAdjustmentMinor);
      expect(snapshot1.actions.length, snapshot2.actions.length);
    });

    test('MealRevenueBreakdown fromTotals net calculation unchanged', () {
      final breakdown = MealRevenueBreakdown.fromTotals(
        baseMinor: 1000,
        extrasMinor: 200,
        paidSwapsMinor: 150,
        discountsMinor: 100,
      );

      expect(breakdown.netMinor, 1250);
      expect(breakdown.baseMinor, 1000);
    });

    test('suggestion cache invalidation still works', () async {
      final MealInsightsService service = MealInsightsService(
        transactionRepository: transactionRepository,
        productRepository: productRepository,
        suggestionCacheTtl: const Duration(minutes: 5),
        maxCacheSize: 50,
      );

      await service.prefetchSuggestions(
        productIds: <int>[1],
        productNamesById: <int, String>{1: 'Burger'},
      );

      expect(service.hasCachedSuggestions(1), true);
      service.invalidateSuggestionCacheForProduct(1);
      expect(service.hasCachedSuggestions(1), false);

      await service.prefetchSuggestions(
        productIds: <int>[1, 2],
        productNamesById: <int, String>{1: 'Burger', 2: 'Fries'},
      );
      service.invalidateSuggestionCache();
      expect(service.currentCacheSize, 0);
    });
  });
}
