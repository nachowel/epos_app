import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/models/semantic_product_configuration.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

enum BreakfastSetValidationState { valid, incomplete, invalid }

enum BreakfastSetValidationFilter { all, valid, invalid, incomplete }

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
    required this.allItems,
    required this.items,
    required this.availableCategories,
    required this.searchQuery,
    required this.validationFilter,
    required this.isLoading,
    required this.isCreating,
    required this.errorMessage,
  });

  const AdminBreakfastSetsState.initial()
    : allItems = const <AdminBreakfastSetListItem>[],
      items = const <AdminBreakfastSetListItem>[],
      availableCategories = const <Category>[],
      searchQuery = '',
      validationFilter = BreakfastSetValidationFilter.all,
      isLoading = false,
      isCreating = false,
      errorMessage = null;

  final List<AdminBreakfastSetListItem> allItems;
  final List<AdminBreakfastSetListItem> items;
  final List<Category> availableCategories;
  final String searchQuery;
  final BreakfastSetValidationFilter validationFilter;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;

  int get totalItemCount => allItems.length;

  AdminBreakfastSetsState copyWith({
    List<AdminBreakfastSetListItem>? allItems,
    List<AdminBreakfastSetListItem>? items,
    List<Category>? availableCategories,
    String? searchQuery,
    BreakfastSetValidationFilter? validationFilter,
    bool? isLoading,
    bool? isCreating,
    Object? errorMessage = _unset,
  }) {
    return AdminBreakfastSetsState(
      allItems: allItems ?? this.allItems,
      items: items ?? this.items,
      availableCategories: availableCategories ?? this.availableCategories,
      searchQuery: searchQuery ?? this.searchQuery,
      validationFilter: validationFilter ?? this.validationFilter,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
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
      final List<Category> categories = await _ref
          .read(categoryRepositoryProvider)
          .getAll(activeOnly: false);
      final List<Category> availableCategories =
          categories
              .where((Category category) => category.isActive)
              .toList(growable: false)
            ..sort(
              (Category left, Category right) =>
                  left.sortOrder != right.sortOrder
                  ? left.sortOrder.compareTo(right.sortOrder)
                  : left.name.toLowerCase().compareTo(right.name.toLowerCase()),
            );
      final Map<int, String> categoryNamesById = <int, String>{
        for (final Category category in categories) category.id: category.name,
      };
      final List<Product> allProducts = await _ref
          .read(productRepositoryProvider)
          .getAll(activeOnly: false);
      final Map<int, ProductMenuConfigurationProfile> profiles = await _ref
          .read(breakfastConfigurationRepositoryProvider)
          .loadConfigurationProfiles(
            allProducts.map((Product product) => product.id),
          );
      final List<Product> products = allProducts
          .where(
            (Product product) =>
                profiles[product.id]?.hasSemanticSetConfig ?? false,
          )
          .toList(growable: false);
      final List<AdminBreakfastSetListItem> items =
          await Future.wait<AdminBreakfastSetListItem>(
            products.map(
              (Product product) => _buildListItem(
                product: product,
                categoryName:
                    categoryNamesById[product.categoryId] ?? 'Unknown Category',
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
      final List<AdminBreakfastSetListItem> immutableItems =
          List<AdminBreakfastSetListItem>.unmodifiable(items);

      state = state.copyWith(
        allItems: immutableItems,
        items: _applyFilters(
          items: immutableItems,
          searchQuery: state.searchQuery,
          validationFilter: state.validationFilter,
        ),
        availableCategories: List<Category>.unmodifiable(availableCategories),
        isLoading: false,
        isCreating: false,
        errorMessage: null,
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
    required int categoryId,
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
            categoryId: categoryId,
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

  void updateSearchQuery(String value) {
    final String normalizedQuery = value.trim();
    state = state.copyWith(
      searchQuery: normalizedQuery,
      items: _applyFilters(
        items: state.allItems,
        searchQuery: normalizedQuery,
        validationFilter: state.validationFilter,
      ),
      errorMessage: null,
    );
  }

  void updateValidationFilter(BreakfastSetValidationFilter filter) {
    state = state.copyWith(
      validationFilter: filter,
      items: _applyFilters(
        items: state.allItems,
        searchQuery: state.searchQuery,
        validationFilter: filter,
      ),
      errorMessage: null,
    );
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

  List<AdminBreakfastSetListItem> _applyFilters({
    required List<AdminBreakfastSetListItem> items,
    required String searchQuery,
    required BreakfastSetValidationFilter validationFilter,
  }) {
    final String normalizedQuery = searchQuery.trim().toLowerCase();
    return items
        .where((AdminBreakfastSetListItem item) {
          if (!_matchesValidationFilter(item, validationFilter)) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return _searchableTermsForItem(
            item,
          ).any((String term) => term.contains(normalizedQuery));
        })
        .toList(growable: false);
  }

  bool _matchesValidationFilter(
    AdminBreakfastSetListItem item,
    BreakfastSetValidationFilter filter,
  ) {
    switch (filter) {
      case BreakfastSetValidationFilter.all:
        return true;
      case BreakfastSetValidationFilter.valid:
        return item.validationState == BreakfastSetValidationState.valid;
      case BreakfastSetValidationFilter.invalid:
        return item.validationState == BreakfastSetValidationState.invalid;
      case BreakfastSetValidationFilter.incomplete:
        return item.validationState == BreakfastSetValidationState.incomplete;
    }
  }

  List<String> _searchableTermsForItem(AdminBreakfastSetListItem item) {
    return <String>[
      item.product.name.trim().toLowerCase(),
      item.categoryName.trim().toLowerCase(),
    ];
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
