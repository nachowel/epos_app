import '../../core/errors/error_mapper.dart';
import '../../core/errors/exceptions.dart';
import '../models/breakfast_cooking_instruction.dart';
import '../../data/repositories/breakfast_configuration_repository.dart';
import '../models/breakfast_cart_selection.dart';
import '../models/breakfast_rebuild.dart';
import '../models/product.dart';
import '../models/semantic_product_configuration.dart';
import '../models/transaction_line.dart';
import 'breakfast_cooking_instruction_service.dart';
import 'breakfast_rebuild_engine.dart';
import 'semantic_menu_policy_service.dart';

enum PosProductSelectionPath { standard, legacyFlat, semanticBundle }

class BreakfastPosAddableProduct {
  const BreakfastPosAddableProduct({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.sortKey,
    required this.isChoiceCapable,
    required this.isSwapEligible,
  });

  final int id;
  final String name;
  final int priceMinor;
  final int sortKey;
  final bool isChoiceCapable;
  final bool isSwapEligible;
}

class BreakfastPosSelectionPreview {
  const BreakfastPosSelectionPreview({
    required this.requestedState,
    required this.rebuildResult,
    required this.validationMessages,
    required this.addableProducts,
    required this.cookingTargets,
  });

  final BreakfastRequestedState requestedState;
  final BreakfastRebuildResult rebuildResult;
  final List<String> validationMessages;
  final List<BreakfastPosAddableProduct> addableProducts;
  final List<BreakfastCookingInstructionTarget> cookingTargets;

  bool get canConfirm => validationMessages.isEmpty;

  BreakfastCartSelection toCartSelection({
    required BreakfastSetConfiguration configuration,
  }) {
    if (!canConfirm) {
      throw ValidationException(validationMessages.join('\n'));
    }
    return BreakfastCartSelection(
      requestedState: requestedState,
      rebuildResult: rebuildResult,
      modifierDisplayLines: _buildModifierDisplayLines(),
      choiceDisplayLines: _buildChoiceDisplayLines(
        configuration: configuration,
      ),
      cookingDisplayLines: cookingTargets
          .where(
            (BreakfastCookingInstructionTarget target) => target.hasSelection,
          )
          .map(
            (BreakfastCookingInstructionTarget target) =>
                BreakfastCookingInstructionDisplayLine(
                  itemName: target.itemName,
                  instructionLabel: target.selectedInstructionLabel!,
                ),
          )
          .toList(growable: false),
    );
  }

  List<BreakfastCartModifierDisplayLine> _buildModifierDisplayLines() {
    final List<BreakfastCartModifierDisplayLine> lines =
        <BreakfastCartModifierDisplayLine>[];
    for (final BreakfastClassifiedModifier modifier
        in rebuildResult.classifiedModifiers) {
      final String quantitySuffix = modifier.quantity > 1
          ? ' x${modifier.quantity}'
          : '';
      switch (modifier.kind) {
        case BreakfastModifierKind.setRemove:
          lines.add(
            BreakfastCartModifierDisplayLine(
              prefix: '-',
              itemName: '${modifier.displayName}$quantitySuffix',
              tone: BreakfastCartModifierTone.removed,
            ),
          );
        case BreakfastModifierKind.choiceIncluded:
          break;
        case BreakfastModifierKind.extraAdd:
        case BreakfastModifierKind.freeSwap:
        case BreakfastModifierKind.paidSwap:
          lines.add(
            BreakfastCartModifierDisplayLine(
              prefix: '+',
              itemName: '${modifier.displayName}$quantitySuffix',
              tone: BreakfastCartModifierTone.added,
            ),
          );
      }
    }
    return lines;
  }

  List<BreakfastCartChoiceDisplayLine> _buildChoiceDisplayLines({
    required BreakfastSetConfiguration configuration,
  }) {
    final List<BreakfastCartChoiceDisplayLine> lines =
        <BreakfastCartChoiceDisplayLine>[];
    for (final BreakfastChoiceGroupConfig group in configuration.choiceGroups) {
      BreakfastChosenGroupRequest? selectedChoice;
      for (final BreakfastChosenGroupRequest choice
          in requestedState.chosenGroups) {
        if (choice.groupId == group.groupId) {
          selectedChoice = choice;
          break;
        }
      }
      if (selectedChoice == null) {
        continue;
      }
      String selectedLabel = breakfastNoneChoiceDisplayName;
      if (!selectedChoice.isExplicitNone) {
        for (final BreakfastChoiceGroupMemberConfig member in group.members) {
          if (member.itemProductId == selectedChoice.selectedItemProductId) {
            selectedLabel = member.displayName;
            break;
          }
        }
      }
      lines.add(
        BreakfastCartChoiceDisplayLine(
          groupName: group.groupName.replaceAll(
            RegExp(r'\s+choice$', caseSensitive: false),
            '',
          ),
          selectedLabel: selectedLabel,
        ),
      );
    }
    return lines;
  }
}

