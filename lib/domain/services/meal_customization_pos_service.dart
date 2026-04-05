import '../../core/errors/exceptions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/product_repository.dart';
import '../models/meal_adjustment_profile.dart';
import '../models/meal_customization.dart';
import '../models/product.dart';
import '../repositories/meal_adjustment_profile_repository.dart';
import 'meal_adjustment_profile_validation_service.dart';
import 'meal_customization_engine.dart';

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
  final String? stableIdentityKey;
  final int adjustmentMinor;
  final int finalLineTotalMinor;

  bool get canConfirm => validationMessages.isEmpty && snapshot != null;

  MealCustomizationCartSelection toCartSelection() {
    final MealCustomizationResolvedSnapshot resolvedSnapshot = snapshot ??
        (throw ValidationException(validationMessages.join('\n')));
    return MealCustomizationCartSelection(
      request: request,
      snapshot: resolvedSnapshot,
      stableIdentityKey: stableIdentityKey ?? resolvedSnapshot.stableIdentityKey,
      summaryLines: summaryLines,
      compactSummary: compactSummary,
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
  }) : _mealAdjustmentProfileRepository = mealAdjustmentProfileRepository,
       _validationService = validationService,
       _productRepository = productRepository,
       _engine = engine;

  final MealAdjustmentProfileRepository _mealAdjustmentProfileRepository;
  final MealAdjustmentProfileValidationService _validationService;
  final ProductRepository _productRepository;
  final MealCustomizationEngine _engine;

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
    };
    final Map<int, String> productNamesById = await _loadProductNames(productIds);
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
    final MealCustomizationRequest request = editorState.toRequest(
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
        editorState: editorState,
        request: request,
        snapshot: snapshot,
        validationMessages: const <String>[],
        summaryLines: summaryLines,
        compactSummary: _buildCompactSummary(summaryLines),
        stableIdentityKey: snapshot.stableIdentityKey,
        adjustmentMinor: snapshot.totalAdjustmentMinor,
        finalLineTotalMinor: product.priceMinor + snapshot.totalAdjustmentMinor,
      );
    } on MealCustomizationRequestRejectedException catch (error) {
      return MealCustomizationPosPreview(
        editorState: editorState,
        request: request,
        validationMessages: error.issues
            .map((MealCustomizationRequestIssue issue) => issue.message)
            .toList(growable: false),
        summaryLines: const <String>[],
        compactSummary: '',
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
    final int profileId = overrideProfileId ??
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
      final Set<int> breakfastProductIds =
          await _mealAdjustmentProfileRepository.loadBreakfastSemanticProductIds(
            <int>[product.id],
          );
      if (breakfastProductIds.contains(product.id)) {
        throw MealCustomizationRuntimeConfigurationException(
          productId: product.id,
          profileId: profileId,
          detail:
              'Breakfast semantic products cannot carry a meal-adjustment profile.',
        );
      }
    }
    return draft.toRuntimeProfile(profileId: profileId);
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

  List<String> _buildSummaryLines({
    required MealCustomizationResolvedSnapshot snapshot,
    required Map<int, String> productNamesById,
  }) {
    final List<String> lines = <String>[];
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedComponentActions) {
      switch (action.action) {
        case MealCustomizationAction.remove:
          final String itemName = _resolveProductName(
            action.itemProductId,
            productNamesById,
          );
          lines.add('No $itemName');
          break;
        case MealCustomizationAction.swap:
          final String sourceName = _resolveProductName(
            action.sourceItemProductId,
            productNamesById,
          );
          final String targetName = _resolveProductName(
            action.itemProductId,
            productNamesById,
          );
          final String priceSuffix = action.priceDeltaMinor == 0
              ? ''
              : ' ${_signedMoney(action.priceDeltaMinor)}';
          lines.add('$sourceName → $targetName$priceSuffix');
          break;
        case MealCustomizationAction.extra:
        case MealCustomizationAction.discount:
          break;
      }
    }
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedExtraActions) {
      final String itemName = _resolveProductName(
        action.itemProductId,
        productNamesById,
      );
      final String quantityPrefix = action.quantity > 1 ? '${action.quantity}x ' : '';
      lines.add(
        'Extra $quantityPrefix$itemName ${_signedMoney(action.priceDeltaMinor)}',
      );
    }
    for (final MealCustomizationSemanticAction action
        in snapshot.triggeredDiscounts) {
      lines.add('${_discountLabel(action)} ${_signedMoney(action.priceDeltaMinor)}');
    }
    return lines;
  }

  String _buildCompactSummary(List<String> summaryLines) {
    final List<String> trimmed = summaryLines
        .where((String line) => line.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    return trimmed.join(' · ');
  }

  String _resolveProductName(int? productId, Map<int, String> productNamesById) {
    if (productId == null) {
      return 'Unknown';
    }
    return productNamesById[productId] ?? 'Product $productId';
  }

  String _signedMoney(int amountMinor) {
    final String absolute = CurrencyFormatter.fromMinor(amountMinor.abs());
    if (amountMinor > 0) {
      return '+$absolute';
    }
    if (amountMinor < 0) {
      return '-$absolute';
    }
    return absolute;
  }

  String _discountLabel(MealCustomizationSemanticAction action) {
    switch (action.chargeReason) {
      case MealCustomizationChargeReason.comboDiscount:
        return 'Combo discount';
      case MealCustomizationChargeReason.removalDiscount:
        return 'Removal discount';
      case MealCustomizationChargeReason.freeSwap:
      case MealCustomizationChargeReason.paidSwap:
      case MealCustomizationChargeReason.extraAdd:
      case null:
        return 'Discount';
    }
  }
}
