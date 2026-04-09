import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/meal_adjustment_profile.dart';
import '../../../domain/models/meal_customization.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_modifier.dart';
import '../../../domain/models/semantic_product_configuration.dart';
import '../../../domain/services/admin_service.dart';
import '../../../domain/models/meal_insights.dart';
import '../../../domain/services/meal_adjustment_profile_validation_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_products_provider.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/semantic_product_configuration_dialog.dart';

const String _visibleOnPosLabel = 'Visible on POS';
const String _hiddenOnPosLabel = 'Hidden on POS';
const String _archivedLabel = 'Archived';
const String _configureSemanticLabel = 'Set Builder';
const String _configureMealAdjustmentLabel = 'Meal Engine';
const String _roleLabel = 'Type';
const String _semanticConfigSavedLabel = 'Set configuration saved.';
const String _mealAdjustmentSavedLabel = 'Meal customization assignment saved.';
const String _deleteProductTitle = 'Delete product?';
const String _deleteProductMessage =
    'Are you sure you want to delete this product?';
const String _productDeletedMessage = 'Product deleted.';
const String _setDeletedMessage = 'Set product deleted.';
const String _manageModifiersLabel = 'Modifiers';
const String _addProductModifierLabel = 'Add modifier';
const String _modifierCategoryLabel = 'Modifier category';
const String _modifierTypeLabel = 'Type';
const String _modifierProductLabel = 'Select product';
const String _modifierProductSearchLabel = 'Search products';
const String _modifierProductFilterLabel = 'Filter by category';
const String _modifierSourceCategoryLabel = 'Source category';
const String _modifierPriceBehaviorLabel = 'Price behavior';
const String _modifierUiSectionLabel = 'UI section';
const String _modifierNoStructuredValueLabel = 'None';
const String _modifierSelectionRequiredMessage =
    'Select a product before saving the modifier.';
const String _modifierBulkCategoryRequiredMessage =
    'Select a source category before bulk add.';
const String _modifierBulkSummarySelectCategoryMessage =
    'Select a source category to preview the bulk add.';
const String _newModifierProductLabel = 'New product';
const String _newModifierProductTitle = 'Quick add product';
const String _standalonePosVisibilityLabel = 'Visible on POS as item';
const String _modifierLinkedProductLabel = 'Linked product';
const String _modifierVisibleInPickerLabel = 'Available for modifier linking';
const String _modifierSectionFreeLabel = 'Free';
const String _modifierSectionSaucesLabel = 'Sauces';
const String _modifierSectionAddInsLabel = 'Add-ins';
const String _modifierSectionIncludedLabel = 'Included';
const String _modifierSectionExtrasLabel = 'Extras';
const String _modifierSectionChoicesLabel = 'Set choices';
const String _modifierSectionOtherLabel = 'Other';
const String _modifierDialogHint =
    'Structured burger modifiers are grouped into Free, Sauces, and Add-ins. Legacy flat modifiers remain available for older products.';
const String _setChoiceWarning =
    'This product contains set-choice rows. Manage those through Set Builder. This modal only supports product-level flat/structured modifiers.';
const String _modifierCreatedMessage = 'Modifier created.';
const String _modifierUpdatedMessage = 'Modifier updated.';
const String _modifierDeletedMessage = 'Modifier removed.';
const String _modifierBulkAddActionLabel = 'Bulk add';
const String _removeModifierTitle = 'Remove modifier?';
const String _removeModifierMessage =
    'This permanently removes the modifier from this product.';
const String _productCreatedForModifierMessage =
    'Product created and selected for modifier linking.';
const String _productArchivedOnDeleteMessage =
    'Product cannot be deleted because it exists in past orders. It has been archived instead.';
