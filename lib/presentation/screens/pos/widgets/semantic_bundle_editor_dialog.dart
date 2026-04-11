import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/breakfast_cooking_instruction.dart';
import '../../../../domain/models/breakfast_line_edit.dart';
import '../../../../domain/models/breakfast_rebuild.dart';
import '../../../../domain/models/product.dart';
import '../../../../domain/services/breakfast_pos_service.dart';

class SemanticBundleEditorDialog extends ConsumerStatefulWidget {
  const SemanticBundleEditorDialog({
    required this.product,
    this.initialRequestedState = const BreakfastRequestedState(),
    this.initialEditorData,
    this.choiceDefaults = const <String, String?>{},
    super.key,
  });

  final Product product;
  final BreakfastRequestedState initialRequestedState;
  final BreakfastPosEditorData? initialEditorData;
  final Map<String, String?> choiceDefaults;

  @override
  ConsumerState<SemanticBundleEditorDialog> createState() =>
      _SemanticBundleEditorDialogState();
}

class _SemanticBundleEditorDialogState
    extends ConsumerState<SemanticBundleEditorDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  BreakfastPosEditorData? _editorData;
  BreakfastRequestedState _requestedState = const BreakfastRequestedState();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _requiredChoicesSectionKey = GlobalKey();
  int? _expandedRemovalSelectorProductId;
  int? _expandedCookingSelectorProductId;

  @override
  void initState() {
    super.initState();
    _requestedState = widget.initialRequestedState;
    if (widget.initialEditorData case final BreakfastPosEditorData editorData) {
      _editorData = _applyConfiguredChoiceDefaults(editorData);
      _isLoading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final BreakfastPosEditorData loadedEditorData = await ref
          .read(breakfastPosServiceProvider)
          .loadEditorData(
            product: widget.product,
            requestedState: _requestedState,
          );
      final BreakfastPosEditorData editorData = _applyConfiguredChoiceDefaults(
        loadedEditorData,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _editorData = editorData;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = ErrorMapper.toUserMessageAndLog(
          error,
          logger: ref.read(appLoggerProvider),
          eventType: 'semantic_bundle_editor_load_failed',
          stackTrace: stackTrace,
        );
        _isLoading = false;
      });
    }
  }

  void _apply(BreakfastLineEdit edit) {
    final BreakfastPosEditorData? editorData = _editorData;
    if (editorData == null) {
      return;
    }
    final BreakfastRequestedState nextState = edit.applyTo(_requestedState);
    final BreakfastPosSelectionPreview preview = ref
        .read(breakfastPosServiceProvider)
        .previewSelection(
          product: widget.product,
          configuration: editorData.configuration,
          requestedState: nextState,
        );
    final Set<int> availableCookingTargetIds = preview.cookingTargets
        .map((BreakfastCookingInstructionTarget target) => target.itemProductId)
        .toSet();
    setState(() {
      _requestedState = preview.requestedState;
      _editorData = BreakfastPosEditorData(
        product: editorData.product,
        profile: editorData.profile,
        configuration: editorData.configuration,
        preview: preview,
      );
      if (!availableCookingTargetIds.contains(
        _expandedCookingSelectorProductId,
      )) {
        _expandedCookingSelectorProductId = null;
      }
      _errorMessage = null;
    });
  }

  void _handleIncludedItemToggle({
    required BreakfastSetItemConfig item,
    required int removedQuantity,
  }) {
    if (!item.isRemovable) {
      return;
    }
    if (item.defaultQuantity == 1) {
      _apply(
        BreakfastLineEdit.setRemovedQuantity(
          itemProductId: item.itemProductId,
          quantity: removedQuantity > 0 ? 0 : 1,
        ),
      );
      return;
    }

    if (removedQuantity > 0) {
      _apply(
        BreakfastLineEdit.setRemovedQuantity(
          itemProductId: item.itemProductId,
          quantity: 0,
        ),
      );
      setState(() {
        _expandedRemovalSelectorProductId = null;
      });
      return;
    }

    setState(() {
      _expandedRemovalSelectorProductId =
          _expandedRemovalSelectorProductId == item.itemProductId
          ? null
          : item.itemProductId;
    });
  }

  void _selectRemovedQuantity({
    required BreakfastSetItemConfig item,
    required int quantity,
  }) {
    _apply(
      BreakfastLineEdit.setRemovedQuantity(
        itemProductId: item.itemProductId,
        quantity: quantity,
      ),
    );
    setState(() {
      _expandedRemovalSelectorProductId = null;
    });
  }

  void _toggleCookingSelector(int itemProductId) {
    setState(() {
      _expandedCookingSelectorProductId =
          _expandedCookingSelectorProductId == itemProductId
          ? null
          : itemProductId;
    });
  }

  void _selectCookingInstruction({
    required int itemProductId,
    required BreakfastCookingInstructionOption? option,
  }) {
    _apply(
      BreakfastLineEdit.setCookingInstruction(
        itemProductId: itemProductId,
        instructionCode: option?.code,
        instructionLabel: option?.label,
      ),
    );
    setState(() {
      _expandedCookingSelectorProductId = null;
    });
  }

  Future<void> _scrollToRequiredChoices() async {
    final BuildContext? sectionContext =
        _requiredChoicesSectionKey.currentContext;
    if (sectionContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  BreakfastPosEditorData _applyConfiguredChoiceDefaults(
    BreakfastPosEditorData editorData,
  ) {
    if (widget.choiceDefaults.isEmpty) {
      return editorData;
    }
    BreakfastRequestedState nextState = editorData.preview.requestedState;
    bool changed = false;
    final Map<int, BreakfastChosenGroupRequest> selectedChoices =
        <int, BreakfastChosenGroupRequest>{
          for (final BreakfastChosenGroupRequest group
              in nextState.chosenGroups)
            group.groupId: group,
        };
    for (final BreakfastChoiceGroupConfig group
        in editorData.configuration.choiceGroups) {
      if (selectedChoices[group.groupId] != null) {
        continue;
      }
      final String normalizedGroupName = _normalizeChoiceToken(
        _choiceSummaryName(group),
      );
      final String? canonicalGroupKey = _choiceDefaultGroupKey(group);
      final String? configuredDefault =
          widget.choiceDefaults[normalizedGroupName] ??
          (canonicalGroupKey == null
              ? null
              : widget.choiceDefaults[canonicalGroupKey]);
      if (configuredDefault == null) {
        continue;
      }
      final String normalizedDefault = _normalizeChoiceToken(configuredDefault);
      final BreakfastChoiceGroupMemberConfig? matchedMember =
          _resolveConfiguredDefaultMember(
            group: group,
            normalizedDefault: normalizedDefault,
          );
      if (matchedMember != null) {
        nextState = BreakfastLineEdit.chooseGroup(
          groupId: group.groupId,
          selectedItemProductId: matchedMember.itemProductId,
          quantity: group.includedQuantity,
        ).applyTo(nextState);
        changed = true;
        continue;
      }
      if (group.allowsExplicitNoneSelection &&
          _matchesExplicitNoneDefault(
            group: group,
            normalizedDefault: normalizedDefault,
          )) {
        nextState = BreakfastLineEdit.chooseGroup(
          groupId: group.groupId,
          selectedItemProductId: null,
          quantity: 1,
        ).applyTo(nextState);
        changed = true;
        continue;
      }
      if (group.members.isNotEmpty) {
        nextState = BreakfastLineEdit.chooseGroup(
          groupId: group.groupId,
          selectedItemProductId: group.members.first.itemProductId,
          quantity: group.includedQuantity,
        ).applyTo(nextState);
        changed = true;
      }
    }
    if (!changed) {
      return editorData;
    }
    final BreakfastPosSelectionPreview preview = ref
        .read(breakfastPosServiceProvider)
        .previewSelection(
          product: editorData.product,
          configuration: editorData.configuration,
          requestedState: nextState,
        );
    _requestedState = preview.requestedState;
    return BreakfastPosEditorData(
      product: editorData.product,
      profile: editorData.profile,
      configuration: editorData.configuration,
      preview: preview,
    );
  }

  String _choiceSummaryName(BreakfastChoiceGroupConfig group) {
    return group.groupName.replaceAll(
      RegExp(r'\s+choice$', caseSensitive: false),
      '',
    );
  }

  String _normalizeChoiceToken(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String? _choiceDefaultGroupKey(BreakfastChoiceGroupConfig group) {
    final List<String> candidates = <String>[
      _choiceSummaryName(group),
      group.groupName,
      ...group.members.map((BreakfastChoiceGroupMemberConfig member) {
        return member.displayName;
      }),
    ].map(_normalizeChoiceToken).toList(growable: false);

    if (candidates.any(
      (String value) =>
          value.contains('drink') ||
          value.contains('tea') ||
          value.contains('coffee') ||
          value.contains('latte') ||
          value.contains('cappuccino'),
    )) {
      return 'drink';
    }
    if (candidates.any(
      (String value) =>
          value.contains('bread') ||
          value.contains('toast') ||
          value.contains('bakery'),
    )) {
      return 'bread';
    }
    return null;
  }

  BreakfastChoiceGroupMemberConfig? _resolveConfiguredDefaultMember({
    required BreakfastChoiceGroupConfig group,
    required String normalizedDefault,
  }) {
    final List<String> preferredAliases = _choiceDefaultAliases(
      normalizedDefault,
    );
    for (final String alias in preferredAliases) {
      for (final BreakfastChoiceGroupMemberConfig member in group.members) {
        final String normalizedMember = _normalizeChoiceToken(
          member.displayName,
        );
        if (normalizedMember == alias ||
            normalizedMember.contains(alias) ||
            alias.contains(normalizedMember)) {
          return member;
        }
      }
    }
    return null;
  }

  List<String> _choiceDefaultAliases(String normalizedDefault) {
    switch (normalizedDefault) {
      case 'cappucciolatte':
        return <String>['cappucciolatte', 'cappuccino', 'latte'];
      case 'toast':
        return <String>['toast', 'toasts'];
      default:
        return <String>[normalizedDefault];
    }
  }

  bool _matchesExplicitNoneDefault({
    required BreakfastChoiceGroupConfig group,
    required String normalizedDefault,
  }) {
    final Set<String> aliases = <String>{
      'none',
      'nodrink',
      'notoastbread',
      'notoastorbread',
      'nobread',
      _normalizeChoiceToken(group.explicitNoneDisplayLabel),
    };
    return aliases.contains(normalizedDefault);
  }

  @override
  Widget build(BuildContext context) {
    final BreakfastPosEditorData? editorData = _editorData;
    return Dialog(
      key: const ValueKey<String>('semantic-bundle-dialog'),
      insetPadding: const EdgeInsets.all(AppSizes.spacingMd),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 900),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : editorData == null
              ? Center(
                  child: Text(
                    _errorMessage ?? 'Unable to load breakfast builder.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : _buildLoaded(editorData),
        ),
      ),
    );
  }

  Widget _buildLoaded(BreakfastPosEditorData editorData) {
    final BreakfastPosSelectionPreview preview = editorData.preview;
    final Map<int, int> removedQuantities = <int, int>{
      for (final BreakfastRemovedSetItemRequest item
          in _requestedState.removedSetItems)
        item.itemProductId: item.quantity,
    };
    final Map<int, int> addedQuantities = <int, int>{
      for (final BreakfastAddedProductRequest item
          in _requestedState.addedProducts)
        item.itemProductId: item.quantity,
    };
    final Map<int, BreakfastChosenGroupRequest> selectedChoices =
        <int, BreakfastChosenGroupRequest>{
          for (final BreakfastChosenGroupRequest group
              in _requestedState.chosenGroups)
            group.groupId: group,
        };
    final Map<int, BreakfastCookingInstructionRequest>
    selectedCookingInstructions = <int, BreakfastCookingInstructionRequest>{
      for (final BreakfastCookingInstructionRequest instruction
          in _requestedState.cookingInstructions)
        instruction.itemProductId: instruction,
    };
    final Map<int, BreakfastCookingInstructionTarget>
    cookingTargetsByProductId = <int, BreakfastCookingInstructionTarget>{
      for (final BreakfastCookingInstructionTarget target
          in preview.cookingTargets)
        target.itemProductId: target,
    };
    final int pendingRequiredChoiceCount = editorData.configuration.choiceGroups
        .where((BreakfastChoiceGroupConfig group) {
          final BreakfastChosenGroupRequest? choice =
              selectedChoices[group.groupId];
          if (choice == null) {
            return true;
          }
          return group.minSelect > 0 &&
              choice.isExplicitNone &&
              !group.allowsExplicitNoneSelection;
        })
        .length;
    final String? blockingMessage =
        preview.canConfirm || preview.validationMessages.isEmpty
        ? null
        : preview.validationMessages.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.fromMinor(widget.product.priceMinor),
                    style: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey<String>('semantic-bundle-close'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        if (_errorMessage != null) ...<Widget>[
          const SizedBox(height: AppSizes.spacingSm),
          _message(_errorMessage!, AppColors.error),
        ],
        const SizedBox(height: AppSizes.spacingXs),
        Container(
          key: const ValueKey<String>('semantic-required-summary-bar'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingSm,
            vertical: AppSizes.spacingXs,
          ),
          decoration: BoxDecoration(
            color: pendingRequiredChoiceCount > 0
                ? AppColors.warning.withValues(alpha: 0.08)
                : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: pendingRequiredChoiceCount > 0
                  ? AppColors.warning.withValues(alpha: 0.22)
                  : AppColors.border,
            ),
          ),
          child: _StickyShortcutBar(
            groups: editorData.configuration.choiceGroups,
            selectedChoices: selectedChoices,
            onSelectChoice:
                ({
                  required BreakfastChoiceGroupConfig group,
                  required int? selectedItemProductId,
                  required int quantity,
                }) {
                  _apply(
                    BreakfastLineEdit.chooseGroup(
                      groupId: group.groupId,
                      selectedItemProductId: selectedItemProductId,
                      quantity: quantity,
                    ),
                  );
                },
            choiceSummaryName: _choiceSummaryName,
          ),
        ),
        const SizedBox(height: AppSizes.spacingSm),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _section(
                  title: 'Included Items',
                  trailing: _SectionMetaPill(
                    label: '${editorData.configuration.setItems.length} items',
                  ),
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final double tileWidth = constraints.maxWidth >= 900
                              ? (constraints.maxWidth -
                                        AppSizes.spacingXs * 3) /
                                    4
                              : constraints.maxWidth >= 660
                              ? (constraints.maxWidth -
                                        AppSizes.spacingXs * 2) /
                                    3
                              : constraints.maxWidth >= 460
                              ? (constraints.maxWidth - AppSizes.spacingXs) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: AppSizes.spacingXs,
                            runSpacing: AppSizes.spacingXs,
                            children: editorData.configuration.setItems
                                .map((BreakfastSetItemConfig item) {
                                  final int removedQuantity =
                                      removedQuantities[item.itemProductId] ??
                                      0;
                                  return SizedBox(
                                    width: tileWidth,
                                    child: _IncludedItemRow(
                                      item: item,
                                      removedQuantity: removedQuantity,
                                      selectorExpanded:
                                          _expandedRemovalSelectorProductId ==
                                          item.itemProductId,
                                      cookingTarget:
                                          cookingTargetsByProductId[item
                                              .itemProductId],
                                      selectedCookingInstruction:
                                          selectedCookingInstructions[item
                                              .itemProductId],
                                      cookingSelectorExpanded:
                                          _expandedCookingSelectorProductId ==
                                          item.itemProductId,
                                      onToggle: () => _handleIncludedItemToggle(
                                        item: item,
                                        removedQuantity: removedQuantity,
                                      ),
                                      onSelectRemovedQuantity: (int quantity) =>
                                          _selectRemovedQuantity(
                                            item: item,
                                            quantity: quantity,
                                          ),
                                      onOpenSelector: () {
                                        setState(() {
                                          _expandedRemovalSelectorProductId =
                                              item.itemProductId;
                                        });
                                      },
                                      onToggleCookingSelector: () =>
                                          _toggleCookingSelector(
                                            item.itemProductId,
                                          ),
                                      onSelectCookingInstruction:
                                          (
                                            BreakfastCookingInstructionOption?
                                            option,
                                          ) => _selectCookingInstruction(
                                            itemProductId: item.itemProductId,
                                            option: option,
                                          ),
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          );
                        },
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                _section(
                  title: 'Extras',
                  trailing: _SectionMetaPill(
                    label:
                        '${addedQuantities.values.fold<int>(0, (int sum, int value) => sum + value)} added',
                  ),
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final double cardWidth = constraints.maxWidth >= 900
                              ? (constraints.maxWidth -
                                        AppSizes.spacingXs * 3) /
                                    4
                              : constraints.maxWidth >= 660
                              ? (constraints.maxWidth -
                                        AppSizes.spacingXs * 2) /
                                    3
                              : constraints.maxWidth >= 500
                              ? (constraints.maxWidth - AppSizes.spacingXs) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: AppSizes.spacingXs,
                            runSpacing: AppSizes.spacingXs,
                            children: preview.addableProducts
                                .map((BreakfastPosAddableProduct product) {
                                  final int quantity =
                                      addedQuantities[product.id] ?? 0;
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _ExtraItemCard(
                                      product: product,
                                      quantity: quantity,
                                      onDecrease: () {
                                        _apply(
                                          BreakfastLineEdit.setAddedQuantity(
                                            itemProductId: product.id,
                                            quantity: quantity - 1,
                                          ),
                                        );
                                      },
                                      onIncrease: () {
                                        _apply(
                                          BreakfastLineEdit.setAddedQuantity(
                                            itemProductId: product.id,
                                            quantity: quantity + 1,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          );
                        },
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                _section(
                  sectionKey: _requiredChoicesSectionKey,
                  title: 'Required Choices',
                  trailing: pendingRequiredChoiceCount == 0
                      ? const _SectionMetaPill(label: 'Ready')
                      : _SectionMetaPill(
                          label: '$pendingRequiredChoiceCount pending',
                          tone: _SectionMetaTone.warning,
                        ),
                  child: Column(
                    children: editorData.configuration.choiceGroups
                        .map((BreakfastChoiceGroupConfig group) {
                          final BreakfastChosenGroupRequest? currentChoice =
                              selectedChoices[group.groupId];
                          final int? selectedId =
                              currentChoice?.selectedItemProductId;
                          final bool isExplicitNone =
                              currentChoice?.isExplicitNone ?? false;
                          final bool supportsExplicitNone =
                              group.allowsExplicitNoneSelection;
                          final bool hasSatisfiedSelection =
                              currentChoice != null &&
                              (supportsExplicitNone || !isExplicitNone);
                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: AppSizes.spacingXs,
                            ),
                            padding: const EdgeInsets.all(AppSizes.spacingSm),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusSm,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        group.groupName,
                                        style: const TextStyle(
                                          fontSize: AppSizes.fontSm,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    _SectionMetaPill(
                                      label: hasSatisfiedSelection
                                          ? 'Done'
                                          : 'Pending',
                                      tone: hasSatisfiedSelection
                                          ? _SectionMetaTone.neutral
                                          : _SectionMetaTone.warning,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LayoutBuilder(
                                  builder:
                                      (
                                        BuildContext context,
                                        BoxConstraints constraints,
                                      ) {
                                        final double optionWidth =
                                            constraints.maxWidth >= 720
                                            ? (constraints.maxWidth -
                                                      AppSizes.spacingXs * 2) /
                                                  3
                                            : constraints.maxWidth >= 460
                                            ? (constraints.maxWidth -
                                                      AppSizes.spacingXs) /
                                                  2
                                            : constraints.maxWidth;

                                        final List<Widget> options = <Widget>[
                                          if (supportsExplicitNone)
                                            SizedBox(
                                              width: optionWidth,
                                              child: _ChoiceOptionButton(
                                                optionKey: ValueKey<String>(
                                                  'semantic-choice-none-${group.groupId}',
                                                ),
                                                label: group
                                                    .explicitNoneDisplayLabel,
                                                selected: isExplicitNone,
                                                onTap: () {
                                                  _apply(
                                                    BreakfastLineEdit.chooseGroup(
                                                      groupId: group.groupId,
                                                      selectedItemProductId:
                                                          null,
                                                      quantity: 1,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ...group.members.map((
                                            BreakfastChoiceGroupMemberConfig
                                            member,
                                          ) {
                                            return SizedBox(
                                              width: optionWidth,
                                              child: _ChoiceOptionButton(
                                                optionKey: ValueKey<String>(
                                                  'semantic-choice-select-${group.groupId}-${member.itemProductId}',
                                                ),
                                                label: member.displayName,
                                                selected:
                                                    !isExplicitNone &&
                                                    selectedId ==
                                                        member.itemProductId,
                                                onTap: () {
                                                  _apply(
                                                    BreakfastLineEdit.chooseGroup(
                                                      groupId: group.groupId,
                                                      selectedItemProductId:
                                                          member.itemProductId,
                                                      quantity: group
                                                          .includedQuantity,
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          }),
                                        ];

                                        return Wrap(
                                          spacing: AppSizes.spacingXs,
                                          runSpacing: AppSizes.spacingXs,
                                          children: options,
                                        );
                                      },
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spacingXs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingSm,
            vertical: AppSizes.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: AppSizes.spacingXs,
                  runSpacing: AppSizes.spacingXs,
                  children: <Widget>[
                    _SummaryStat(
                      label: 'Set',
                      value: CurrencyFormatter.fromMinor(
                        preview.rebuildResult.lineSnapshot.baseUnitPriceMinor,
                      ),
                    ),
                    _SummaryStat(
                      label: 'Extras',
                      value: CurrencyFormatter.fromMinor(
                        preview.rebuildResult.lineSnapshot.modifierTotalMinor,
                      ),
                    ),
                    _SummaryStat(
                      label: 'Total',
                      value: CurrencyFormatter.fromMinor(
                        preview.rebuildResult.lineSnapshot.lineTotalMinor,
                      ),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
              if (pendingRequiredChoiceCount > 0) ...<Widget>[
                const SizedBox(width: AppSizes.spacingSm),
                _SectionMetaPill(
                  label:
                      '$pendingRequiredChoiceCount choice${pendingRequiredChoiceCount == 1 ? '' : 's'} pending',
                  tone: _SectionMetaTone.warning,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacingXs),
        Row(
          children: <Widget>[
            Expanded(
              child: blockingMessage == null
                  ? const SizedBox.shrink()
                  : Text(
                      pendingRequiredChoiceCount > 0
                          ? 'Finish required choices to continue'
                          : blockingMessage,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: AppSizes.fontSm,
                      ),
                    ),
            ),
            if (pendingRequiredChoiceCount > 0) ...<Widget>[
              TextButton.icon(
                key: const ValueKey<String>('semantic-scroll-required-choices'),
                onPressed: _scrollToRequiredChoices,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacingSm,
                    vertical: AppSizes.spacingSm,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                label: const Text('Finish choices'),
              ),
              const SizedBox(width: AppSizes.spacingXs),
            ],
            OutlinedButton(
              key: const ValueKey<String>('semantic-bundle-cancel'),
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(132, 54),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacingLg,
                  vertical: AppSizes.spacingMd,
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                textStyle: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSizes.spacingMd),
            ElevatedButton(
              key: const ValueKey<String>('semantic-bundle-confirm'),
              onPressed: preview.canConfirm
                  ? () => Navigator.of(context).pop(
                      preview.toCartSelection(
                        configuration: editorData.configuration,
                      ),
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(188, 58),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacingXl,
                  vertical: AppSizes.spacingMd,
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.standard,
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: AppSizes.fontMd,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
              child: const Text('Add to Order'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _section({
    Key? sectionKey,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    final String sectionSlug = title.toLowerCase().replaceAll(' ', '-');
    return Container(
      key: sectionKey,
      padding: const EdgeInsets.all(AppSizes.spacingSm),
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
                child: Text(
                  title,
                  key: ValueKey<String>('semantic-section-$sectionSlug'),
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: AppSizes.spacingXs),
          child,
        ],
      ),
    );
  }

  Widget _message(String message, Color color) {
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
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingXs,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
          color: emphasize
              ? AppColors.primary.withValues(alpha: 0.24)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w700,
              color: emphasize ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? AppSizes.fontMd : 12,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

enum _SectionMetaTone { neutral, warning }

class _SectionMetaPill extends StatelessWidget {
  const _SectionMetaPill({
    required this.label,
    this.tone = _SectionMetaTone.neutral,
  });

  final String label;
  final _SectionMetaTone tone;

  @override
  Widget build(BuildContext context) {
    final bool isWarning = tone == _SectionMetaTone.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isWarning
              ? AppColors.warning.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isWarning ? AppColors.warning : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StickyShortcutBar extends StatelessWidget {
  const _StickyShortcutBar({
    required this.groups,
    required this.selectedChoices,
    required this.onSelectChoice,
    required this.choiceSummaryName,
  });

  final List<BreakfastChoiceGroupConfig> groups;
  final Map<int, BreakfastChosenGroupRequest> selectedChoices;
  final void Function({
    required BreakfastChoiceGroupConfig group,
    required int? selectedItemProductId,
    required int quantity,
  })
  onSelectChoice;
  final String Function(BreakfastChoiceGroupConfig group) choiceSummaryName;

  @override
  Widget build(BuildContext context) {
    final List<BreakfastChoiceGroupConfig> orderedGroups =
        List<BreakfastChoiceGroupConfig>.from(groups)
          ..sort((BreakfastChoiceGroupConfig a, BreakfastChoiceGroupConfig b) {
            return _groupRank(a).compareTo(_groupRank(b));
          });
    final List<Widget> groupWidgets = orderedGroups
        .map(
          (BreakfastChoiceGroupConfig group) => Expanded(
            child: _StickyShortcutGroup(
              group: group,
              currentChoice: selectedChoices[group.groupId],
              onSelectChoice: onSelectChoice,
              semanticLabel: choiceSummaryName(group),
            ),
          ),
        )
        .toList(growable: false);

    if (groupWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: groupWidgets
          .expand(
            (Widget groupWidget) => <Widget>[
              groupWidget,
              if (groupWidget != groupWidgets.last)
                const SizedBox(width: AppSizes.spacingSm),
            ],
          )
          .toList(growable: false),
    );
  }

  int _groupRank(BreakfastChoiceGroupConfig group) {
    final String normalizedName = choiceSummaryName(group).toLowerCase();
    if (normalizedName.contains('drink') ||
        normalizedName.contains('tea') ||
        normalizedName.contains('coffee')) {
      return 0;
    }
    if (normalizedName.contains('bread') || normalizedName.contains('toast')) {
      return 1;
    }
    return 2 + groups.indexOf(group);
  }
}

class _StickyShortcutGroup extends StatelessWidget {
  const _StickyShortcutGroup({
    required this.group,
    required this.currentChoice,
    required this.onSelectChoice,
    required this.semanticLabel,
  });

  final BreakfastChoiceGroupConfig group;
  final BreakfastChosenGroupRequest? currentChoice;
  final void Function({
    required BreakfastChoiceGroupConfig group,
    required int? selectedItemProductId,
    required int quantity,
  })
  onSelectChoice;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final int? selectedId = currentChoice?.selectedItemProductId;
    final bool isExplicitNone = currentChoice?.isExplicitNone ?? false;
    final bool supportsExplicitNone = group.allowsExplicitNoneSelection;
    final List<Widget> buttons = <Widget>[
      ...group.members.map(
        (BreakfastChoiceGroupMemberConfig member) => Expanded(
          child: _StickyChoiceButton(
            buttonKey: ValueKey<String>(
              'semantic-sticky-choice-select-${group.groupId}-${member.itemProductId}',
            ),
            semanticLabel: '$semanticLabel ${member.displayName}',
            label: member.displayName,
            selected: !isExplicitNone && selectedId == member.itemProductId,
            weakened: false,
            onTap: () {
              onSelectChoice(
                group: group,
                selectedItemProductId: member.itemProductId,
                quantity: group.includedQuantity,
              );
            },
          ),
        ),
      ),
      if (supportsExplicitNone)
        Expanded(
          child: _StickyChoiceButton(
            buttonKey: ValueKey<String>(
              'semantic-sticky-choice-none-${group.groupId}',
            ),
            semanticLabel: '$semanticLabel ${group.explicitNoneDisplayLabel}',
            label: group.explicitNoneDisplayLabel,
            selected: isExplicitNone,
            weakened: true,
            onTap: () {
              onSelectChoice(
                group: group,
                selectedItemProductId: null,
                quantity: 1,
              );
            },
          ),
        ),
    ];

    return Row(
      children: buttons
          .expand(
            (Widget button) => <Widget>[
              button,
              if (button != buttons.last) const SizedBox(width: 6),
            ],
          )
          .toList(growable: false),
    );
  }
}

class _StickyChoiceButton extends StatelessWidget {
  const _StickyChoiceButton({
    required this.buttonKey,
    required this.semanticLabel,
    required this.label,
    required this.selected,
    required this.weakened,
    required this.onTap,
  });

  final Key buttonKey;
  final String semanticLabel;
  final String label;
  final bool selected;
  final bool weakened;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = weakened
        ? AppColors.textSecondary
        : AppColors.primary;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: BorderSide(
            color: selected
                ? activeColor
                : weakened
                ? AppColors.border
                : AppColors.primary.withValues(alpha: 0.32),
            width: selected ? 1.4 : 1,
          ),
          backgroundColor: selected
              ? activeColor.withValues(alpha: weakened ? 0.14 : 0.18)
              : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected
                  ? activeColor
                  : weakened
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RowActionPill extends StatelessWidget {
  const _RowActionPill({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.keyValue,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Key keyValue;

  @override
  Widget build(BuildContext context) {
    final Color foreground = AppColors.textSecondary;
    return OutlinedButton.icon(
      key: keyValue,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: AppColors.border),
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _ChoiceOptionButton extends StatelessWidget {
  const _ChoiceOptionButton({
    required this.optionKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key optionKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        key: optionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingSm,
            vertical: AppSizes.spacingXs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppSizes.fontSm,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CookingInstructionChip extends StatelessWidget {
  const _CookingInstructionChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: chipKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingSm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtraItemCard extends StatelessWidget {
  const _ExtraItemCard({
    required this.product,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final BreakfastPosAddableProduct product;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final bool hasQuantity = quantity > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('semantic-add-card-${product.id}'),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: onIncrease,
        child: Container(
          padding: const EdgeInsets.all(AppSizes.spacingSm),
          decoration: BoxDecoration(
            color: hasQuantity
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: hasQuantity
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppSizes.fontSm,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingXs),
                  Text(
                    CurrencyFormatter.fromMinor(product.priceMinor),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingSm),
              Row(
                children: <Widget>[
                  if (hasQuantity)
                    _TouchQuantityButton(
                      buttonKey: ValueKey<String>(
                        'semantic-add-dec-${product.id}',
                      ),
                      icon: Icons.remove_rounded,
                      enabled: true,
                      onTap: onDecrease,
                    )
                  else
                    const SizedBox(width: 52, height: 52),
                  const SizedBox(width: AppSizes.spacingXs),
                  Expanded(
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        hasQuantity ? '$quantity added' : 'Tap to add',
                        key: ValueKey<String>(
                          'semantic-add-status-${product.id}',
                        ),
                        style: TextStyle(
                          fontSize: hasQuantity ? 14 : 12,
                          fontWeight: FontWeight.w900,
                          color: hasQuantity
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingXs),
                  _TouchQuantityButton(
                    buttonKey: ValueKey<String>(
                      'semantic-add-inc-${product.id}',
                    ),
                    icon: Icons.add_rounded,
                    enabled: true,
                    onTap: onIncrease,
                    accentColor: AppColors.primary,
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

class _TouchQuantityButton extends StatelessWidget {
  const _TouchQuantityButton({
    required this.buttonKey,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.accentColor = AppColors.textPrimary,
  });

  final Key buttonKey;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: FilledButton(
        key: buttonKey,
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          disabledBackgroundColor: AppColors.border,
          foregroundColor: AppColors.surface,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class _IncludedItemRow extends StatelessWidget {
  const _IncludedItemRow({
    required this.item,
    required this.removedQuantity,
    required this.selectorExpanded,
    required this.cookingSelectorExpanded,
    required this.onToggle,
    required this.onSelectRemovedQuantity,
    required this.onOpenSelector,
    required this.onToggleCookingSelector,
    required this.onSelectCookingInstruction,
    this.cookingTarget,
    this.selectedCookingInstruction,
  });

  final BreakfastSetItemConfig item;
  final int removedQuantity;
  final bool selectorExpanded;
  final bool cookingSelectorExpanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelectRemovedQuantity;
  final VoidCallback onOpenSelector;
  final VoidCallback onToggleCookingSelector;
  final ValueChanged<BreakfastCookingInstructionOption?>
  onSelectCookingInstruction;
  final BreakfastCookingInstructionTarget? cookingTarget;
  final BreakfastCookingInstructionRequest? selectedCookingInstruction;

  bool get _isMultiQuantity => item.defaultQuantity > 1;
  int get _remainingQuantity => item.defaultQuantity - removedQuantity;

  String get _subtitle {
    if (!item.isRemovable) {
      return item.defaultQuantity > 1
          ? '${item.defaultQuantity} included · fixed'
          : 'Fixed';
    }
    if (removedQuantity == 0) {
      return _isMultiQuantity ? '${item.defaultQuantity} included' : '';
    }
    if (_remainingQuantity <= 0) {
      return '$removedQuantity removed';
    }
    return '$removedQuantity removed · $_remainingQuantity left';
  }

  Color get _accentColor {
    if (!item.isRemovable) {
      return AppColors.textSecondary;
    }
    if (removedQuantity == 0) {
      return AppColors.success;
    }
    if (_remainingQuantity <= 0) {
      return AppColors.error;
    }
    return AppColors.warning;
  }

  Color get _rowBackgroundColor {
    if (!item.isRemovable) {
      return AppColors.surfaceMuted;
    }
    if (removedQuantity == 0) {
      return AppColors.surfaceMuted;
    }
    return _accentColor.withValues(alpha: 0.09);
  }

  Color get _rowBorderColor {
    if (selectorExpanded || cookingSelectorExpanded) {
      return _accentColor.withValues(alpha: 0.45);
    }
    if (!item.isRemovable || removedQuantity == 0) {
      return AppColors.border;
    }
    return _accentColor.withValues(alpha: 0.32);
  }

  Color get _chipBackgroundColor {
    if (!item.isRemovable) {
      return AppColors.surface;
    }
    if (removedQuantity == 0) {
      return AppColors.surface;
    }
    return _accentColor.withValues(alpha: 0.12);
  }

  Color get _chipTextColor {
    if (!item.isRemovable) {
      return AppColors.textPrimary;
    }
    if (removedQuantity == 0) {
      return AppColors.textPrimary;
    }
    return _accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final bool showSelector =
        item.isRemovable && _isMultiQuantity && selectorExpanded;
    final bool hasCookingTrigger = cookingTarget != null;
    final bool showCookingSelector =
        hasCookingTrigger && cookingSelectorExpanded;
    final bool showChangeAction =
        item.isRemovable &&
        _isMultiQuantity &&
        removedQuantity > 0 &&
        !selectorExpanded;
    final String? cookingLabel = selectedCookingInstruction?.instructionLabel;
    final bool hasStatus = _subtitle.isNotEmpty;
    final BorderRadius chipRadius = BorderRadius.circular(AppSizes.radiusMd);
    final BorderRadius chipActionRadius = BorderRadius.circular(
      AppSizes.radiusMd - 1,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        color: _rowBackgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: _rowBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: _chipBackgroundColor,
                borderRadius: chipRadius,
                border: Border.all(
                  color: showSelector || showCookingSelector
                      ? _accentColor.withValues(alpha: 0.4)
                      : _rowBorderColor,
                  width:
                      removedQuantity > 0 ||
                          showSelector ||
                          showCookingSelector ||
                          cookingLabel != null
                      ? 1.4
                      : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey<String>(
                          'semantic-include-${item.itemProductId}',
                        ),
                        onTap: item.isRemovable ? onToggle : null,
                        borderRadius: hasCookingTrigger
                            ? BorderRadius.only(
                                topLeft: chipActionRadius.topLeft,
                                bottomLeft: chipActionRadius.bottomLeft,
                              )
                            : chipActionRadius,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item.itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _chipTextColor,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasCookingTrigger) ...<Widget>[
                    Container(width: 1, height: 24, color: _rowBorderColor),
                    SizedBox(
                      width: 40,
                      height: 48,
                      child: Tooltip(
                        message: cookingLabel ?? 'Cook',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey<String>(
                              'semantic-cooking-trigger-${item.itemProductId}',
                            ),
                            onTap: onToggleCookingSelector,
                            borderRadius: BorderRadius.only(
                              topRight: chipActionRadius.topRight,
                              bottomRight: chipActionRadius.bottomRight,
                            ),
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color:
                                      cookingLabel != null ||
                                          showCookingSelector
                                      ? AppColors.primary.withValues(
                                          alpha: 0.14,
                                        )
                                      : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        cookingLabel != null ||
                                            showCookingSelector
                                        ? AppColors.primary.withValues(
                                            alpha: 0.3,
                                          )
                                        : AppColors.border,
                                  ),
                                ),
                                child: Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 18,
                                  color:
                                      cookingLabel != null ||
                                          showCookingSelector
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasStatus || cookingLabel != null) ...<Widget>[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  if (hasStatus)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: removedQuantity == 0 && item.isRemovable
                            ? AppColors.surface
                            : _accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _subtitle,
                        key: ValueKey<String>(
                          'semantic-include-status-${item.itemProductId}',
                        ),
                        style: TextStyle(
                          color: removedQuantity == 0 && item.isRemovable
                              ? AppColors.textSecondary
                              : _accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          height: 1,
                        ),
                      ),
                    ),
                  if (cookingLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${item.itemName} — $cookingLabel',
                        key: ValueKey<String>(
                          'semantic-cooking-status-${item.itemProductId}',
                        ),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          height: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                if (showChangeAction)
                  _RowActionPill(
                    keyValue: ValueKey<String>(
                      'semantic-include-change-${item.itemProductId}',
                    ),
                    onPressed: onOpenSelector,
                    icon: Icons.tune_rounded,
                    label: 'Adjust',
                  ),
              ],
            ),
            if (showSelector) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                key: ValueKey<String>(
                  'semantic-include-selector-${item.itemProductId}',
                ),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Wrap(
                  spacing: AppSizes.spacingXs,
                  runSpacing: AppSizes.spacingXs,
                  children: List<Widget>.generate(item.defaultQuantity, (
                    int index,
                  ) {
                    final int quantity = index + 1;
                    final bool isSelected = quantity == removedQuantity;
                    return ChoiceChip(
                      key: ValueKey<String>(
                        'semantic-include-remove-${item.itemProductId}-$quantity',
                      ),
                      label: Text('Remove $quantity'),
                      selected: isSelected,
                      onSelected: (_) => onSelectRemovedQuantity(quantity),
                      selectedColor: _accentColor.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? _accentColor
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? _accentColor.withValues(alpha: 0.45)
                            : AppColors.border,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }),
                ),
              ),
            ],
            if (showCookingSelector && cookingTarget != null) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                key: ValueKey<String>(
                  'semantic-cooking-selector-${item.itemProductId}',
                ),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Wrap(
                  spacing: AppSizes.spacingXs,
                  runSpacing: AppSizes.spacingXs,
                  children: <Widget>[
                    _CookingInstructionChip(
                      chipKey: ValueKey<String>(
                        'semantic-cooking-option-${item.itemProductId}-standard',
                      ),
                      label: 'Standard',
                      selected: selectedCookingInstruction == null,
                      onTap: () => onSelectCookingInstruction(null),
                    ),
                    ...cookingTarget!.options.map((
                      BreakfastCookingInstructionOption option,
                    ) {
                      return _CookingInstructionChip(
                        chipKey: ValueKey<String>(
                          'semantic-cooking-option-${item.itemProductId}-${option.code}',
                        ),
                        label: option.label,
                        selected:
                            selectedCookingInstruction?.instructionCode ==
                            option.code,
                        onTap: () => onSelectCookingInstruction(option),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
