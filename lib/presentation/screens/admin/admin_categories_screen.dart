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
  static const String _reorderSavedMessage = 'Category order saved.';

  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminCategoriesNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminCategoriesState state = ref.watch(
      adminCategoriesNotifierProvider,
    );
    final List<Category> visibleCategories = state.categories
        .where((Category category) => !_isProtectedSystemCategory(category))
        .toList(growable: false);

    return AdminScaffold(
      title: AppStrings.categoryManagementTitle,
      currentRoute: '/admin/categories',
      child: Column(
        children: <Widget>[
          _Toolbar(
            isBusy: state.isSaving || state.isLoading,
            isReorderMode: _isReorderMode,
            hasUnsavedChanges: state.hasReorderChanges,
            hasCategories: state.categories.isNotEmpty,
            onAdd: () => _openCategoryDialog(context),
            onEnterReorderMode: () {
              setState(() => _isReorderMode = true);
            },
            onSaveReorder: _saveReorder,
            onCancelReorder: _cancelReorder,
          ),
          const SizedBox(height: AppSizes.spacingMd),
          if (state.errorMessage != null) ...<Widget>[
            _ErrorBox(message: state.errorMessage!),
            const SizedBox(height: AppSizes.spacingMd),
          ],
          Expanded(
            child: _isReorderMode
                ? _CategoryReorderPanel(
                    categories: state.reorderDraft,
                    isLoading: state.isLoading,
                    isSaving: state.isSaving,
                    hasUnsavedChanges: state.hasReorderChanges,
                    onReorder: _handleReorderDraft,
                  )
                : RefreshIndicator(
                    onRefresh: () => ref
                        .read(adminCategoriesNotifierProvider.notifier)
                        .load(),
                    child: ListView(
                      children: <Widget>[
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
                              onEdit: () => _openCategoryDialog(
                                context,
                                category: category,
                              ),
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

  Future<void> _saveReorder() async {
    final bool success = await ref
        .read(adminCategoriesNotifierProvider.notifier)
        .saveReorder();
    if (!mounted) {
      return;
    }

    final String message = success
        ? _reorderSavedMessage
        : (ref.read(adminCategoriesNotifierProvider).errorMessage ??
              AppStrings.operationFailed);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    if (success) {
      setState(() => _isReorderMode = false);
    }
  }

  void _cancelReorder() {
    ref.read(adminCategoriesNotifierProvider.notifier).discardReorderChanges();
    setState(() => _isReorderMode = false);
  }

  void _handleReorderDraft(int oldIndex, int newIndex) {
    final List<int> before = ref
        .read(adminCategoriesNotifierProvider)
        .reorderDraft
        .map((Category category) => category.id)
        .toList(growable: false);
    debugPrint(
      'admin_category_reorder requested '
      'oldIndex=$oldIndex newIndex=$newIndex before=$before',
    );
    ref.read(adminCategoriesNotifierProvider.notifier).reorderDraft(
      oldIndex,
      newIndex,
    );
    final List<int> after = ref
        .read(adminCategoriesNotifierProvider)
        .reorderDraft
        .map((Category category) => category.id)
        .toList(growable: false);
    debugPrint('admin_category_reorder applied after=$after');
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

    final AdminCategoriesNotifier notifier = ref.read(
      adminCategoriesNotifierProvider.notifier,
    );
    final bool success = category == null
        ? await notifier.createCategory(
            name: result.name,
            sortOrder: result.sortOrder,
            isActive: result.isActive,
            imageUrl: result.imageUrl,
          )
        : await notifier.updateCategory(
            id: category.id,
            name: result.name,
            sortOrder: result.sortOrder,
            isActive: result.isActive,
            imageUrl: result.imageUrl,
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
    return _isArchivedCategoryName(category.name);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.isBusy,
    required this.isReorderMode,
    required this.hasUnsavedChanges,
    required this.hasCategories,
    required this.onAdd,
    required this.onEnterReorderMode,
    required this.onSaveReorder,
    required this.onCancelReorder,
  });

  final bool isBusy;
  final bool isReorderMode;
  final bool hasUnsavedChanges;
  final bool hasCategories;
  final VoidCallback onAdd;
  final VoidCallback onEnterReorderMode;
  final Future<void> Function() onSaveReorder;
  final VoidCallback onCancelReorder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            isReorderMode
                ? 'Long-press and drag cards to set the exact category order. Positions 1 to 3 become the featured Category Entry row.'
                : AppStrings.categoryToolbarMessage,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSizes.spacingMd),
        if (isReorderMode) ...<Widget>[
          OutlinedButton(
            key: const ValueKey<String>('category-reorder-cancel'),
            onPressed: isBusy ? null : onCancelReorder,
            child: Text(AppStrings.cancel),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          ElevatedButton.icon(
            key: const ValueKey<String>('category-reorder-save'),
            onPressed: isBusy || !hasUnsavedChanges ? null : onSaveReorder,
            icon: const Icon(Icons.save_rounded),
            label: Text(AppStrings.saveSettings),
          ),
        ] else ...<Widget>[
          OutlinedButton.icon(
            key: const ValueKey<String>('category-enter-reorder-mode'),
            onPressed: isBusy || !hasCategories ? null : onEnterReorderMode,
            icon: const Icon(Icons.drag_indicator_rounded),
            label: const Text('Reorder'),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          ElevatedButton.icon(
            onPressed: isBusy ? null : onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(AppStrings.addCategory),
          ),
        ],
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

class _CategoryReorderPanel extends StatelessWidget {
  const _CategoryReorderPanel({
    required this.categories,
    required this.isLoading,
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.onReorder,
  });

  final List<Category> categories;
  final bool isLoading;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (categories.isEmpty) {
      return const _EmptyState(
        message: 'No categories available to reorder yet.',
      );
    }

    return ReorderableListView.builder(
      key: const ValueKey<String>('category-reorder-list'),
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: AppSizes.spacingLg),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ReorderOverview(hasUnsavedChanges: hasUnsavedChanges),
          const SizedBox(height: AppSizes.spacingMd),
          const _ReorderModeHint(
            key: ValueKey<String>('category-reorder-primary-zone'),
          ),
        ],
      ),
      onReorder: isSaving ? (_, __) {} : onReorder,
      itemCount: categories.length,
      itemBuilder: (BuildContext context, int index) {
        final Category category = categories[index];
        return Container(
          key: ValueKey<int>(category.id),
          margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
          child: _ReorderCategoryListTile(
            category: category,
            position: index,
            dragHandle: _CategoryReorderDragHandle(
              index: index,
              categoryId: category.id,
              enabled: !isSaving,
            ),
          ),
        );
      },
    );
  }
}

class _ReorderOverview extends StatelessWidget {
  const _ReorderOverview({required this.hasUnsavedChanges});

  final bool hasUnsavedChanges;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(
              Icons.view_carousel_rounded,
              color: AppColors.primaryDarker,
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          const Expanded(
            child: Text(
              'Drag cards into their final order, then choose Save to persist the new sort_order across every category.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          _StatusChip(
            label: hasUnsavedChanges ? 'Unsaved changes' : 'Saved order',
            backgroundColor: hasUnsavedChanges
                ? AppColors.warningLight
                : AppColors.successLight,
            foregroundColor: hasUnsavedChanges
                ? AppColors.warningStrong
                : AppColors.successStrong,
          ),
        ],
      ),
    );
  }
}

class _ReorderModeHint extends StatelessWidget {
  const _ReorderModeHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reorder categories',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSizes.spacingXs),
          Text(
            'Positions 1–4 are marked as Category Entry large cards. Positions 5+ remain standard grid cards. Drag using the handle on the right.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderCategoryListTile extends StatelessWidget {
  const _ReorderCategoryListTile({
    required this.category,
    required this.position,
    required this.dragHandle,
  });

  final Category category;
  final int position;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final bool isPrioritySlot = position < 4;
    final bool isSystemCategory = _isArchivedCategoryName(category.name);

    final List<Widget> chips = <Widget>[
      _StatusChip(
        label: 'Position ${position + 1}',
        backgroundColor: AppColors.surfaceAlt,
        foregroundColor: AppColors.textSecondary,
      ),
      _StatusChip(
        label: isPrioritySlot ? 'Category Entry large' : 'Standard grid',
        backgroundColor: isPrioritySlot
            ? AppColors.primaryLight
            : AppColors.surfaceAlt,
        foregroundColor: isPrioritySlot
            ? AppColors.primaryDarker
            : AppColors.textSecondary,
      ),
      if (!category.isActive)
        const _StatusChip(
          label: 'Hidden on POS',
          backgroundColor: AppColors.warningLight,
          foregroundColor: AppColors.warningStrong,
        ),
      if (isSystemCategory)
        const _StatusChip(
          label: 'System fallback',
          backgroundColor: AppColors.dangerLight,
          foregroundColor: AppColors.dangerStrong,
        ),
    ];

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: isPrioritySlot ? AppColors.primary : AppColors.borderStrong,
          ),
        ),
        child: ListTile(
          minVerticalPadding: AppSizes.spacingSm,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingMd,
            vertical: AppSizes.spacingXs,
          ),
          leading: _ReorderThumbnail(category: category),
          title: Text(
            category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSizes.spacingXs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSizes.spacingXs,
                  runSpacing: AppSizes.spacingXs,
                  children: chips,
                ),
                const SizedBox(height: AppSizes.spacingXs),
                Text(
                  isPrioritySlot
                      ? 'Large card zone in Category Entry ordering.'
                      : 'Standard grid zone in Category Entry ordering.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
                _CategoryReorderDebugInfo(
                  position: position,
                  categoryId: category.id,
                ),
              ],
            ),
          ),
          trailing: dragHandle,
        ),
      ),
    );
  }
}

