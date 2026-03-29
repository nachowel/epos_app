import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_modifier.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminModifiersState {
  const AdminModifiersState({
    required this.products,
    required this.modifiers,
    required this.selectedProductId,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  const AdminModifiersState.initial()
    : products = const <Product>[],
      modifiers = const <ProductModifier>[],
      selectedProductId = null,
      isLoading = false,
      isSaving = false,
      errorMessage = null;

  final List<Product> products;
  final List<ProductModifier> modifiers;
  final int? selectedProductId;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  AdminModifiersState copyWith({
    List<Product>? products,
    List<ProductModifier>? modifiers,
    Object? selectedProductId = _unset,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return AdminModifiersState(
      products: products ?? this.products,
      modifiers: modifiers ?? this.modifiers,
      selectedProductId: selectedProductId == _unset
          ? this.selectedProductId
          : selectedProductId as int?,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminModifiersNotifier extends StateNotifier<AdminModifiersState> {
  AdminModifiersNotifier(this._ref)
    : super(const AdminModifiersState.initial());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final List<Product> products = await _ref
          .read(adminServiceProvider)
          .getProducts();
      final int? selectedProductId =
          state.selectedProductId ??
          (products.isEmpty ? null : products.first.id);
      final List<ProductModifier> modifiers = selectedProductId == null
          ? const <ProductModifier>[]
          : await _ref
                .read(adminServiceProvider)
                .getModifiersForProduct(selectedProductId);
      state = state.copyWith(
        products: products,
        modifiers: modifiers,
        selectedProductId: selectedProductId,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_modifiers_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> selectProduct(int? productId) async {
    state = state.copyWith(
      selectedProductId: productId,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final List<ProductModifier> modifiers = productId == null
          ? const <ProductModifier>[]
          : await _ref
                .read(adminServiceProvider)
                .getModifiersForProduct(productId);
      state = state.copyWith(
        modifiers: modifiers,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_modifiers_select_product_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<bool> createModifier({
    required int productId,
    required String name,
    required ModifierType type,
    required int extraPriceMinor,
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
          .createModifier(
            user: currentUser,
            productId: productId,
            name: name,
            type: type,
            extraPriceMinor: extraPriceMinor,
            isActive: isActive,
          );
      await selectProduct(productId);
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_modifier_create_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> updateModifier({
    required int id,
    required int productId,
    required String name,
    required ModifierType type,
    required int extraPriceMinor,
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
          .updateModifier(
            user: currentUser,
            id: id,
            productId: productId,
            name: name,
            type: type,
            extraPriceMinor: extraPriceMinor,
            isActive: isActive,
          );
      await selectProduct(productId);
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_modifier_update_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> toggleModifierActive({
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
          .toggleModifierActive(user: currentUser, id: id, isActive: isActive);
      await selectProduct(state.selectedProductId);
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_modifier_toggle_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }
}

final StateNotifierProvider<AdminModifiersNotifier, AdminModifiersState>
adminModifiersNotifierProvider =
    StateNotifierProvider<AdminModifiersNotifier, AdminModifiersState>(
      (Ref ref) => AdminModifiersNotifier(ref),
    );

const Object _unset = Object();
