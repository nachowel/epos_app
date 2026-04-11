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
    required this.reorderDraft,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  const AdminCategoriesState.initial()
    : categories = const <Category>[],
      reorderDraft = const <Category>[],
      isLoading = false,
      isSaving = false,
      errorMessage = null;

  final List<Category> categories;
  final List<Category> reorderDraft;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  bool get hasReorderChanges => !_idsInSameOrder(categories, reorderDraft);

  AdminCategoriesState copyWith({
    List<Category>? categories,
    List<Category>? reorderDraft,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return AdminCategoriesState(
      categories: categories ?? this.categories,
      reorderDraft: reorderDraft ?? this.reorderDraft,
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
        reorderDraft: categories,
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
    String? imageUrl,
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
            imageUrl: imageUrl,
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
    String? imageUrl,
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
            imageUrl: imageUrl,
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

  void reorderDraft(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= state.reorderDraft.length ||
        newIndex < 0 ||
        newIndex > state.reorderDraft.length) {
      return;
    }

    final List<Category> nextDraft = List<Category>.from(state.reorderDraft);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final Category movedCategory = nextDraft.removeAt(oldIndex);
    nextDraft.insert(newIndex, movedCategory);
    state = state.copyWith(reorderDraft: nextDraft, errorMessage: null);
  }

  void discardReorderChanges() {
    state = state.copyWith(reorderDraft: state.categories, errorMessage: null);
  }

  Future<bool> saveReorder() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    if (!state.hasReorderChanges) {
      return true;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .reorderCategories(
            user: currentUser,
            orderedIds: state.reorderDraft
                .map((Category category) => category.id)
                .toList(growable: false),
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
          eventType: 'admin_category_reorder_failed',
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

bool _idsInSameOrder(List<Category> left, List<Category> right) {
  if (left.length != right.length) {
    return false;
  }
  for (int index = 0; index < left.length; index += 1) {
    if (left[index].id != right[index].id) {
      return false;
    }
  }
  return true;
}
