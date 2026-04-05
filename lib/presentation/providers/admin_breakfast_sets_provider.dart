import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/models/semantic_product_configuration.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

const String _setBreakfastCategoryName = 'Set Breakfast';

enum BreakfastSetValidationState { valid, incomplete, invalid }

class AdminBreakfastSetListItem {
  const AdminBreakfastSetListItem({
    required this.product,
    required this.categoryName,
    required this.profile,
    required this.includedUnitCount,
    required this.validationState,
    required this.validationSummary,
  });

  final Product product;
  final String categoryName;
  final ProductMenuConfigurationProfile profile;
  final int includedUnitCount;
  final BreakfastSetValidationState validationState;
  final String validationSummary;
}

class AdminBreakfastSetsState {
  const AdminBreakfastSetsState({
    required this.items,
    required this.isLoading,
    required this.isCreating,
    required this.errorMessage,
    required this.hasBreakfastCategory,
  });

  const AdminBreakfastSetsState.initial()
    : items = const <AdminBreakfastSetListItem>[],
      isLoading = false,
      isCreating = false,
      errorMessage = null,
      hasBreakfastCategory = true;

  final List<AdminBreakfastSetListItem> items;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;
  final bool hasBreakfastCategory;

  AdminBreakfastSetsState copyWith({
    List<AdminBreakfastSetListItem>? items,
    bool? isLoading,
    bool? isCreating,
    Object? errorMessage = _unset,
    bool? hasBreakfastCategory,
  }) {
    return AdminBreakfastSetsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      hasBreakfastCategory: hasBreakfastCategory ?? this.hasBreakfastCategory,
    );
  }
}