class _CategoryReorderDragHandle extends StatelessWidget {
  const _CategoryReorderDragHandle({
    required this.index,
    required this.categoryId,
    required this.enabled,
  });

  final int index;
  final int categoryId;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Widget handleVisual = Listener(
      onPointerDown: (_) {
        debugPrint(
          'admin_category_reorder handle_down '
          'categoryId=$categoryId index=$index enabled=$enabled',
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: ValueKey<String>('category-reorder-drag-handle-$categoryId'),
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primaryLight.withValues(alpha: 0.95)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: enabled ? AppColors.primary : AppColors.border,
            width: enabled ? 1.5 : 1,
          ),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primaryDarker.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 28,
          color: enabled ? AppColors.primaryDarker : AppColors.textMuted,
        ),
      ),
    );

    if (!enabled) {
      return Tooltip(
        message: 'Reorder is temporarily disabled while saving.',
        child: handleVisual,
      );
    }

    return ReorderableDragStartListener(
      index: index,
      child: handleVisual,
    );
  }
}

class _CategoryReorderDebugInfo extends StatelessWidget {
  const _CategoryReorderDebugInfo({
    required this.position,
    required this.categoryId,
  });

  final int position;
  final int categoryId;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Row ${position + 1} | ID $categoryId',
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ReorderThumbnail extends StatelessWidget {
  const _ReorderThumbnail({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = category.imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: SizedBox(
        width: 72,
        height: 72,
        child: imageUrl == null || imageUrl.isEmpty
            ? const _CategoryPreviewPlaceholder()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const _CategoryPreviewPlaceholder(),
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const _CategoryPreviewPlaceholder();
                    },
              ),
      ),
    );
  }
}

