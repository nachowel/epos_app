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
import '../../../domain/models/semantic_product_configuration.dart';
import '../../../domain/services/admin_service.dart';
import '../../../domain/models/meal_insights.dart';
import '../../../domain/services/meal_adjustment_profile_validation_service.dart';
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
                      productCount:
                          state.legacyMealLineCountsByProduct.length,
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
                              legacyLineCount: state.legacyMealLineCountsByProduct[product.id] ?? 0,
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
                              legacyLineCount: state.legacyMealLineCountsByProduct[product.id] ?? 0,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_mealAdjustmentSavedLabel)),
      );
    }
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
                        : _mealHealthColor(
                            mealProfileVisibility?.healthStatus,
                          ),
                  ),
                  if (mealProfileVisibility != null)
                    const _StatusChip(
                      label: 'Has meal customizations',
                      color: AppColors.primary,
                    ),
                  if (mealProfileVisibility != null)
                    _StatusChip(
                      label: 'Health: ${mealProfileVisibility!.healthStatus.name}',
                      color: _mealHealthColor(mealProfileVisibility!.healthStatus),
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
                    color: mealProfileVisibility!.healthStatus ==
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
    final bool hasSelectedProfile = _selectedProfileId != null &&
        _profiles.any(
          (MealAdjustmentProfile profile) => profile.id == _selectedProfileId,
        );
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
                      child: Text(profile.name),
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
                if (_errorMessage != null)
                  _MessageBox(
                    message: _errorMessage!,
                    color: AppColors.error,
                  ),
                if (_healthSummary == null)
                  const _MessageBox(
                    message:
                        'No meal-adjustment profile is assigned. Save to keep the product on the normal standard flow.',
                    color: AppColors.primary,
                  )
                else ...<Widget>[
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
            MealCustomizationExtraSelection(itemProductId: extraOption.itemProductId),
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
            .map((String line) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
                  child: Text(line),
                ))
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
  const _MessageBox({required this.message, required this.color});

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
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
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
                            if (_insights!.topDiscountPatterns
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: AppSizes.spacingMd),
                              const Text(
                                'Discount patterns',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              ..._insights!.topDiscountPatterns.map(
                                _buildStatRow,
                              ),
                            ],
                            if (_insights!.operationalNotes
                                .isNotEmpty) ...<Widget>[
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
    if (insights.topSwaps.isNotEmpty && insights.topSwaps.first.usageCount > 5) {
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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
