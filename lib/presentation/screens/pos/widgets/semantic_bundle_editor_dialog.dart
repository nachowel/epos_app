import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/breakfast_cart_selection.dart';
import '../../../../domain/models/breakfast_line_edit.dart';
import '../../../../domain/models/breakfast_rebuild.dart';
import '../../../../domain/models/product.dart';
import '../../../../domain/services/breakfast_pos_service.dart';

class SemanticBundleEditorDialog extends ConsumerStatefulWidget {
  const SemanticBundleEditorDialog({
    required this.product,
    this.initialRequestedState = const BreakfastRequestedState(),
    this.initialEditorData,
    super.key,
  });

  final Product product;
  final BreakfastRequestedState initialRequestedState;
  final BreakfastPosEditorData? initialEditorData;

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

  @override
  void initState() {
    super.initState();
    _requestedState = widget.initialRequestedState;
    if (widget.initialEditorData case final BreakfastPosEditorData editorData) {
      _editorData = editorData;
      _isLoading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final BreakfastPosEditorData editorData = await ref
          .read(breakfastPosServiceProvider)
          .loadEditorData(
            product: widget.product,
            requestedState: _requestedState,
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
    setState(() {
      _requestedState = nextState;
      _editorData = BreakfastPosEditorData(
        product: editorData.product,
        profile: editorData.profile,
        configuration: editorData.configuration,
        preview: preview,
      );
      _errorMessage = null;
    });
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
          padding: const EdgeInsets.all(AppSizes.spacingLg),
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
    final Map<int, int?> selectedChoices = <int, int?>{
      for (final BreakfastChosenGroupRequest group
          in _requestedState.chosenGroups)
        group.groupId: group.selectedItemProductId,
    };
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
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacingXs),
                  Text(
                    CurrencyFormatter.fromMinor(widget.product.priceMinor),
                    style: const TextStyle(
                      fontSize: AppSizes.fontMd,
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
        const SizedBox(height: AppSizes.spacingMd),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _section(
                  title: 'Included Items',
                  child: Column(
                    children: editorData.configuration.setItems
                        .map((BreakfastSetItemConfig item) {
                          final bool removable = item.isRemovable;
                          final bool checked =
                              (removedQuantities[item.itemProductId] ?? 0) == 0;
                          return CheckboxListTile(
                            key: ValueKey<String>(
                              'semantic-include-${item.itemProductId}',
                            ),
                            value: checked,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: removable
                                ? (bool? value) {
                                    _apply(
                                      BreakfastLineEdit.setRemovedQuantity(
                                        itemProductId: item.itemProductId,
                                        quantity: value == true
                                            ? 0
                                            : item.defaultQuantity,
                                      ),
                                    );
                                  }
                                : null,
                            title: Text(
                              item.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              removable
                                  ? 'Included x${item.defaultQuantity}'
                                  : 'Included x${item.defaultQuantity} · Locked',
                            ),
                            secondary: removable
                                ? null
                                : const Icon(Icons.lock_outline_rounded),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
                _section(
                  title: 'Required Choices',
                  child: Column(
                    children: editorData.configuration.choiceGroups
                        .map((BreakfastChoiceGroupConfig group) {
                          final int? selectedId =
                              selectedChoices[group.groupId];
                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: AppSizes.spacingMd,
                            ),
                            padding: const EdgeInsets.all(AppSizes.spacingMd),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  group.groupName,
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
                                const SizedBox(height: AppSizes.spacingSm),
                                ...group.members.map((
                                  BreakfastChoiceGroupMemberConfig member,
                                ) {
                                  return RadioListTile<int>(
                                    key: ValueKey<String>(
                                      'semantic-choice-select-${group.groupId}-${member.itemProductId}',
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    value: member.itemProductId,
                                    groupValue: selectedId,
                                    title: Text(member.displayName),
                                    onChanged: (int? value) {
                                      if (value == null) {
                                        return;
                                      }
                                      _apply(
                                        BreakfastLineEdit.chooseGroup(
                                          groupId: group.groupId,
                                          selectedItemProductId: value,
                                          quantity: 1,
                                        ),
                                      );
                                    },
                                  );
                                }),
                              ],
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
                _section(
                  title: 'Extras',
                  child: Column(
                    children: preview.addableProducts
                        .map((BreakfastPosAddableProduct product) {
                          final int quantity = addedQuantities[product.id] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSizes.spacingSm,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: AppSizes.spacingXs,
                                      ),
                                      Text(
                                        CurrencyFormatter.fromMinor(
                                          product.priceMinor,
                                        ),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _MiniStepper(
                                  decrementKey: ValueKey<String>(
                                    'semantic-add-dec-${product.id}',
                                  ),
                                  incrementKey: ValueKey<String>(
                                    'semantic-add-inc-${product.id}',
                                  ),
                                  quantity: quantity,
                                  canDecrease: quantity > 0,
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
                              ],
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
                _section(
                  title: 'Summary',
                  child: Column(
                    children: <Widget>[
                      _summaryLine(
                        'Set Total',
                        CurrencyFormatter.fromMinor(
                          preview.rebuildResult.lineSnapshot.baseUnitPriceMinor,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingSm),
                      _summaryLine(
                        'Extras',
                        CurrencyFormatter.fromMinor(
                          preview.rebuildResult.lineSnapshot.modifierTotalMinor,
                        ),
                      ),
                      const Divider(height: AppSizes.spacingLg),
                      _summaryLine(
                        'Total',
                        CurrencyFormatter.fromMinor(
                          preview.rebuildResult.lineSnapshot.lineTotalMinor,
                        ),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spacingMd),
        Row(
          children: <Widget>[
            Expanded(
              child: blockingMessage == null
                  ? const SizedBox.shrink()
                  : Text(
                      blockingMessage,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSizes.spacingSm),
            ElevatedButton(
              key: const ValueKey<String>('semantic-bundle-confirm'),
              onPressed: preview.canConfirm
                  ? () => Navigator.of(context).pop(preview.toCartSelection())
                  : null,
              child: const Text('Add to Order'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
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
            title,
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
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

  Widget _summaryLine(String label, String value, {bool emphasize = false}) {
    final TextStyle style = TextStyle(
      fontSize: emphasize ? AppSizes.fontMd : AppSizes.fontSm,
      fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
      color: AppColors.textPrimary,
    );
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
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
