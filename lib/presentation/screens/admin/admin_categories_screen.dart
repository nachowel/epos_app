import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/category.dart';
import '../../../domain/services/admin_service.dart';
import '../../providers/admin_categories_provider.dart';
import 'widgets/admin_scaffold.dart';

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  static const String _duplicateCategoryMessage =
      'Category with this name already exists';
  static const String _deleteBlockedMessage =
      'This category contains active products. Move, archive, or delete them first.';
  static const String _deleteConfirmTitle = 'Delete category?';
  static const String _deleteConfirmBody = 'This action cannot be undone.';
  static const String _deleteSuccessMessage = 'Category deleted.';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminCategoriesNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminCategoriesNotifierProvider);
    final List<Category> visibleCategories = state.categories
        .where((Category category) => !_isProtectedSystemCategory(category))
        .toList(growable: false);

    return AdminScaffold(
      title: AppStrings.categoryManagementTitle,
      currentRoute: '/admin/categories',
      child: Column(
        children: <Widget>[
          _Toolbar(
            onAdd: () => _openCategoryDialog(context),
            isBusy: state.isSaving,
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(adminCategoriesNotifierProvider.notifier).load(),
              child: ListView(
                children: <Widget>[
                  if (state.errorMessage != null)
                    _ErrorBox(message: state.errorMessage!),
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppSizes.spacingXl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visibleCategories.isEmpty)
                    _EmptyState(message: AppStrings.noCategoriesDefined)
                  else
                    ...visibleCategories.map(
                      (Category category) => _CategoryTile(
                        category: category,
                        isSaving: state.isSaving,
                        onEdit: () =>
                            _openCategoryDialog(context, category: category),
                        onDelete: () => _handleDeleteCategory(category),
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

  Future<void> _openCategoryDialog(
    BuildContext context, {
    Category? category,
  }) async {
    final _CategoryFormResult? result = await showDialog<_CategoryFormResult>(
      context: context,
      builder: (BuildContext context) => _CategoryDialog(
        category: category,
        existingCategories: ref
            .read(adminCategoriesNotifierProvider)
            .categories,
      ),
    );
    if (result == null) {
      return;
    }

    final notifier = ref.read(adminCategoriesNotifierProvider.notifier);
    final bool success = category == null
        ? await notifier.createCategory(
            name: result.name,
            sortOrder: result.sortOrder,
            isActive: result.isActive,
          )
        : await notifier.updateCategory(
            id: category.id,
            name: result.name,
            sortOrder: result.sortOrder,
            isActive: result.isActive,
          );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (category == null
                    ? AppStrings.categoryCreated
                    : AppStrings.categoryUpdated)
              : (ref.read(adminCategoriesNotifierProvider).errorMessage ??
                    AppStrings.operationFailed),
        ),
      ),
    );
  }

  Future<void> _handleDeleteCategory(Category category) async {
    if (_isProtectedSystemCategory(category)) {
      return;
    }
    final AdminCategoriesNotifier notifier = ref.read(
      adminCategoriesNotifierProvider.notifier,
    );
    final bool? hasProducts = await notifier.categoryHasActiveProducts(
      id: category.id,
    );
    if (!mounted) {
      return;
    }
    if (hasProducts == null) {
      final String message =
          ref.read(adminCategoriesNotifierProvider).errorMessage ??
          AppStrings.operationFailed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (hasProducts) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_deleteBlockedMessage)));
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(_deleteConfirmTitle),
          content: const Text(_deleteConfirmBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.cancel),
            ),
            ElevatedButton(
              key: ValueKey<String>('category-delete-confirm-${category.id}'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    final bool success = await notifier.deleteCategory(id: category.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? _deleteSuccessMessage
              : (ref.read(adminCategoriesNotifierProvider).errorMessage ??
                    AppStrings.operationFailed),
        ),
      ),
    );
  }

  bool _isProtectedSystemCategory(Category category) {
    return category.name.trim().toLowerCase() ==
        AdminService.archivedCategoryName.toLowerCase();
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onAdd, required this.isBusy});

  final VoidCallback onAdd;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            AppStrings.categoryToolbarMessage,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSizes.spacingMd),
        ElevatedButton.icon(
          onPressed: isBusy ? null : onAdd,
          icon: const Icon(Icons.add_rounded),
          label: Text(AppStrings.addCategory),
        ),
      ],
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.category,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const String _visibilityTooltip =
      'Hide this category from POS without deleting it';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: category.isActive ? 1 : 0.62,
      child: Card(
        key: ValueKey<String>('category-tile-${category.id}'),
        margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSizes.spacingSm,
                      runSpacing: AppSizes.spacingXs,
                      children: <Widget>[
                        Text(
                          category.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (!category.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.spacingSm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusSm,
                              ),
                            ),
                            child: const Text(
                              'Hidden',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${AppStrings.sortOrderLabel}: ${category.sortOrder}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingMd),
              Row(
                children: <Widget>[
                  const Text(
                    'Visible on POS',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: AppSizes.spacingXs),
                  const Tooltip(
                    message: _visibilityTooltip,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    key: ValueKey<String>(
                      'category-visible-switch-${category.id}',
                    ),
                    value: category.isActive,
                    onChanged: isSaving
                        ? null
                        : (bool value) async {
                            await ref
                                .read(adminCategoriesNotifierProvider.notifier)
                                .updateCategory(
                                  id: category.id,
                                  name: category.name,
                                  sortOrder: category.sortOrder,
                                  isActive: value,
                                );
                          },
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  OutlinedButton(
                    key: ValueKey<String>('category-edit-${category.id}'),
                    onPressed: isSaving ? null : onEdit,
                    child: Text(AppStrings.edit),
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  TextButton(
                    key: ValueKey<String>('category-delete-${category.id}'),
                    onPressed: isSaving ? null : onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category, required this.existingCategories});

  final Category? category;
  final List<Category> existingCategories;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  static const String _visibilityTooltip =
      'Hide this category from POS without deleting it';

  late final TextEditingController _nameController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _sortOrderController = TextEditingController(
      text: '${widget.category?.sortOrder ?? 0}',
    );
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.category == null
            ? AppStrings.addCategoryDialogTitle
            : AppStrings.editCategoryDialogTitle,
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('category-name-field'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppStrings.categoryNameLabel,
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              key: const ValueKey<String>('category-sort-order-field'),
              controller: _sortOrderController,
              decoration: InputDecoration(labelText: AppStrings.sortOrderLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            SwitchListTile(
              key: const ValueKey<String>('category-visible-dialog-switch'),
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: <Widget>[
                  const Text('Visible on POS'),
                  const SizedBox(width: AppSizes.spacingXs),
                  const Tooltip(
                    message: _visibilityTooltip,
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              value: _isActive,
              onChanged: (bool value) => setState(() => _isActive = value),
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
          key: const ValueKey<String>('category-save'),
          onPressed: () {
            final String? validationMessage = _validateName();
            if (validationMessage != null) {
              setState(() => _nameError = validationMessage);
              return;
            }
            Navigator.of(context).pop(
              _CategoryFormResult(
                name: _nameController.text.trim(),
                sortOrder: int.tryParse(_sortOrderController.text) ?? 0,
                isActive: _isActive,
              ),
            );
          },
          child: Text(AppStrings.saveSettings),
        ),
      ],
    );
  }

  String? _validateName() {
    final String value = _nameController.text.trim();
    if (value.isEmpty) {
      return 'Category name is required.';
    }
    final String normalizedValue = value.toLowerCase();
    for (final Category category in widget.existingCategories) {
      if (widget.category != null && category.id == widget.category!.id) {
        continue;
      }
      if (category.name.trim().toLowerCase() == normalizedValue) {
        return _AdminCategoriesScreenState._duplicateCategoryMessage;
      }
    }
    return null;
  }
}

class _CategoryFormResult {
  const _CategoryFormResult({
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final String name;
  final int sortOrder;
  final bool isActive;
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
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
