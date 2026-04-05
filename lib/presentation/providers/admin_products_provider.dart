import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/meal_adjustment_profile.dart';
import '../../domain/models/product.dart';
import '../../domain/models/semantic_product_configuration.dart';
import '../../domain/services/admin_service.dart';
import '../../domain/services/meal_adjustment_profile_validation_service.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

enum AdminProductStatusFilter { active, archived, all }

class AdminMealProfileVisibility {
  const AdminMealProfileVisibility({
    required this.profileId,
    required this.profileName,
    required this.healthStatus,
    required this.headline,
    required this.previewSummary,
  });

  final int profileId;
  final String profileName;
  final MealAdjustmentHealthStatus healthStatus;
  final String headline;
  final String previewSummary;
}

class AdminProductsState {
  const AdminProductsState({
    required this.categories,
    required this.allProducts,
    required this.products,
    required this.setProducts,
    required this.normalProducts,
    required this.profiles,
    required this.mealProfileVisibilityByProductId,
    required this.legacyMealLineCountsByProduct,
    required this.selectedCategoryId,
    required this.selectedStatusFilter,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  const AdminProductsState.initial()
    : categories = const <Category>[],
      allProducts = const <Product>[],
      products = const <Product>[],
      setProducts = const <Product>[],
      normalProducts = const <Product>[],
      profiles = const <int, ProductMenuConfigurationProfile>{},
      mealProfileVisibilityByProductId =
          const <int, AdminMealProfileVisibility>{},
      legacyMealLineCountsByProduct = const <int, int>{},
      selectedCategoryId = null,
      selectedStatusFilter = AdminProductStatusFilter.active,
      isLoading = false,
      isSaving = false,
      errorMessage = null;

  final List<Category> categories;
  final List<Product> allProducts;
  final List<Product> products;
  final List<Product> setProducts;
  final List<Product> normalProducts;
  final Map<int, ProductMenuConfigurationProfile> profiles;
  final Map<int, AdminMealProfileVisibility> mealProfileVisibilityByProductId;
  final Map<int, int> legacyMealLineCountsByProduct;
  final int? selectedCategoryId;
  final AdminProductStatusFilter selectedStatusFilter;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  AdminProductsState copyWith({
    List<Category>? categories,
    List<Product>? allProducts,
    List<Product>? products,
    List<Product>? setProducts,
    List<Product>? normalProducts,
    Map<int, ProductMenuConfigurationProfile>? profiles,
    Map<int, AdminMealProfileVisibility>? mealProfileVisibilityByProductId,
    Map<int, int>? legacyMealLineCountsByProduct,
    Object? selectedCategoryId = _unset,
    AdminProductStatusFilter? selectedStatusFilter,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return AdminProductsState(
      categories: categories ?? this.categories,
      allProducts: allProducts ?? this.allProducts,
      products: products ?? this.products,
      setProducts: setProducts ?? this.setProducts,
      normalProducts: normalProducts ?? this.normalProducts,
      profiles: profiles ?? this.profiles,
      mealProfileVisibilityByProductId:
          mealProfileVisibilityByProductId ??
          this.mealProfileVisibilityByProductId,
      legacyMealLineCountsByProduct:
          legacyMealLineCountsByProduct ??
          this.legacyMealLineCountsByProduct,
      selectedCategoryId: selectedCategoryId == _unset
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminProductsNotifier extends StateNotifier<AdminProductsState> {
  AdminProductsNotifier(this._ref) : super(const AdminProductsState.initial());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final List<Category> categories = await _ref
          .read(adminServiceProvider)
          .getCategories();
      final int? selectedCategoryId = _ensureValidSelection<int>(
        current: state.selectedCategoryId,
        items: categories.map((Category category) => category.id),
      );
      final List<Product> allProducts = await _ref
          .read(adminServiceProvider)
          .getProducts(categoryId: selectedCategoryId);
      final List<Product> products = _applyStatusFilter(
        allProducts,
        state.selectedStatusFilter,
      );
      final Map<int, ProductMenuConfigurationProfile> profiles = await _ref
          .read(semanticMenuAdminServiceProvider)
          .getProductProfiles(allProducts.map((Product product) => product.id));
      final Map<int, AdminMealProfileVisibility> mealProfileVisibilityByProductId =
          await _loadMealProfileVisibility(allProducts);
      Map<int, int> legacyLineCounts = const <int, int>{};
      try {
        legacyLineCounts = await _ref
            .read(mealInsightsServiceProvider)
            .getLegacyLineCountsByProduct();
      } catch (_) {
        // Legacy counts are best-effort — do not block admin load.
      }
      final _ProductSections sections = _splitProducts(products, profiles);

      state = state.copyWith(
        categories: categories,
        allProducts: allProducts,
        products: products,
        setProducts: sections.setProducts,
        normalProducts: sections.normalProducts,
        profiles: profiles,
        mealProfileVisibilityByProductId: mealProfileVisibilityByProductId,
        legacyMealLineCountsByProduct: legacyLineCounts,
        selectedCategoryId: selectedCategoryId,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_products_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> selectCategory(int? categoryId) async {
    final int? validCategoryId = _ensureValidSelection<int>(
      current: categoryId,
      items: state.categories.map((Category category) => category.id),
    );
    state = state.copyWith(
      selectedCategoryId: validCategoryId,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final List<Product> allProducts = await _ref
          .read(adminServiceProvider)
          .getProducts(categoryId: validCategoryId);
      final List<Product> products = _applyStatusFilter(
        allProducts,
        state.selectedStatusFilter,
      );
      final Map<int, ProductMenuConfigurationProfile> profiles = await _ref
          .read(semanticMenuAdminServiceProvider)
          .getProductProfiles(allProducts.map((Product product) => product.id));
      final Map<int, AdminMealProfileVisibility> mealProfileVisibilityByProductId =
          await _loadMealProfileVisibility(allProducts);
      final _ProductSections sections = _splitProducts(products, profiles);
      state = state.copyWith(
        allProducts: allProducts,
        products: products,
        setProducts: sections.setProducts,
        normalProducts: sections.normalProducts,
        profiles: profiles,
        mealProfileVisibilityByProductId: mealProfileVisibilityByProductId,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_products_select_category_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> selectStatusFilter(AdminProductStatusFilter filter) async {
    final List<Product> products = _applyStatusFilter(
      state.allProducts,
      filter,
    );
    final _ProductSections sections = _splitProducts(products, state.profiles);
    state = state.copyWith(
      selectedStatusFilter: filter,
      products: products,
      setProducts: sections.setProducts,
      normalProducts: sections.normalProducts,
      errorMessage: null,
    );
  }

  Future<bool> createProduct({
    required int categoryId,
    required String name,
    required int priceMinor,
    required bool hasModifiers,
    required int sortOrder,
    required bool isActive,
    required bool isVisibleOnPos,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .createProduct(
            user: currentUser,
            categoryId: categoryId,
            name: name,
            priceMinor: priceMinor,
            hasModifiers: hasModifiers,
            sortOrder: sortOrder,
            isActive: isActive,
            isVisibleOnPos: isVisibleOnPos,
          );
      await load();
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_product_create_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> updateProduct({
    required int id,
    required int categoryId,
    required String name,
    required int priceMinor,
    required bool hasModifiers,
    required int sortOrder,
    required bool isActive,
    required bool isVisibleOnPos,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .updateProduct(
            user: currentUser,
            id: id,
            categoryId: categoryId,
            name: name,
            priceMinor: priceMinor,
            hasModifiers: hasModifiers,
            sortOrder: sortOrder,
            isActive: isActive,
            isVisibleOnPos: isVisibleOnPos,
          );
      await load();
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_product_update_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> toggleProductActive({
    required int id,
    required bool isActive,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .toggleProductActive(user: currentUser, id: id, isActive: isActive);
      await load();
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_product_toggle_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> toggleProductVisibilityOnPos({
    required int id,
    required bool isVisibleOnPos,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .toggleProductVisibilityOnPos(
            user: currentUser,
            id: id,
            isVisibleOnPos: isVisibleOnPos,
          );
      await load();
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_product_visibility_toggle_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<ProductDeleteOutcome?> deleteProduct({required int id}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return null;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final ProductDeleteOutcome outcome = await _ref
          .read(adminServiceProvider)
          .deleteProduct(user: currentUser, id: id);
      await load();
      state = state.copyWith(isSaving: false, errorMessage: null);
      return outcome;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_product_delete_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<ProductDeletionAnalysis?> analyzeDeletion({required int id}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return null;
    }
    try {
      return await _ref
          .read(adminServiceProvider)
          .analyzeProductDeletion(user: currentUser, id: id);
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_product_delete_analysis_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<ProductDeleteOutcome?> deleteProductWithImpactAcknowledged({
    required int id,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return null;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final ProductDeleteOutcome outcome = await _ref
          .read(adminServiceProvider)
          .deleteProduct(
            user: currentUser,
            id: id,
            confirmSemanticImpact: true,
          );
      await load();
      state = state.copyWith(isSaving: false, errorMessage: null);
      return outcome;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_product_delete_confirmed_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  List<Product> _applyStatusFilter(
    List<Product> products,
    AdminProductStatusFilter filter,
  ) {
    return products
        .where((Product product) {
          return switch (filter) {
            AdminProductStatusFilter.active => product.isActive,
            AdminProductStatusFilter.archived => !product.isActive,
            AdminProductStatusFilter.all => true,
          };
        })
        .toList(growable: false);
  }

  _ProductSections _splitProducts(
    List<Product> products,
    Map<int, ProductMenuConfigurationProfile> profiles,
  ) {
    final List<Product> setProducts = <Product>[];
    final List<Product> normalProducts = <Product>[];
    for (final Product product in products) {
      final ProductMenuConfigurationProfile? profile = profiles[product.id];
      if (_isSetProduct(profile)) {
        setProducts.add(product);
      } else {
        normalProducts.add(product);
      }
    }
    return _ProductSections(
      setProducts: List<Product>.unmodifiable(setProducts),
      normalProducts: List<Product>.unmodifiable(normalProducts),
    );
  }

  bool _isSetProduct(ProductMenuConfigurationProfile? profile) {
    if (profile == null) {
      return false;
    }
    return profile.hasSemanticSetConfig;
  }

  T? _ensureValidSelection<T>({
    required T? current,
    required Iterable<T> items,
  }) {
    final List<T> availableItems = items.toList(growable: false);
    if (availableItems.isEmpty) {
      return null;
    }
    if (current != null && availableItems.contains(current)) {
      return current;
    }
    return availableItems.first;
  }

  Future<Map<int, AdminMealProfileVisibility>> _loadMealProfileVisibility(
    List<Product> products,
  ) async {
    final Set<int> profileIds = products
        .map((Product product) => product.mealAdjustmentProfileId)
        .whereType<int>()
        .toSet();
    if (profileIds.isEmpty) {
      return const <int, AdminMealProfileVisibility>{};
    }

    final Map<int, MealAdjustmentProfile> profilesById =
        <int, MealAdjustmentProfile>{
          for (final MealAdjustmentProfile profile
              in await _ref
                  .read(mealAdjustmentProfileRepositoryProvider)
                  .listProfilesForAdmin())
            profile.id: profile,
        };
    final Map<int, AdminMealProfileVisibility> visibilityByProfileId =
        <int, AdminMealProfileVisibility>{};
    for (final int profileId in profileIds) {
      final MealAdjustmentProfile? profile = profilesById[profileId];
      final MealAdjustmentProfileDraft? draft = await _ref
          .read(mealAdjustmentProfileRepositoryProvider)
          .loadProfileDraft(profileId);
      final AdminMealProfileVisibility visibility;
      if (draft == null) {
        visibility = AdminMealProfileVisibility(
          profileId: profileId,
          profileName: profile?.name ?? 'Missing profile #$profileId',
          healthStatus: MealAdjustmentHealthStatus.invalid,
          headline: 'Assigned meal profile is missing.',
          previewSummary: 'Preview unavailable.',
        );
      } else {
        final MealAdjustmentProfileHealthSummary healthSummary = await _ref
            .read(mealAdjustmentProfileValidationServiceProvider)
            .computeHealthSummary(draft);
        visibility = AdminMealProfileVisibility(
          profileId: profileId,
          profileName: profile?.name ?? draft.name,
          healthStatus: healthSummary.healthStatus,
          headline: healthSummary.headline,
          previewSummary: await _buildMealProfilePreview(draft),
        );
      }
      visibilityByProfileId[profileId] = visibility;
    }

    final Map<int, AdminMealProfileVisibility> visibilityByProductId =
        <int, AdminMealProfileVisibility>{};
    for (final Product product in products) {
      final int? profileId = product.mealAdjustmentProfileId;
      if (profileId == null) {
        continue;
      }
      final AdminMealProfileVisibility? visibility =
          visibilityByProfileId[profileId];
      if (visibility != null) {
        visibilityByProductId[product.id] = visibility;
      }
    }
    return visibilityByProductId;
  }

  Future<String> _buildMealProfilePreview(
    MealAdjustmentProfileDraft draft,
  ) async {
    final Set<int> productIds = <int>{
      for (final MealAdjustmentComponentDraft component in draft.components)
        component.defaultItemProductId,
      for (final MealAdjustmentComponentDraft component in draft.components)
        ...component.swapOptions.map(
          (MealAdjustmentComponentOptionDraft option) => option.optionItemProductId,
        ),
      for (final MealAdjustmentExtraOptionDraft extra in draft.extraOptions)
        extra.itemProductId,
    };
    final Map<int, String> namesById = <int, String>{};
    for (final int productId in productIds) {
      final Product? product = await _ref
          .read(productRepositoryProvider)
          .getById(productId);
      if (product != null) {
        namesById[productId] = product.name;
      }
    }

    final List<String> fragments = <String>[
      for (final MealAdjustmentComponentDraft component in draft.components.take(2))
        '${component.displayName}: ${namesById[component.defaultItemProductId] ?? '#${component.defaultItemProductId}'}',
    ];
    if (draft.extraOptions.isNotEmpty) {
      final List<String> extras = draft.extraOptions
          .take(2)
          .map(
            (MealAdjustmentExtraOptionDraft extra) =>
                namesById[extra.itemProductId] ?? '#${extra.itemProductId}',
          )
          .toList(growable: false);
      fragments.add('Extras: ${extras.join(', ')}');
    }
    if (fragments.isEmpty) {
      return 'No active components configured.';
    }
    return fragments.join(' · ');
  }
}

class _ProductSections {
  const _ProductSections({
    required this.setProducts,
    required this.normalProducts,
  });

  final List<Product> setProducts;
  final List<Product> normalProducts;
}

final StateNotifierProvider<AdminProductsNotifier, AdminProductsState>
adminProductsNotifierProvider =
    StateNotifierProvider<AdminProductsNotifier, AdminProductsState>(
      (Ref ref) => AdminProductsNotifier(ref),
    );

const Object _unset = Object();
