import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/meal_adjustment_profile.dart';
import '../../domain/models/meal_customization.dart';
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
      errorMessage:
          errorMessage == _unset ? this.errorMessage : errorMessage as String?,
      successMessage: successMessage == _unset
          ? this.successMessage
          : successMessage as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AdminMealProfilesNotifier
    extends StateNotifier<AdminMealProfilesState> {
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
    int freeSwapLimit = 0,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final MealAdjustmentProfileDraft draft = MealAdjustmentProfileDraft(
        name: name,
        description: description,
        freeSwapLimit: freeSwapLimit,
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
      errorMessage:
          errorMessage == _unset ? this.errorMessage : errorMessage as String?,
      successMessage: successMessage == _unset
          ? this.successMessage
          : successMessage as String?,
    );
  }
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
      state = state.copyWith(
        draft: draft,
        isLoading: false,
        isDirty: false,
      );
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

  void initNewProfile({String name = 'New Profile'}) {
    state = state.copyWith(
      draft: MealAdjustmentProfileDraft(
        name: name,
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
    int? freeSwapLimit,
    bool? isActive,
  }) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null) return;
    state = state.copyWith(
      draft: current.copyWith(
        name: name,
        description: identical(description, _unset)
            ? current.description
            : description as String?,
        freeSwapLimit: freeSwapLimit,
        isActive: isActive,
      ),
      isDirty: true,
    );
    _revalidate();
  }

  void updateComponents(List<MealAdjustmentComponentDraft> components) {
    final MealAdjustmentProfileDraft? current = state.draft;
    if (current == null) return;
    state = state.copyWith(
      draft: current.copyWith(components: components),
      isDirty: true,
    );
    _revalidate();
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
    for (final MealAdjustmentValidationIssue issue
        in result.blockingErrors) {
      counts[issue.section] = (counts[issue.section] ?? 0) + 1;
    }
    for (final MealAdjustmentValidationIssue issue in result.warnings) {
      counts[issue.section] = (counts[issue.section] ?? 0) + 1;
    }
    return counts;
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

final StateNotifierProvider<AdminMealProfileEditorNotifier,
    AdminMealProfileEditorState>
adminMealProfileEditorNotifierProvider = StateNotifierProvider<
  AdminMealProfileEditorNotifier,
  AdminMealProfileEditorState
>((Ref ref) => AdminMealProfileEditorNotifier(ref));

const Object _unset = Object();
