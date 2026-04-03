import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminCategoriesState {
  const AdminCategoriesState({
    required this.categories,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  const AdminCategoriesState.initial()
    : categories = const <Category>[],
      isLoading = false,
      isSaving = false,
      errorMessage = null;

  final List<Category> categories;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  AdminCategoriesState copyWith({
    List<Category>? categories,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return AdminCategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminCategoriesNotifier extends StateNotifier<AdminCategoriesState> {
  AdminCategoriesNotifier(this._ref)
    : super(const AdminCategoriesState.initial());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final List<Category> categories = await _ref
          .read(adminServiceProvider)
          .getCategories();
      state = state.copyWith(
        categories: categories,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_categories_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<bool> createCategory({
    required String name,
    required int sortOrder,
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
          .createCategory(
            user: currentUser,
            name: name,
            sortOrder: sortOrder,
            isActive: isActive,
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
          eventType: 'admin_category_create_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> updateCategory({
    required int id,
    required String name,
    required int sortOrder,
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
          .updateCategory(
            user: currentUser,
            id: id,
            name: name,
            sortOrder: sortOrder,
            isActive: isActive,
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
          eventType: 'admin_category_update_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool?> categoryHasActiveProducts({required int id}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return null;
    }
    state = state.copyWith(errorMessage: null);
    try {
      return await _ref
          .read(adminServiceProvider)
          .categoryHasActiveProducts(user: currentUser, id: id);
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_category_has_active_products_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<bool> deleteCategory({required int id}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .deleteCategory(user: currentUser, id: id);
      await load();
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_category_delete_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }
}

final StateNotifierProvider<AdminCategoriesNotifier, AdminCategoriesState>
adminCategoriesNotifierProvider =
    StateNotifierProvider<AdminCategoriesNotifier, AdminCategoriesState>(
      (Ref ref) => AdminCategoriesNotifier(ref),
    );

const Object _unset = Object();