const String _setArchivedOnDeleteMessage =
    'This set exists in past orders. It has been archived instead.';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  bool _pendingCategorySelectionRepair = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminProductsNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProductsNotifierProvider);
    final int? safeSelectedCategoryId = _ensureValidSelection<int>(
      current: state.selectedCategoryId,
      items: state.categories.map((Category category) => category.id),
    );
    if (safeSelectedCategoryId != state.selectedCategoryId) {
      _scheduleCategorySelectionRepair();
    }

    return AdminScaffold(
      title: AppStrings.productManagementTitle,
      currentRoute: '/admin/products',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<int?>(
                  key: const ValueKey<String>('product-category-filter'),
                  value: safeSelectedCategoryId,
                  decoration: InputDecoration(
                    labelText: AppStrings.categoryFilterLabel,
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  items: state.categories
                      .map(
                        (Category category) => DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: state.isLoading
                      ? null
                      : (int? value) {
                          ref
                              .read(adminProductsNotifierProvider.notifier)
                              .selectCategory(value);
                        },
                ),
              ),
              const SizedBox(width: AppSizes.spacingMd),
              ElevatedButton.icon(
                onPressed: state.categories.isEmpty || state.isSaving
                    ? null
                    : () => _openProductDialog(
                        context,
                        categories: state.categories,
                        initialCategoryId: safeSelectedCategoryId,
                      ),
                icon: const Icon(Icons.add_rounded),
                label: Text(AppStrings.addProduct),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSizes.spacingSm,
              children: <Widget>[
                _StatusFilterChip(
                  key: const ValueKey<String>('product-filter-active'),
                  label: 'Active',
                  selected:
                      state.selectedStatusFilter ==
                      AdminProductStatusFilter.active,
                  onSelected: () => ref
                      .read(adminProductsNotifierProvider.notifier)
                      .selectStatusFilter(AdminProductStatusFilter.active),
                ),
                _StatusFilterChip(
                  key: const ValueKey<String>('product-filter-archived'),
                  label: 'Archived',
                  selected:
                      state.selectedStatusFilter ==
                      AdminProductStatusFilter.archived,
                  onSelected: () => ref
                      .read(adminProductsNotifierProvider.notifier)
                      .selectStatusFilter(AdminProductStatusFilter.archived),
                ),
                _StatusFilterChip(
                  key: const ValueKey<String>('product-filter-all'),
                  label: 'All',
                  selected:
                      state.selectedStatusFilter ==
                      AdminProductStatusFilter.all,
                  onSelected: () => ref
                      .read(adminProductsNotifierProvider.notifier)
                      .selectStatusFilter(AdminProductStatusFilter.all),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(adminProductsNotifierProvider.notifier).load(),
              child: ListView(
                children: <Widget>[
                  if (state.errorMessage != null)
                    _MessageBox(
                      message: state.errorMessage!,
                      color: AppColors.error,
                    ),
                  _MessageBox(
                    message: AppStrings.productListInfoMessage,
                    color: AppColors.primary,
                  ),
                  if (state.legacyMealLineCountsByProduct.isNotEmpty)
                    _LegacyCleanupBanner(
                      totalLines: state.legacyMealLineCountsByProduct.values
                          .fold<int>(0, (int a, int b) => a + b),
                      productCount: state.legacyMealLineCountsByProduct.length,
                    ),
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppSizes.spacingXl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.products.isEmpty)
                    _EmptyState(message: AppStrings.noProductsForSelection)
                  else ...<Widget>[
                    _ProductSection(
                      key: const ValueKey<String>('set-products-section'),
                      title: 'Set Products',
                      emptyMessage: 'No set products',
                      children: state.setProducts
                          .map(
                            (Product product) => _ProductTile(
                              product: product,
                              profile:
                                  state.profiles[product.id] ??
                                  ProductMenuConfigurationProfile(
                                    productId: product.id,
                                    flatModifierCount: 0,
                                    setItemCount: 0,
                                    choiceGroupCount: 0,
                                    choiceMemberCount: 0,
                                  ),
                              mealProfileVisibility: state
                                  .mealProfileVisibilityByProductId[product.id],
                              categories: state.categories,
                              isSaving: state.isSaving,
                              showSetBuilder: true,
                              legacyLineCount:
                                  state.legacyMealLineCountsByProduct[product
                                      .id] ??
                                  0,
                              onEdit: () => _openProductDialog(
                                context,
                                categories: state.categories,
                                product: product,
                              ),
                              onConfigureSemantic: () =>
                                  _openSemanticConfigurationDialog(
                                    context,
                                    productId: product.id,
                                  ),
                              onConfigureMealAdjustment: () =>
                                  _openMealAdjustmentDialog(product),
                              onManageModifiers: () =>
                                  _openProductModifiersDialog(product),
                              onDelete: () => _confirmDeleteProduct(product),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppSizes.spacingLg),
                    _ProductSection(
                      key: const ValueKey<String>('normal-products-section'),
                      title: 'Items',
                      emptyMessage: 'No items',
                      children: state.normalProducts
                          .map(
                            (Product product) => _ProductTile(
                              product: product,
                              profile:
                                  state.profiles[product.id] ??
                                  ProductMenuConfigurationProfile(
                                    productId: product.id,
                                    flatModifierCount: 0,
                                    setItemCount: 0,
                                    choiceGroupCount: 0,
                                    choiceMemberCount: 0,
                                  ),
                              mealProfileVisibility: state
                                  .mealProfileVisibilityByProductId[product.id],
                              categories: state.categories,
                              isSaving: state.isSaving,
                              showSetBuilder: false,
                              legacyLineCount:
                                  state.legacyMealLineCountsByProduct[product
                                      .id] ??
                                  0,
                              onEdit: () => _openProductDialog(
                                context,
                                categories: state.categories,
                                product: product,
                              ),
                              onConfigureSemantic: () =>
                                  _openSemanticConfigurationDialog(
                                    context,
                                    productId: product.id,
                                  ),
                              onConfigureMealAdjustment: () =>
                                  _openMealAdjustmentDialog(product),
                              onManageModifiers: () =>
                                  _openProductModifiersDialog(product),
                              onDelete: () => _confirmDeleteProduct(product),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleCategorySelectionRepair() {
    if (_pendingCategorySelectionRepair) {
      return;
    }
    _pendingCategorySelectionRepair = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _pendingCategorySelectionRepair = false;
      if (!mounted) {
        return;
      }
      final state = ref.read(adminProductsNotifierProvider);
      final int? safeSelectedCategoryId = _ensureValidSelection<int>(
        current: state.selectedCategoryId,
        items: state.categories.map((Category category) => category.id),
      );
      if (safeSelectedCategoryId == state.selectedCategoryId) {
        return;
      }
      await ref
          .read(adminProductsNotifierProvider.notifier)
          .selectCategory(safeSelectedCategoryId);
    });
  }

  Future<void> _openProductDialog(
    BuildContext context, {
    required List<Category> categories,
    int? initialCategoryId,
    Product? product,
  }) async {
    final _ProductFormResult? result = await showDialog<_ProductFormResult>(
      context: context,
      builder: (BuildContext context) => _ProductDialog(
        categories: categories,
        initialCategoryId: initialCategoryId,
        product: product,
      ),
    );
    if (result == null) {
      return;
    }

    final notifier = ref.read(adminProductsNotifierProvider.notifier);
    final bool success = product == null
        ? await notifier.createProduct(
            categoryId: result.categoryId,
            name: result.name,
            priceMinor: result.priceMinor,
            hasModifiers: result.hasModifiers,
            sortOrder: result.sortOrder,
            isActive: result.isActive,
            isVisibleOnPos: result.isVisibleOnPos,
          )
        : await notifier.updateProduct(
            id: product.id,
            categoryId: result.categoryId,
            name: result.name,
            priceMinor: result.priceMinor,
            hasModifiers: result.hasModifiers,
            sortOrder: result.sortOrder,
            isActive: result.isActive,
            isVisibleOnPos: result.isVisibleOnPos,
          );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (product == null
                    ? AppStrings.productCreated
                    : AppStrings.productUpdated)
              : (ref.read(adminProductsNotifierProvider).errorMessage ??
                    AppStrings.operationFailed),
        ),
      ),
    );
  }

  Future<void> _openSemanticConfigurationDialog(
    BuildContext context, {
    required int productId,
  }) async {
    final bool? changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          SemanticProductConfigurationDialog(productId: productId),
    );
    if (changed == true) {
      await ref.read(adminProductsNotifierProvider.notifier).load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(const SnackBar(content: Text(_semanticConfigSavedLabel)));
    }
  }

  Future<void> _openMealAdjustmentDialog(Product product) async {
    final bool? changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          _MealAdjustmentAssignmentDialog(product: product),
    );
    if (changed == true) {
      await ref.read(adminProductsNotifierProvider.notifier).load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_mealAdjustmentSavedLabel)));
    }
  }

  Future<void> _openProductModifiersDialog(Product product) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          _ProductModifiersDialog(product: product),
    );
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final AdminProductsNotifier notifier = ref.read(
      adminProductsNotifierProvider.notifier,
    );
    final ProductDeletionAnalysis? analysis = await notifier.analyzeDeletion(
      id: product.id,
    );
    if (analysis == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(adminProductsNotifierProvider).errorMessage ??
                AppStrings.operationFailed,
          ),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }

    final _DeleteDecision? decision = await showDialog<_DeleteDecision>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_deleteDialogTitle(analysis)),
          content: Text(_deleteDialogBody(analysis)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.cancel),
            ),
            ElevatedButton(
              key: ValueKey<String>('product-delete-confirm-${product.id}'),
              onPressed: () => Navigator.of(context).pop(
                _DeleteDecision(
                  confirmSemanticImpact:
                      !analysis.isSetProduct && analysis.hasSemanticReferences,
                ),
              ),
              child: Text(analysis.hasHistoricalUsage ? 'Archive' : 'Delete'),
            ),
          ],
        );
      },
    );
    if (decision == null) {
      return;
    }

    final ProductDeleteOutcome? outcome = decision.confirmSemanticImpact
        ? await notifier.deleteProductWithImpactAcknowledged(id: product.id)
        : await notifier.deleteProduct(id: product.id);

    if (!mounted) {
      return;
    }
    final String message;
    if (outcome == null) {
      message =
          ref.read(adminProductsNotifierProvider).errorMessage ??
          AppStrings.operationFailed;
    } else {
      message = _deleteOutcomeMessage(analysis, outcome);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _deleteDialogTitle(ProductDeletionAnalysis analysis) {
    if (analysis.isSetProduct) {
      return analysis.hasHistoricalUsage
          ? 'Archive set product?'
          : 'Delete this set product?';
    }
    if (analysis.hasHistoricalUsage) {
      return 'Archive product?';
    }
    return _deleteProductTitle;
  }

  String _deleteDialogBody(ProductDeletionAnalysis analysis) {
    if (analysis.isSetProduct) {
      if (analysis.hasHistoricalUsage) {
        return _setArchivedOnDeleteMessage;
      }
      return 'This removes the set and its builder configuration.\nIncluded items, required choices, and extras will NOT delete the master products they reference.';
    }
    if (analysis.hasHistoricalUsage) {
      return _productArchivedOnDeleteMessage;
    }
    if (analysis.hasMealAdjustmentReferences) {
      return 'This product is referenced by active meal-adjustment profiles and cannot be archived or deleted.\n\nUsed as default item in ${analysis.mealComponentDefaultReferenceCount} component(s)\nUsed as swap target in ${analysis.mealSwapOptionReferenceCount} option(s)\nUsed as extra item in ${analysis.mealExtraOptionReferenceCount} profile extra(s)\nUsed in ${analysis.mealPricingRuleReferenceCount} pricing rule condition(s)\nImpacts ${analysis.mealAffectedProfileCount} active profile(s)';
    }
    if (analysis.hasSemanticReferences) {
      return 'This product is used by other set configurations. Deleting it may affect those sets.\n\nUsed in ${analysis.setConfigReferenceCount} set configurations\nUsed in ${analysis.requiredChoiceReferenceCount} required choices\nUsed in ${analysis.extrasPoolReferenceCount} extras pools';
    }
    return _deleteProductMessage;
  }

  String _deleteOutcomeMessage(
    ProductDeletionAnalysis analysis,
    ProductDeleteOutcome outcome,
  ) {
    return switch (outcome) {
      ProductDeleteOutcome.deleted =>
        analysis.isSetProduct ? _setDeletedMessage : _productDeletedMessage,
      ProductDeleteOutcome.deactivated =>
        analysis.isSetProduct
            ? _setArchivedOnDeleteMessage
            : _productArchivedOnDeleteMessage,
    };
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({
    required this.product,
    required this.profile,
    required this.mealProfileVisibility,
    required this.categories,
    required this.isSaving,
    required this.showSetBuilder,
    required this.onEdit,
    required this.onConfigureSemantic,
    required this.onConfigureMealAdjustment,
    required this.onManageModifiers,
    required this.onDelete,
    this.legacyLineCount = 0,
  });

  final Product product;
  final ProductMenuConfigurationProfile profile;
  final AdminMealProfileVisibility? mealProfileVisibility;
  final List<Category> categories;
  final bool isSaving;
  final bool showSetBuilder;
  final VoidCallback onEdit;
  final VoidCallback onConfigureSemantic;
  final VoidCallback onConfigureMealAdjustment;
  final VoidCallback onManageModifiers;
  final VoidCallback onDelete;
  final int legacyLineCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String categoryName = '-';
    for (final Category category in categories) {
      if (category.id == product.categoryId) {
        categoryName = category.name;
        break;
      }
    }

    final bool visibleInPos = product.isActive && product.isVisibleOnPos;

    return Opacity(
      opacity: product.isActive ? 1 : 0.62,
      child: Card(
        key: ValueKey<String>('product-tile-${product.id}'),
        margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
        child: ListTile(
          title: Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$categoryName · ${CurrencyFormatter.fromMinor(product.priceMinor)} · ${AppStrings.hasModifiersLabel}=${product.hasModifiers}',
              ),
              const SizedBox(height: AppSizes.spacingXs),
              Wrap(
                spacing: AppSizes.spacingXs,
                runSpacing: AppSizes.spacingXs,
                children: <Widget>[
                  _StatusChip(
                    label: product.isActive
                        ? AppStrings.active
                        : _archivedLabel,
                    color: product.isActive
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  _StatusChip(
                    label: visibleInPos
                        ? _visibleOnPosLabel
                        : _hiddenOnPosLabel,
                    color: visibleInPos ? AppColors.primary : AppColors.warning,
                  ),
                  _StatusChip(
                    label: '$_roleLabel: ${_menuTypeLabel(profile.type)}',
                    color: _menuTypeColor(profile.type),
                  ),
                  _StatusChip(
                    label: product.mealAdjustmentProfileId == null
                        ? 'Meal profile: none'
                        : 'Meal profile: ${mealProfileVisibility?.profileName ?? '#${product.mealAdjustmentProfileId}'}',
                    color: product.mealAdjustmentProfileId == null
                        ? AppColors.textSecondary
                        : _mealHealthColor(mealProfileVisibility?.healthStatus),
                  ),
                  if (mealProfileVisibility != null)
                    const _StatusChip(
                      label: 'Has meal customizations',
                      color: AppColors.primary,
                    ),
                  if (mealProfileVisibility != null)
                    _StatusChip(
                      label:
                          'Health: ${mealProfileVisibility!.healthStatus.name}',
                      color: _mealHealthColor(
                        mealProfileVisibility!.healthStatus,
                      ),
                    ),
                  if (legacyLineCount > 0)
                    _StatusChip(
                      label: 'Legacy lines: $legacyLineCount',
                      color: AppColors.warning,
                    ),
                ],
              ),
              if (mealProfileVisibility != null) ...<Widget>[
                const SizedBox(height: AppSizes.spacingXs),
                Text(
                  mealProfileVisibility!.headline,
                  style: TextStyle(
                    color:
                        mealProfileVisibility!.healthStatus ==
                            MealAdjustmentHealthStatus.invalid
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Preview: ${mealProfileVisibility!.previewSummary}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          trailing: Wrap(
            spacing: AppSizes.spacingSm,
            runSpacing: AppSizes.spacingSm,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(_visibleOnPosLabel),
                  Switch(
                    value: product.isVisibleOnPos,
                    onChanged: isSaving
                        ? null
                        : (bool value) {
                            ref
                                .read(adminProductsNotifierProvider.notifier)
                                .toggleProductVisibilityOnPos(
                                  id: product.id,
                                  isVisibleOnPos: value,
                                );
                          },
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(AppStrings.active),
                  Switch(
                    value: product.isActive,
                    onChanged: isSaving
                        ? null
                        : (bool value) {
                            ref
                                .read(adminProductsNotifierProvider.notifier)
                                .toggleProductActive(
                                  id: product.id,
                                  isActive: value,
                                );
                          },
                  ),
                ],
              ),
              if (showSetBuilder)
                OutlinedButton(
                  key: ValueKey<String>('product-set-builder-${product.id}'),
                  onPressed: isSaving ? null : onConfigureSemantic,
                  child: const Text(_configureSemanticLabel),
                ),
              if (!showSetBuilder)
                OutlinedButton(
                  key: ValueKey<String>('product-meal-engine-${product.id}'),
                  onPressed: isSaving ? null : onConfigureMealAdjustment,
                  child: const Text(_configureMealAdjustmentLabel),
                ),
              if (!showSetBuilder && product.mealAdjustmentProfileId != null)
                OutlinedButton(
                  key: ValueKey<String>('product-meal-insights-${product.id}'),
                  onPressed: isSaving
                      ? null
                      : () => _showMealInsights(context, ref),
                  child: const Text('Meal Insights'),
                ),
              OutlinedButton(
                key: ValueKey<String>('product-modifiers-${product.id}'),
                onPressed: isSaving ? null : onManageModifiers,
                child: const Text(_manageModifiersLabel),
              ),
              OutlinedButton(
                onPressed: isSaving ? null : onEdit,
                child: Text(AppStrings.edit),
              ),
              TextButton(
                key: ValueKey<String>('product-delete-${product.id}'),
                onPressed: isSaving ? null : onDelete,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMealInsights(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _MealInsightsDialog(product: product),
    );
  }
}

Color _mealHealthColor(MealAdjustmentHealthStatus? status) {
  switch (status) {
    case MealAdjustmentHealthStatus.valid:
      return AppColors.success;
    case MealAdjustmentHealthStatus.incomplete:
      return AppColors.warning;
    case MealAdjustmentHealthStatus.invalid:
      return AppColors.error;
    case null:
      return AppColors.textSecondary;
  }
}

class _MealAdjustmentAssignmentDialog extends ConsumerStatefulWidget {
  const _MealAdjustmentAssignmentDialog({required this.product});

  final Product product;

  @override
  ConsumerState<_MealAdjustmentAssignmentDialog> createState() =>
      _MealAdjustmentAssignmentDialogState();
}

class _MealAdjustmentAssignmentDialogState
    extends ConsumerState<_MealAdjustmentAssignmentDialog> {
  List<MealAdjustmentProfile> _profiles = const <MealAdjustmentProfile>[];
  int? _selectedProfileId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  MealAdjustmentProfileHealthSummary? _healthSummary;
  MealCustomizationResolvedSnapshot? _previewSnapshot;
  MealCustomizationRequest? _previewRequest;

  @override
  void initState() {
    super.initState();
    _selectedProfileId = widget.product.mealAdjustmentProfileId;
    Future<void>.microtask(_loadProfilesAndState);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelectedProfile =
        _selectedProfileId != null &&
        _profiles.any(
          (MealAdjustmentProfile profile) => profile.id == _selectedProfileId,
        );
    final MealAdjustmentProfile? selectedProfile = hasSelectedProfile
        ? _profiles.firstWhere(
            (MealAdjustmentProfile profile) => profile.id == _selectedProfileId,
          )
        : null;
    return AlertDialog(
      title: Text('Meal Engine: ${widget.product.name}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<int?>(
                isExpanded: true,
                value: hasSelectedProfile ? _selectedProfileId : null,
                decoration: const InputDecoration(
                  labelText: 'Assigned meal profile',
                ),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ..._profiles.map(
                    (MealAdjustmentProfile profile) => DropdownMenuItem<int?>(
                      value: profile.id,
                      child: Text(
                        '${profile.name} • ${_mealProfileTypeBadgeLabel(profile.kind)}',
                      ),
                    ),
                  ),
                ],
                onChanged: _isLoading || _isSaving
                    ? null
                    : (int? value) async {
                        setState(() {
                          _selectedProfileId = value;
                        });
                        await _loadSelectedProfileState();
                      },
              ),
              const SizedBox(height: AppSizes.spacingMd),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...<Widget>[
                if (selectedProfile != null)
                  _MessageBox(
                    message:
                        '${selectedProfile.name} (${_mealProfileTypeBadgeLabel(selectedProfile.kind)})'
                        '\n${_mealProfileAssignmentSummary(selectedProfile.kind)}',
                    color:
                        selectedProfile.kind ==
                            MealAdjustmentProfileKind.sandwich
                        ? AppColors.primary
                        : AppColors.success,
                  ),
                if (_errorMessage != null)
                  _MessageBox(message: _errorMessage!, color: AppColors.error),
                if (_healthSummary == null)
                  const _MessageBox(
                    message:
                        'No meal-adjustment profile is assigned. Save to keep the product on the normal standard flow.',
                    color: AppColors.primary,
                  )
                else ...<Widget>[
                  if (selectedProfile?.kind ==
                      MealAdjustmentProfileKind.sandwich)
                    const _MessageBox(
                      message:
                          'Roll uses the product price as the base price. Sandwich and Baguette use the surcharges configured on the profile. Sauces are free multi-select, toast only appears for Sandwich bread, and paid extras come from Add-ins.',
                      color: AppColors.primary,
                    ),
                  _MessageBox(
                    message: _healthSummary!.headline,
                    color: _healthColor(_healthSummary!.healthStatus),
                  ),
                  const SizedBox(height: AppSizes.spacingSm),
                  Text(_healthSummary!.body),
                  const SizedBox(height: AppSizes.spacingSm),
                  Text(
                    'Blocking errors: ${_healthSummary!.validationResult.blockingErrors.length}',
                  ),
                  Text(
                    'Affected products: ${_healthSummary!.affectedProducts.length}',
                  ),
                  const SizedBox(height: AppSizes.spacingMd),
                  if (_previewRequest == null)
                    const Text(
                      'Sample preview unavailable: profile has no removable, swappable, or extra sample input.',
                    )
                  else if (_previewSnapshot == null)
                    const Text(
                      'Sample preview unavailable because the selected profile is invalid.',
                    )
                  else
                    _MealAdjustmentPreviewCard(
                      request: _previewRequest!,
                      snapshot: _previewSnapshot!,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: _isLoading || _isSaving ? null : _save,
          child: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _loadProfilesAndState() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<MealAdjustmentProfile> profiles = await ref
          .read(mealAdjustmentProfileRepositoryProvider)
          .listProfilesForAdmin();
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = profiles;
      });
      await _loadSelectedProfileState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '$error';
      });
    }
  }

  Future<void> _loadSelectedProfileState() async {
    final int? profileId = _selectedProfileId;
    if (profileId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _healthSummary = null;
        _previewSnapshot = null;
        _previewRequest = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _healthSummary = null;
      _previewSnapshot = null;
      _previewRequest = null;
    });

    try {
      final mealAdminService = ref.read(mealAdjustmentAdminServiceProvider);
      final MealAdjustmentProfileDraft draft = await mealAdminService
          .loadProfileDraft(profileId);
      final MealAdjustmentProfileHealthSummary healthSummary =
          await mealAdminService.computeHealthSummary(draft);
      final MealCustomizationRequest? previewRequest = _buildSampleRequest(
        product: widget.product,
        draft: draft,
      );
      MealCustomizationResolvedSnapshot? previewSnapshot;
      if (previewRequest != null &&
          healthSummary.healthStatus == MealAdjustmentHealthStatus.valid) {
        previewSnapshot = await mealAdminService.previewEvaluation(
          draft: draft,
          request: previewRequest,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _healthSummary = healthSummary;
        _previewRequest = previewRequest;
        _previewSnapshot = previewSnapshot;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '$error';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final mealAdminService = ref.read(mealAdjustmentAdminServiceProvider);
      final int? profileId = _selectedProfileId;
      if (profileId == null) {
        await mealAdminService.unassignProfileFromProduct(widget.product.id);
      } else {
        await mealAdminService.assignProfileToProduct(
          productId: widget.product.id,
          profileId: profileId,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = '$error';
      });
    }
  }

  MealCustomizationRequest? _buildSampleRequest({
    required Product product,
    required MealAdjustmentProfileDraft draft,
  }) {
    final MealAdjustmentComponentDraft? removableComponent = draft.components
        .where(
          (MealAdjustmentComponentDraft component) =>
              component.isActive && component.canRemove,
        )
        .cast<MealAdjustmentComponentDraft?>()
        .firstWhere(
          (MealAdjustmentComponentDraft? component) => component != null,
          orElse: () => null,
        );
    final MealAdjustmentComponentDraft? swappableComponent = draft.components
        .where(
          (MealAdjustmentComponentDraft component) =>
              component.isActive &&
              component.swapOptions.any(
                (MealAdjustmentComponentOptionDraft option) => option.isActive,
              ),
        )
        .cast<MealAdjustmentComponentDraft?>()
        .firstWhere(
          (MealAdjustmentComponentDraft? component) => component != null,
          orElse: () => null,
        );
    final MealAdjustmentExtraOptionDraft? extraOption = draft.extraOptions
        .where((MealAdjustmentExtraOptionDraft option) => option.isActive)
        .cast<MealAdjustmentExtraOptionDraft?>()
        .firstWhere(
          (MealAdjustmentExtraOptionDraft? option) => option != null,
          orElse: () => null,
        );

    final List<String> removedComponentKeys = removableComponent == null
        ? const <String>[]
        : <String>[removableComponent.componentKey];
    final List<MealCustomizationComponentSelection> swapSelections =
        swappableComponent == null
        ? const <MealCustomizationComponentSelection>[]
        : <MealCustomizationComponentSelection>[
            MealCustomizationComponentSelection(
              componentKey: swappableComponent.componentKey,
              targetItemProductId: swappableComponent.swapOptions
                  .firstWhere(
                    (MealAdjustmentComponentOptionDraft option) =>
                        option.isActive,
                  )
                  .optionItemProductId,
            ),
          ];
    final List<MealCustomizationExtraSelection> extraSelections =
        extraOption == null
        ? const <MealCustomizationExtraSelection>[]
        : <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(
              itemProductId: extraOption.itemProductId,
            ),
          ];
    if (removedComponentKeys.isEmpty &&
        swapSelections.isEmpty &&
        extraSelections.isEmpty) {
      return null;
    }
    return MealCustomizationRequest(
      productId: product.id,
      profileId: draft.id,
      removedComponentKeys: removedComponentKeys,
      swapSelections: swapSelections,
      extraSelections: extraSelections,
    );
  }

  Color _healthColor(MealAdjustmentHealthStatus status) {
    switch (status) {
      case MealAdjustmentHealthStatus.valid:
        return AppColors.success;
      case MealAdjustmentHealthStatus.incomplete:
        return AppColors.warning;
      case MealAdjustmentHealthStatus.invalid:
        return AppColors.error;
    }
  }
}

class _MealAdjustmentPreviewCard extends StatelessWidget {
  const _MealAdjustmentPreviewCard({
    required this.request,
    required this.snapshot,
  });

  final MealCustomizationRequest request;
  final MealCustomizationResolvedSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = <String>[
      'Sample request: remove=${request.removedComponentKeys.join(', ')}, swaps=${request.swapSelections.length}, extras=${request.extraSelections.length}',
      'Resolved actions: ${snapshot.actions.length}',
      'Applied rules: ${snapshot.appliedRuleIds.isEmpty ? 'none' : snapshot.appliedRuleIds.join(', ')}',
      'Adjustment total: ${CurrencyFormatter.fromMinor(snapshot.totalAdjustmentMinor)}',
      'Free swaps used: ${snapshot.freeSwapCountUsed}',
      'Paid swaps used: ${snapshot.paidSwapCountUsed}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: lines
            .map(
              (String line) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
                child: Text(line),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

String _menuTypeLabel(ProductMenuConfigType type) {
  switch (type) {
    case ProductMenuConfigType.standard:
      return 'Standard';
    case ProductMenuConfigType.legacyFlat:
      return 'Flat Modifiers';
    case ProductMenuConfigType.semanticSet:
      return 'Set Product';
    case ProductMenuConfigType.mixed:
      return 'Mixed (conflict)';
  }
}

Color _menuTypeColor(ProductMenuConfigType type) {
  switch (type) {
    case ProductMenuConfigType.standard:
      return AppColors.textSecondary;
    case ProductMenuConfigType.legacyFlat:
      return AppColors.primary;
    case ProductMenuConfigType.semanticSet:
      return AppColors.success;
    case ProductMenuConfigType.mixed:
      return AppColors.warning;
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({
    required this.categories,
    this.initialCategoryId,
    this.product,
  });

  final List<Category> categories;
  final int? initialCategoryId;
  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _sortOrderController;
  late int _categoryId;
  late bool _hasModifiers;
  late bool _isActive;
  late bool _isVisibleOnPos;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: '${widget.product?.priceMinor ?? 0}',
    );
    _sortOrderController = TextEditingController(
      text: '${widget.product?.sortOrder ?? 0}',
    );
    _categoryId =
        widget.product?.categoryId ??
        _ensureValidSelection<int>(
          current: widget.initialCategoryId,
          items: widget.categories.map((Category category) => category.id),
        ) ??
        widget.categories.first.id;
    _hasModifiers = widget.product?.hasModifiers ?? false;
    _isActive = widget.product?.isActive ?? true;
    _isVisibleOnPos = widget.product?.isVisibleOnPos ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null
            ? AppStrings.addProductDialogTitle
            : AppStrings.editProductDialogTitle,
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<int>(
              value: _categoryId,
              decoration: InputDecoration(labelText: AppStrings.categoryLabel),
              items: widget.categories
                  .map(
                    (Category category) => DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() => _categoryId = value);
                }
              },
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppStrings.productNameLabel,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: AppStrings.priceMinorLabel,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              controller: _sortOrderController,
              decoration: InputDecoration(labelText: AppStrings.sortOrderLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasModifiers,
              onChanged: (bool? value) {
                setState(() => _hasModifiers = value ?? false);
              },
              title: Text(AppStrings.hasModifiersLabel),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (bool value) => setState(() => _isActive = value),
              title: Text(AppStrings.active),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isVisibleOnPos,
              onChanged: (bool value) =>
                  setState(() => _isVisibleOnPos = value),
              title: const Text(_visibleOnPosLabel),
              subtitle: const Text(
                'Hide product from cashier POS without deleting it.',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(
              _ProductFormResult(
                categoryId: _categoryId,
                name: _nameController.text,
                priceMinor: int.tryParse(_priceController.text) ?? -1,
                sortOrder: int.tryParse(_sortOrderController.text) ?? 0,
                hasModifiers: _hasModifiers,
                isActive: _isActive,
                isVisibleOnPos: _isVisibleOnPos,
              ),
            );
          },
          child: Text(AppStrings.saveSettings),
        ),
      ],
    );
  }
}

class _ProductFormResult {
  const _ProductFormResult({
    required this.categoryId,
    required this.name,
    required this.priceMinor,
    required this.sortOrder,
    required this.hasModifiers,
    required this.isActive,
    required this.isVisibleOnPos,
  });

  final int categoryId;
  final String name;
  final int priceMinor;
  final int sortOrder;
  final bool hasModifiers;
  final bool isActive;
  final bool isVisibleOnPos;
}

class _ProductModifiersDialog extends ConsumerStatefulWidget {
  const _ProductModifiersDialog({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductModifiersDialog> createState() =>
      _ProductModifiersDialogState();
}

class _ProductModifiersDialogState
    extends ConsumerState<_ProductModifiersDialog> {
  List<ProductModifier> _modifiers = const <ProductModifier>[];
  List<Product> _availableProducts = const <Product>[];
  List<Category> _availableCategories = const <Category>[];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _infoMessage;

  bool get _containsSetChoices =>
      _modifiers.any((ProductModifier modifier) => modifier.isChoice);

  bool get _prefersStructuredUi =>
      _modifiers.any((ProductModifier modifier) => modifier.hasStructuredUi);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadDialogData);
  }

  @override
  Widget build(BuildContext context) {
    final List<_ModifierSectionGroup> groups = _buildModifierGroups(_modifiers);
    return AlertDialog(
      key: ValueKey<String>('product-modifiers-dialog-${widget.product.id}'),
      title: Text('Modifiers: ${widget.product.name}'),
      content: SizedBox(
        width: 920,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_errorMessage != null)
                _MessageBox(message: _errorMessage!, color: AppColors.error),
              if (_infoMessage != null)
                _MessageBox(message: _infoMessage!, color: AppColors.success),
              const _MessageBox(
                message: _modifierDialogHint,
                color: AppColors.primary,
              ),
              if (_containsSetChoices)
                const _MessageBox(
                  message: _setChoiceWarning,
                  color: AppColors.warning,
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_modifiers.length} modifier row(s)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    key: const ValueKey<String>('modifier-add-button'),
                    onPressed: _isLoading || _isSaving || _containsSetChoices
                        ? null
                        : () => _openModifierEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(_addProductModifierLabel),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingMd),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : groups.isEmpty
                    ? _EmptyState(message: AppStrings.noModifiersForProduct)
                    : SingleChildScrollView(
                        child: Column(
                          children: groups
                              .map(
                                (_ModifierSectionGroup group) =>
                                    _ModifierSectionCard(
                                      group: group,
                                      isSaving: _isSaving,
                                      onEdit:
                                          group.section ==
                                                  _ModifierSection.choice ||
                                              _containsSetChoices
                                          ? null
                                          : _openModifierEditor,
                                      onDelete:
                                          group.section ==
                                                  _ModifierSection.choice ||
                                              _containsSetChoices
                                          ? null
                                          : _confirmDeleteModifier,
                                      onToggleActive: _toggleModifierActive,
                                    ),
                              )
                              .toList(growable: false),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(AppStrings.close),
        ),
      ],
    );
  }

  Future<void> _loadDialogData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        ref
            .read(adminServiceProvider)
            .getModifiersForProduct(widget.product.id),
        ref.read(adminServiceProvider).getProducts(),
        ref.read(adminServiceProvider).getCategories(),
      ]);
      final List<ProductModifier> modifiers =
          results[0] as List<ProductModifier>;
      final List<Product> products = results[1] as List<Product>;
      final List<Category> categories = results[2] as List<Category>;
      if (!mounted) {
        return;
      }
      setState(() {
        _modifiers = modifiers;
        _availableProducts = _sortedProducts(products);
        _availableCategories = _sortedCategories(categories);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '$error';
      });
    }
  }

  Future<void> _openModifierEditor([ProductModifier? modifier]) async {
    final _ProductModifierEditorResult? result =
        await showDialog<_ProductModifierEditorResult>(
          context: context,
          builder: (BuildContext context) => _ProductModifierEditorDialog(
            products: _availableProducts,
            categories: _availableCategories,
            modifier: modifier,
            existingModifiers: _modifiers,
            prefersStructuredUi: _prefersStructuredUi,
            onQuickCreateProduct: _openQuickCreateProductDialog,
          ),
        );
    if (result == null) {
      return;
    }

    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = AppStrings.accessDenied);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      if (modifier == null &&
          result.mode == _ProductModifierEditorMode.bulk &&
          result.sourceCategoryId != null) {
        final BulkModifierCreateResult bulkResult = await ref
            .read(adminServiceProvider)
            .bulkCreateModifiersFromCategory(
              user: currentUser,
              productId: widget.product.id,
              sourceCategoryId: result.sourceCategoryId!,
              type: result.type,
              isActive: result.isActive,
              priceBehavior: result.priceBehavior,
              uiSection: result.uiSection,
            );
        await _loadDialogData();
        if (!mounted) {
          return;
        }
        setState(() {
          _isSaving = false;
          _infoMessage =
              'Bulk add complete. Added ${bulkResult.createdCount} product(s). Skipped ${bulkResult.skippedCount} already linked.';
        });
      } else if (modifier == null) {
        await ref
            .read(adminServiceProvider)
            .createModifier(
              user: currentUser,
              productId: widget.product.id,
              name: result.linkedProductName!,
              type: result.type,
              extraPriceMinor: result.extraPriceMinor,
              isActive: result.isActive,
              itemProductId: result.linkedProductId,
              priceBehavior: result.priceBehavior,
              uiSection: result.uiSection,
            );
        await _loadDialogData();
        if (!mounted) {
          return;
        }
        setState(() {
          _isSaving = false;
          _infoMessage = _modifierCreatedMessage;
        });
      } else {
        await ref
            .read(adminServiceProvider)
            .updateModifier(
              user: currentUser,
              id: modifier.id,
              productId: widget.product.id,
              name: result.linkedProductName!,
              type: result.type,
              extraPriceMinor: result.extraPriceMinor,
              isActive: result.isActive,
              itemProductId: result.linkedProductId,
              priceBehavior: result.priceBehavior,
              uiSection: result.uiSection,
            );
        await _loadDialogData();
        if (!mounted) {
          return;
        }
        setState(() {
          _isSaving = false;
          _infoMessage = _modifierUpdatedMessage;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = '$error';
      });
    }
  }

  Future<void> _toggleModifierActive(
    ProductModifier modifier,
    bool isActive,
  ) async {
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = AppStrings.accessDenied);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await ref
          .read(adminServiceProvider)
          .toggleModifierActive(
            user: currentUser,
            id: modifier.id,
            isActive: isActive,
          );
      await _loadDialogData();
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = '$error';
      });
    }
  }

  Future<void> _confirmDeleteModifier(ProductModifier modifier) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(_removeModifierTitle),
        content: Text('${modifier.name}\n\n$_removeModifierMessage'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            key: ValueKey<String>('modifier-delete-confirm-${modifier.id}'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = AppStrings.accessDenied);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await ref
          .read(adminServiceProvider)
          .deleteModifier(user: currentUser, id: modifier.id);
      await _loadDialogData();
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _infoMessage = _modifierDeletedMessage;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = '$error';
      });
    }
  }

  Future<Product?> _openQuickCreateProductDialog() async {
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = AppStrings.accessDenied);
      return null;
    }
    final _QuickModifierProductResult? result =
        await showDialog<_QuickModifierProductResult>(
          context: context,
          builder: (BuildContext context) =>
              _QuickModifierProductDialog(categories: _availableCategories),
        );
    if (result == null) {
      return null;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final int productId = await ref
          .read(adminServiceProvider)
          .createProduct(
            user: currentUser,
            categoryId: result.categoryId,
            name: result.name,
            priceMinor: result.priceMinor,
            hasModifiers: false,
            sortOrder: 0,
            isActive: result.isActive,
            isVisibleOnPos: result.isVisibleOnPos,
          );
      final Product product = Product(
        id: productId,
        categoryId: result.categoryId,
        mealAdjustmentProfileId: null,
        name: result.name,
        priceMinor: result.priceMinor,
        imageUrl: null,
        hasModifiers: false,
        sortOrder: 0,
        isActive: result.isActive,
        isVisibleOnPos: result.isVisibleOnPos,
      );
      await ref.read(adminProductsNotifierProvider.notifier).load();
      if (!mounted) {
        return null;
      }
      setState(() {
        _availableProducts = _sortedProducts(<Product>[
          ..._availableProducts.where((Product item) => item.id != product.id),
          product,
        ]);
        _isSaving = false;
        _infoMessage = _productCreatedForModifierMessage;
      });
      return product;
    } catch (error) {
      if (!mounted) {
        return null;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = '$error';
      });
      return null;
    }
  }
}

