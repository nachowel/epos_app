import '../../core/errors/exceptions.dart';
import '../../data/repositories/product_repository.dart';
import '../models/meal_adjustment_profile.dart';
import '../models/meal_customization.dart';
import '../models/meal_pricing_explanation.dart';
import '../models/product.dart';
import '../repositories/meal_adjustment_profile_repository.dart';
import 'meal_adjustment_profile_validation_service.dart';
import 'meal_customization_engine.dart';
import 'meal_pricing_explanation_builder.dart';

class MealCustomizationPosEditorData {
  const MealCustomizationPosEditorData({
    required this.product,
    required this.profile,
    required this.productNamesById,
    required this.preview,
  });

  final Product product;
  final MealAdjustmentProfile profile;
  final Map<int, String> productNamesById;
  final MealCustomizationPosPreview preview;
}

class MealCustomizationPosPreview {
  const MealCustomizationPosPreview({
    required this.editorState,
    required this.request,
    required this.validationMessages,
    required this.summaryLines,
    required this.compactSummary,
    required this.displayName,
    this.snapshot,
    this.stableIdentityKey,
    this.adjustmentMinor = 0,
    this.finalLineTotalMinor = 0,
  });

  final MealCustomizationEditorState editorState;
  final MealCustomizationRequest request;
  final MealCustomizationResolvedSnapshot? snapshot;
  final List<String> validationMessages;
  final List<String> summaryLines;
  final String compactSummary;
  final String displayName;
  final String? stableIdentityKey;
  final int adjustmentMinor;
  final int finalLineTotalMinor;

  bool get canConfirm => validationMessages.isEmpty && snapshot != null;

  MealCustomizationCartSelection toCartSelection() {
    final MealCustomizationResolvedSnapshot resolvedSnapshot =
        snapshot ?? (throw ValidationException(validationMessages.join('\n')));
    return MealCustomizationCartSelection(
      request: request,
      snapshot: resolvedSnapshot,
      stableIdentityKey:
          stableIdentityKey ?? resolvedSnapshot.stableIdentityKey,
      summaryLines: summaryLines,
      compactSummary: compactSummary,
      displayName: displayName,
      perUnitAdjustmentMinor: adjustmentMinor,
      perUnitLineTotalMinor: finalLineTotalMinor,
    );
  }
}

class MealCustomizationPosService {
  const MealCustomizationPosService({
    required MealAdjustmentProfileRepository mealAdjustmentProfileRepository,
    required MealAdjustmentProfileValidationService validationService,
    required ProductRepository productRepository,
    MealCustomizationEngine engine = const MealCustomizationEngine(),
    MealPricingExplanationBuilder pricingExplanationBuilder =
        const MealPricingExplanationBuilder(),
  }) : _mealAdjustmentProfileRepository = mealAdjustmentProfileRepository,
       _validationService = validationService,
       _productRepository = productRepository,
       _engine = engine,
       _pricingExplanationBuilder = pricingExplanationBuilder;

  final MealAdjustmentProfileRepository _mealAdjustmentProfileRepository;
  final MealAdjustmentProfileValidationService _validationService;
  final ProductRepository _productRepository;
  final MealCustomizationEngine _engine;
  final MealPricingExplanationBuilder _pricingExplanationBuilder;

  Future<MealCustomizationPosEditorData> loadEditorData({
    required Product product,
    MealCustomizationEditorState initialState =
        const MealCustomizationEditorState(),
  }) async {
    final MealAdjustmentProfile profile = await _loadRuntimeProfile(
      product: product,
    );
    return _buildEditorData(
      product: product,
      profile: profile,
      initialState: initialState,
    );
  }

  Future<MealCustomizationPosEditorData> loadEditorDataForPersistedProfile({
    required Product product,
    required int profileId,
    MealCustomizationEditorState initialState =
        const MealCustomizationEditorState(),
  }) async {
    final MealAdjustmentProfile profile = await _loadRuntimeProfile(
      product: product,
      overrideProfileId: profileId,
      enforceCurrentProductBinding: false,
      enforceBreakfastCompatibility: false,
    );
    return _buildEditorData(
      product: product,
      profile: profile,
      initialState: initialState,
    );
  }

