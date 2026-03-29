import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/category.dart';
import '../../providers/admin_categories_provider.dart';
import 'widgets/admin_scaffold.dart';

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
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
                  else if (state.categories.isEmpty)
                    _EmptyState(message: AppStrings.noCategoriesDefined)
                  else
                    ...state.categories.map(
                      (Category category) => _CategoryTile(
                        category: category,
                        isSaving: state.isSaving,
                        onEdit: () =>
                            _openCategoryDialog(context, category: category),
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
      builder: (BuildContext context) => _CategoryDialog(category: category),
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
  });

  final Category category;
  final bool isSaving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: ListTile(
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${AppStrings.sortOrderLabel}: ${category.sortOrder}'),
        trailing: Wrap(
          spacing: AppSizes.spacingSm,
          children: <Widget>[
            Switch(
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

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final Category? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;

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
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppStrings.categoryNameLabel,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              controller: _sortOrderController,
              decoration: InputDecoration(labelText: AppStrings.sortOrderLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppStrings.active),
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
          onPressed: () {
            Navigator.of(context).pop(
              _CategoryFormResult(
                name: _nameController.text,
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