class _ModifierSectionCard extends StatelessWidget {
  const _ModifierSectionCard({
    required this.group,
    required this.isSaving,
    required this.onToggleActive,
    this.onEdit,
    this.onDelete,
  });

  final _ModifierSectionGroup group;
  final bool isSaving;
  final Future<void> Function(ProductModifier modifier, bool isActive)
  onToggleActive;
  final Future<void> Function(ProductModifier modifier)? onEdit;
  final Future<void> Function(ProductModifier modifier)? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('modifier-section-${group.section.name}'),
      margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            group.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          ...group.modifiers.map(
            (ProductModifier modifier) => _ModifierListRow(
              modifier: modifier,
              isSaving: isSaving,
              onEdit: onEdit,
              onDelete: onDelete,
              onToggleActive: onToggleActive,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModifierListRow extends StatelessWidget {
  const _ModifierListRow({
    required this.modifier,
    required this.isSaving,
    required this.onToggleActive,
    this.onEdit,
    this.onDelete,
  });

  final ProductModifier modifier;
  final bool isSaving;
  final Future<void> Function(ProductModifier modifier, bool isActive)
  onToggleActive;
  final Future<void> Function(ProductModifier modifier)? onEdit;
  final Future<void> Function(ProductModifier modifier)? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('modifier-row-${modifier.id}'),
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  modifier.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSizes.spacingXs),
                Text(
                  _modifierSummary(modifier),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                modifier.isActive ? AppStrings.active : _archivedLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Switch(
                value: modifier.isActive,
                onChanged: isSaving
                    ? null
                    : (bool value) => onToggleActive(modifier, value),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.spacingSm),
          OutlinedButton(
            key: ValueKey<String>('modifier-edit-${modifier.id}'),
            onPressed: isSaving || onEdit == null
                ? null
                : () => onEdit!(modifier),
            child: Text(AppStrings.edit),
          ),
          const SizedBox(width: AppSizes.spacingXs),
          TextButton(
            key: ValueKey<String>('modifier-delete-${modifier.id}'),
            onPressed: isSaving || onDelete == null
                ? null
                : () => onDelete!(modifier),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _ProductModifierEditorDialog extends StatefulWidget {
  const _ProductModifierEditorDialog({
    required this.products,
    required this.categories,
    required this.existingModifiers,
    required this.prefersStructuredUi,
    required this.onQuickCreateProduct,
    this.modifier,
  });

  final List<Product> products;
  final List<Category> categories;
  final List<ProductModifier> existingModifiers;
  final ProductModifier? modifier;
  final bool prefersStructuredUi;
  final Future<Product?> Function() onQuickCreateProduct;

  @override
  State<_ProductModifierEditorDialog> createState() =>
      _ProductModifierEditorDialogState();
}

class _ProductModifierEditorDialogState
    extends State<_ProductModifierEditorDialog> {
  TextEditingController? _productSearchController;
  late List<Product> _products;
  late _ProductModifierEditorMode _mode;
  late ModifierType _type;
  late ModifierPriceBehavior? _priceBehavior;
  late ModifierUiSection? _uiSection;
  late bool _isActive;
  int? _selectedProductId;
  int? _selectedCategoryId;
  String? _validationMessage;
  bool _isProgrammaticSearchUpdate = false;

  List<Product> get _filteredProducts {
    final List<Product> products = _products
        .where(
          (Product product) =>
              _selectedCategoryId == null ||
              product.categoryId == _selectedCategoryId,
        )
        .toList(growable: false);
    return _sortedProducts(products);
  }

  Product? get _selectedProduct =>
      _selectedProductId == null ? null : _findProductById(_selectedProductId!);

  Set<int> get _existingLinkedProductIds => widget.existingModifiers
      .map((ProductModifier modifier) => modifier.itemProductId)
      .whereType<int>()
      .toSet();

  _BulkModifierSelectionSummary get _bulkSummary {
    if (_selectedCategoryId == null) {
      return const _BulkModifierSelectionSummary(
        categorySelected: false,
        addCount: 0,
        skippedCount: 0,
      );
    }

    int addCount = 0;
    int skippedCount = 0;
    final Set<int> existingLinkedProductIds = _existingLinkedProductIds;
    final Set<int> seenProductIds = <int>{};

    for (final Product product in _products) {
      if (!product.isActive || product.categoryId != _selectedCategoryId) {
        continue;
      }
      if (!seenProductIds.add(product.id)) {
        continue;
      }
      if (existingLinkedProductIds.contains(product.id)) {
        skippedCount += 1;
      } else {
        addCount += 1;
      }
    }

    return _BulkModifierSelectionSummary(
      categorySelected: true,
      addCount: addCount,
      skippedCount: skippedCount,
    );
  }

  @override
  void initState() {
    super.initState();
    _products = _sortedProducts(widget.products);
    _mode = _ProductModifierEditorMode.single;
    _selectedProductId = widget.modifier?.itemProductId;
    _selectedCategoryId = _selectedProduct?.categoryId;
    _type =
        widget.modifier?.type ??
        (widget.prefersStructuredUi
            ? ModifierType.extra
            : ModifierType.included);
    _priceBehavior =
        widget.modifier?.priceBehavior ??
        (widget.prefersStructuredUi ? ModifierPriceBehavior.free : null);
    _uiSection =
        widget.modifier?.uiSection ??
        (widget.prefersStructuredUi ? ModifierUiSection.toppings : null);
    _isActive = widget.modifier?.isActive ?? true;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Product? selectedProduct = _selectedProduct;
    final _BulkModifierSelectionSummary bulkSummary = _bulkSummary;
    final bool showBulkMode = widget.modifier == null;
    return AlertDialog(
      title: Text(
        widget.modifier == null ? _addProductModifierLabel : 'Edit modifier',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_validationMessage != null)
                _MessageBox(
                  message: _validationMessage!,
                  color: AppColors.error,
                ),
              if (showBulkMode) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: RadioListTile<_ProductModifierEditorMode>(
                        key: const ValueKey<String>('modifier-mode-single'),
                        contentPadding: EdgeInsets.zero,
                        value: _ProductModifierEditorMode.single,
                        groupValue: _mode,
                        title: const Text('Single product'),
                        onChanged: (_ProductModifierEditorMode? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _mode = value;
                            _validationMessage = null;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<_ProductModifierEditorMode>(
                        key: const ValueKey<String>('modifier-mode-bulk'),
                        contentPadding: EdgeInsets.zero,
                        value: _ProductModifierEditorMode.bulk,
                        groupValue: _mode,
                        title: const Text('Bulk from category'),
                        onChanged: (_ProductModifierEditorMode? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _mode = value;
                            _validationMessage = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacingSm),
              ],
              if (_mode == _ProductModifierEditorMode.bulk) ...<Widget>[
                DropdownButtonFormField<int?>(
                  key: const ValueKey<String>('modifier-bulk-category-field'),
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: _modifierSourceCategoryLabel,
                  ),
                  items: widget.categories
                      .map(
                        (Category category) => DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (int? value) {
                    setState(() {
                      _selectedCategoryId = value;
                      _validationMessage = null;
                    });
                  },
                ),
                const SizedBox(height: AppSizes.spacingSm),
                _MessageBox(
                  key: const ValueKey<String>('modifier-bulk-summary'),
                  message: bulkSummary.categorySelected
                      ? 'Will add ${bulkSummary.addCount} product(s). Skip ${bulkSummary.skippedCount} already linked.'
                      : _modifierBulkSummarySelectCategoryMessage,
                  color: AppColors.primary,
                ),
              ] else ...<Widget>[
                DropdownButtonFormField<int?>(
                  key: const ValueKey<String>('modifier-category-filter'),
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: _modifierProductFilterLabel,
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...widget.categories.map(
                      (Category category) => DropdownMenuItem<int?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (int? value) {
                    setState(() {
                      _selectedCategoryId = value;
                      _validationMessage = null;
                    });
                  },
                ),
                const SizedBox(height: AppSizes.spacingMd),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Autocomplete<Product>(
                        initialValue: TextEditingValue(
                          text: selectedProduct?.name ?? '',
                        ),
                        displayStringForOption: (Product option) => option.name,
                        optionsBuilder: (TextEditingValue value) {
                          final String query = value.text.trim().toLowerCase();
                          return _filteredProducts.where((Product product) {
                            if (query.isEmpty) {
                              return true;
                            }
                            return product.name.toLowerCase().contains(query);
                          });
                        },
                        onSelected: (Product product) {
                          _selectProduct(product);
                        },
                        fieldViewBuilder:
                            (
                              BuildContext context,
                              TextEditingController textEditingController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              _productSearchController = textEditingController;
                              return TextField(
                                key: const ValueKey<String>(
                                  'modifier-product-search',
                                ),
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: _modifierProductSearchLabel,
                                  hintText: 'Search by product name',
                                ),
                                onChanged: _handleProductSearchChanged,
                                onTap: () {
                                  if (textEditingController.text.isEmpty) {
                                    textEditingController
                                        .selection = TextSelection.collapsed(
                                      offset: textEditingController.text.length,
                                    );
                                  }
                                },
                              );
                            },
                        optionsViewBuilder:
                            (
                              BuildContext context,
                              AutocompleteOnSelected<Product> onSelected,
                              Iterable<Product> options,
                            ) {
                              final List<Product> items = options.toList(
                                growable: false,
                              );
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 240,
                                      minWidth: 320,
                                      maxWidth: 420,
                                    ),
                                    child: items.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.all(
                                              AppSizes.spacingMd,
                                            ),
                                            child: Text('No products found.'),
                                          )
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            itemCount: items.length,
                                            itemBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) {
                                                  final Product option =
                                                      items[index];
                                                  return ListTile(
                                                    key: ValueKey<String>(
                                                      'modifier-product-option-${option.id}',
                                                    ),
                                                    title: Text(option.name),
                                                    subtitle: Text(
                                                      '${_categoryNameForId(widget.categories, option.categoryId)} · ${CurrencyFormatter.fromMinor(option.priceMinor)}',
                                                    ),
                                                    onTap: () =>
                                                        onSelected(option),
                                                  );
                                                },
                                          ),
                                  ),
                                ),
                              );
                            },
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacingSm),
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'modifier-new-product-button',
                      ),
                      onPressed: () async {
                        final Product? product = await widget
                            .onQuickCreateProduct();
                        if (product == null) {
                          return;
                        }
                        _selectProduct(product);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(_newModifierProductLabel),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacingSm),
                if (selectedProduct != null)
                  _MessageBox(
                    message:
                        '$_modifierLinkedProductLabel: ${selectedProduct.name}\n'
                        '${_categoryNameForId(widget.categories, selectedProduct.categoryId)} · ${CurrencyFormatter.fromMinor(selectedProduct.priceMinor)}\n'
                        '${selectedProduct.isVisibleOnPos ? _visibleOnPosLabel : _hiddenOnPosLabel}',
                    color: AppColors.primary,
                  )
                else
                  const _MessageBox(
                    message: _modifierVisibleInPickerLabel,
                    color: AppColors.primary,
                  ),
              ],
              const SizedBox(height: AppSizes.spacingMd),
              DropdownButtonFormField<ModifierType>(
                key: const ValueKey<String>('modifier-type-field'),
                value: _type,
                decoration: const InputDecoration(
                  labelText: _modifierTypeLabel,
                ),
                items: ProductModifier.legacyFlatTypes
                    .map(
                      (ModifierType type) => DropdownMenuItem<ModifierType>(
                        value: type,
                        child: Text(_labelForType(type)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (ModifierType? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _type = value;
                    if (_type != ModifierType.extra) {
                      _priceBehavior = null;
                      _uiSection = null;
                    }
                  });
                },
              ),
              const SizedBox(height: AppSizes.spacingMd),
              DropdownButtonFormField<ModifierPriceBehavior?>(
                key: const ValueKey<String>('modifier-price-behavior-field'),
                value: _type == ModifierType.extra ? _priceBehavior : null,
                decoration: const InputDecoration(
                  labelText: _modifierPriceBehaviorLabel,
                ),
                items: const <DropdownMenuItem<ModifierPriceBehavior?>>[
                  DropdownMenuItem<ModifierPriceBehavior?>(
                    value: null,
                    child: Text(_modifierNoStructuredValueLabel),
                  ),
                  DropdownMenuItem<ModifierPriceBehavior?>(
                    value: ModifierPriceBehavior.free,
                    child: Text('Free'),
                  ),
                  DropdownMenuItem<ModifierPriceBehavior?>(
                    value: ModifierPriceBehavior.paid,
                    child: Text('Paid'),
                  ),
                ],
                onChanged: _type != ModifierType.extra
                    ? null
                    : (ModifierPriceBehavior? value) {
                        setState(() {
                          _priceBehavior = value;
                        });
                      },
              ),
              const SizedBox(height: AppSizes.spacingMd),
              DropdownButtonFormField<ModifierUiSection?>(
                key: const ValueKey<String>('modifier-ui-section-field'),
                value: _type == ModifierType.extra ? _uiSection : null,
                decoration: const InputDecoration(
                  labelText: _modifierUiSectionLabel,
                ),
                items: const <DropdownMenuItem<ModifierUiSection?>>[
                  DropdownMenuItem<ModifierUiSection?>(
                    value: null,
                    child: Text(_modifierNoStructuredValueLabel),
                  ),
                  DropdownMenuItem<ModifierUiSection?>(
                    value: ModifierUiSection.toppings,
                    child: Text('Toppings'),
                  ),
                  DropdownMenuItem<ModifierUiSection?>(
                    value: ModifierUiSection.sauces,
                    child: Text('Sauces'),
                  ),
                  DropdownMenuItem<ModifierUiSection?>(
                    value: ModifierUiSection.addIns,
                    child: Text('Add-ins'),
                  ),
                ],
                onChanged: _type != ModifierType.extra
                    ? null
                    : (ModifierUiSection? value) {
                        setState(() {
                          _uiSection = value;
                        });
                      },
              ),
              const SizedBox(height: AppSizes.spacingMd),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (bool value) => setState(() => _isActive = value),
                title: Text(AppStrings.active),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
        ElevatedButton(
          key: const ValueKey<String>('modifier-submit-button'),
          onPressed: () {
            final String? validationMessage = _validateForm();
            if (validationMessage != null) {
              setState(() {
                _validationMessage = validationMessage;
              });
              return;
            }
            final _ProductModifierEditorResult? result = _buildResult();
            if (result == null) {
              return;
            }
            Navigator.of(context).pop(result);
          },
          child: Text(
            _mode == _ProductModifierEditorMode.bulk
                ? _modifierBulkAddActionLabel
                : AppStrings.saveSettings,
          ),
        ),
      ],
    );
  }

  Product? _findProductById(int id) {
    for (final Product product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  void _selectProduct(Product product) {
    setState(() {
      _products = _sortedProducts(<Product>[
        ..._products.where((Product item) => item.id != product.id),
        product,
      ]);
      _selectedProductId = product.id;
      _selectedCategoryId = product.categoryId;
      _validationMessage = null;
    });
    _setSearchText(product.name);
  }

  void _setSearchText(String value) {
    final TextEditingController? controller = _productSearchController;
    if (controller == null) {
      return;
    }
    _isProgrammaticSearchUpdate = true;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _isProgrammaticSearchUpdate = false;
  }

  void _handleProductSearchChanged(String value) {
    if (_isProgrammaticSearchUpdate) {
      return;
    }
    final Product? selectedProduct = _selectedProduct;
    if (selectedProduct == null) {
      return;
    }
    if (value.trim() == selectedProduct.name) {
      return;
    }
    setState(() {
      _selectedProductId = null;
    });
  }

  String? _validateForm() {
    if ((_priceBehavior == null) != (_uiSection == null)) {
      return 'Price behavior and UI section must be set together for structured modifiers.';
    }
    if (_mode == _ProductModifierEditorMode.bulk) {
      if (_selectedCategoryId == null) {
        return _modifierBulkCategoryRequiredMessage;
      }
      return null;
    }
    if (_selectedProductId == null) {
      return _modifierSelectionRequiredMessage;
    }
    return null;
  }

  _ProductModifierEditorResult? _buildResult() {
    final ModifierPriceBehavior? effectivePriceBehavior =
        _type == ModifierType.extra ? _priceBehavior : null;
    final ModifierUiSection? effectiveUiSection = _type == ModifierType.extra
        ? _uiSection
        : null;
    if (_mode == _ProductModifierEditorMode.bulk) {
      if (_selectedCategoryId == null) {
        return null;
      }
      return _ProductModifierEditorResult.bulk(
        sourceCategoryId: _selectedCategoryId!,
        type: _type,
        isActive: _isActive,
        priceBehavior: effectivePriceBehavior,
        uiSection: effectiveUiSection,
      );
    }
    final Product? selectedProduct = _selectedProduct;
    if (selectedProduct == null) {
      return null;
    }
    final bool usesStructuredFields =
        _type == ModifierType.extra &&
        (_priceBehavior != null || _uiSection != null);
    final int extraPriceMinor =
        _type != ModifierType.extra ||
            _priceBehavior == ModifierPriceBehavior.free
        ? 0
        : selectedProduct.priceMinor;
    return _ProductModifierEditorResult.single(
      linkedProductId: selectedProduct.id,
      linkedProductName: selectedProduct.name,
      type: _type,
      extraPriceMinor: extraPriceMinor,
      isActive: _isActive,
      priceBehavior: usesStructuredFields ? _priceBehavior : null,
      uiSection: usesStructuredFields ? _uiSection : null,
    );
  }
}

enum _ProductModifierEditorMode { single, bulk }

class _BulkModifierSelectionSummary {
  const _BulkModifierSelectionSummary({
    required this.categorySelected,
    required this.addCount,
    required this.skippedCount,
  });

  final bool categorySelected;
  final int addCount;
  final int skippedCount;
}

class _ProductModifierEditorResult {
  const _ProductModifierEditorResult.single({
    required this.linkedProductId,
    required this.linkedProductName,
    required this.type,
    required this.extraPriceMinor,
    required this.isActive,
    this.priceBehavior,
    this.uiSection,
  }) : mode = _ProductModifierEditorMode.single,
       sourceCategoryId = null;

  const _ProductModifierEditorResult.bulk({
    required this.sourceCategoryId,
    required this.type,
    required this.isActive,
    this.priceBehavior,
    this.uiSection,
  }) : mode = _ProductModifierEditorMode.bulk,
       linkedProductId = null,
       linkedProductName = null,
       extraPriceMinor = 0;

  final _ProductModifierEditorMode mode;
  final int? linkedProductId;
  final String? linkedProductName;
  final int? sourceCategoryId;
  final ModifierType type;
  final int extraPriceMinor;
  final bool isActive;
  final ModifierPriceBehavior? priceBehavior;
  final ModifierUiSection? uiSection;
}

class _QuickModifierProductDialog extends StatefulWidget {
  const _QuickModifierProductDialog({required this.categories});

  final List<Category> categories;

  @override
  State<_QuickModifierProductDialog> createState() =>
      _QuickModifierProductDialogState();
}

class _QuickModifierProductDialogState
    extends State<_QuickModifierProductDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late int _categoryId;
  late bool _isActive;
  late bool _isVisibleOnPos;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _priceController = TextEditingController(text: '0');
    _categoryId = widget.categories.first.id;
    _isActive = true;
    _isVisibleOnPos = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(_newModifierProductTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('quick-product-name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product name'),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            DropdownButtonFormField<int>(
              key: const ValueKey<String>('quick-product-category'),
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.categories
                  .map(
                    (Category category) => DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() => _categoryId = value);
                }
              },
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              key: const ValueKey<String>('quick-product-price'),
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price minor'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (bool value) => setState(() => _isActive = value),
              title: Text(AppStrings.active),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isVisibleOnPos,
              onChanged: (bool value) =>
                  setState(() => _isVisibleOnPos = value),
              title: const Text(_standalonePosVisibilityLabel),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(
              _QuickModifierProductResult(
                name: _nameController.text,
                categoryId: _categoryId,
                priceMinor: int.tryParse(_priceController.text) ?? -1,
                isActive: _isActive,
                isVisibleOnPos: _isVisibleOnPos,
              ),
            );
          },
          child: Text(AppStrings.saveSettings),
        ),
      ],
    );
  }
}

