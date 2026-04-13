import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/services/catalog_service.dart';
import '../utils/sort_mode_draft.dart' as sort_draft;

class ProductsState {
  const ProductsState({
    required this.categories,
    required this.categoryProductCounts,
    required this.products,
    required this.sortDraft,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.isSavingSortOrder,
    required this.isSortMode,
    required this.errorMessage,
  });

  const ProductsState.initial()
    : categories = const <Category>[],
      categoryProductCounts = const <int, int>{},
      products = const <Product>[],
      sortDraft = const <Product>[],
      selectedCategoryId = null,
      isLoading = false,
      isSavingSortOrder = false,
      isSortMode = false,
      errorMessage = null;

  final List<Category> categories;
  final Map<int, int> categoryProductCounts;
  final List<Product> products;
  final List<Product> sortDraft;
  final int? selectedCategoryId;
  final bool isLoading;
  final bool isSavingSortOrder;
  final bool isSortMode;
  final String? errorMessage;

  bool get hasSortChanges => !sort_draft.idsInSameOrder(
    products,
    sortDraft,
    idOf: (Product product) => product.id,
  );

  ProductsState copyWith({
    List<Category>? categories,
    Map<int, int>? categoryProductCounts,
    List<Product>? products,
    List<Product>? sortDraft,
    Object? selectedCategoryId = _unset,
    bool? isLoading,
    bool? isSavingSortOrder,
    bool? isSortMode,
    Object? errorMessage = _unset,
  }) {
    return ProductsState(
      categories: categories ?? this.categories,
      categoryProductCounts:
          categoryProductCounts ?? this.categoryProductCounts,
      products: products ?? this.products,
      sortDraft: sortDraft ?? this.sortDraft,
      selectedCategoryId: selectedCategoryId == _unset
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      isLoading: isLoading ?? this.isLoading,
      isSavingSortOrder: isSavingSortOrder ?? this.isSavingSortOrder,
      isSortMode: isSortMode ?? this.isSortMode,
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
        sortDraft: products,
        selectedCategoryId: effectiveCategoryId,
        isLoading: false,
        isSavingSortOrder: false,
        isSortMode: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        isSavingSortOrder: false,
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
      isSortMode: false,
      isSavingSortOrder: false,
      errorMessage: null,
    );
    try {
      final products = await _ref
          .read(catalogServiceProvider)
          .getProducts(categoryId: categoryId);
      state = state.copyWith(
        products: products,
        sortDraft: products,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        isSavingSortOrder: false,
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
      sortDraft: const <Product>[],
      selectedCategoryId: null,
      isLoading: false,
      isSavingSortOrder: false,
      isSortMode: false,
      errorMessage: null,
    );
  }

  void enterSortMode() {
    if (state.isLoading ||
        state.isSavingSortOrder ||
        state.selectedCategoryId == null ||
        state.products.isEmpty) {
      return;
    }

    state = state.copyWith(
      isSortMode: true,
      sortDraft: state.products,
      errorMessage: null,
    );
  }

  void discardSortChanges() {
    state = state.copyWith(
      sortDraft: state.products,
      isSortMode: false,
      isSavingSortOrder: false,
      errorMessage: null,
    );
  }

  void moveSortDraftUp(int index) {
    _updateSortDraft(sort_draft.moveDraftItemUp(state.sortDraft, index));
  }

  void moveSortDraftDown(int index) {
    _updateSortDraft(sort_draft.moveDraftItemDown(state.sortDraft, index));
  }

  void moveSortDraftToTop(int index) {
    _updateSortDraft(sort_draft.moveDraftItemToTop(state.sortDraft, index));
  }

  void moveSortDraftToBottom(int index) {
    _updateSortDraft(sort_draft.moveDraftItemToBottom(state.sortDraft, index));
  }

  Future<bool> saveSortOrder() async {
    final int? categoryId = state.selectedCategoryId;
    if (categoryId == null) {
      return false;
    }
    if (!state.isSortMode) {
      return true;
    }
    if (!state.hasSortChanges) {
      state = state.copyWith(
        isSortMode: false,
        sortDraft: state.products,
        errorMessage: null,
      );
      return true;
    }

    state = state.copyWith(isSavingSortOrder: true, errorMessage: null);
    try {
      await _ref
          .read(productRepositoryProvider)
          .reorderWithinCategory(
            categoryId: categoryId,
            orderedIds: state.sortDraft
                .map((Product product) => product.id)
                .toList(growable: false),
          );
      final List<Product> products = await _ref
          .read(catalogServiceProvider)
          .getProducts(categoryId: categoryId);
      state = state.copyWith(
        products: products,
        sortDraft: products,
        isSortMode: false,
        isSavingSortOrder: false,
        errorMessage: null,
      );
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSavingSortOrder: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'catalog_reorder_products_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  void _updateSortDraft(List<Product> nextDraft) {
    if (!state.isSortMode || identical(nextDraft, state.sortDraft)) {
      return;
    }
    state = state.copyWith(sortDraft: nextDraft, errorMessage: null);
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
