import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/semantic_product_configuration.dart';
import '../../../domain/services/admin_service.dart';
import '../../providers/admin_products_provider.dart';
import 'widgets/admin_scaffold.dart';
import 'widgets/semantic_product_configuration_dialog.dart';

const String _visibleOnPosLabel = 'Visible on POS';
const String _hiddenOnPosLabel = 'Hidden on POS';
const String _archivedLabel = 'Archived';
const String _configureSemanticLabel = 'Set Builder';
const String _roleLabel = 'Type';
const String _semanticConfigSavedLabel = 'Set configuration saved.';
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
                              categories: state.categories,
                              isSaving: state.isSaving,
                              showSetBuilder: true,
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
                              categories: state.categories,
                              isSaving: state.isSaving,
                              showSetBuilder: false,
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
    Product? product,
  }) async {
    final _ProductFormResult? result = await showDialog<_ProductFormResult>(
      context: context,
      builder: (BuildContext context) =>
          _ProductDialog(categories: categories, product: product),
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
    required this.categories,
    required this.isSaving,
    required this.showSetBuilder,
    required this.onEdit,
    required this.onConfigureSemantic,
    required this.onDelete,
  });

  final Product product;
  final ProductMenuConfigurationProfile profile;
  final List<Category> categories;
  final bool isSaving;
  final bool showSetBuilder;
  final VoidCallback onEdit;
  final VoidCallback onConfigureSemantic;
  final VoidCallback onDelete;

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
                ],
              ),
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
  const _ProductDialog({required this.categories, this.product});

  final List<Category> categories;
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
    _categoryId = widget.product?.categoryId ?? widget.categories.first.id;
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
