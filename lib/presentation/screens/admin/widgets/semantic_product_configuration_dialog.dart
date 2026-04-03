import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/product.dart';
import '../../../../domain/models/semantic_product_configuration.dart';
import '../../../providers/auth_provider.dart';

class SemanticProductConfigurationDialog extends ConsumerStatefulWidget {
  const SemanticProductConfigurationDialog({
    required this.productId,
    super.key,
  });

  final int productId;

  @override
  ConsumerState<SemanticProductConfigurationDialog> createState() =>
      _SemanticProductConfigurationDialogState();
}

class _SemanticProductConfigurationDialogState
    extends ConsumerState<SemanticProductConfigurationDialog> {
  final TextEditingController _priceController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  SemanticProductConfigurationEditorData? _editorData;
  SemanticMenuValidationResult? _validationResult;
  int _validationRequestId = 0;
  List<SemanticSetItemDraft> _setItems = const <SemanticSetItemDraft>[];
  List<SemanticChoiceGroupDraft> _choiceGroups =
      const <SemanticChoiceGroupDraft>[];
  List<SemanticExtraItemDraft> _extras = const <SemanticExtraItemDraft>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final SemanticProductConfigurationEditorData editorData = await ref
          .read(semanticMenuAdminServiceProvider)
          .loadEditorData(widget.productId);
      if (!mounted) {
        return;
      }
      setState(() {
        _editorData = editorData;
        _setItems = List<SemanticSetItemDraft>.from(
          editorData.configuration.setItems,
        );
        _choiceGroups = List<SemanticChoiceGroupDraft>.from(
          editorData.configuration.choiceGroups,
        );
        _extras = List<SemanticExtraItemDraft>.from(
          editorData.configuration.extras,
        );
        _validationResult = editorData.validationResult;
        _priceController.text = _formatPrice(editorData.rootProduct.priceMinor);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorMapper.toUserMessageAndLog(
          error,
          logger: ref.read(appLoggerProvider),
          eventType: 'semantic_menu_admin_load_failed',
          stackTrace: stackTrace,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    if (editorData == null) {
      return Center(
        child: Text(
          _errorMessage ?? 'Unable to load set builder.',
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppSizes.spacingLg),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Set Builder',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacingXs),
                        Text(
                          editorData.rootProduct.name,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      key: const ValueKey<String>(
                        'semantic-builder-price-field',
                      ),
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Set Price',
                        prefixText: '£',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingMd),
                  IconButton(
                    key: const ValueKey<String>('semantic-builder-close'),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingMd),
              _banner(
                'This product is managed using Set Builder',
                AppColors.primary,
              ),
              if (editorData.profile.hasLegacyFlatConfig) ...<Widget>[
                const SizedBox(height: AppSizes.spacingSm),
                _banner(
                  'Legacy modifiers should stay disabled for this product.',
                  AppColors.warning,
                ),
              ],
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: AppSizes.spacingSm),
                _banner(_errorMessage!, AppColors.error),
              ],
              if (_validationResult
                  case final SemanticMenuValidationResult result) ...<Widget>[
                if (result.errors.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSizes.spacingSm),
                  _validationBanner(
                    'Save blocked',
                    result.errors,
                    AppColors.error,
                  ),
                ],
                if (result.warnings.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSizes.spacingSm),
                  _validationBanner(
                    'Check before saving',
                    result.warnings,
                    AppColors.warning,
                  ),
                ],
              ],
              const SizedBox(height: AppSizes.spacingMd),
              const TabBar(
                key: ValueKey<String>('semantic-builder-tabs'),
                isScrollable: true,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: <Tab>[
                  Tab(text: 'Included Items'),
                  Tab(text: 'Required Choices'),
                  Tab(text: 'Extras'),
                  Tab(text: 'Rules'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: <Widget>[
              _buildIncludedTab(editorData),
              _buildChoicesTab(editorData),
              _buildExtrasTab(editorData),
              _buildRulesTab(editorData),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSizes.spacingLg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSizes.spacingSm),
              ElevatedButton(
                key: const ValueKey<String>('semantic-builder-save'),
                onPressed: _isSaving || !(_validationResult?.canSave ?? true)
                    ? null
                    : _save,
                child: Text(_isSaving ? 'Saving...' : 'Save Settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncludedTab(SemanticProductConfigurationEditorData editorData) {
    return _tabFrame(
      heading: 'Define what comes inside the set.',
      actionLabel: '+ Add Item',
      actionKey: const ValueKey<String>('semantic-add-item'),
      onAction: _addSetItem,
      child: _setItems.isEmpty
          ? _empty(
              'No included items yet. Add the products that come with this set by default.',
            )
          : ListView.separated(
              itemCount: _setItems.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.spacingSm),
              itemBuilder: (BuildContext context, int index) {
                final SemanticSetItemDraft item = _setItems[index];
                final Product? product = _findProduct(
                  editorData.availableProducts,
                  item.itemProductId,
                );
                return _rowCard(
                  key: ValueKey<String>('semantic-set-item-$index'),
                  title: item.itemName,
                  subtitle: product == null
                      ? null
                      : CurrencyFormatter.fromMinor(product.priceMinor),
                  controls: <Widget>[
                    IconButton(
                      key: ValueKey<String>('semantic-set-item-pick-$index'),
                      onPressed: () => _replaceSetItem(index),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Removable',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Switch(
                          value: item.isRemovable,
                          onChanged: (bool value) => _updateSetItem(
                            index,
                            item.copyWith(isRemovable: value),
                          ),
                        ),
                      ],
                    ),
                    _MiniStepper(
                      decrementKey: ValueKey<String>(
                        'semantic-set-item-quantity-$index-decrement',
                      ),
                      incrementKey: ValueKey<String>(
                        'semantic-set-item-quantity-$index-increment',
                      ),
                      quantity: item.defaultQuantity,
                      canDecrease: item.defaultQuantity > 1,
                      onDecrease: () => _updateSetItem(
                        index,
                        item.copyWith(
                          defaultQuantity: item.defaultQuantity - 1,
                        ),
                      ),
                      onIncrease: () => _updateSetItem(
                        index,
                        item.copyWith(
                          defaultQuantity: item.defaultQuantity + 1,
                        ),
                      ),
                    ),
                    _moveButtons(
                      upKey: ValueKey<String>('semantic-set-item-up-$index'),
                      downKey: ValueKey<String>(
                        'semantic-set-item-down-$index',
                      ),
                      canMoveUp: index > 0,
                      canMoveDown: index < _setItems.length - 1,
                      onMoveUp: () => _moveSetItem(index, index - 1),
                      onMoveDown: () => _moveSetItem(index, index + 1),
                    ),
                    IconButton(
                      key: ValueKey<String>('semantic-set-item-delete-$index'),
                      onPressed: () => _removeSetItem(index),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildChoicesTab(SemanticProductConfigurationEditorData editorData) {
    return _tabFrame(
      heading: 'Force the cashier to choose one option for each group.',
      actionLabel: '+ Add Choice Group',
      actionKey: const ValueKey<String>('semantic-add-choice-group'),
      onAction: _addChoiceGroup,
      child: _choiceGroups.isEmpty
          ? _empty(
              'No required choices yet. Add groups such as Hot Drink or Bread.',
            )
          : ListView.separated(
              itemCount: _choiceGroups.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.spacingMd),
              itemBuilder: (BuildContext context, int index) {
                final SemanticChoiceGroupDraft group = _choiceGroups[index];
                return Container(
                  key: ValueKey<String>('semantic-choice-group-$index'),
                  padding: const EdgeInsets.all(AppSizes.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  group.name.isEmpty
                                      ? 'New choice group'
                                      : group.name,
                                  style: const TextStyle(
                                    fontSize: AppSizes.fontMd,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.spacingXs),
                                const Text(
                                  'Choose one',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'semantic-choice-edit-$index',
                            ),
                            onPressed: () => _editChoiceGroup(index),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'semantic-choice-delete-$index',
                            ),
                            onPressed: () => _removeChoiceGroup(index),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.spacingSm),
                      if (group.members.isEmpty)
                        const Text(
                          'No options yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      else
                        ...List<Widget>.generate(group.members.length, (
                          int memberIndex,
                        ) {
                          final SemanticChoiceMemberDraft member =
                              group.members[memberIndex];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(member.itemName),
                            trailing: IconButton(
                              key: ValueKey<String>(
                                'semantic-choice-member-delete-$index-$memberIndex',
                              ),
                              onPressed: () =>
                                  _removeChoiceMember(index, memberIndex),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          );
                        }),
                      OutlinedButton.icon(
                        key: ValueKey<String>(
                          'semantic-choice-add-option-$index',
                        ),
                        onPressed: () => _addChoiceMember(index),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('+ Add Option'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildExtrasTab(SemanticProductConfigurationEditorData editorData) {
    return _tabFrame(
      heading: 'Only products listed here appear under Extras on POS.',
      actionLabel: '+ Add Extra Item',
      actionKey: const ValueKey<String>('semantic-add-extra-item'),
      onAction: _addExtraItem,
      child: _extras.isEmpty
          ? _empty('No extras yet. Add the products available under Extras.')
          : ListView.separated(
              itemCount: _extras.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.spacingSm),
              itemBuilder: (BuildContext context, int index) {
                final SemanticExtraItemDraft extra = _extras[index];
                final Product? product = _findProduct(
                  editorData.availableProducts,
                  extra.itemProductId,
                );
                return _rowCard(
                  key: ValueKey<String>('semantic-extra-item-$index'),
                  title: extra.itemName,
                  subtitle: product == null
                      ? 'Unavailable'
                      : CurrencyFormatter.fromMinor(product.priceMinor),
                  controls: <Widget>[
                    _moveButtons(
                      upKey: ValueKey<String>('semantic-extra-up-$index'),
                      downKey: ValueKey<String>('semantic-extra-down-$index'),
                      canMoveUp: index > 0,
                      canMoveDown: index < _extras.length - 1,
                      onMoveUp: () => _moveExtraItem(index, index - 1),
                      onMoveDown: () => _moveExtraItem(index, index + 1),
                    ),
                    IconButton(
                      key: ValueKey<String>('semantic-extra-delete-$index'),
                      onPressed: () => _removeExtraItem(index),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildRulesTab(SemanticProductConfigurationEditorData editorData) {
    return _tabFrame(
      heading: 'Simple pricing guidance for swaps and extras.',
      actionLabel: null,
      actionKey: null,
      onAction: null,
      child: ListView(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSizes.spacingLg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Swap Rules',
                  style: TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
                _rule('Free swaps allowed', '2'),
                const SizedBox(height: AppSizes.spacingSm),
                _rule('After free swaps', 'Extra item price is charged'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (editorData == null || currentUser == null) {
      return;
    }
    final int? priceMinor = _parsePrice(_priceController.text);
    if (priceMinor == null) {
      setState(() {
        _errorMessage = 'Enter a valid set price.';
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final SemanticProductConfigurationDraft draft = _buildDraft(editorData);
    try {
      await ref
          .read(semanticMenuAdminServiceProvider)
          .saveConfiguration(user: currentUser, configuration: draft);
      final Product rootProduct = editorData.rootProduct;
      if (priceMinor != rootProduct.priceMinor) {
        await ref
            .read(adminServiceProvider)
            .updateProduct(
              user: currentUser,
              id: rootProduct.id,
              categoryId: rootProduct.categoryId,
              name: rootProduct.name,
              priceMinor: priceMinor,
              hasModifiers: rootProduct.hasModifiers,
              sortOrder: rootProduct.sortOrder,
              isActive: rootProduct.isActive,
              isVisibleOnPos: rootProduct.isVisibleOnPos,
            );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on SemanticProductConfigurationValidationException catch (error) {
      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    } catch (error, stackTrace) {
      setState(() {
        _isSaving = false;
        _errorMessage = ErrorMapper.toUserMessageAndLog(
          error,
          logger: ref.read(appLoggerProvider),
          eventType: 'semantic_menu_admin_save_failed',
          stackTrace: stackTrace,
        );
      });
    }
  }

  Future<void> _addSetItem() async {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    if (editorData == null) {
      return;
    }
    final Product? product = await _pickProduct(
      title: 'Add Included Item',
      products: _availableSetProducts(editorData.availableProducts),
    );
    if (product == null) {
      return;
    }
    setState(() {
      _setItems = <SemanticSetItemDraft>[
        ..._setItems,
        SemanticSetItemDraft(
          itemProductId: product.id,
          itemName: product.name,
          defaultQuantity: 1,
          isRemovable: true,
          sortOrder: _setItems.length,
        ),
      ];
    });
    unawaited(_refreshValidation());
  }

  Future<void> _replaceSetItem(int index) async {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    if (editorData == null) {
      return;
    }
    final SemanticSetItemDraft current = _setItems[index];
    final Product? product = await _pickProduct(
      title: 'Change Included Item',
      products: _availableSetProducts(
        editorData.availableProducts,
        currentId: current.itemProductId,
      ),
    );
    if (product == null) {
      return;
    }
    _updateSetItem(
      index,
      current.copyWith(itemProductId: product.id, itemName: product.name),
    );
  }

  void _updateSetItem(int index, SemanticSetItemDraft item) {
    setState(() {
      _setItems = List<SemanticSetItemDraft>.from(_setItems)..[index] = item;
    });
    unawaited(_refreshValidation());
  }

  void _moveSetItem(int fromIndex, int toIndex) {
    setState(() {
      final List<SemanticSetItemDraft> items = List<SemanticSetItemDraft>.from(
        _setItems,
      );
      final SemanticSetItemDraft item = items.removeAt(fromIndex);
      items.insert(toIndex, item);
      _setItems = List<SemanticSetItemDraft>.generate(
        items.length,
        (int index) => items[index].copyWith(sortOrder: index),
        growable: false,
      );
    });
    unawaited(_refreshValidation());
  }

  void _removeSetItem(int index) {
    setState(() {
      final List<SemanticSetItemDraft> items = List<SemanticSetItemDraft>.from(
        _setItems,
      )..removeAt(index);
      _setItems = List<SemanticSetItemDraft>.generate(
        items.length,
        (int itemIndex) => items[itemIndex].copyWith(sortOrder: itemIndex),
        growable: false,
      );
    });
    unawaited(_refreshValidation());
  }

  Future<void> _addChoiceGroup() async {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    if (editorData == null) {
      return;
    }
    final _ChoiceGroupResult? result = await showDialog<_ChoiceGroupResult>(
      context: context,
      builder: (BuildContext context) {
        return _ChoiceGroupDialog(
          title: 'Add Choice Group',
          availableProducts: _availableChoiceProducts(
            editorData.availableProducts,
          ),
        );
      },
    );
    if (result == null) {
      return;
    }
    setState(() {
      _choiceGroups = <SemanticChoiceGroupDraft>[
        ..._choiceGroups,
        SemanticChoiceGroupDraft(
          name: result.name,
          minSelect: 1,
          maxSelect: 1,
          includedQuantity: 1,
          sortOrder: _choiceGroups.length,
          members: result.members,
        ),
      ];
    });
    unawaited(_refreshValidation());
  }

  Future<void> _editChoiceGroup(int index) async {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    if (editorData == null) {
      return;
    }
    final SemanticChoiceGroupDraft group = _choiceGroups[index];
    final _ChoiceGroupResult? result = await showDialog<_ChoiceGroupResult>(
      context: context,
      builder: (BuildContext context) {
        return _ChoiceGroupDialog(
          title: 'Edit Choice Group',
          initialName: group.name,
          initialMembers: group.members,
          availableProducts: _availableChoiceProducts(
            editorData.availableProducts,
            allowIds: group.members
                .map((SemanticChoiceMemberDraft member) => member.itemProductId)
                .toSet(),
          ),
        );
      },
    );
    if (result == null) {
      return;
    }
    setState(() {
      _choiceGroups = List<SemanticChoiceGroupDraft>.from(_choiceGroups)
        ..[index] = group.copyWith(name: result.name, members: result.members);
    });
    unawaited(_refreshValidation());
  }

  void _removeChoiceGroup(int index) {
    setState(() {
      final List<SemanticChoiceGroupDraft> groups =
          List<SemanticChoiceGroupDraft>.from(_choiceGroups)..removeAt(index);
      _choiceGroups = List<SemanticChoiceGroupDraft>.generate(
        groups.length,
        (int groupIndex) => groups[groupIndex].copyWith(sortOrder: groupIndex),
        growable: false,
      );
    });
    unawaited(_refreshValidation());
  }

  Future<void> _addChoiceMember(int groupIndex) async {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    if (editorData == null) {
      return;
    }
    final SemanticChoiceGroupDraft group = _choiceGroups[groupIndex];
    final Product? product = await _pickProduct(
      title: 'Add Option',
      products: _availableChoiceProducts(
        editorData.availableProducts,
        denyIds: group.members
            .map((SemanticChoiceMemberDraft member) => member.itemProductId)
            .toSet(),
      ),
    );
    if (product == null) {
      return;
    }
    final List<SemanticChoiceMemberDraft> members =
        List<SemanticChoiceMemberDraft>.from(group.members)..add(
          SemanticChoiceMemberDraft(
            itemProductId: product.id,
            itemName: product.name,
            position: group.members.length,
          ),
        );
    setState(() {
      _choiceGroups = List<SemanticChoiceGroupDraft>.from(_choiceGroups)
        ..[groupIndex] = group.copyWith(members: members);
    });
    unawaited(_refreshValidation());
  }

  void _removeChoiceMember(int groupIndex, int memberIndex) {
    final SemanticChoiceGroupDraft group = _choiceGroups[groupIndex];
    final List<SemanticChoiceMemberDraft> members =
        List<SemanticChoiceMemberDraft>.from(group.members)
          ..removeAt(memberIndex);
    setState(() {
      _choiceGroups = List<SemanticChoiceGroupDraft>.from(_choiceGroups)
        ..[groupIndex] = group.copyWith(
          members: List<SemanticChoiceMemberDraft>.generate(
            members.length,
            (int index) => members[index].copyWith(position: index),
            growable: false,
          ),
        );
    });
    unawaited(_refreshValidation());
  }

  Future<void> _addExtraItem() async {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    if (editorData == null) {
      return;
    }
    final Product? product = await _pickProduct(
      title: 'Add Extra Item',
      products: _availableExtraProducts(editorData.availableProducts),
    );
    if (product == null) {
      return;
    }
    setState(() {
      _extras = <SemanticExtraItemDraft>[
        ..._extras,
        SemanticExtraItemDraft(
          itemProductId: product.id,
          itemName: product.name,
          sortOrder: _extras.length,
        ),
      ];
    });
    unawaited(_refreshValidation());
  }

  void _removeExtraItem(int index) {
    setState(() {
      final List<SemanticExtraItemDraft> extras =
          List<SemanticExtraItemDraft>.from(_extras)..removeAt(index);
      _extras = List<SemanticExtraItemDraft>.generate(
        extras.length,
        (int extraIndex) => extras[extraIndex].copyWith(sortOrder: extraIndex),
        growable: false,
      );
    });
    unawaited(_refreshValidation());
  }

  void _moveExtraItem(int fromIndex, int toIndex) {
    setState(() {
      final List<SemanticExtraItemDraft> extras =
          List<SemanticExtraItemDraft>.from(_extras);
      final SemanticExtraItemDraft item = extras.removeAt(fromIndex);
      extras.insert(toIndex, item);
      _extras = List<SemanticExtraItemDraft>.generate(
        extras.length,
        (int index) => extras[index].copyWith(sortOrder: index),
        growable: false,
      );
    });
    unawaited(_refreshValidation());
  }

  Future<Product?> _pickProduct({
    required String title,
    required List<Product> products,
  }) {
    if (products.isEmpty) {
      return Future<Product?>.value(null);
    }
    return showDialog<Product>(
      context: context,
      builder: (BuildContext context) =>
          _ProductPickerDialog(title: title, products: products),
    );
  }

  List<Product> _availableSetProducts(
    List<Product> products, {
    int? currentId,
  }) {
    final int? rootId = _editorData?.rootProduct.id;
    final Set<int> selectedIds = _setItems
        .where((SemanticSetItemDraft item) => item.itemProductId != currentId)
        .map((SemanticSetItemDraft item) => item.itemProductId)
        .toSet();
    final Set<int> choiceIds = _choiceGroups
        .expand(
          (SemanticChoiceGroupDraft group) => group.members.map(
            (SemanticChoiceMemberDraft member) => member.itemProductId,
          ),
        )
        .toSet();
    final Set<int> extraIds = _extras
        .map((SemanticExtraItemDraft extra) => extra.itemProductId)
        .toSet();
    return products
        .where((Product product) {
          if (product.id == rootId) {
            return currentId == product.id;
          }
          if (selectedIds.contains(product.id)) {
            return currentId == product.id;
          }
          if (choiceIds.contains(product.id) || extraIds.contains(product.id)) {
            return currentId == product.id;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<Product> _availableChoiceProducts(
    List<Product> products, {
    Set<int> denyIds = const <int>{},
    Set<int> allowIds = const <int>{},
  }) {
    final int? rootId = _editorData?.rootProduct.id;
    final Set<int> setIds = _setItems
        .map((SemanticSetItemDraft item) => item.itemProductId)
        .toSet();
    final Set<int> extraIds = _extras
        .map((SemanticExtraItemDraft extra) => extra.itemProductId)
        .toSet();
    return products
        .where((Product product) {
          if (product.id == rootId) {
            return false;
          }
          if (denyIds.contains(product.id)) {
            return false;
          }
          if (allowIds.contains(product.id)) {
            return true;
          }
          if (setIds.contains(product.id) || extraIds.contains(product.id)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<Product> _availableExtraProducts(List<Product> products) {
    final int? rootId = _editorData?.rootProduct.id;
    final Set<int> selectedIds = _extras
        .map((SemanticExtraItemDraft extra) => extra.itemProductId)
        .toSet();
    final Set<int> setIds = _setItems
        .map((SemanticSetItemDraft item) => item.itemProductId)
        .toSet();
    final Set<int> choiceIds = _choiceGroups
        .expand(
          (SemanticChoiceGroupDraft group) => group.members.map(
            (SemanticChoiceMemberDraft member) => member.itemProductId,
          ),
        )
        .toSet();
    return products
        .where((Product product) {
          if (product.id == rootId) {
            return false;
          }
          if (selectedIds.contains(product.id)) {
            return false;
          }
          if (setIds.contains(product.id) || choiceIds.contains(product.id)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Product? _findProduct(List<Product> products, int productId) {
    for (final Product product in products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  SemanticProductConfigurationDraft _buildDraft(
    SemanticProductConfigurationEditorData editorData,
  ) {
    return SemanticProductConfigurationDraft(
      productId: editorData.rootProduct.id,
      setItems: List<SemanticSetItemDraft>.from(_setItems)
        ..sort((SemanticSetItemDraft a, SemanticSetItemDraft b) {
          return a.sortOrder.compareTo(b.sortOrder);
        }),
      choiceGroups: List<SemanticChoiceGroupDraft>.from(_choiceGroups)
        ..sort((SemanticChoiceGroupDraft a, SemanticChoiceGroupDraft b) {
          return a.sortOrder.compareTo(b.sortOrder);
        }),
      extras: List<SemanticExtraItemDraft>.from(_extras)
        ..sort((SemanticExtraItemDraft a, SemanticExtraItemDraft b) {
          return a.sortOrder.compareTo(b.sortOrder);
        }),
    );
  }

  Future<void> _refreshValidation() async {
    final SemanticProductConfigurationEditorData? editorData = _editorData;
    if (editorData == null) {
      return;
    }
    final int requestId = ++_validationRequestId;
    final SemanticMenuValidationResult result = await ref
        .read(semanticMenuAdminServiceProvider)
        .validateConfiguration(
          configuration: _buildDraft(editorData),
          profile: editorData.profile,
        );
    if (!mounted || requestId != _validationRequestId) {
      return;
    }
    setState(() {
      _validationResult = result;
    });
  }

  String _formatPrice(int priceMinor) {
    final int major = priceMinor ~/ 100;
    final int minor = priceMinor % 100;
    return '$major.${minor.toString().padLeft(2, '0')}';
  }

  int? _parsePrice(String value) {
    final double? parsed = double.tryParse(value.replaceAll(',', '.').trim());
    if (parsed == null || parsed.isNegative) {
      return null;
    }
    return (parsed * 100).round();
  }

  Widget _tabFrame({
    required String heading,
    required Widget child,
    required String? actionLabel,
    required Key? actionKey,
    required VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  heading,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                ElevatedButton.icon(
                  key: actionKey,
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(actionLabel),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _empty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _rowCard({
    required String title,
    required List<Widget> controls,
    String? subtitle,
    Key? key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSizes.spacingXs),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Wrap(spacing: AppSizes.spacingSm, children: controls),
        ],
      ),
    );
  }

  Widget _moveButtons({
    required Key upKey,
    required Key downKey,
    required bool canMoveUp,
    required bool canMoveDown,
    required VoidCallback onMoveUp,
    required VoidCallback onMoveDown,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          key: upKey,
          onPressed: canMoveUp ? onMoveUp : null,
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
        IconButton(
          key: downKey,
          onPressed: canMoveDown ? onMoveDown : null,
          icon: const Icon(Icons.arrow_downward_rounded),
        ),
      ],
    );
  }

  Widget _rule(String label, String value) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _banner(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _validationBanner(String title, List<String> messages, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          ...messages.map(
            (String message) => Padding(
              padding: const EdgeInsets.only(top: AppSizes.spacingXs),
              child: Text(
                message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.decrementKey,
    required this.incrementKey,
    required this.quantity,
    required this.canDecrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final Key decrementKey;
  final Key incrementKey;
  final int quantity;
  final bool canDecrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          key: decrementKey,
          onPressed: canDecrease ? onDecrease : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(
          key: incrementKey,
          onPressed: onIncrease,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

class _ProductPickerDialog extends StatefulWidget {
  const _ProductPickerDialog({required this.title, required this.products});

  final String title;
  final List<Product> products;

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<Product> filtered = widget.products
        .where((Product product) {
          return product.name.toLowerCase().contains(_query.toLowerCase());
        })
        .toList(growable: false);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('semantic-product-picker-search'),
              decoration: const InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (BuildContext context, int index) {
                  final Product product = filtered[index];
                  return ListTile(
                    key: ValueKey<String>(
                      'semantic-product-picker-item-${product.id}',
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      CurrencyFormatter.fromMinor(product.priceMinor),
                    ),
                    onTap: () => Navigator.of(context).pop(product),
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
      ],
    );
  }
}

class _ChoiceGroupResult {
  const _ChoiceGroupResult({required this.name, required this.members});

  final String name;
  final List<SemanticChoiceMemberDraft> members;
}

class _ChoiceGroupDialog extends StatefulWidget {
  const _ChoiceGroupDialog({
    required this.title,
    required this.availableProducts,
    this.initialName = '',
    this.initialMembers = const <SemanticChoiceMemberDraft>[],
  });

  final String title;
  final List<Product> availableProducts;
  final String initialName;
  final List<SemanticChoiceMemberDraft> initialMembers;

  @override
  State<_ChoiceGroupDialog> createState() => _ChoiceGroupDialogState();
}

class _ChoiceGroupDialogState extends State<_ChoiceGroupDialog> {
  late final TextEditingController _nameController;
  late List<SemanticChoiceMemberDraft> _members;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _members = List<SemanticChoiceMemberDraft>.from(widget.initialMembers);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addOption() async {
    final Set<int> selectedIds = _members
        .map((SemanticChoiceMemberDraft member) => member.itemProductId)
        .toSet();
    final List<Product> products = widget.availableProducts
        .where((Product product) => !selectedIds.contains(product.id))
        .toList(growable: false);
    if (products.isEmpty) {
      return;
    }
    final Product? product = await showDialog<Product>(
      context: context,
      builder: (BuildContext context) =>
          _ProductPickerDialog(title: 'Add Option', products: products),
    );
    if (product == null || !mounted) {
      return;
    }
    setState(() {
      _members = <SemanticChoiceMemberDraft>[
        ..._members,
        SemanticChoiceMemberDraft(
          itemProductId: product.id,
          itemName: product.name,
          position: _members.length,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave =
        _nameController.text.trim().isNotEmpty && _members.isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('semantic-choice-group-name-input'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            const Text(
              'Choose one',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            if (_members.isEmpty)
              const Text(
                'Add at least one option.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...List<Widget>.generate(_members.length, (int index) {
                final SemanticChoiceMemberDraft member = _members[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(member.itemName),
                  trailing: IconButton(
                    key: ValueKey<String>(
                      'semantic-choice-group-dialog-delete-$index',
                    ),
                    onPressed: () {
                      setState(() {
                        _members = List<SemanticChoiceMemberDraft>.from(
                          _members,
                        )..removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                );
              }),
            const SizedBox(height: AppSizes.spacingMd),
            OutlinedButton.icon(
              key: const ValueKey<String>('semantic-choice-group-add-option'),
              onPressed: _addOption,
              icon: const Icon(Icons.add_rounded),
              label: const Text('+ Add Option'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey<String>('semantic-choice-group-save'),
          onPressed: canSave
              ? () {
                  Navigator.of(context).pop(
                    _ChoiceGroupResult(
                      name: _nameController.text.trim(),
                      members: List<SemanticChoiceMemberDraft>.generate(
                        _members.length,
                        (int index) =>
                            _members[index].copyWith(position: index),
                        growable: false,
                      ),
                    ),
                  );
                }
              : null,
          child: const Text('Save Group'),
        ),
      ],
    );
  }
}