class AdminBreakfastSetsNotifier
    extends StateNotifier<AdminBreakfastSetsState> {
  AdminBreakfastSetsNotifier(this._ref)
    : super(const AdminBreakfastSetsState.initial());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final Category? breakfastCategory = await _loadBreakfastCategory();
      if (breakfastCategory == null) {
        state = state.copyWith(
          items: const <AdminBreakfastSetListItem>[],
          isLoading: false,
          isCreating: false,
          errorMessage: null,
          hasBreakfastCategory: false,
        );
        return;
      }

      final List<Product> products = await _ref
          .read(productRepositoryProvider)
          .getByCategory(breakfastCategory.id, activeOnly: false);
      final Map<int, ProductMenuConfigurationProfile> profiles = await _ref
          .read(breakfastConfigurationRepositoryProvider)
          .loadConfigurationProfiles(
            products.map((Product product) => product.id),
          );
      final List<AdminBreakfastSetListItem> items =
          await Future.wait<AdminBreakfastSetListItem>(
            products.map(
              (Product product) => _buildListItem(
                product: product,
                categoryName: breakfastCategory.name,
                profile:
                    profiles[product.id] ??
                    ProductMenuConfigurationProfile(
                      productId: product.id,
                      flatModifierCount: 0,
                      setItemCount: 0,
                      choiceGroupCount: 0,
                      choiceMemberCount: 0,
                    ),
              ),
            ),
          );

      state = state.copyWith(
        items: List<AdminBreakfastSetListItem>.unmodifiable(items),
        isLoading: false,
        isCreating: false,
        errorMessage: null,
        hasBreakfastCategory: true,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        isCreating: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_breakfast_sets_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<int?> createBreakfastSetRoot({
    required String name,
    required int priceMinor,
    required bool isActive,
    required bool isVisibleOnPos,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return null;
    }

    state = state.copyWith(isCreating: true, errorMessage: null);
    try {
      final int productId = await _ref
          .read(adminServiceProvider)
          .createBreakfastSetRoot(
            user: currentUser,
            name: name,
            priceMinor: priceMinor,
            isActive: isActive,
            isVisibleOnPos: isVisibleOnPos,
          );
      await load();
      state = state.copyWith(isCreating: false, errorMessage: null);
      return productId;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_breakfast_set_create_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<AdminBreakfastSetListItem> _buildListItem({
    required Product product,
    required String categoryName,
    required ProductMenuConfigurationProfile profile,
  }) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        profile.hasSemanticSetConfig
        ? await _ref
              .read(breakfastConfigurationRepositoryProvider)
              .loadAdminConfigurationDraft(product.id)
        : null;
    final _ValidationSummary validation = await _buildValidationSummary(
      product: product,
      profile: profile,
      draftConfiguration: draftConfiguration,
    );
    return AdminBreakfastSetListItem(
      product: product,
      categoryName: categoryName,
      profile: profile,
      includedUnitCount: _calculateIncludedUnitCount(draftConfiguration),
      validationState: validation.state,
      validationSummary: validation.summary,
    );
  }

  Future<_ValidationSummary> _buildValidationSummary({
    required Product product,
    required ProductMenuConfigurationProfile profile,
    SemanticProductConfigurationDraft? draftConfiguration,
  }) async {
    if (profile.hasLegacyFlatConfig && profile.hasSemanticSetConfig) {
      return const _ValidationSummary(
        state: BreakfastSetValidationState.invalid,
        summary: 'Legacy flat modifiers still need cleanup.',
      );
    }
    if (!profile.hasSemanticSetConfig) {
      return const _ValidationSummary(
        state: BreakfastSetValidationState.incomplete,
        summary: 'Configuration not started.',
      );
    }

    final SemanticProductConfigurationDraft resolvedDraftConfiguration =
        draftConfiguration ??
        await _ref
            .read(breakfastConfigurationRepositoryProvider)
            .loadAdminConfigurationDraft(product.id);
    if (!resolvedDraftConfiguration.hasSemanticStructure) {
      return _ValidationSummary(
        state: BreakfastSetValidationState.incomplete,
        summary: 'Add set items and choice groups.',
      );
    }

    final SemanticMenuValidationResult validation = await _ref
        .read(semanticMenuAdminServiceProvider)
        .validateConfiguration(
          configuration: resolvedDraftConfiguration,
          profile: profile,
        );
    if (validation.errors.isNotEmpty) {
      return _ValidationSummary(
        state: BreakfastSetValidationState.invalid,
        summary: _summarizeIssues(validation.errors),
      );
    }
    if (validation.warnings.isNotEmpty) {
      return _ValidationSummary(
        state: BreakfastSetValidationState.incomplete,
        summary: _summarizeIssues(validation.warnings),
      );
    }

    return const _ValidationSummary(
      state: BreakfastSetValidationState.valid,
      summary: 'Ready for editing.',
    );
  }

  int _calculateIncludedUnitCount(
    SemanticProductConfigurationDraft? draftConfiguration,
  ) {
    if (draftConfiguration == null) {
      return 0;
    }
    return draftConfiguration.setItems.fold<int>(
      0,
      (int sum, SemanticSetItemDraft item) => sum + item.defaultQuantity,
    );
  }

  String _summarizeIssues(List<String> issues) {
    final List<String> uniqueIssues = issues.toSet().toList(growable: false);
    if (uniqueIssues.isEmpty) {
      return '';
    }
    if (uniqueIssues.length == 1) {
      return uniqueIssues.single;
    }
    if (uniqueIssues.length == 2) {
      return '${uniqueIssues.first}; ${uniqueIssues.last}';
    }
    final List<String> visibleIssues = uniqueIssues
        .take(2)
        .toList(growable: false);
    final int hiddenIssueCount = uniqueIssues.length - visibleIssues.length;
    return '${visibleIssues.join('; ')} +$hiddenIssueCount more.';
  }

  Future<Category?> _loadBreakfastCategory() async {
    final List<Category> categories = await _ref
        .read(categoryRepositoryProvider)
        .getAll(activeOnly: false);
    for (final Category category in categories) {
      if (category.name.trim().toLowerCase() ==
          _setBreakfastCategoryName.toLowerCase()) {
        return category;
      }
    }
    return null;
  }
}

class _ValidationSummary {
  const _ValidationSummary({required this.state, required this.summary});

  final BreakfastSetValidationState state;
  final String summary;
}

final StateNotifierProvider<AdminBreakfastSetsNotifier, AdminBreakfastSetsState>
adminBreakfastSetsNotifierProvider =
    StateNotifierProvider<AdminBreakfastSetsNotifier, AdminBreakfastSetsState>(
      (Ref ref) => AdminBreakfastSetsNotifier(ref),
    );

const Object _unset = Object();
