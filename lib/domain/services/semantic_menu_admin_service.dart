import '../../core/errors/exceptions.dart';
import '../../data/repositories/breakfast_configuration_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../models/product.dart';
import '../models/semantic_product_configuration.dart';
import '../models/user.dart';
import 'semantic_menu_policy_service.dart';

class SemanticMenuAdminService {
  const SemanticMenuAdminService({
    required ProductRepository productRepository,
    required BreakfastConfigurationRepository breakfastConfigurationRepository,
    SemanticMenuPolicyService policyService = const SemanticMenuPolicyService(),
  }) : _productRepository = productRepository,
       _breakfastConfigurationRepository = breakfastConfigurationRepository,
       _policyService = policyService;

  final ProductRepository _productRepository;
  final BreakfastConfigurationRepository _breakfastConfigurationRepository;
  final SemanticMenuPolicyService _policyService;

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
      availableProducts: await _productRepository.getAll(activeOnly: false),
      configuration: configuration,
      validationResult: validationResult,
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
}
