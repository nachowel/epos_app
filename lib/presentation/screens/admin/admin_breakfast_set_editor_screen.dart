import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../domain/models/breakfast_extra_preset.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/semantic_product_configuration.dart';
import '../../providers/admin_breakfast_set_editor_provider.dart';
import 'widgets/admin_scaffold.dart';

const String _listRoute = '/admin/breakfast-sets';
const String _saveSuccessMessage = 'Breakfast set configuration saved.';

class AdminBreakfastSetEditorScreen extends ConsumerStatefulWidget {
  const AdminBreakfastSetEditorScreen({required this.productId, super.key});

  final int productId;

  @override
  ConsumerState<AdminBreakfastSetEditorScreen> createState() =>
      _AdminBreakfastSetEditorScreenState();
}

class _AdminBreakfastSetEditorScreenState
    extends ConsumerState<AdminBreakfastSetEditorScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(adminBreakfastSetEditorNotifierProvider.notifier)
          .load(widget.productId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminBreakfastSetEditorState state = ref.watch(
      adminBreakfastSetEditorNotifierProvider,
    );

    return AdminScaffold(
      title: 'Breakfast Set Editor',
      currentRoute: _listRoute,
      child: Column(
        children: <Widget>[
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(context, state),
          ),
          _ActionBar(
            status: state.draftStatus,
            canSave: state.isSaveEnabled,
            onCancel: () => context.go(_listRoute),
            onSave: _saveConfiguration,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminBreakfastSetEditorState state) {
    final SemanticProductConfigurationEditorData? editorData = state.editorData;
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    if (state.errorMessage != null && editorData == null) {
      return ListView(
        children: <Widget>[
          _MessageBox(message: state.errorMessage!, color: AppColors.error),
        ],
      );
    }
    if (editorData == null) {
      return ListView(
        children: <Widget>[
          _EmptySection(message: 'Breakfast set editor data is unavailable.'),
        ],
      );
    }
    if (draftConfiguration == null) {
      return ListView(
        children: <Widget>[
          _EmptySection(message: 'Breakfast set draft data is unavailable.'),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(adminBreakfastSetEditorNotifierProvider.notifier)
          .load(widget.productId),
      child: ListView(
        children: <Widget>[
          if (state.errorMessage != null)
            _MessageBox(message: state.errorMessage!, color: AppColors.error),
          _MessageBox(
            message:
                'Changes in this editor save to the local database only. Remote sync and create/delete root flows remain outside this screen.',
            color: AppColors.primary,
          ),
          _SectionCard(
            title: 'Set Info',
            child: _SetInfoSection(
              editorData: editorData,
              categoryName: state.categoryName ?? 'Unknown Category',
              draftConfiguration: draftConfiguration,
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _SectionCard(
            title: 'Set Items',
            child: _SetItemsSection(
              setItemProducts: editorData.availableSetItemProducts,
              items: draftConfiguration.setItems,
              itemIssues: state.setItemInlineIssues,
              onAddItem: _showAddSetItemDialog,
              onRemoveItem: (int index) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .removeSetItemAt(index),
              onQuantityChanged: (int index, String value) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .updateSetItemQuantityAt(index, value),
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _SectionCard(
            title: 'Choice Groups',
            child: _ChoiceGroupsSection(
              availableProducts: editorData.availableProducts,
              groups: draftConfiguration.choiceGroups,
              groupIssues: state.choiceGroupInlineIssues,
              onAddGroup: () => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .addChoiceGroup(),
              onRemoveGroup: (int index) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .removeChoiceGroupAt(index),
              onGroupNameChanged: (int index, String value) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .updateChoiceGroupNameAt(index, value),
              onMinChanged: (int index, String value) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .updateChoiceGroupMinSelectAt(index, value),
              onMaxChanged: (int index, String value) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .updateChoiceGroupMaxSelectAt(index, value),
              onIncludedChanged: (int index, String value) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .updateChoiceGroupIncludedQuantityAt(index, value),
              onAddMember: _showAddChoiceMemberDialog,
              onRemoveMember: (int groupIndex, int memberIndex) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .removeChoiceGroupMemberAt(groupIndex, memberIndex),
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _SectionCard(
            title: 'Extras Pool',
            child: _ExtrasSection(
              extras: draftConfiguration.extras,
              itemIssues: state.extraInlineIssues,
              presets: editorData.extraPresets,
              onAddExtras: () => _showAddExtraDialog(
                availableProducts: editorData.availableProducts,
                draftConfiguration: draftConfiguration,
              ),
              onApplyPreset: editorData.extraPresets.isEmpty
                  ? null
                  : () => _showApplyExtraPresetDialog(editorData.extraPresets),
              onCreatePreset: () => _showCreateExtraPresetDialog(
                availableProducts: editorData.availableProducts,
                initialSelectedProductIds: draftConfiguration.extras
                    .map((SemanticExtraItemDraft extra) => extra.itemProductId)
                    .toSet(),
              ),
              onRemoveExtra: (int index) => ref
                  .read(adminBreakfastSetEditorNotifierProvider.notifier)
                  .removeExtraItemAt(index),
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _SectionCard(
            title: 'Validation Summary',
            child: _ValidationSummarySection(
              status: state.draftStatus,
              issues: state.validationIssues,
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _SectionCard(
            title: 'Action Bar',
            child: Text(
              state.isSaveEnabled
                  ? 'Save is available because the current draft is valid and will persist the current snapshot locally.'
                  : state.draftStatus ==
                        AdminBreakfastSetEditorDraftStatus.incomplete
                  ? 'Save stays disabled until warnings are resolved and the draft becomes fully valid.'
                  : 'Save stays disabled while blocking validation issues remain.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSizes.spacingLg),
        ],
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    final bool success = await ref
        .read(adminBreakfastSetEditorNotifierProvider.notifier)
        .save();
    if (!mounted) {
      return;
    }
    final String message = success
        ? _saveSuccessMessage
        : (ref.read(adminBreakfastSetEditorNotifierProvider).errorMessage ??
              'Failed to save breakfast set configuration.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddSetItemDialog(List<Product> availableProducts) async {
    final AdminBreakfastSetEditorState currentState = ref.read(
      adminBreakfastSetEditorNotifierProvider,
    );
    final SemanticProductConfigurationDraft? draftConfiguration =
        currentState.draftConfiguration;
    ref
        .read(appLoggerProvider)
        .info(
          eventType: 'admin_breakfast_set_item_picker_opened',
          entityId: '${widget.productId}',
          metadata: <String, Object?>{
            'root_product_id': widget.productId,
            'source_available_set_item_products_length':
                availableProducts.length,
            'source_available_set_item_product_ids': availableProducts
                .map((Product product) => product.id)
                .toList(growable: false),
            'current_draft_set_item_ids':
                draftConfiguration?.setItems
                    .map((SemanticSetItemDraft item) => item.itemProductId)
                    .toList(growable: false) ??
                const <int>[],
            'current_choice_member_ids':
                draftConfiguration?.choiceGroups
                    .expand(
                      (SemanticChoiceGroupDraft group) => group.members.map(
                        (SemanticChoiceMemberDraft member) =>
                            member.itemProductId,
                      ),
                    )
                    .toList(growable: false) ??
                const <int>[],
            'current_extra_ids':
                draftConfiguration?.extras
                    .map((SemanticExtraItemDraft extra) => extra.itemProductId)
                    .toList(growable: false) ??
                const <int>[],
            'ui_picker_row_count': availableProducts.length,
          },
        );
    final List<AdminBreakfastSetItemSelection>?
    selections = await showDialog<List<AdminBreakfastSetItemSelection>>(
      context: context,
      builder: (BuildContext context) {
        return _SetItemPickerDialog(
          title: 'Add Set Item',
          products: availableProducts,
          disabledProductIds:
              draftConfiguration?.setItems
                  .map((SemanticSetItemDraft item) => item.itemProductId)
                  .toSet() ??
              const <int>{},
          multiSelect: true,
          emptyMessage:
              'No available included items to add. Included Items come from the set-item pool only; Choice Members can reuse existing active products from other POS categories.',
        );
      },
    );
    if (selections == null || selections.isEmpty || !mounted) {
      return;
    }
    await ref
        .read(adminBreakfastSetEditorNotifierProvider.notifier)
        .addSetItemSelections(selections);
  }

  Future<void> _showAddChoiceMemberDialog(
    int groupIndex,
    List<Product> availableProducts,
  ) async {
    final Product? product = await showDialog<Product>(
      context: context,
      builder: (BuildContext context) {
        return _ProductPickerDialog(
          title: 'Add Choice Member',
          products: availableProducts,
        );
      },
    );
    if (product == null || !mounted) {
      return;
    }
    await ref
        .read(adminBreakfastSetEditorNotifierProvider.notifier)
        .addChoiceGroupMemberAt(groupIndex, product);
  }

  Future<void> _showAddExtraDialog({
    required List<Product> availableProducts,
    required SemanticProductConfigurationDraft draftConfiguration,
  }) async {
    final List<Product>? products = await showDialog<List<Product>>(
      context: context,
      builder: (BuildContext context) {
        return _ProductPickerDialog(
          title: 'Add Extra Item',
          products: _availableExtraProducts(
            availableProducts: availableProducts,
            draftConfiguration: draftConfiguration,
          ),
          multiSelect: true,
        );
      },
    );
    if (products == null || products.isEmpty || !mounted) {
      return;
    }
    await ref
        .read(adminBreakfastSetEditorNotifierProvider.notifier)
        .addExtraItems(products);
  }

  Future<void> _showApplyExtraPresetDialog(
    List<BreakfastExtraPreset> presets,
  ) async {
    final BreakfastExtraPreset? preset = await showDialog<BreakfastExtraPreset>(
      context: context,
      builder: (BuildContext context) {
        return _ExtraPresetPickerDialog(presets: presets);
      },
    );
    if (preset == null || !mounted) {
      return;
    }
    await ref
        .read(adminBreakfastSetEditorNotifierProvider.notifier)
        .applyExtraPreset(preset);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Breakfast extras preset applied.')),
    );
  }

  Future<void> _showCreateExtraPresetDialog({
    required List<Product> availableProducts,
    required Set<int> initialSelectedProductIds,
  }) async {
    final _ExtraPresetDraft? presetDraft = await showDialog<_ExtraPresetDraft>(
      context: context,
      builder: (BuildContext context) {
        return _ExtraPresetEditorDialog(
          products: _presetProducts(availableProducts),
          initialSelectedProductIds: initialSelectedProductIds,
        );
      },
    );
    if (presetDraft == null || !mounted) {
      return;
    }
    final bool success = await ref
        .read(adminBreakfastSetEditorNotifierProvider.notifier)
        .saveExtraPreset(
          name: presetDraft.name,
          products: presetDraft.products,
        );
    if (!mounted) {
      return;
    }
    final String message = success
        ? 'Breakfast extras preset saved.'
        : (ref.read(adminBreakfastSetEditorNotifierProvider).errorMessage ??
              'Failed to save breakfast extras preset.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Product> _availableExtraProducts({
    required List<Product> availableProducts,
    required SemanticProductConfigurationDraft draftConfiguration,
  }) {
    final Set<int> blockedIds = <int>{
      widget.productId,
      ...draftConfiguration.setItems.map(
        (SemanticSetItemDraft item) => item.itemProductId,
      ),
      ...draftConfiguration.choiceGroups.expand(
        (SemanticChoiceGroupDraft group) => group.members.map(
          (SemanticChoiceMemberDraft member) => member.itemProductId,
        ),
      ),
      ...draftConfiguration.extras.map(
        (SemanticExtraItemDraft extra) => extra.itemProductId,
      ),
    };
    return availableProducts
        .where((Product product) => !blockedIds.contains(product.id))
        .toList(growable: false);
  }

  List<Product> _presetProducts(List<Product> availableProducts) {
    return availableProducts
        .where((Product product) => product.id != widget.productId)
        .toList(growable: false);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            child,
          ],
        ),
      ),
    );
  }
}

class _SetInfoSection extends StatelessWidget {
  const _SetInfoSection({
    required this.editorData,
    required this.categoryName,
    required this.draftConfiguration,
  });

  final SemanticProductConfigurationEditorData editorData;
  final String categoryName;
  final SemanticProductConfigurationDraft draftConfiguration;

  @override
  Widget build(BuildContext context) {
    final int includedUnitCount = draftConfiguration.setItems.fold<int>(
      0,
      (int sum, SemanticSetItemDraft item) => sum + item.defaultQuantity,
    );
    return Wrap(
      spacing: AppSizes.spacingMd,
      runSpacing: AppSizes.spacingMd,
      children: <Widget>[
        _InfoTile(label: 'Root Product', value: editorData.rootProduct.name),
        _InfoTile(label: 'Category', value: categoryName),
        _InfoTile(label: 'Included Units', value: '$includedUnitCount'),
        _InfoTile(
          label: 'Item Rows',
          value: '${draftConfiguration.setItems.length}',
        ),
        _InfoTile(
          label: 'Choice Group Count',
          value: '${draftConfiguration.choiceGroups.length}',
        ),
        _InfoTile(
          label: 'Extras Count',
          value: '${draftConfiguration.extras.length}',
        ),
      ],
    );
  }
}

class _SetItemsSection extends StatelessWidget {
  const _SetItemsSection({
    required this.setItemProducts,
    required this.items,
    required this.itemIssues,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onQuantityChanged,
  });

  final List<Product> setItemProducts;
  final List<SemanticSetItemDraft> items;
  final Map<int, List<String>> itemIssues;
  final ValueChanged<List<Product>> onAddItem;
  final ValueChanged<int> onRemoveItem;
  final void Function(int index, String value) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Included Items use the set-item pool only. Choice Members can reuse active products from their normal POS categories, so drinks and breads do not need duplicate breakfast-category products.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSizes.spacingMd),
        if (items.isEmpty)
          const _EmptySection(message: 'No set items configured yet.'),
        ...List<Widget>.generate(items.length, (int index) {
          final SemanticSetItemDraft item = items[index];
          final List<String> issues = itemIssues[index] ?? const <String>[];
          return Container(
            key: ValueKey<String>('breakfast-editor-set-item-$index'),
            margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
            padding: const EdgeInsets.all(AppSizes.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: issues.isEmpty ? AppColors.border : AppColors.warning,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.itemName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSizes.spacingXs),
                          Text(
                            'Sort ${item.sortOrder}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        key: ValueKey<String>(
                          'breakfast-editor-qty-$index-${item.defaultQuantity}',
                        ),
                        initialValue: '${item.defaultQuantity}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty'),
                        onChanged: (String value) =>
                            onQuantityChanged(index, value),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacingSm),
                    IconButton(
                      key: ValueKey<String>('breakfast-editor-remove-$index'),
                      onPressed: () => onRemoveItem(index),
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppColors.error,
                      tooltip: 'Remove set item',
                    ),
                  ],
                ),
                if (issues.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSizes.spacingSm),
                  ...issues.map(
                    (String issue) =>
                        _IssueRow(message: issue, color: AppColors.warning),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: AppSizes.spacingSm),
        OutlinedButton.icon(
          key: const ValueKey<String>('breakfast-editor-add-item'),
          onPressed: () => onAddItem(setItemProducts),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Item'),
        ),
      ],
    );
  }
}

class _ChoiceGroupsSection extends StatelessWidget {
  const _ChoiceGroupsSection({
    required this.availableProducts,
    required this.groups,
    required this.groupIssues,
    required this.onAddGroup,
    required this.onRemoveGroup,
    required this.onGroupNameChanged,
    required this.onMinChanged,
    required this.onMaxChanged,
    required this.onIncludedChanged,
    required this.onAddMember,
    required this.onRemoveMember,
  });

  final List<Product> availableProducts;
  final List<SemanticChoiceGroupDraft> groups;
  final Map<int, List<String>> groupIssues;
  final VoidCallback onAddGroup;
  final ValueChanged<int> onRemoveGroup;
  final void Function(int index, String value) onGroupNameChanged;
  final void Function(int index, String value) onMinChanged;
  final void Function(int index, String value) onMaxChanged;
  final void Function(int index, String value) onIncludedChanged;
  final void Function(int groupIndex, List<Product> availableProducts)
  onAddMember;
  final void Function(int groupIndex, int memberIndex) onRemoveMember;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Choice Members reuse existing active catalog products from their normal POS categories. Do not create duplicate Tea or Bread products just to use them in breakfast choices.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSizes.spacingMd),
        if (groups.isEmpty)
          const _EmptySection(message: 'No choice groups configured yet.'),
        ...List<Widget>.generate(groups.length, (int groupIndex) {
          final SemanticChoiceGroupDraft group = groups[groupIndex];
          final List<String> issues =
              groupIssues[groupIndex] ?? const <String>[];
          return Container(
            key: ValueKey<String>('breakfast-editor-choice-group-$groupIndex'),
            margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
            padding: const EdgeInsets.all(AppSizes.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: issues.isEmpty ? AppColors.border : AppColors.warning,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        key: ValueKey<String>(
                          'breakfast-editor-choice-name-$groupIndex',
                        ),
                        initialValue: group.name,
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                        ),
                        onChanged: (String value) =>
                            onGroupNameChanged(groupIndex, value),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacingSm),
                    IconButton(
                      key: ValueKey<String>(
                        'breakfast-editor-choice-remove-$groupIndex',
                      ),
                      onPressed: () => onRemoveGroup(groupIndex),
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AppColors.error,
                      tooltip: 'Remove choice group',
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacingMd),
                Wrap(
                  spacing: AppSizes.spacingSm,
                  runSpacing: AppSizes.spacingSm,
                  children: <Widget>[
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        key: ValueKey<String>(
                          'breakfast-editor-choice-min-$groupIndex-${group.minSelect}',
                        ),
                        initialValue: '${group.minSelect}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Min'),
                        onChanged: (String value) =>
                            onMinChanged(groupIndex, value),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        key: ValueKey<String>(
                          'breakfast-editor-choice-max-$groupIndex-${group.maxSelect}',
                        ),
                        initialValue: '${group.maxSelect}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Max'),
                        onChanged: (String value) =>
                            onMaxChanged(groupIndex, value),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextFormField(
                        key: ValueKey<String>(
                          'breakfast-editor-choice-included-$groupIndex-${group.includedQuantity}',
                        ),
                        initialValue: '${group.includedQuantity}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Included Qty',
                        ),
                        onChanged: (String value) =>
                            onIncludedChanged(groupIndex, value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spacingMd),
                Text(
                  'Members',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                if (group.members.isEmpty)
                  const _EmptySection(message: 'No members added yet.')
                else
                  ...List<Widget>.generate(group.members.length, (
                    int memberIndex,
                  ) {
                    final SemanticChoiceMemberDraft member =
                        group.members[memberIndex];
                    return Container(
                      key: ValueKey<String>(
                        'breakfast-editor-choice-member-$groupIndex-$memberIndex',
                      ),
                      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacingMd,
                        vertical: AppSizes.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              member.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'breakfast-editor-choice-member-remove-$groupIndex-$memberIndex',
                            ),
                            onPressed: () =>
                                onRemoveMember(groupIndex, memberIndex),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Remove choice member',
                          ),
                        ],
                      ),
                    );
                  }),
                OutlinedButton.icon(
                  key: ValueKey<String>(
                    'breakfast-editor-choice-add-member-$groupIndex',
                  ),
                  onPressed: () => onAddMember(groupIndex, availableProducts),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Member'),
                ),
                if (issues.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSizes.spacingSm),
                  ...issues.map(
                    (String issue) =>
                        _IssueRow(message: issue, color: AppColors.warning),
                  ),
                ],
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          key: const ValueKey<String>('breakfast-editor-choice-add-group'),
          onPressed: onAddGroup,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Choice Group'),
        ),
      ],
    );
  }
}

class _ExtrasSection extends StatelessWidget {
  const _ExtrasSection({
    required this.extras,
    required this.itemIssues,
    required this.presets,
    required this.onAddExtras,
    required this.onApplyPreset,
    required this.onCreatePreset,
    required this.onRemoveExtra,
  });

  final List<SemanticExtraItemDraft> extras;
  final Map<int, List<String>> itemIssues;
  final List<BreakfastExtraPreset> presets;
  final VoidCallback onAddExtras;
  final VoidCallback? onApplyPreset;
  final VoidCallback onCreatePreset;
  final ValueChanged<int> onRemoveExtra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Extras reuse existing active catalog products from their normal POS categories. Applying a preset copies those products into this set so later preset changes do not silently modify saved extras pools.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSizes.spacingMd),
        if (extras.isEmpty)
          const _EmptySection(message: 'No extras configured yet.')
        else
          ...List<Widget>.generate(extras.length, (int index) {
            final SemanticExtraItemDraft extra = extras[index];
            final List<String> issues = itemIssues[index] ?? const <String>[];
            return Container(
              key: ValueKey<String>('breakfast-editor-extra-$index'),
              margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
              padding: const EdgeInsets.all(AppSizes.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: issues.isEmpty ? AppColors.border : AppColors.warning,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          extra.itemName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'Sort ${extra.sortOrder}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: AppSizes.spacingSm),
                      IconButton(
                        key: ValueKey<String>(
                          'breakfast-editor-extra-remove-$index',
                        ),
                        onPressed: () => onRemoveExtra(index),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.error,
                        tooltip: 'Remove extra',
                      ),
                    ],
                  ),
                  if (issues.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSizes.spacingSm),
                    ...issues.map(
                      (String issue) =>
                          _IssueRow(message: issue, color: AppColors.warning),
                    ),
                  ],
                ],
              ),
            );
          }),
        const SizedBox(height: AppSizes.spacingSm),
        Wrap(
          spacing: AppSizes.spacingSm,
          runSpacing: AppSizes.spacingSm,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('breakfast-editor-extra-add'),
              onPressed: onAddExtras,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Extra'),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>(
                'breakfast-editor-extra-apply-preset',
              ),
              onPressed: onApplyPreset,
              icon: const Icon(Icons.library_add_rounded),
              label: Text(
                presets.isEmpty ? 'No Presets Saved' : 'Apply Preset',
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>(
                'breakfast-editor-extra-create-preset',
              ),
              onPressed: onCreatePreset,
              icon: const Icon(Icons.bookmark_add_rounded),
              label: const Text('Create Preset'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ValidationSummarySection extends StatelessWidget {
  const _ValidationSummarySection({required this.status, required this.issues});

  final AdminBreakfastSetEditorDraftStatus status;
  final List<AdminBreakfastSetEditorValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final List<AdminBreakfastSetEditorValidationIssue> blockingIssues = issues
        .where(
          (AdminBreakfastSetEditorValidationIssue issue) =>
              issue.severity == AdminBreakfastSetEditorIssueSeverity.error,
        )
        .toList(growable: false);
    final List<AdminBreakfastSetEditorValidationIssue> warnings = issues
        .where(
          (AdminBreakfastSetEditorValidationIssue issue) =>
              issue.severity == AdminBreakfastSetEditorIssueSeverity.warning,
        )
        .toList(growable: false);
    final List<AdminBreakfastSetEditorIssueSection> affectedSections = issues
        .map((AdminBreakfastSetEditorValidationIssue issue) => issue.section)
        .toSet()
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          decoration: BoxDecoration(
            color: _statusColor(status).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: _statusColor(status)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _ValidationBadge(state: status),
                  const SizedBox(width: AppSizes.spacingSm),
                  Expanded(
                    child: Text(
                      _summaryHeadline(
                        status: status,
                        blockingCount: blockingIssues.length,
                        warningCount: warnings.length,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingSm),
              Text(
                _summaryBody(status),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (affectedSections.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSizes.spacingMd),
          Text(
            'Affected Sections',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Wrap(
            spacing: AppSizes.spacingSm,
            runSpacing: AppSizes.spacingSm,
            children: affectedSections
                .map(
                  (AdminBreakfastSetEditorIssueSection section) =>
                      _SectionBadge(
                        label: _sectionLabel(section),
                        color: _sectionColor(section),
                      ),
                )
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: AppSizes.spacingMd),
        Text(
          'Blocking Errors',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSizes.spacingSm),
        if (blockingIssues.isEmpty)
          const _EmptySection(message: 'No blocking validation errors.')
        else
          ...blockingIssues.map(
            (AdminBreakfastSetEditorValidationIssue issue) => _IssueRow(
              message: issue.message,
              color: AppColors.error,
              sectionLabel: _sectionLabel(issue.section),
            ),
          ),
        const SizedBox(height: AppSizes.spacingMd),
        Text(
          'Warnings',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSizes.spacingSm),
        if (warnings.isEmpty)
          const _EmptySection(
            message: 'No warnings. The current draft is complete.',
          )
        else
          ...warnings.map(
            (AdminBreakfastSetEditorValidationIssue issue) => _IssueRow(
              message: issue.message,
              color: AppColors.warning,
              sectionLabel: _sectionLabel(issue.section),
            ),
          ),
      ],
    );
  }

  String _summaryHeadline({
    required AdminBreakfastSetEditorDraftStatus status,
    required int blockingCount,
    required int warningCount,
  }) {
    switch (status) {
      case AdminBreakfastSetEditorDraftStatus.valid:
        return 'Draft is valid. Save is available.';
      case AdminBreakfastSetEditorDraftStatus.incomplete:
        return 'Draft is incomplete: $warningCount warning(s) need attention.';
      case AdminBreakfastSetEditorDraftStatus.invalid:
        return 'Draft is invalid: $blockingCount blocking error(s) must be fixed.';
    }
  }

  String _summaryBody(AdminBreakfastSetEditorDraftStatus status) {
    switch (status) {
      case AdminBreakfastSetEditorDraftStatus.valid:
        return 'This draft passes the current validation rules and can be saved to the local database.';
      case AdminBreakfastSetEditorDraftStatus.incomplete:
        return 'Warnings do not break the draft structure, but Save stays disabled until the draft becomes fully valid.';
      case AdminBreakfastSetEditorDraftStatus.invalid:
        return 'Fix the blocking errors below before Save becomes available.';
    }
  }

  String _sectionLabel(AdminBreakfastSetEditorIssueSection section) {
    switch (section) {
      case AdminBreakfastSetEditorIssueSection.setInfo:
        return 'Set Info';
      case AdminBreakfastSetEditorIssueSection.setItems:
        return 'Set Items';
      case AdminBreakfastSetEditorIssueSection.extras:
        return 'Extras';
      case AdminBreakfastSetEditorIssueSection.choiceGroups:
        return 'Choice Groups';
      case AdminBreakfastSetEditorIssueSection.general:
        return 'General';
    }
  }

  Color _sectionColor(AdminBreakfastSetEditorIssueSection section) {
    switch (section) {
      case AdminBreakfastSetEditorIssueSection.setInfo:
        return AppColors.primary;
      case AdminBreakfastSetEditorIssueSection.setItems:
        return AppColors.warning;
      case AdminBreakfastSetEditorIssueSection.extras:
        return AppColors.success;
      case AdminBreakfastSetEditorIssueSection.choiceGroups:
        return AppColors.primaryLight;
      case AdminBreakfastSetEditorIssueSection.general:
        return AppColors.textSecondary;
    }
  }

  Color _statusColor(AdminBreakfastSetEditorDraftStatus status) {
    switch (status) {
      case AdminBreakfastSetEditorDraftStatus.valid:
        return AppColors.success;
      case AdminBreakfastSetEditorDraftStatus.incomplete:
        return AppColors.warning;
      case AdminBreakfastSetEditorDraftStatus.invalid:
        return AppColors.error;
    }
  }
}

class _ExtraPresetDraft {
  const _ExtraPresetDraft({required this.name, required this.products});

  final String name;
  final List<Product> products;
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.status,
    required this.canSave,
    required this.onCancel,
    required this.onSave,
  });

  final AdminBreakfastSetEditorDraftStatus status;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _actionText(status),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
          const SizedBox(width: AppSizes.spacingSm),
          ElevatedButton(
            key: const ValueKey<String>('breakfast-editor-save'),
            onPressed: canSave ? onSave : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _actionText(AdminBreakfastSetEditorDraftStatus status) {
    switch (status) {
      case AdminBreakfastSetEditorDraftStatus.valid:
        return 'Draft is valid. Save writes the current snapshot to the local database.';
      case AdminBreakfastSetEditorDraftStatus.incomplete:
        return 'Resolve warnings before Save becomes available.';
      case AdminBreakfastSetEditorDraftStatus.invalid:
        return 'Fix blocking validation errors before Save becomes available.';
    }
  }
}

class _ExtraPresetPickerDialog extends StatelessWidget {
  const _ExtraPresetPickerDialog({required this.presets});

  final List<BreakfastExtraPreset> presets;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Apply Extras Preset'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: presets.isEmpty
            ? const Center(
                child: Text(
                  'No breakfast extras presets saved yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.builder(
                itemCount: presets.length,
                itemBuilder: (BuildContext context, int index) {
                  final BreakfastExtraPreset preset = presets[index];
                  return ListTile(
                    key: ValueKey<String>(
                      'breakfast-editor-extra-preset-${preset.id}',
                    ),
                    title: Text(preset.name),
                    subtitle: Text(
                      preset.items.length == 1
                          ? '1 product'
                          : '${preset.items.length} products',
                    ),
                    onTap: () => Navigator.of(context).pop(preset),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ExtraPresetEditorDialog extends StatefulWidget {
  const _ExtraPresetEditorDialog({
    required this.products,
    required this.initialSelectedProductIds,
  });

  final List<Product> products;
  final Set<int> initialSelectedProductIds;

  @override
  State<_ExtraPresetEditorDialog> createState() =>
      _ExtraPresetEditorDialogState();
}

class _ExtraPresetEditorDialogState extends State<_ExtraPresetEditorDialog> {
  late final TextEditingController _nameController;
  late final Set<int> _selectedProductIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _selectedProductIds = Set<int>.from(widget.initialSelectedProductIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleSelection(Product product) {
    setState(() {
      if (!_selectedProductIds.add(product.id)) {
        _selectedProductIds.remove(product.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> filtered = widget.products
        .where(
          (Product product) =>
              product.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);
    final bool canSave =
        _nameController.text.trim().isNotEmpty &&
        _selectedProductIds.isNotEmpty;

    return AlertDialog(
      title: const Text('Create Extras Preset'),
      content: SizedBox(
        width: 560,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('breakfast-editor-extra-preset-name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Preset Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              key: const ValueKey<String>(
                'breakfast-editor-extra-preset-search',
              ),
              decoration: const InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Text(
              _selectedProductIds.length == 1
                  ? '1 item selected'
                  : '${_selectedProductIds.length} items selected',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching products found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Product product = filtered[index];
                        final bool isSelected = _selectedProductIds.contains(
                          product.id,
                        );
                        return ListTile(
                          key: ValueKey<String>(
                            'breakfast-editor-extra-preset-product-${product.id}',
                          ),
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(product),
                          ),
                          title: Text(product.name),
                          onTap: () => _toggleSelection(product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('breakfast-editor-extra-preset-save'),
          onPressed: !canSave
              ? null
              : () {
                  final List<Product> products = widget.products
                      .where(
                        (Product product) =>
                            _selectedProductIds.contains(product.id),
                      )
                      .toList(growable: false);
                  Navigator.of(context).pop(
                    _ExtraPresetDraft(
                      name: _nameController.text.trim(),
                      products: products,
                    ),
                  );
                },
          child: const Text('Save Preset'),
        ),
      ],
    );
  }
}

class _SetItemPickerDialog extends StatefulWidget {
  const _SetItemPickerDialog({
    required this.title,
    required this.products,
    required this.disabledProductIds,
    this.emptyMessage = 'No matching products found.',
    this.multiSelect = false,
  });

  final String title;
  final List<Product> products;
  final Set<int> disabledProductIds;
  final String emptyMessage;
  final bool multiSelect;

  @override
  State<_SetItemPickerDialog> createState() => _SetItemPickerDialogState();
}

class _SetItemPickerDialogState extends State<_SetItemPickerDialog> {
  String _query = '';
  final Map<int, int> _selectedQuantities = <int, int>{};

  void _toggleSelection(Product product) {
    setState(() {
      if (_selectedQuantities.containsKey(product.id)) {
        _selectedQuantities.remove(product.id);
        return;
      }
      _selectedQuantities[product.id] = 1;
    });
  }

  void _changeQuantity(Product product, int delta) {
    setState(() {
      final int currentQuantity = _selectedQuantities[product.id] ?? 1;
      final int nextQuantity = currentQuantity + delta;
      if (nextQuantity < 1) {
        return;
      }
      _selectedQuantities[product.id] = nextQuantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> filtered = widget.products
        .where(
          (Product product) =>
              product.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);
    final int selectionCount = _selectedQuantities.length;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        height: 560,
        child: Column(
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('breakfast-editor-product-search'),
              decoration: const InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            if (widget.multiSelect)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectionCount == 1
                      ? '1 item selected'
                      : '$selectionCount items selected',
                  key: const ValueKey<String>(
                    'breakfast-editor-product-selected-count',
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (widget.multiSelect) const SizedBox(height: AppSizes.spacingMd),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.emptyMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Product product = filtered[index];
                        final bool isDisabled = widget.disabledProductIds
                            .contains(product.id);
                        final bool isSelected = _selectedQuantities.containsKey(
                          product.id,
                        );
                        final int quantity =
                            _selectedQuantities[product.id] ?? 1;
                        return ListTile(
                          key: ValueKey<String>(
                            'breakfast-editor-product-item-${product.id}',
                          ),
                          enabled: !isDisabled,
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: isDisabled
                                ? null
                                : (_) => _toggleSelection(product),
                          ),
                          title: Text(product.name),
                          subtitle: isDisabled
                              ? const Text(
                                  'Already added. Edit quantity in the set items list.',
                                )
                              : null,
                          trailing: isDisabled
                              ? const Icon(
                                  Icons.block_rounded,
                                  color: AppColors.textSecondary,
                                )
                              : SizedBox(
                                  width: 140,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      IconButton(
                                        key: ValueKey<String>(
                                          'breakfast-editor-product-qty-dec-${product.id}',
                                        ),
                                        onPressed: isSelected && quantity > 1
                                            ? () => _changeQuantity(product, -1)
                                            : null,
                                        icon: const Icon(
                                          Icons.remove_circle_outline_rounded,
                                        ),
                                        tooltip: 'Decrease quantity',
                                      ),
                                      Expanded(
                                        child: Text(
                                          '$quantity',
                                          key: ValueKey<String>(
                                            'breakfast-editor-product-qty-${product.id}-$quantity',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isSelected
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: ValueKey<String>(
                                          'breakfast-editor-product-qty-inc-${product.id}',
                                        ),
                                        onPressed: isSelected
                                            ? () => _changeQuantity(product, 1)
                                            : null,
                                        icon: const Icon(
                                          Icons.add_circle_outline_rounded,
                                        ),
                                        tooltip: 'Increase quantity',
                                      ),
                                    ],
                                  ),
                                ),
                          onTap: isDisabled
                              ? null
                              : () => _toggleSelection(product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.multiSelect)
          FilledButton(
            key: const ValueKey<String>('breakfast-editor-product-submit'),
            onPressed: _selectedQuantities.isEmpty
                ? null
                : () {
                    final List<AdminBreakfastSetItemSelection> selections =
                        widget.products
                            .where(
                              (Product product) =>
                                  _selectedQuantities.containsKey(product.id),
                            )
                            .map(
                              (Product product) =>
                                  AdminBreakfastSetItemSelection(
                                    product: product,
                                    quantity:
                                        _selectedQuantities[product.id] ?? 1,
                                  ),
                            )
                            .toList(growable: false);
                    Navigator.of(context).pop(selections);
                  },
            child: const Text('Add Selected'),
          ),
      ],
    );
  }
}

class _ProductPickerDialog extends StatefulWidget {
  const _ProductPickerDialog({
    required this.title,
    required this.products,
    this.emptyMessage = 'No matching products found.',
    this.multiSelect = false,
  });

  final String title;
  final List<Product> products;
  final String emptyMessage;
  final bool multiSelect;

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  String _query = '';
  final Set<int> selectedProductIds = <int>{};

  void _toggleSelection(Product product) {
    setState(() {
      if (!selectedProductIds.add(product.id)) {
        selectedProductIds.remove(product.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> filtered = widget.products
        .where((Product product) {
          return product.name.toLowerCase().contains(_query.toLowerCase());
        })
        .toList(growable: false);
    final int selectionCount = selectedProductIds.length;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('breakfast-editor-product-search'),
              decoration: const InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            if (widget.multiSelect)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectionCount == 1
                      ? '1 item selected'
                      : '$selectionCount items selected',
                  key: const ValueKey<String>(
                    'breakfast-editor-product-selected-count',
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (widget.multiSelect) const SizedBox(height: AppSizes.spacingMd),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.emptyMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Product product = filtered[index];
                        final bool isSelected = selectedProductIds.contains(
                          product.id,
                        );
                        return ListTile(
                          key: ValueKey<String>(
                            'breakfast-editor-product-item-${product.id}',
                          ),
                          leading: widget.multiSelect
                              ? Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelection(product),
                                )
                              : null,
                          title: Text(product.name),
                          onTap: () {
                            if (widget.multiSelect) {
                              _toggleSelection(product);
                              return;
                            }
                            Navigator.of(context).pop(product);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.multiSelect)
          FilledButton(
            key: const ValueKey<String>('breakfast-editor-product-submit'),
            onPressed: selectedProductIds.isEmpty
                ? null
                : () {
                    final List<Product> selectedProducts = widget.products
                        .where(
                          (Product product) =>
                              selectedProductIds.contains(product.id),
                        )
                        .toList(growable: false);
                    Navigator.of(context).pop(selectedProducts);
                  },
            child: const Text('Add Selected'),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.spacingXs),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationBadge extends StatelessWidget {
  const _ValidationBadge({required this.state});

  final AdminBreakfastSetEditorDraftStatus state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case AdminBreakfastSetEditorDraftStatus.valid:
        return const _StatusBadge(label: 'Valid', color: AppColors.success);
      case AdminBreakfastSetEditorDraftStatus.incomplete:
        return const _StatusBadge(
          label: 'Incomplete',
          color: AppColors.warning,
        );
      case AdminBreakfastSetEditorDraftStatus.invalid:
        return const _StatusBadge(label: 'Invalid', color: AppColors.error);
    }
  }
}

class _SectionBadge extends StatelessWidget {
  const _SectionBadge({required this.label, required this.color});

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
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

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
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.message,
    required this.color,
    this.sectionLabel,
  });

  final String message;
  final Color color;
  final String? sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 10, color: color),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (sectionLabel != null) ...<Widget>[
                  _SectionBadge(label: sectionLabel!, color: color),
                  const SizedBox(height: AppSizes.spacingXs),
                ],
                Text(message, style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
      ),
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

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
