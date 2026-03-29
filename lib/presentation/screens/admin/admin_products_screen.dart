import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product.dart';
import '../../providers/admin_products_provider.dart';
import 'widgets/admin_scaffold.dart';

const String _visibleOnPosLabel = 'Visible on POS';
const String _hiddenOnPosLabel = 'Hidden on POS';
const String _inactiveLabel = 'Inactive';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
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

    return AdminScaffold(
      title: AppStrings.productManagementTitle,
      currentRoute: '/admin/products',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: state.selectedCategoryId,
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
                  else
                    ...state.products.map(
                      (Product product) => _ProductTile(
                        product: product,
                        categories: state.categories,
                        isSaving: state.isSaving,
                        onEdit: () => _openProductDialog(
                          context,
                          categories: state.categories,
                          product: product,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({
    required this.product,
    required this.categories,
    required this.isSaving,
    required this.onEdit,
  });

  final Product product;
  final List<Category> categories;
  final bool isSaving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String categoryName = '-';
    for (final Category category in categories) {
      if (category.id == product.categoryId) {
        categoryName = category.name;
        break;
      }
    }

    return Card(
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
                  label: product.isActive ? AppStrings.active : _inactiveLabel,
                  color: product.isActive
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                _StatusChip(
                  label: product.isVisibleOnPos
                      ? _visibleOnPosLabel
                      : _hiddenOnPosLabel,
                  color: product.isVisibleOnPos
                      ? AppColors.primary
                      : AppColors.warning,
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
            OutlinedButton(
              onPressed: isSaving ? null : onEdit,
              child: Text(AppStrings.edit),
            ),
          ],
        ),
      ),
    );
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