  Future<MealCustomizationPosEditorData> _buildEditorData({
    required Product product,
    required MealAdjustmentProfile profile,
    required MealCustomizationEditorState initialState,
  }) async {
    final Set<int> productIds = <int>{
      product.id,
      for (final MealAdjustmentComponent component in profile.components)
        component.defaultItemProductId,
      for (final MealAdjustmentComponent component in profile.components)
        ...component.swapOptions.map(
          (MealAdjustmentComponentOption option) => option.optionItemProductId,
        ),
      for (final MealAdjustmentExtraOption option in profile.extraOptions)
        option.itemProductId,
      ...profile.sandwichSettings.sauceProductIds,
      ...initialState.sandwichSelection.sauceProductIds,
    };
    final Map<int, String> productNamesById = await _loadProductNames(
      productIds,
    );
    final MealCustomizationPosPreview preview = previewSelection(
      product: product,
      profile: profile,
      editorState: initialState,
      productNamesById: productNamesById,
    );
    return MealCustomizationPosEditorData(
      product: product,
      profile: profile,
      productNamesById: productNamesById,
      preview: preview,
    );
  }

  MealCustomizationPosPreview previewSelection({
    required Product product,
    required MealAdjustmentProfile profile,
    required MealCustomizationEditorState editorState,
    required Map<int, String> productNamesById,
  }) {
    final MealCustomizationEditorState normalizedEditorState =
        _normalizeEditorState(
          profile: profile,
          editorState: editorState,
          productNamesById: productNamesById,
        );
    final MealCustomizationRequest request = normalizedEditorState.toRequest(
      productId: product.id,
      profileId: profile.id,
    );
    try {
      final MealCustomizationResolvedSnapshot snapshot = _engine.evaluate(
        profile: profile,
        request: request,
      );
      final List<String> summaryLines = _buildSummaryLines(
        snapshot: snapshot,
        productNamesById: productNamesById,
      );
      return MealCustomizationPosPreview(
        editorState: normalizedEditorState,
        request: request,
        snapshot: snapshot,
        validationMessages: const <String>[],
        summaryLines: summaryLines,
        compactSummary: _buildCompactSummary(summaryLines),
        displayName: _buildDisplayName(product: product, snapshot: snapshot),
        stableIdentityKey: snapshot.stableIdentityKey,
        adjustmentMinor: snapshot.totalAdjustmentMinor,
        finalLineTotalMinor: product.priceMinor + snapshot.totalAdjustmentMinor,
      );
    } on MealCustomizationRequestRejectedException catch (error) {
      return MealCustomizationPosPreview(
        editorState: normalizedEditorState,
        request: request,
        validationMessages: error.issues
            .map((MealCustomizationRequestIssue issue) => issue.message)
            .toList(growable: false),
        summaryLines: const <String>[],
        compactSummary: '',
        displayName: product.name,
        finalLineTotalMinor: product.priceMinor,
      );
    }
  }

  MealCustomizationRehydrationResult rehydrateSnapshot({
    required MealCustomizationResolvedSnapshot snapshot,
    required int lineQuantity,
  }) {
    return MealCustomizationRehydrationResult(
      editorState: snapshot.toEditorState(),
      snapshot: snapshot,
      stableIdentityKey: snapshot.stableIdentityKey,
      lineQuantity: lineQuantity,
    );
  }

  Future<MealAdjustmentProfile> _loadRuntimeProfile({
    required Product product,
    int? overrideProfileId,
    bool enforceCurrentProductBinding = true,
    bool enforceBreakfastCompatibility = true,
  }) async {
    final int profileId =
        overrideProfileId ??
        product.mealAdjustmentProfileId ??
        (throw ValidationException(
          'Meal customization requires an assigned profile.',
        ));
    if (enforceCurrentProductBinding &&
        product.mealAdjustmentProfileId != profileId) {
      throw MealCustomizationRuntimeConfigurationException(
        productId: product.id,
        profileId: profileId,
        detail: 'Assigned meal-adjustment profile does not match the product.',
      );
    }
    final MealAdjustmentProfileDraft? draft =
        await _mealAdjustmentProfileRepository.loadProfileDraft(profileId);
    if (draft == null) {
      throw MealCustomizationRuntimeConfigurationException(
        productId: product.id,
        profileId: profileId,
        detail: 'Assigned meal-adjustment profile is missing.',
      );
    }
    if (!draft.isActive) {
      throw MealCustomizationRuntimeConfigurationException(
        productId: product.id,
        profileId: profileId,
        detail: 'Assigned meal-adjustment profile is inactive.',
      );
    }
    final MealAdjustmentValidationResult validationResult =
        await _validationService.validateDraft(draft);
    if (!validationResult.canSave) {
      throw MealCustomizationRuntimeConfigurationException(
        productId: product.id,
        profileId: profileId,
        detail: validationResult.message,
      );
    }
    if (enforceBreakfastCompatibility) {
      final Set<int> breakfastRootProductIds =
          await _mealAdjustmentProfileRepository
              .loadBreakfastSemanticRootProductIds(<int>[product.id]);
      if (breakfastRootProductIds.contains(product.id)) {
        throw MealCustomizationRuntimeConfigurationException(
          productId: product.id,
          profileId: profileId,
          detail: _buildBreakfastCompatibilityMessage(
            productName: product.name,
            profileName: draft.name,
          ),
        );
      }
    }
    return draft.toRuntimeProfile(profileId: profileId);
  }

