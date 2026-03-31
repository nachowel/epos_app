import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';

class ProductsState {
  const ProductsState({
    required this.categories,
    required this.products,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.errorMessage,
  });

  const ProductsState.initial()
    : categories = const <Category>[],
      products = const <Product>[],
      selectedCategoryId = null,
      isLoading = false,
      errorMessage = null;

  final List<Category> categories;
  final List<Product> products;
  final int? selectedCategoryId;
  final bool isLoading;
  final String? errorMessage;

  ProductsState copyWith({
    List<Category>? categories,
    List<Product>? products,
    Object? selectedCategoryId = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return ProductsState(
      categories: categories ?? this.categories,
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

  Future<void> loadCatalog() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final List<Category> categories = await _ref
          .read(catalogServiceProvider)
          .getCategories();
      final bool selectedCategoryStillVisible =
          state.selectedCategoryId == null ||
          categories.any(
            (Category category) => category.id == state.selectedCategoryId,
          );
      final int? selectedCategoryId = selectedCategoryStillVisible
          ? state.selectedCategoryId
          : null;
      final int? effectiveCategoryId =
          selectedCategoryId ??
          (categories.isEmpty ? null : categories.first.id);

      final List<Product> products = await _ref
          .read(catalogServiceProvider)
          .getProducts(categoryId: effectiveCategoryId);

      state = state.copyWith(
        categories: categories,
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
}

final StateNotifierProvider<ProductsNotifier, ProductsState>
productsNotifierProvider =
    StateNotifierProvider<ProductsNotifier, ProductsState>(
      (Ref ref) => ProductsNotifier(ref),
    );

const Object _unset = Object();
