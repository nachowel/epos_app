import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/breakfast_configuration_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../models/breakfast_extra_preset.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/semantic_product_configuration.dart';
import '../models/user.dart';
import 'semantic_menu_policy_service.dart';

class SemanticMenuAdminService {
  const SemanticMenuAdminService({
    required ProductRepository productRepository,
    required CategoryRepository categoryRepository,
    required BreakfastConfigurationRepository breakfastConfigurationRepository,
    SemanticMenuPolicyService policyService = const SemanticMenuPolicyService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _productRepository = productRepository,
       _categoryRepository = categoryRepository,
       _breakfastConfigurationRepository = breakfastConfigurationRepository,
       _policyService = policyService,
       _logger = logger;

  final ProductRepository _productRepository;
  final CategoryRepository _categoryRepository;
  final BreakfastConfigurationRepository _breakfastConfigurationRepository;
  final SemanticMenuPolicyService _policyService;
  final AppLogger _logger;

  static const String _breakfastItemsCategoryName = 'Breakfast Items';

  Future<Map<int, ProductMenuConfigurationProfile>> getProductProfiles(
    Iterable<int> productIds,
  ) {
    return _breakfastConfigurationRepository.loadConfigurationProfiles(
      productIds,
    );
  }

  Future<SemanticProductConfigurationEditorData> loadEditorData(
    int rootProductId,
  ) async {
    final Product? rootProduct = await _productRepository.getById(
      rootProductId,
    );
    if (rootProduct == null) {
      throw NotFoundException('Product not found: $rootProductId');
    }

    final Map<int, ProductMenuConfigurationProfile> profiles =
        await _breakfastConfigurationRepository.loadConfigurationProfiles(<int>[
          rootProductId,
        ]);
    final SemanticProductConfigurationDraft configuration =
        await _breakfastConfigurationRepository.loadAdminConfigurationDraft(
          rootProductId,
        );
    final SemanticMenuValidationResult validationResult =
        await validateConfiguration(
          configuration: configuration,
          profile:
              profiles[rootProductId] ??
              ProductMenuConfigurationProfile(
                productId: rootProductId,
                flatModifierCount: 0,
                setItemCount: 0,
                choiceGroupCount: 0,
                choiceMemberCount: 0,
              ),
        );

    final List<Product> activeProducts = await _productRepository.getAll(
      activeOnly: true,
    );
    final _SetItemPoolResolution setItemPoolResolution =
        await _loadAvailableSetItemProducts(rootProductId: rootProductId);
    final List<Product> availableSetItemProducts =
        setItemPoolResolution.products;
    final List<BreakfastExtraPreset> extraPresets =
        await _breakfastConfigurationRepository.loadExtraPresets();

    _logger.info(
      eventType: 'semantic_menu_editor_data_loaded',
      entityId: '$rootProductId',
      metadata: <String, Object?>{
        'root_product_id': rootProductId,
        'draft_set_item_ids': configuration.setItems
            .map((SemanticSetItemDraft item) => item.itemProductId)
            .toList(growable: false),
        'draft_choice_member_ids': configuration.choiceGroups
            .expand(
              (SemanticChoiceGroupDraft group) => group.members.map(
                (SemanticChoiceMemberDraft member) => member.itemProductId,
              ),
            )
            .toList(growable: false),
        'available_set_item_products_length': availableSetItemProducts.length,
        'available_set_item_product_ids': availableSetItemProducts
            .map((Product product) => product.id)
            .toList(growable: false),
      },
    );

    return SemanticProductConfigurationEditorData(
      rootProduct: rootProduct,
      profile:
          profiles[rootProductId] ??
          ProductMenuConfigurationProfile(
            productId: rootProductId,
            flatModifierCount: 0,
            setItemCount: 0,
            choiceGroupCount: 0,
            choiceMemberCount: 0,
          ),
      availableProducts: activeProducts,
      availableSetItemProducts: availableSetItemProducts,
      extraPresets: extraPresets,
      configuration: configuration,
      validationResult: validationResult,
    );
  }

  Future<List<BreakfastExtraPreset>> loadExtraPresets() {
    return _breakfastConfigurationRepository.loadExtraPresets();
  }

  Future<int> saveExtraPreset({
    required User user,
    int? presetId,
    required String name,
    required Iterable<int> itemProductIds,
  }) async {
    _ensureAdmin(user);

    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ValidationException('Preset name is required.');
    }

    final List<int> normalizedIds = <int>[];
    final Set<int> seenIds = <int>{};
    for (final int productId in itemProductIds) {
      if (seenIds.add(productId)) {
        normalizedIds.add(productId);
      }
    }
    if (normalizedIds.isEmpty) {
      throw ValidationException('Select at least one extra product.');
    }

    final List<BreakfastExtraPreset> existingPresets =
        await _breakfastConfigurationRepository.loadExtraPresets();
    final String normalizedName = trimmedName.toLowerCase();
    final bool duplicateName = existingPresets.any(
      (BreakfastExtraPreset preset) =>
          preset.id != presetId &&
          preset.name.trim().toLowerCase() == normalizedName,
    );
    if (duplicateName) {
      throw ValidationException(
        'A breakfast extras preset with this name already exists.',
      );
    }

    final List<Product> allProducts = await _productRepository.getAll(
      activeOnly: false,
    );
    final Map<int, Product> productsById = <int, Product>{
      for (final Product product in allProducts) product.id: product,
    };
    final Set<int> setRootProductIds = await _breakfastConfigurationRepository
        .loadSetRootProductIds();
    for (final int productId in normalizedIds) {
      if (!productsById.containsKey(productId)) {
        throw ValidationException(
          'Preset products must reference real catalog products.',
        );
      }
      if (setRootProductIds.contains(productId)) {
        throw ValidationException(
          'A breakfast set root cannot be saved in an extras preset.',
        );
      }
    }

    return _breakfastConfigurationRepository.saveExtraPreset(
      presetId: presetId,
      name: trimmedName,
      itemProductIds: normalizedIds,
    );
  }

  Future<SemanticMenuValidationResult> validateConfiguration({
    required SemanticProductConfigurationDraft configuration,
    ProductMenuConfigurationProfile? profile,
  }) async {
    final ProductMenuConfigurationProfile effectiveProfile =
        profile ?? await _loadProfile(configuration.productId);
    final List<Product> allProducts = await _productRepository.getAll(
      activeOnly: false,
    );
    final Map<int, Product> productsById = <int, Product>{
      for (final Product product in allProducts) product.id: product,
    };
    final Set<int> setRootProductIds = await _breakfastConfigurationRepository
        .loadSetRootProductIds();
    final Set<int> choiceMemberProductIds =
        await _breakfastConfigurationRepository.loadChoiceMemberProductIds();

    return _policyService.validateDraft(
      profile: effectiveProfile,
      configuration: configuration,
      productsById: productsById,
      setRootProductIds: setRootProductIds,
      choiceMemberProductIds: choiceMemberProductIds,
    );
  }

  Future<void> saveConfiguration({
    required User user,
    required SemanticProductConfigurationDraft configuration,
  }) async {
    _ensureAdmin(user);

    final Product? rootProduct = await _productRepository.getById(
      configuration.productId,
    );
    if (rootProduct == null) {
      throw ValidationException('Product selection is required.');
    }

    final SemanticMenuValidationResult validationResult =
        await validateConfiguration(configuration: configuration);
    if (!validationResult.canSave) {
      throw SemanticProductConfigurationValidationException(
        List<String>.unmodifiable(validationResult.errors),
      );
    }

    await _breakfastConfigurationRepository.replaceAdminConfiguration(
      configuration,
    );
  }

  void _ensureAdmin(User user) {
    if (user.role != UserRole.admin) {
      throw UnauthorisedException(
        'Only admins can access semantic menu configuration.',
      );
    }
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

  Future<_SetItemPoolResolution> _loadAvailableSetItemProducts({
    required int rootProductId,
  }) async {
    final List<Category> categories = await _categoryRepository.getAll(
      activeOnly: false,
    );
    final List<Category> matchingCategories = categories
        .where(
          (Category category) =>
              category.name.trim().toLowerCase() ==
              _breakfastItemsCategoryName.toLowerCase(),
        )
        .toList(growable: false);
    if (matchingCategories.isEmpty) {
      _logger.info(
        eventType: 'breakfast_set_item_pool_resolved',
        entityId: '$rootProductId',
        metadata: <String, Object?>{
          'root_product_id': rootProductId,
          'source_category_name': _breakfastItemsCategoryName,
          'matching_category_ids': const <int>[],
          'matching_category_names': const <String>[],
          'active_product_count_before_filter': 0,
          'active_product_count_after_filter': 0,
          'final_available_set_item_products_length': 0,
          'available_set_item_product_ids': const <int>[],
        },
      );
      return const _SetItemPoolResolution(
        products: <Product>[],
        matchingCategories: <Category>[],
        rawActiveProductCount: 0,
      );
    }

    final List<Product> products = <Product>[];
    final Set<int> seenProductIds = <int>{};
    int rawActiveProductCount = 0;
    for (final Category category in matchingCategories) {
      final List<Product> categoryProducts = await _productRepository
          .getByCategory(category.id, activeOnly: true);
      rawActiveProductCount += categoryProducts.length;
      for (final Product product in categoryProducts) {
        if (seenProductIds.add(product.id)) {
          products.add(product);
        }
      }
    }
    final List<Product> resolvedProducts = List<Product>.unmodifiable(products);
    _logger.info(
      eventType: 'breakfast_set_item_pool_resolved',
      entityId: '$rootProductId',
      metadata: <String, Object?>{
        'root_product_id': rootProductId,
        'source_category_name': _breakfastItemsCategoryName,
        'matching_category_ids': matchingCategories
            .map((Category category) => category.id)
            .toList(growable: false),
        'matching_category_names': matchingCategories
            .map((Category category) => category.name)
            .toList(growable: false),
        'active_product_count_before_filter': rawActiveProductCount,
        'active_product_count_after_filter': resolvedProducts.length,
        'final_available_set_item_products_length': resolvedProducts.length,
        'available_set_item_product_ids': resolvedProducts
            .map((Product product) => product.id)
            .toList(growable: false),
      },
    );
    return _SetItemPoolResolution(
      products: resolvedProducts,
      matchingCategories: matchingCategories,
      rawActiveProductCount: rawActiveProductCount,
    );
  }
}

class _SetItemPoolResolution {
  const _SetItemPoolResolution({
    required this.products,
    required this.matchingCategories,
    required this.rawActiveProductCount,
  });

  final List<Product> products;
  final List<Category> matchingCategories;
  final int rawActiveProductCount;
}