class _CategoryPreviewPlaceholder extends StatelessWidget {
  const _CategoryPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primaryLight,
            AppColors.primaryLighter,
            AppColors.surfaceAlt,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: AppColors.primaryDarker.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingSm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
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
  late final TextEditingController _imageUrlController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _imageUrlController = TextEditingController(
      text: widget.category?.imageUrl ?? '',
    );
    _sortOrderController = TextEditingController(
      text: '${widget.category?.sortOrder ?? 0}',
    );
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
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
        child: SingleChildScrollView(
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
                key: const ValueKey<String>('category-image-url-field'),
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://example.com/category.jpg',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.spacingSm),
              _CategoryImageUrlPreview(imageUrl: _normalizedImageUrl),
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
                imageUrl: _normalizedImageUrl,
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

  String? get _normalizedImageUrl {
    final String trimmed = _imageUrlController.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _CategoryFormResult {
  const _CategoryFormResult({
    required this.name,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
  });

  final String name;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
}

class _CategoryImageUrlPreview extends StatelessWidget {
  const _CategoryImageUrlPreview({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('category-image-preview'),
      width: double.infinity,
      height: 156,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? const _CategoryImageUrlPlaceholder()
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const _CategoryImageUrlPlaceholder(),
              loadingBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return const _CategoryImageUrlPlaceholder();
                  },
            ),
    );
  }
}

class _CategoryImageUrlPlaceholder extends StatelessWidget {
  const _CategoryImageUrlPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey<String>('category-image-preview-placeholder'),
      color: AppColors.surfaceAlt,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(
              Icons.image_outlined,
              color: AppColors.textSecondary,
              size: 30,
            ),
            SizedBox(height: AppSizes.spacingSm),
            Text(
              'Preview unavailable',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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

bool _isArchivedCategoryName(String name) {
  return name.trim().toLowerCase() ==
      AdminService.archivedCategoryName.toLowerCase();
}
