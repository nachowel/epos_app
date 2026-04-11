import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/models/category.dart';
import '../../domain/models/meal_adjustment_profile.dart';
import '../../domain/models/meal_customization.dart';
import '../../domain/models/product.dart';
import '../../domain/repositories/meal_adjustment_profile_repository.dart';
import '../../domain/services/meal_adjustment_profile_validation_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class AdminMealProfilesState {
  const AdminMealProfilesState({
    required this.profiles,
    required this.productCountByProfileId,
    required this.healthByProfileId,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
    required this.successMessage,
  });

  const AdminMealProfilesState.initial()
    : profiles = const <MealAdjustmentProfile>[],
      productCountByProfileId = const <int, int>{},
      healthByProfileId = const <int, MealAdjustmentHealthStatus>{},
      isLoading = false,
      isSaving = false,
      errorMessage = null,
      successMessage = null;

  final List<MealAdjustmentProfile> profiles;
  final Map<int, int> productCountByProfileId;
  final Map<int, MealAdjustmentHealthStatus> healthByProfileId;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  AdminMealProfilesState copyWith({
    List<MealAdjustmentProfile>? profiles,
    Map<int, int>? productCountByProfileId,
    Map<int, MealAdjustmentHealthStatus>? healthByProfileId,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return AdminMealProfilesState(
      profiles: profiles ?? this.profiles,
      productCountByProfileId:
          productCountByProfileId ?? this.productCountByProfileId,
      healthByProfileId: healthByProfileId ?? this.healthByProfileId,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: successMessage == _unset
          ? this.successMessage
          : successMessage as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AdminMealProfilesNotifier extends StateNotifier<AdminMealProfilesState> {
  AdminMealProfilesNotifier(this._ref)
    : super(const AdminMealProfilesState.initial());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      final List<MealAdjustmentProfile> profiles = await _ref
          .read(mealAdjustmentAdminServiceProvider)
          .listAllProfiles();
      final Map<int, int> productCounts = <int, int>{};
      final Map<int, MealAdjustmentHealthStatus> healthMap =
          <int, MealAdjustmentHealthStatus>{};
      for (final MealAdjustmentProfile profile in profiles) {
        final List<MealAdjustmentProductSummary> products = await _ref
            .read(mealAdjustmentAdminServiceProvider)
            .listProductsUsingProfile(profile.id);
        productCounts[profile.id] = products.length;
        try {
          final MealAdjustmentProfileDraft? draft = await _ref
              .read(mealAdjustmentProfileRepositoryProvider)
              .loadProfileDraft(profile.id);
          if (draft != null) {
            final MealAdjustmentProfileHealthSummary summary = await _ref
                .read(mealAdjustmentProfileValidationServiceProvider)
                .computeHealthSummary(draft);
            healthMap[profile.id] = summary.healthStatus;
          } else {
            healthMap[profile.id] = MealAdjustmentHealthStatus.invalid;
          }
        } catch (_) {
          healthMap[profile.id] = MealAdjustmentHealthStatus.invalid;
        }
      }
      state = state.copyWith(
        profiles: profiles,
        productCountByProfileId: productCounts,
        healthByProfileId: healthMap,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_meal_profiles_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<int?> createProfile({
    required String name,
    String? description,
    MealAdjustmentProfileKind kind = MealAdjustmentProfileKind.standard,
    int freeSwapLimit = 0,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final MealAdjustmentProfileDraft draft = MealAdjustmentProfileDraft(
        name: name,
        description: description,
        kind: kind,
        sandwichSettings: kind == MealAdjustmentProfileKind.sandwich
            ? SandwichProfileSettings(
                sauceProductIds: normalizeSandwichSauceProductIds(
                  (await _ref
                          .read(productRepositoryProvider)
                          .getSandwichSauceProducts())
                      .map((Product product) => product.id),
                ),
              )
            : const SandwichProfileSettings(),
        freeSwapLimit: kind == MealAdjustmentProfileKind.sandwich
            ? 0
            : freeSwapLimit,
        isActive: false,
      );
      final int profileId = await _ref
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(draft);
      await load();
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Profile "$name" created.',
      );
      return profileId;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_meal_profile_create_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<int?> duplicateProfile(int sourceProfileId) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final int newId = await _ref
          .read(mealAdjustmentAdminServiceProvider)
          .duplicateProfile(sourceProfileId);
      await load();
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Profile duplicated.',
      );
      return newId;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_meal_profile_duplicate_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<bool> archiveProfile(int profileId) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(mealAdjustmentAdminServiceProvider)
          .archiveProfile(profileId);
      await load();
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Profile archived.',
      );
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_meal_profile_archive_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> deleteProfile(int profileId) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(mealAdjustmentAdminServiceProvider)
          .deleteProfile(profileId);
      await load();
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Profile deleted.',
      );
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_meal_profile_delete_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draft editor state
// ─────────────────────────────────────────────────────────────────────────────

class AdminMealProfileEditorState {
  const AdminMealProfileEditorState({
    required this.draft,
    required this.validationResult,
    required this.healthSummary,
    required this.sectionValidationCounts,
    required this.previewSnapshot,
    required this.previewRequest,
    required this.ruleExplanations,
    required this.isLoading,
    required this.isSaving,
    required this.isDirty,
    required this.errorMessage,
    required this.successMessage,
  });

  const AdminMealProfileEditorState.initial()
    : draft = null,
      validationResult = null,
      healthSummary = null,
      sectionValidationCounts = const <MealAdjustmentValidationSection, int>{},
      previewSnapshot = null,
      previewRequest = null,
      ruleExplanations = const <int, String>{},
      isLoading = false,
      isSaving = false,
      isDirty = false,
      errorMessage = null,
      successMessage = null;

  final MealAdjustmentProfileDraft? draft;
  final MealAdjustmentValidationResult? validationResult;
  final MealAdjustmentProfileHealthSummary? healthSummary;
  final Map<MealAdjustmentValidationSection, int> sectionValidationCounts;
  final MealCustomizationResolvedSnapshot? previewSnapshot;
  final MealCustomizationRequest? previewRequest;
  final Map<int, String> ruleExplanations;
  final bool isLoading;
  final bool isSaving;
  final bool isDirty;
  final String? errorMessage;
  final String? successMessage;

  bool get canSave => validationResult?.canSave ?? false;
  bool get hasBlockingErrors =>
      validationResult != null && validationResult!.blockingErrors.isNotEmpty;
  bool get hasWarnings =>
      validationResult != null && validationResult!.warnings.isNotEmpty;

  AdminMealProfileEditorState copyWith({
    Object? draft = _unset,
    Object? validationResult = _unset,
    Object? healthSummary = _unset,
    Map<MealAdjustmentValidationSection, int>? sectionValidationCounts,
    Object? previewSnapshot = _unset,
    Object? previewRequest = _unset,
    Map<int, String>? ruleExplanations,
    bool? isLoading,
    bool? isSaving,
    bool? isDirty,
    Object? errorMessage = _unset,
    Object? successMessage = _unset,
  }) {
    return AdminMealProfileEditorState(
      draft: draft == _unset
          ? this.draft
          : draft as MealAdjustmentProfileDraft?,
      validationResult: validationResult == _unset
          ? this.validationResult
          : validationResult as MealAdjustmentValidationResult?,
      healthSummary: healthSummary == _unset
          ? this.healthSummary
          : healthSummary as MealAdjustmentProfileHealthSummary?,
      sectionValidationCounts:
          sectionValidationCounts ?? this.sectionValidationCounts,
      previewSnapshot: previewSnapshot == _unset
          ? this.previewSnapshot
          : previewSnapshot as MealCustomizationResolvedSnapshot?,
      previewRequest: previewRequest == _unset
          ? this.previewRequest
          : previewRequest as MealCustomizationRequest?,
      ruleExplanations: ruleExplanations ?? this.ruleExplanations,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: successMessage == _unset
          ? this.successMessage
          : successMessage as String?,
    );
  }
}

class AdminMealProfileProductOption {
  const AdminMealProfileProductOption({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.isActive,
    this.hasMealAdjustmentProfile = false,
    this.hasOwnedSemanticConfiguration = false,
  });

  final int id;
  final String name;
  final String categoryName;
  final bool isActive;
  final bool hasMealAdjustmentProfile;
  final bool hasOwnedSemanticConfiguration;

  String get searchLabel => '$name $categoryName'.toLowerCase();

  String get displayLabel => '$name · $categoryName';

  bool get isValidAddInCandidate =>
      isActive && !hasMealAdjustmentProfile && !hasOwnedSemanticConfiguration;

  bool get isSauceCategory =>
      categoryName.trim().toLowerCase() == kSaucesCategoryName.toLowerCase();
}

class AdminMealProfileProductCatalog {
  const AdminMealProfileProductCatalog({required this.products});

  final List<AdminMealProfileProductOption> products;

  List<AdminMealProfileProductOption> get activeProducts => products
      .where((AdminMealProfileProductOption product) => product.isActive)
      .toList(growable: false);

  List<AdminMealProfileProductOption> get activeAddInProducts => products
      .where(
        (AdminMealProfileProductOption product) =>
            product.isValidAddInCandidate,
      )
      .toList(growable: false);

  List<AdminMealProfileProductOption> get activeSauceProducts => products
      .where((AdminMealProfileProductOption product) {
        return product.isActive && product.isSauceCategory;
      })
      .toList(growable: false);

  Map<int, AdminMealProfileProductOption> get byId =>
      <int, AdminMealProfileProductOption>{
        for (final AdminMealProfileProductOption product in products)
          product.id: product,
      };
}

class AdminMealProfileEditorNotifier
    extends StateNotifier<AdminMealProfileEditorState> {
  AdminMealProfileEditorNotifier(this._ref)
    : super(const AdminMealProfileEditorState.initial());

  final Ref _ref;

  Future<void> loadProfile(int profileId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final MealAdjustmentProfileDraft draft = await _ref
          .read(mealAdjustmentAdminServiceProvider)
          .loadProfileDraft(profileId);
      state = state.copyWith(draft: draft, isLoading: false, isDirty: false);
      await _revalidate();
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_meal_profile_editor_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void initNewProfile({
    String name = 'New Profile',
    MealAdjustmentProfileKind kind = MealAdjustmentProfileKind.standard,
  }) {
    state = state.copyWith(
      draft: MealAdjustmentProfileDraft(
        name: name,
        kind: kind,
        freeSwapLimit: 0,
        isActive: false,
      ),
      isLoading: false,
      isDirty: true,
      errorMessage: null,
    );
    _revalidate();
  }

  void updateDraft(MealAdjustmentProfileDraft updatedDraft) {
    state = state.copyWith(draft: updatedDraft, isDirty: true);
    _revalidate();
  }

  void updateBasicInfo({
    String? name,
    Object? description = _unset,
    MealAdjustmentProfileKind? kind,
    int? freeSwapLimit,
    bool? isActive,
  }) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null) return;
    final MealAdjustmentProfileKind nextKind = kind ?? current.kind;
    state = state.copyWith(
      draft: current.copyWith(
        name: name,
        description: identical(description, _unset)
            ? current.description
            : description as String?,
        kind: nextKind,
        freeSwapLimit: nextKind == MealAdjustmentProfileKind.sandwich
            ? 0
            : freeSwapLimit,
        isActive: isActive,
        components: nextKind == MealAdjustmentProfileKind.sandwich
            ? const <MealAdjustmentComponentDraft>[]
            : current.components,
        pricingRules: nextKind == MealAdjustmentProfileKind.sandwich
            ? const <MealAdjustmentPricingRuleDraft>[]
            : current.pricingRules,
      ),
      isDirty: true,
    );
    _revalidate();
  }

  void updateComponents(List<MealAdjustmentComponentDraft> components) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null) return;
    final List<MealAdjustmentComponentDraft> normalized = components
        .asMap()
        .entries
        .map((MapEntry<int, MealAdjustmentComponentDraft> entry) {
          final List<MealAdjustmentComponentOptionDraft> swapOptions = entry
              .value
              .swapOptions
              .asMap()
              .entries
              .map((MapEntry<int, MealAdjustmentComponentOptionDraft> option) {
                return option.value.copyWith(sortOrder: option.key);
              })
              .toList(growable: false);
          return entry.value.copyWith(
            sortOrder: entry.key,
            swapOptions: swapOptions,
          );
        })
        .toList(growable: false);
    state = state.copyWith(
      draft: current.copyWith(components: normalized),
      isDirty: true,
    );
    _revalidate();
  }

  void addComponent() {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null) return;
    final List<MealAdjustmentComponentDraft> updated =
        List<MealAdjustmentComponentDraft>.from(current.components)..add(
          MealAdjustmentComponentDraft(
            componentKey: 'component_${current.components.length + 1}',
            displayName: '',
            defaultItemProductId: 0,
            quantity: 1,
            canRemove: true,
            sortOrder: current.components.length,
            isActive: true,
          ),
        );
    updateComponents(updated);
  }

  void updateComponentAt(int index, MealAdjustmentComponentDraft component) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null || index < 0 || index >= current.components.length) {
      return;
    }
    final List<MealAdjustmentComponentDraft> updated =
        List<MealAdjustmentComponentDraft>.from(current.components);
    updated[index] = component;
    updateComponents(updated);
  }

  void removeComponentAt(int index) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null || index < 0 || index >= current.components.length) {
      return;
    }
    final List<MealAdjustmentComponentDraft> updated =
        List<MealAdjustmentComponentDraft>.from(current.components)
          ..removeAt(index);
    updateComponents(updated);
  }

  void updateExtras(List<MealAdjustmentExtraOptionDraft> extras) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null) return;
    state = state.copyWith(
      draft: current.copyWith(extraOptions: extras),
      isDirty: true,
    );
    _revalidate();
  }

  void updateSandwichSettings(SandwichProfileSettings sandwichSettings) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null) return;
    state = state.copyWith(
      draft: current.copyWith(sandwichSettings: sandwichSettings),
      isDirty: true,
    );
    _revalidate();
  }

  void updatePricingRules(List<MealAdjustmentPricingRuleDraft> rules) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null) return;
    state = state.copyWith(
      draft: current.copyWith(pricingRules: rules),
      isDirty: true,
    );
    _revalidate();
  }

  Future<bool> save() async {
    final MealAdjustmentProfileDraft? draft = state.draft;
    if (draft == null) return false;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final int profileId = await _ref
          .read(mealAdjustmentAdminServiceProvider)
          .saveProfileDraft(draft);
      final MealAdjustmentProfileDraft savedDraft = await _ref
          .read(mealAdjustmentAdminServiceProvider)
          .loadProfileDraft(profileId);
      state = state.copyWith(
        draft: savedDraft,
        isSaving: false,
        isDirty: false,
        successMessage: 'Profile saved.',
      );
      await _revalidate();
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_meal_profile_editor_save_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<void> _revalidate() async {
    final MealAdjustmentProfileDraft? draft = state.draft;
    if (draft == null) return;
    try {
      final MealAdjustmentValidationResult validationResult = await _ref
          .read(mealAdjustmentProfileValidationServiceProvider)
          .validateDraft(draft);
      final MealAdjustmentProfileHealthSummary healthSummary = await _ref
          .read(mealAdjustmentProfileValidationServiceProvider)
          .computeHealthSummary(draft);
      final Map<MealAdjustmentValidationSection, int> sectionCounts =
          _computeSectionCounts(validationResult);
      final Map<int, String> explanations = _buildRuleExplanations(draft);
      state = state.copyWith(
        validationResult: validationResult,
        healthSummary: healthSummary,
        sectionValidationCounts: sectionCounts,
        ruleExplanations: explanations,
      );
    } catch (_) {
      // Validation failure during editing is non-fatal.
    }
  }

  Map<MealAdjustmentValidationSection, int> _computeSectionCounts(
    MealAdjustmentValidationResult result,
  ) {
    final Map<MealAdjustmentValidationSection, int> counts =
        <MealAdjustmentValidationSection, int>{};
    for (final MealAdjustmentValidationIssue issue in result.blockingErrors) {
      final MealAdjustmentValidationSection targetSection =
          _resolveEditorSection(issue);
      counts[targetSection] = (counts[targetSection] ?? 0) + 1;
    }
    for (final MealAdjustmentValidationIssue issue in result.warnings) {
      final MealAdjustmentValidationSection targetSection =
          _resolveEditorSection(issue);
      counts[targetSection] = (counts[targetSection] ?? 0) + 1;
    }
    return counts;
  }

  MealAdjustmentValidationSection _resolveEditorSection(
    MealAdjustmentValidationIssue issue,
  ) {
    switch (issue.section) {
      case MealAdjustmentValidationSection.swaps:
        return MealAdjustmentValidationSection.components;
      case MealAdjustmentValidationSection.references:
        if (issue.componentKey != null) {
          return MealAdjustmentValidationSection.components;
        }
        if (issue.ruleId != null) {
          return MealAdjustmentValidationSection.rules;
        }
        return MealAdjustmentValidationSection.extras;
      case MealAdjustmentValidationSection.assignments:
      case MealAdjustmentValidationSection.products:
        return MealAdjustmentValidationSection.profile;
      case MealAdjustmentValidationSection.profile:
      case MealAdjustmentValidationSection.components:
      case MealAdjustmentValidationSection.extras:
      case MealAdjustmentValidationSection.rules:
        return issue.section;
    }
  }

  Map<int, String> _buildRuleExplanations(MealAdjustmentProfileDraft draft) {
    final Map<int, String> explanations = <int, String>{};
    for (final MealAdjustmentPricingRuleDraft rule in draft.pricingRules) {
      final int key = rule.id ?? rule.hashCode;
      explanations[key] = _explainRule(rule);
    }
    return explanations;
  }

  String _explainRule(MealAdjustmentPricingRuleDraft rule) {
    final String typeLabel = switch (rule.ruleType) {
      MealAdjustmentPricingRuleType.removeOnly => 'Remove discount',
      MealAdjustmentPricingRuleType.combo => 'Combo pricing',
      MealAdjustmentPricingRuleType.swap => 'Swap pricing',
      MealAdjustmentPricingRuleType.extra => 'Extra pricing',
    };
    final String deltaLabel = rule.priceDeltaMinor >= 0
        ? '+${(rule.priceDeltaMinor / 100).toStringAsFixed(2)}'
        : (rule.priceDeltaMinor / 100).toStringAsFixed(2);
    final String conditionSummary = rule.conditions.isEmpty
        ? 'no conditions'
        : '${rule.conditions.length} condition(s)';
    final String activeLabel = rule.isActive ? '' : ' [INACTIVE]';
    return '$typeLabel: $deltaLabel with $conditionSummary (priority ${rule.priority})$activeLabel';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final StateNotifierProvider<AdminMealProfilesNotifier, AdminMealProfilesState>
adminMealProfilesNotifierProvider =
    StateNotifierProvider<AdminMealProfilesNotifier, AdminMealProfilesState>(
      (Ref ref) => AdminMealProfilesNotifier(ref),
    );

final StateNotifierProvider<
  AdminMealProfileEditorNotifier,
  AdminMealProfileEditorState
>
adminMealProfileEditorNotifierProvider =
    StateNotifierProvider<
      AdminMealProfileEditorNotifier,
      AdminMealProfileEditorState
    >((Ref ref) => AdminMealProfileEditorNotifier(ref));

final FutureProvider<AdminMealProfileProductCatalog>
adminMealProfileProductCatalogProvider =
    FutureProvider<AdminMealProfileProductCatalog>((Ref ref) async {
      final List<Category> categories = await ref
          .read(categoryRepositoryProvider)
          .getAll(activeOnly: false);
      final Map<int, String> categoryNames = <int, String>{
        for (final Category category in categories) category.id: category.name,
      };
      final List<Product> products = await ref
          .read(productRepositoryProvider)
          .getAll(activeOnly: false);
      final ProductRepository productRepository = ref.read(
        productRepositoryProvider,
      );
      final Set<int> semanticRootProductIds = (await Future.wait(
        products.map((Product product) async {
          final bool hasOwnedSemanticConfiguration = await productRepository
              .hasOwnedSemanticConfiguration(product.id);
          return hasOwnedSemanticConfiguration ? product.id : null;
        }),
      )).whereType<int>().toSet();
      final List<AdminMealProfileProductOption> options =
          products
              .map((Product product) {
                return AdminMealProfileProductOption(
                  id: product.id,
                  name: product.name,
                  categoryName:
                      categoryNames[product.categoryId] ?? 'Unknown Category',
                  isActive: product.isActive,
                  hasMealAdjustmentProfile:
                      product.mealAdjustmentProfileId != null,
                  hasOwnedSemanticConfiguration: semanticRootProductIds
                      .contains(product.id),
                );
              })
              .toList(growable: false)
            ..sort((
              AdminMealProfileProductOption a,
              AdminMealProfileProductOption b,
            ) {
              final int nameCompare = a.name.toLowerCase().compareTo(
                b.name.toLowerCase(),
              );
              if (nameCompare != 0) {
                return nameCompare;
              }
              final int categoryCompare = a.categoryName
                  .toLowerCase()
                  .compareTo(b.categoryName.toLowerCase());
              if (categoryCompare != 0) {
                return categoryCompare;
              }
              return a.id.compareTo(b.id);
            });
      return AdminMealProfileProductCatalog(products: options);
    });

const Object _unset = Object();
