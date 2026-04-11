import '../../core/errors/exceptions.dart';
import '../models/meal_adjustment_profile.dart';
import '../models/meal_customization.dart';
import '../repositories/meal_adjustment_profile_repository.dart';
import 'meal_adjustment_profile_validation_service.dart';
import 'meal_customization_engine.dart';

class MealAdjustmentAdminService {
  const MealAdjustmentAdminService({
    required MealAdjustmentProfileRepository repository,
    required MealAdjustmentProfileValidationService validationService,
    MealCustomizationEngine engine = const MealCustomizationEngine(),
  }) : _repository = repository,
       _validationService = validationService,
       _engine = engine;

  final MealAdjustmentProfileRepository _repository;
  final MealAdjustmentProfileValidationService _validationService;
  final MealCustomizationEngine _engine;

  Future<MealAdjustmentProfileDraft> loadProfileDraft(int profileId) async {
    final MealAdjustmentProfileDraft? draft = await _repository
        .loadProfileDraft(profileId);
    if (draft == null) {
      throw NotFoundException('Meal adjustment profile not found: $profileId');
    }
    return draft;
  }

  Future<MealAdjustmentValidationResult> validateProfileDraft(
    MealAdjustmentProfileDraft draft,
  ) {
    return _validationService.validateDraft(draft);
  }

  Future<MealAdjustmentProfileHealthSummary> computeHealthSummary(
    MealAdjustmentProfileDraft draft,
  ) {
    return _validationService.computeHealthSummary(draft);
  }

  Future<MealCustomizationResolvedSnapshot> previewEvaluation({
    required MealAdjustmentProfileDraft draft,
    required MealCustomizationRequest request,
  }) async {
    final MealAdjustmentValidationResult validationResult =
        await _validationService.validateDraft(draft);
    if (!validationResult.canSave) {
      throw MealAdjustmentProfileValidationException(validationResult);
    }

    final int previewProfileId = draft.id ?? -1;
    return _engine.evaluate(
      profile: draft.toRuntimeProfile(profileId: previewProfileId),
      request: request.copyWith(profileId: previewProfileId),
    );
  }

  Future<int> saveProfileDraft(MealAdjustmentProfileDraft draft) async {
    final MealAdjustmentValidationResult validationResult =
        await _validationService.validateDraft(draft);
    if (!validationResult.canSave) {
      throw MealAdjustmentProfileValidationException(validationResult);
    }
    return _repository.saveProfileDraft(draft);
  }

  Future<void> assignProfileToProduct({
    required int productId,
    required int profileId,
  }) async {
    final MealAdjustmentProfileDraft draft = await loadProfileDraft(profileId);
    final MealAdjustmentValidationResult draftValidation =
        await _validationService.validateDraft(draft);
    if (!draftValidation.canSave) {
      throw MealAdjustmentProfileValidationException(draftValidation);
    }

    final MealAdjustmentValidationResult assignmentValidation =
        await _validationService.validateProductAssignment(
          productId: productId,
          profileId: profileId,
        );
    if (!assignmentValidation.canSave) {
      throw MealAdjustmentProfileValidationException(assignmentValidation);
    }

    final bool updated = await _repository.assignProfileToProduct(
      productId: productId,
      profileId: profileId,
    );
    if (!updated) {
      throw NotFoundException('Product not found: $productId');
    }
  }

  Future<void> unassignProfileFromProduct(int productId) async {
    final bool updated = await _repository.assignProfileToProduct(
      productId: productId,
      profileId: null,
    );
    if (!updated) {
      throw NotFoundException('Product not found: $productId');
    }
  }

  Future<List<MealAdjustmentProductSummary>> listProductsUsingProfile(
    int profileId,
  ) {
    return _repository.listProductsByProfile(profileId);
  }

  Future<List<MealAdjustmentProfile>> listAllProfiles() {
    return _repository.listProfilesForAdmin();
  }

  Future<int> duplicateProfile(int sourceProfileId) async {
    final MealAdjustmentProfileDraft source = await loadProfileDraft(
      sourceProfileId,
    );
    final MealAdjustmentProfileDraft duplicated = source.duplicate();
    return _repository.saveProfileDraft(duplicated);
  }

  Future<int> archiveProfile(int profileId) async {
    final MealAdjustmentProfileDraft draft = await loadProfileDraft(profileId);
    final MealAdjustmentProfileDraft archived = MealAdjustmentProfileDraft(
      id: draft.id,
      name: draft.name,
      description: draft.description,
      kind: draft.kind,
      freeSwapLimit: draft.freeSwapLimit,
      isActive: false,
      components: draft.components,
      extraOptions: draft.extraOptions,
      pricingRules: draft.pricingRules,
    );
    return _repository.saveProfileDraft(archived);
  }

  Future<bool> deleteProfile(int profileId) async {
    final List<MealAdjustmentProductSummary> usages = await _repository
        .listProductsByProfile(profileId);
    if (usages.isNotEmpty) {
      throw MealAdjustmentProfileInUseException(
        profileId: profileId,
        productCount: usages.length,
      );
    }
    return _repository.deleteProfile(profileId);
  }
}