  String _buildBreakfastCompatibilityMessage({
    required String productName,
    required String profileName,
  }) {
    return 'Product "$productName" cannot use meal-adjustment profile "$profileName" because it is configured as a breakfast semantic root product.';
  }

  Future<Map<int, String>> _loadProductNames(Set<int> productIds) async {
    final Map<int, String> names = <int, String>{};
    for (final int productId in productIds) {
      final Product? product = await _productRepository.getById(productId);
      if (product != null) {
        names[productId] = product.name;
      }
    }
    return names;
  }

  MealCustomizationEditorState _normalizeEditorState({
    required MealAdjustmentProfile profile,
    required MealCustomizationEditorState editorState,
    required Map<int, String> productNamesById,
  }) {
    if (profile.kind != MealAdjustmentProfileKind.sandwich) {
      return editorState;
    }
    final SandwichCustomizationSelection normalizedSandwichSelection =
        _normalizeSandwichSelection(
          selection: editorState.sandwichSelection,
          enabledSauceProductIds: profile.sandwichSettings.sauceProductIds,
          productNamesById: productNamesById,
        );
    if (normalizedSandwichSelection == editorState.sandwichSelection) {
      return editorState;
    }
    return editorState.copyWith(sandwichSelection: normalizedSandwichSelection);
  }

  SandwichCustomizationSelection _normalizeSandwichSelection({
    required SandwichCustomizationSelection selection,
    required List<int> enabledSauceProductIds,
    required Map<int, String> productNamesById,
  }) {
    final Map<String, int> enabledSauceIdsByLookupToken = <String, int>{};
    for (final int productId in enabledSauceProductIds) {
      final String? productName = productNamesById[productId];
      if (productName == null || productName.trim().isEmpty) {
        continue;
      }
      for (final String token in sandwichSauceLookupTokensForName(
        productName,
      )) {
        enabledSauceIdsByLookupToken[token] = productId;
      }
    }

    final List<int> mergedSauceIds = <int>[
      ...selection.sauceProductIds,
      ...selection.legacySauceLookupKeys
          .map(canonicalLegacySandwichSauceLookupKey)
          .whereType<String>()
          .map((String key) => enabledSauceIdsByLookupToken[key])
          .whereType<int>(),
    ];
    return selection.copyWith(
      sauceProductIds: normalizeSandwichSauceProductIds(mergedSauceIds),
      legacySauceLookupKeys: const <String>[],
    );
  }

  List<String> _buildSummaryLines({
    required MealCustomizationResolvedSnapshot snapshot,
    required Map<int, String> productNamesById,
  }) {
    final List<PricingExplanationLine> lines = _pricingExplanationBuilder
        .buildCartSummary(
          snapshot: snapshot,
          productNamesById: productNamesById,
        );
    return lines
        .map((PricingExplanationLine line) => line.label)
        .toList(growable: false);
  }

  String _buildCompactSummary(List<String> summaryLines) {
    final List<String> trimmed = summaryLines
        .where((String line) => line.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    return trimmed.join(' · ');
  }

  String _buildDisplayName({
    required Product product,
    required MealCustomizationResolvedSnapshot snapshot,
  }) {
    final SandwichBreadType? breadType = snapshot.sandwichSelection?.breadType;
    if (breadType == null) {
      return product.name;
    }
    return '${product.name} ${sandwichBreadLabel(breadType)}';
  }
}
