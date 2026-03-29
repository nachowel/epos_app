import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminProductsState {
  const AdminProductsState({
    required this.categories,
    required this.products,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  const AdminProductsState.initial()
    : categories = const <Category>[],
      products = const <Product>[],
      selectedCategoryId = null,
      isLoading = false,
      isSaving = false,
      errorMessage = null;

  final List<Category> categories;
  final List<Product> products;
  final int? selectedCategoryId;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  AdminProductsState copyWith({
    List<Category>? categories,
    List<Product>? products,
    Object? selectedCategoryId = _unset,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return AdminProductsState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      selectedCategoryId: selectedCategoryId == _unset
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
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
      final int? selectedCategoryId =
          state.selectedCategoryId ??
          (categories.isEmpty ? null : categories.first.id);
      final List<Product> products = await _ref
          .read(adminServiceProvider)
          .getProducts(categoryId: selectedCategoryId);

      state = state.copyWith(
        categories: categories,
        products: products,
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
    state = state.copyWith(
      selectedCategoryId: categoryId,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final List<Product> products = await _ref
          .read(adminServiceProvider)
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
          eventType: 'admin_products_select_category_failed',
          stackTrace: stackTrace,
        ),
      );
    }
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
      await selectCategory(categoryId);
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
      await selectCategory(categoryId);
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
      await selectCategory(state.selectedCategoryId);
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
      await selectCategory(state.selectedCategoryId);
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
}

final StateNotifierProvider<AdminProductsNotifier, AdminProductsState>
adminProductsNotifierProvider =
    StateNotifierProvider<AdminProductsNotifier, AdminProductsState>(
      (Ref ref) => AdminProductsNotifier(ref),
    );

const Object _unset = Object();