class BreakfastPosEditorData {
  const BreakfastPosEditorData({
    required this.product,
    required this.profile,
    required this.configuration,
    required this.preview,
  });

  final Product product;
  final ProductMenuConfigurationProfile profile;
  final BreakfastSetConfiguration configuration;
  final BreakfastPosSelectionPreview preview;
}

class BreakfastPosService {
  BreakfastPosService({
    required BreakfastConfigurationRepository breakfastConfigurationRepository,
    BreakfastRebuildEngine breakfastRebuildEngine =
        const BreakfastRebuildEngine(),
    BreakfastCookingInstructionService cookingInstructionService =
        const BreakfastCookingInstructionService(),
    SemanticMenuPolicyService policyService = const SemanticMenuPolicyService(),
  }) : _breakfastConfigurationRepository = breakfastConfigurationRepository,
       _breakfastRebuildEngine = breakfastRebuildEngine,
       _cookingInstructionService = cookingInstructionService,
       _policyService = policyService;

  final BreakfastConfigurationRepository _breakfastConfigurationRepository;
  final BreakfastRebuildEngine _breakfastRebuildEngine;
  final BreakfastCookingInstructionService _cookingInstructionService;
  final SemanticMenuPolicyService _policyService;

  Future<PosProductSelectionPath> getSelectionPath(Product product) async {
    final ProductMenuConfigurationProfile profile = await _loadProfile(
      product.id,
    );
    if (profile.hasSemanticSetConfig) {
      return PosProductSelectionPath.semanticBundle;
    }
    if (profile.hasLegacyFlatConfig || product.hasModifiers) {
      return PosProductSelectionPath.legacyFlat;
    }
    return PosProductSelectionPath.standard;
  }

  Future<BreakfastPosEditorData> loadEditorData({
    required Product product,
    BreakfastRequestedState requestedState = const BreakfastRequestedState(),
  }) async {
    final ProductMenuConfigurationProfile profile = await _loadProfile(
      product.id,
    );
    final BreakfastSetConfiguration? baseConfiguration =
        await _breakfastConfigurationRepository.loadSetConfiguration(
          product.id,
        );
    if (!profile.hasSemanticSetConfig || baseConfiguration == null) {
      throw ValidationException(
        'This bundle is not ready for sale. Ask an admin to complete its set configuration.',
      );
    }
    final SemanticMenuValidationResult policyResult = _policyService
        .validateRuntime(profile: profile, configuration: baseConfiguration);
    if (!policyResult.canSave) {
      throw ValidationException(policyResult.errors.join('\n'));
    }

    final BreakfastSetConfiguration configuration = await _augmentConfiguration(
      baseConfiguration: baseConfiguration,
      requestedState: requestedState,
    );
    return BreakfastPosEditorData(
      product: product,
      profile: profile,
      configuration: configuration,
      preview: previewSelection(
        product: product,
        configuration: configuration,
        requestedState: requestedState,
      ),
    );
  }

  BreakfastPosSelectionPreview previewSelection({
    required Product product,
    required BreakfastSetConfiguration configuration,
    required BreakfastRequestedState requestedState,
  }) {
    final BreakfastRequestedState normalizedRequestedState =
        _cookingInstructionService.sanitizeRequestedState(
          configuration: configuration,
          requestedState: requestedState,
        );
    final BreakfastRebuildResult rebuildResult = _breakfastRebuildEngine
        .rebuild(
          BreakfastRebuildInput(
            transactionLine: BreakfastTransactionLineInput(
              lineId: 0,
              lineUuid: 'pos-preview',
              rootProductId: product.id,
              rootProductName: product.name,
              baseUnitPriceMinor: product.priceMinor,
              lineQuantity: 1,
              pricingMode: TransactionLinePricingMode.set,
            ),
            setConfiguration: configuration,
            requestedState: normalizedRequestedState,
          ),
        );

    final validationMessages = {
      ..._toOperatorValidationMessages(
        configuration: configuration,
        requestedState: normalizedRequestedState,
      ),
      ...rebuildResult.validationErrors
          .map(ErrorMapper.toUserMessage)
          .whereType<String>(),
    }.toList(growable: false);

    return BreakfastPosSelectionPreview(
      requestedState: normalizedRequestedState,
      rebuildResult: rebuildResult,
      validationMessages: validationMessages,
      addableProducts: _buildAddableProducts(configuration: configuration),
      cookingTargets: _cookingInstructionService.buildTargets(
        configuration: configuration,
        requestedState: normalizedRequestedState,
      ),
    );
  }

  Future<BreakfastCartSelection> buildCartSelection({
    required Product product,
    required BreakfastRequestedState requestedState,
  }) async {
    final BreakfastPosEditorData editorData = await loadEditorData(
      product: product,
      requestedState: requestedState,
    );
    return editorData.preview.toCartSelection(
      configuration: editorData.configuration,
    );
  }

