import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/services/catalog_service.dart';

class ProductsState {
  const ProductsState({
    required this.categories,
    required this.categoryProductCounts,
    required this.products,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.errorMessage,
  });

  const ProductsState.initial()
    : categories = const <Category>[],
      categoryProductCounts = const <int, int>{},
      products = const <Product>[],
      selectedCategoryId = null,
      isLoading = false,
      errorMessage = null;

  final List<Category> categories;
  final Map<int, int> categoryProductCounts;
  final List<Product> products;
  final int? selectedCategoryId;
  final bool isLoading;
  final String? errorMessage;

  ProductsState copyWith({
    List<Category>? categories,
    Map<int, int>? categoryProductCounts,
    List<Product>? products,
    Object? selectedCategoryId = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return ProductsState(
      categories: categories ?? this.categories,
      categoryProductCounts:
          categoryProductCounts ?? this.categoryProductCounts,
      products: products ?? this.products,
      selectedCategoryId: selectedCategoryId == _unset
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  ProductsNotifier(this._ref) : super(const ProductsState.initial()) {
    loadCatalog();
  }

  final Ref _ref;

  Future<void> loadCatalog({
    int? preferredCategoryId,
    bool preserveVisibleSelection = true,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final CatalogService catalogService = _ref.read(catalogServiceProvider);
      final Future<List<Category>> categoriesFuture = catalogService
          .getCategories();
      final Future<List<Product>> allProductsFuture = catalogService
          .getProducts();
      final List<Category> categories = await categoriesFuture;
      final int? effectiveCategoryId = _resolveEffectiveCategoryId(
        categories: categories,
        preferredCategoryId: preferredCategoryId,
        preserveVisibleSelection: preserveVisibleSelection,
      );

      final List<Product> allProducts = await allProductsFuture;
      final List<Product> products = effectiveCategoryId == null
          ? const <Product>[]
          : await catalogService.getProducts(categoryId: effectiveCategoryId);
      final Map<int, int> categoryProductCounts = <int, int>{};
      for (final Product product in allProducts) {
        categoryProductCounts[product.categoryId] =
            (categoryProductCounts[product.categoryId] ?? 0) + 1;
      }

      state = state.copyWith(
        categories: categories,
        categoryProductCounts: categoryProductCounts,
        products: products,
        selectedCategoryId: effectiveCategoryId,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'catalog_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> selectCategory(int? categoryId) async {
    state = state.copyWith(
      selectedCategoryId: categoryId,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final products = await _ref
          .read(catalogServiceProvider)
          .getProducts(categoryId: categoryId);
      state = state.copyWith(
        products: products,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'catalog_select_category_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void resetToPreOrder() {
    state = state.copyWith(
      products: const <Product>[],
      selectedCategoryId: null,
      isLoading: false,
      errorMessage: null,
    );
  }

  int? _resolveEffectiveCategoryId({
    required List<Category> categories,
    required int? preferredCategoryId,
    required bool preserveVisibleSelection,
  }) {
    if (categories.isEmpty) {
      return null;
    }

    // POS route fallback priority:
    // 1. Valid preferred category from navigation/query params
    // 2. Existing in-memory selection if this is an internal refresh
    // 3. First category in the shared sort_order-derived list
    final bool preferredCategoryStillVisible =
        preferredCategoryId != null &&
        categories.any(
          (Category category) => category.id == preferredCategoryId,
        );
    if (preferredCategoryStillVisible) {
      return preferredCategoryId;
    }

    final bool selectedCategoryStillVisible =
        state.selectedCategoryId != null &&
        categories.any(
          (Category category) => category.id == state.selectedCategoryId,
        );
    if (preserveVisibleSelection &&
        preferredCategoryId == null &&
        selectedCategoryStillVisible) {
      return state.selectedCategoryId;
    }

    return categories.first.id;
  }
}

final StateNotifierProvider<ProductsNotifier, ProductsState>
productsNotifierProvider =
    StateNotifierProvider<ProductsNotifier, ProductsState>(
      (Ref ref) => ProductsNotifier(ref),
    );

const Object _unset = Object();