class _QuickModifierProductResult {
  const _QuickModifierProductResult({
    required this.name,
    required this.categoryId,
    required this.priceMinor,
    required this.isActive,
    required this.isVisibleOnPos,
  });

  final String name;
  final int categoryId;
  final int priceMinor;
  final bool isActive;
  final bool isVisibleOnPos;
}

enum _ModifierSection { free, sauces, addIns, included, extras, choice, other }

class _ModifierSectionGroup {
  const _ModifierSectionGroup({
    required this.section,
    required this.title,
    required this.modifiers,
  });

  final _ModifierSection section;
  final String title;
  final List<ProductModifier> modifiers;
}

List<_ModifierSectionGroup> _buildModifierGroups(
  List<ProductModifier> modifiers,
) {
  final Map<_ModifierSection, List<ProductModifier>> grouped =
      <_ModifierSection, List<ProductModifier>>{};
  for (final ProductModifier modifier in modifiers) {
    grouped
        .putIfAbsent(_sectionForModifier(modifier), () => <ProductModifier>[])
        .add(modifier);
  }

  final List<_ModifierSection> orderedSections = <_ModifierSection>[
    _ModifierSection.free,
    _ModifierSection.sauces,
    _ModifierSection.addIns,
    _ModifierSection.included,
    _ModifierSection.extras,
    _ModifierSection.choice,
    _ModifierSection.other,
  ];

  return orderedSections
      .where(grouped.containsKey)
      .map(
        (_ModifierSection section) => _ModifierSectionGroup(
          section: section,
          title: _sectionLabel(section),
          modifiers: grouped[section]!
            ..sort(
              (ProductModifier a, ProductModifier b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ),
        ),
      )
      .toList(growable: false);
}

_ModifierSection _sectionForModifier(ProductModifier modifier) {
  if (modifier.isChoice) {
    return _ModifierSection.choice;
  }
  if (modifier.priceBehavior == ModifierPriceBehavior.free &&
      modifier.uiSection == ModifierUiSection.toppings) {
    return _ModifierSection.free;
  }
  if (modifier.uiSection == ModifierUiSection.sauces) {
    return _ModifierSection.sauces;
  }
  if (modifier.uiSection == ModifierUiSection.addIns) {
    return _ModifierSection.addIns;
  }
  if (modifier.type == ModifierType.included) {
    return _ModifierSection.included;
  }
  if (modifier.type == ModifierType.extra) {
    return _ModifierSection.extras;
  }
  return _ModifierSection.other;
}

String _sectionLabel(_ModifierSection section) {
  switch (section) {
    case _ModifierSection.free:
      return _modifierSectionFreeLabel;
    case _ModifierSection.sauces:
      return _modifierSectionSaucesLabel;
    case _ModifierSection.addIns:
      return _modifierSectionAddInsLabel;
    case _ModifierSection.included:
      return _modifierSectionIncludedLabel;
    case _ModifierSection.extras:
      return _modifierSectionExtrasLabel;
    case _ModifierSection.choice:
      return _modifierSectionChoicesLabel;
    case _ModifierSection.other:
      return _modifierSectionOtherLabel;
  }
}

String _modifierSummary(ProductModifier modifier) {
  final List<String> parts = <String>[];
  if (modifier.itemProductId != null) {
    parts.add('$_modifierLinkedProductLabel #${modifier.itemProductId}');
  }
  if (modifier.isChoice) {
    parts.add('Set Builder managed');
  } else if (modifier.hasStructuredUi) {
    parts.add(_sectionLabel(_sectionForModifier(modifier)));
    parts.add(
      modifier.priceBehavior == ModifierPriceBehavior.free ? 'Free' : 'Paid',
    );
  } else {
    parts.add(
      modifier.type == ModifierType.included
          ? _modifierSectionIncludedLabel
          : _modifierSectionExtrasLabel,
    );
  }
  parts.add(CurrencyFormatter.fromMinor(modifier.extraPriceMinor));
  return parts.join(' · ');
}

String _labelForType(ModifierType type) {
  switch (type) {
    case ModifierType.included:
      return AppStrings.includedModifiers;
    case ModifierType.extra:
      return AppStrings.extraModifiers;
    case ModifierType.choice:
      return 'Set Choice (use Set Builder)';
  }
}

List<Product> _sortedProducts(List<Product> products) {
  final List<Product> sorted = List<Product>.from(products);
  sorted.sort(
    (Product a, Product b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return sorted;
}

List<Category> _sortedCategories(List<Category> categories) {
  final List<Category> sorted = List<Category>.from(categories);
  sorted.sort(
    (Category a, Category b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return sorted;
}

String _categoryNameForId(List<Category> categories, int categoryId) {
  for (final Category category in categories) {
    if (category.id == categoryId) {
      return category.name;
    }
  }
  return 'Category $categoryId';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingSm,
        vertical: AppSizes.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(label, style: TextStyle(color: color)),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({super.key, required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

String _mealProfileTypeBadgeLabel(MealAdjustmentProfileKind kind) {
  switch (kind) {
    case MealAdjustmentProfileKind.standard:
      return 'STANDARD';
    case MealAdjustmentProfileKind.sandwich:
      return 'SANDWICH';
  }
}

String _mealProfileAssignmentSummary(MealAdjustmentProfileKind kind) {
  switch (kind) {
    case MealAdjustmentProfileKind.standard:
      return 'This product will use standard meal components, add-ins, and pricing rules.';
    case MealAdjustmentProfileKind.sandwich:
      return 'This product will use configurable bread surcharges, free multi-select sauces, sandwich-only toast, and paid add-ins.';
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    super.key,
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSizes.spacingSm),
        if (children.isEmpty)
          _SectionEmptyState(message: emptyMessage)
        else
          ...children,
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _LegacyCleanupBanner extends StatelessWidget {
  const _LegacyCleanupBanner({
    required this.totalLines,
    required this.productCount,
  });

  final int totalLines;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$totalLines legacy meal line(s) across $productCount product(s)',
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'These orders were created before meal customization snapshots. '
            'They lack detailed pricing breakdowns and cannot be edited using the new engine.\n\n'
            'To resolve: assign a meal profile to the product, then new orders will '
            'use the snapshot system. Existing legacy lines will remain read-only in reports.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DeleteDecision {
  const _DeleteDecision({required this.confirmSemanticImpact});

  final bool confirmSemanticImpact;
}

T? _ensureValidSelection<T>({required T? current, required Iterable<T> items}) {
  final List<T> availableItems = items.toList(growable: false);
  if (availableItems.isEmpty) {
    return null;
  }
  if (current != null && availableItems.contains(current)) {
    return current;
  }
  return availableItems.first;
}

class _MealInsightsDialog extends ConsumerStatefulWidget {
  const _MealInsightsDialog({required this.product});

  final Product product;

  @override
  ConsumerState<_MealInsightsDialog> createState() =>
      _MealInsightsDialogState();
}

class _MealInsightsDialogState extends ConsumerState<_MealInsightsDialog> {
  ProductMealInsights? _insights;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    try {
      final ProductMealInsights? result = await ref
          .read(mealInsightsServiceProvider)
          .loadProductInsights(productId: widget.product.id);
      if (!mounted) return;
      setState(() {
        _insights = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: ValueKey<String>('meal-insights-dialog-${widget.product.id}'),
      title: Text('Meal Insights: ${widget.product.name}'),
      content: SizedBox(
        width: 600,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Text('Error loading insights: $_error')
            : _insights == null
            ? const Text('No meal customization data available yet.')
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _InsightMetricRow(
                      label: 'Customizations recorded',
                      value: '${_insights!.customizationCount}',
                    ),
                    if (_insights!.legacyLineCount > 0)
                      _InsightMetricRow(
                        label: 'Legacy lines (no snapshot)',
                        value: '${_insights!.legacyLineCount}',
                      ),
                    if (_insights!.topSwaps.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSizes.spacingMd),
                      const Text(
                        'Top swaps',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      ..._insights!.topSwaps.map(_buildStatRow),
                    ],
                    if (_insights!.topExtras.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSizes.spacingMd),
                      const Text(
                        'Top extras',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      ..._insights!.topExtras.map(_buildStatRow),
                    ],
                    if (_insights!.topRemovals.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSizes.spacingMd),
                      const Text(
                        'Top removals',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      ..._insights!.topRemovals.map(_buildStatRow),
                    ],
                    if (_insights!.topDiscountPatterns.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSizes.spacingMd),
                      const Text(
                        'Discount patterns',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      ..._insights!.topDiscountPatterns.map(_buildStatRow),
                    ],
                    if (_insights!.operationalNotes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSizes.spacingLg),
                      const Text(
                        'Operational notes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      ..._insights!.operationalNotes.map(
                        (String note) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            note,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                    // Decision support notes (Phase 8, Section G)
                    const SizedBox(height: AppSizes.spacingLg),
                    ..._buildDecisionSupportNotes(_insights!),
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  List<Widget> _buildDecisionSupportNotes(ProductMealInsights insights) {
    final List<String> notes = <String>[];
    if (insights.customizationCount == 0 && insights.legacyLineCount > 0) {
      notes.add(
        'All meal lines for this product are legacy. Assigning a meal profile will enable snapshot tracking for new orders.',
      );
    }
    if (insights.customizationCount > 0 && insights.legacyLineCount > 0) {
      notes.add(
        'This product has both modern snapshots and ${insights.legacyLineCount} legacy line(s). Legacy lines are read-only and cannot be re-processed.',
      );
    }
    if (insights.topSwaps.isNotEmpty &&
        insights.topSwaps.first.usageCount > 5) {
      notes.add(
        'High swap frequency detected. Consider pre-configuring "${insights.topSwaps.first.label}" as a visible quick option.',
      );
    }
    if (insights.topRemovals.isNotEmpty &&
        insights.topRemovals.first.usageCount > 3) {
      notes.add(
        'Frequent removal of "${insights.topRemovals.first.label}" — a remove-only pricing rule may help standardize the discount.',
      );
    }
    if (insights.topExtras.isNotEmpty &&
        insights.topExtras.first.usageCount > 3) {
      notes.add(
        'Popular extra "${insights.topExtras.first.label}" — consider adding a dedicated pricing rule for this upsell.',
      );
    }
    if (notes.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      const Text(
        'Decision support',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
      ...notes.map(
        (String note) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildStatRow(MealSuggestionStat stat) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              stat.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Text(
            '${stat.usageCount}x',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightMetricRow extends StatelessWidget {
  const _InsightMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