  Future<ProductMenuConfigurationProfile> _loadProfile(int productId) async {
    final Map<int, ProductMenuConfigurationProfile> profiles =
        await _breakfastConfigurationRepository.loadConfigurationProfiles(<int>[
          productId,
        ]);
    return profiles[productId] ??
        ProductMenuConfigurationProfile(
          productId: productId,
          flatModifierCount: 0,
          setItemCount: 0,
          choiceGroupCount: 0,
          choiceMemberCount: 0,
        );
  }

  Future<BreakfastSetConfiguration> _augmentConfiguration({
    required BreakfastSetConfiguration baseConfiguration,
    required BreakfastRequestedState requestedState,
  }) async {
    final Set<int> missingProductIds = <int>{};
    for (final BreakfastAddedProductRequest add
        in requestedState.addedProducts) {
      if (baseConfiguration.findCatalogProduct(add.itemProductId) == null) {
        missingProductIds.add(add.itemProductId);
      }
    }
    for (final BreakfastChosenGroupRequest choice
        in requestedState.chosenGroups) {
      final int? selectedItemProductId = choice.selectedItemProductId;
      if (selectedItemProductId != null &&
          baseConfiguration.findCatalogProduct(selectedItemProductId) == null) {
        missingProductIds.add(selectedItemProductId);
      }
    }
    if (missingProductIds.isEmpty) {
      return baseConfiguration;
    }

    final Map<int, BreakfastCatalogProduct> extraProducts =
        await _breakfastConfigurationRepository.loadCatalogProductsByIds(
          missingProductIds,
        );
    return baseConfiguration.copyWith(
      catalogProductsById: <int, BreakfastCatalogProduct>{
        ...baseConfiguration.catalogProductsById,
        ...extraProducts,
      },
    );
  }

  List<String> _toOperatorValidationMessages({
    required BreakfastSetConfiguration configuration,
    required BreakfastRequestedState requestedState,
  }) {
    final List<String> messages = <String>[];
    final Map<int, BreakfastChosenGroupRequest> choicesByGroupId =
        <int, BreakfastChosenGroupRequest>{
          for (final BreakfastChosenGroupRequest choice
              in requestedState.chosenGroups)
            choice.groupId: choice,
        };

    for (final BreakfastChoiceGroupConfig group in configuration.choiceGroups) {
      final BreakfastChosenGroupRequest? choice =
          choicesByGroupId[group.groupId];
      final bool hasSelection = choice?.hasSelection ?? false;

      if (group.maxSelect > 1) {
        messages.add(
          '${group.groupName} allows more than one selection. Ask an admin to change it to one selection before selling.',
        );
        continue;
      }

      if (group.minSelect > 0 && !hasSelection) {
        messages.add('Choose an option for ${group.groupName}.');
      }
    }

    for (final BreakfastRemovedSetItemRequest removal
        in requestedState.removedSetItems) {
      BreakfastSetItemConfig? item;
      for (final BreakfastSetItemConfig candidate in configuration.setItems) {
        if (candidate.itemProductId == removal.itemProductId) {
          item = candidate;
          break;
        }
      }
      if (item == null) {
        messages.add(
          'This bundle was updated and one removed item is no longer part of it. Reopen the bundle and choose again.',
        );
        continue;
      }
      if (!item.isRemovable && removal.quantity > 0) {
        messages.add(
          '${item.itemName} is fixed in this bundle and cannot be removed.',
        );
      }
    }

    for (final BreakfastAddedProductRequest add
        in requestedState.addedProducts) {
      if (!configuration.isExplicitExtraProduct(add.itemProductId)) {
        messages.add('This extra is not available for this breakfast.');
      }
    }

    return messages;
  }

  List<BreakfastPosAddableProduct> _buildAddableProducts({
    required BreakfastSetConfiguration configuration,
  }) {
    final List<BreakfastPosAddableProduct> products = configuration.extras
        .map((BreakfastExtraItemConfig extra) {
          final BreakfastCatalogProduct? product = configuration
              .findCatalogProduct(extra.itemProductId);
          if (product == null) {
            return null;
          }
          return BreakfastPosAddableProduct(
            id: product.id,
            name: product.name,
            priceMinor: product.priceMinor,
            sortKey: extra.sortOrder,
            isChoiceCapable: configuration.choiceCapableProductIds.contains(
              product.id,
            ),
            isSwapEligible: configuration.swapEligibleProductIds.contains(
              product.id,
            ),
          );
        })
        .whereType<BreakfastPosAddableProduct>()
        .toList(growable: true);

    products.sort((BreakfastPosAddableProduct a, BreakfastPosAddableProduct b) {
      final int sortCompare = a.sortKey.compareTo(b.sortKey);
      if (sortCompare != 0) {
        return sortCompare;
      }
      return a.name.compareTo(b.name);
    });
    return products;
  }
}
