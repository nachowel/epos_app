import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/breakfast_line_edit.dart';
import '../../../../domain/models/breakfast_rebuild.dart';
import '../../../providers/orders_provider.dart';
import 'order_modifier_presentation.dart';

class BreakfastModifierPopup extends ConsumerStatefulWidget {
  const BreakfastModifierPopup({
    required this.transactionId,
    required this.initialData,
    super.key,
  });

  final int transactionId;
  final BreakfastEditorData initialData;

  @override
  ConsumerState<BreakfastModifierPopup> createState() =>
      _BreakfastModifierPopupState();
}

class _BreakfastModifierPopupState
    extends ConsumerState<BreakfastModifierPopup> {
  late BreakfastEditorData _session;
  bool _isSubmitting = false;
  bool _didChange = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _session = widget.initialData;
  }

  Future<void> _applyEdit(BreakfastLineEdit edit) async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final BreakfastEditorData? updated = await ref
        .read(ordersNotifierProvider.notifier)
        .editBreakfastLine(
          transactionId: widget.transactionId,
          transactionLineId: _session.line.id,
          edit: edit,
          expectedTransactionUpdatedAt: _session.transaction.updatedAt,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      if (updated == null) {
        _errorMessage =
            ref.read(ordersNotifierProvider).errorMessage ??
            AppStrings.operationFailed;
        return;
      }
      _session = updated;
      _didChange = true;
    });
  }

  void _close() {
    Navigator.of(context).pop(_didChange);
  }

  @override
  Widget build(BuildContext context) {
    final Map<int, int> removedQuantities = <int, int>{
      for (final BreakfastRemovedSetItemRequest item
          in _session.requestedState.removedSetItems)
        item.itemProductId: item.quantity,
    };
    final Map<int, int> addedQuantities = <int, int>{
      for (final BreakfastAddedProductRequest item
          in _session.requestedState.addedProducts)
        item.itemProductId: item.quantity,
    };
    final Map<int, BreakfastChosenGroupRequest> chosenGroups =
        <int, BreakfastChosenGroupRequest>{
          for (final BreakfastChosenGroupRequest group
              in _session.requestedState.chosenGroups)
            group.groupId: group,
        };

    return Dialog(
      key: const ValueKey<String>('breakfast-popup'),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(AppSizes.spacingMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Edit Breakfast',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _session.line.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('breakfast-close'),
                    onPressed: _isSubmitting ? null : _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingSm),
              Wrap(
                spacing: AppSizes.spacingSm,
                runSpacing: AppSizes.spacingSm,
                children: <Widget>[
                  _SummaryPill(
                    label: 'Line Total',
                    value: CurrencyFormatter.fromMinor(
                      _session.line.lineTotalMinor,
                    ),
                    valueKey: const ValueKey<String>('breakfast-line-total'),
                  ),
                  _SummaryPill(
                    label: 'Order Total',
                    value: CurrencyFormatter.fromMinor(
                      _session.transaction.totalAmountMinor,
                    ),
                    valueKey: const ValueKey<String>('breakfast-order-total'),
                  ),
                ],
              ),
              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: AppSizes.spacingSm),
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacingSm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.spacingMd),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _EditorSection(
                        title: 'Set Items',
                        child: Column(
                          children: _session.configuration.setItems
                              .map((BreakfastSetItemConfig item) {
                                final int removedQuantity =
                                    removedQuantities[item.itemProductId] ?? 0;
                                return _AdjustableRow(
                                  label: item.itemName,
                                  subtitle:
                                      'Removed $removedQuantity of ${item.defaultQuantity}',
                                  quantity: removedQuantity,
                                  canDecrease:
                                      !_isSubmitting && removedQuantity > 0,
                                  canIncrease:
                                      !_isSubmitting &&
                                      removedQuantity < item.defaultQuantity,
                                  decrementKey: ValueKey<String>(
                                    'breakfast-remove-dec-${item.itemProductId}',
                                  ),
                                  incrementKey: ValueKey<String>(
                                    'breakfast-remove-inc-${item.itemProductId}',
                                  ),
                                  onDecrease: () {
                                    _applyEdit(
                                      BreakfastLineEdit.setRemovedQuantity(
                                        itemProductId: item.itemProductId,
                                        quantity: removedQuantity - 1,
                                      ),
                                    );
                                  },
                                  onIncrease: () {
                                    _applyEdit(
                                      BreakfastLineEdit.setRemovedQuantity(
                                        itemProductId: item.itemProductId,
                                        quantity: removedQuantity + 1,
                                      ),
                                    );
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingMd),
                      _EditorSection(
                        title: 'Choices',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _session.configuration.choiceGroups
                              .map((BreakfastChoiceGroupConfig group) {
                                final BreakfastChosenGroupRequest?
                                currentChoice = chosenGroups[group.groupId];
                                final bool isExplicitNone =
                                    currentChoice?.isExplicitNone ?? false;
                                final bool supportsExplicitNone =
                                    group.allowsExplicitNoneSelection;
                                final int groupQuantity =
                                    currentChoice?.requestedQuantity ?? 0;
                                final int? selectedProductId =
                                    currentChoice?.selectedItemProductId;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSizes.spacingMd,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        group.groupName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: <Widget>[
                                          if (supportsExplicitNone)
                                            ChoiceChip(
                                              key: ValueKey<String>(
                                                'breakfast-choice-none-${group.groupId}',
                                              ),
                                              label: Text(
                                                group.explicitNoneDisplayLabel,
                                              ),
                                              selected: isExplicitNone,
                                              onSelected: _isSubmitting
                                                  ? null
                                                  : (_) {
                                                      _applyEdit(
                                                        BreakfastLineEdit.chooseGroup(
                                                          groupId:
                                                              group.groupId,
                                                          selectedItemProductId:
                                                              null,
                                                          quantity: 1,
                                                        ),
                                                      );
                                                    },
                                            ),
                                          ...group.members.map((
                                            BreakfastChoiceGroupMemberConfig
                                            member,
                                          ) {
                                            final bool isSelected =
                                                selectedProductId ==
                                                member.itemProductId;
                                            return ChoiceChip(
                                              key: ValueKey<String>(
                                                'breakfast-choice-select-${group.groupId}-${member.itemProductId}',
                                              ),
                                              label: Text(member.displayName),
                                              selected: isSelected,
                                              onSelected: _isSubmitting
                                                  ? null
                                                  : (_) {
                                                      final int nextQuantity =
                                                          groupQuantity > 0 &&
                                                              !isExplicitNone
                                                          ? groupQuantity
                                                          : group
                                                                .includedQuantity;
                                                      _applyEdit(
                                                        BreakfastLineEdit.chooseGroup(
                                                          groupId:
                                                              group.groupId,
                                                          selectedItemProductId:
                                                              member
                                                                  .itemProductId,
                                                          quantity:
                                                              nextQuantity,
                                                        ),
                                                      );
                                                    },
                                            );
                                          }),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              isExplicitNone
                                                  ? '${group.explicitNoneDisplayLabel} selected'
                                                  : selectedProductId == null
                                                  ? 'No selection'
                                                  : 'Qty $groupQuantity',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            key: ValueKey<String>(
                                              'breakfast-choice-clear-${group.groupId}',
                                            ),
                                            onPressed:
                                                _isSubmitting ||
                                                    selectedProductId == null ||
                                                    group.minSelect > 0
                                                ? null
                                                : () {
                                                    _applyEdit(
                                                      BreakfastLineEdit.clearGroup(
                                                        groupId: group.groupId,
                                                      ),
                                                    );
                                                  },
                                            child: const Text('Clear'),
                                          ),
                                          const SizedBox(width: 8),
                                          _MiniStepper(
                                            quantity: groupQuantity,
                                            canDecrease:
                                                !_isSubmitting &&
                                                selectedProductId != null &&
                                                !isExplicitNone &&
                                                (group.minSelect > 0
                                                    ? groupQuantity >
                                                          group.minSelect
                                                    : groupQuantity > 0),
                                            canIncrease:
                                                !_isSubmitting &&
                                                selectedProductId != null &&
                                                !(group.minSelect > 0 &&
                                                    group.maxSelect == 1),
                                            decrementKey: ValueKey<String>(
                                              'breakfast-choice-dec-${group.groupId}',
                                            ),
                                            incrementKey: ValueKey<String>(
                                              'breakfast-choice-inc-${group.groupId}',
                                            ),
                                            onDecrease: () {
                                              if (selectedProductId == null) {
                                                return;
                                              }
                                              final int nextQuantity =
                                                  groupQuantity - 1;
                                              if (nextQuantity <= 0) {
                                                _applyEdit(
                                                  BreakfastLineEdit.clearGroup(
                                                    groupId: group.groupId,
                                                  ),
                                                );
                                                return;
                                              }
                                              _applyEdit(
                                                BreakfastLineEdit.chooseGroup(
                                                  groupId: group.groupId,
                                                  selectedItemProductId:
                                                      selectedProductId,
                                                  quantity: nextQuantity,
                                                ),
                                              );
                                            },
                                            onIncrease: () {
                                              if (selectedProductId == null) {
                                                return;
                                              }
                                              _applyEdit(
                                                BreakfastLineEdit.chooseGroup(
                                                  groupId: group.groupId,
                                                  selectedItemProductId:
                                                      selectedProductId,
                                                  quantity: groupQuantity + 1,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingMd),
                      _EditorSection(
                        title: 'Extras',
                        child: Column(
                          children: _session.addableProducts
                              .map((BreakfastAddableProduct product) {
                                final int addedQuantity =
                                    addedQuantities[product.id] ?? 0;
                                return _AdjustableRow(
                                  label: product.name,
                                  subtitle:
                                      '${CurrencyFormatter.fromMinor(product.priceMinor)} • Extra charge applies',
                                  quantity: addedQuantity,
                                  canDecrease:
                                      !_isSubmitting && addedQuantity > 0,
                                  canIncrease: !_isSubmitting,
                                  decrementKey: ValueKey<String>(
                                    'breakfast-add-dec-${product.id}',
                                  ),
                                  incrementKey: ValueKey<String>(
                                    'breakfast-add-inc-${product.id}',
                                  ),
                                  onDecrease: () {
                                    _applyEdit(
                                      BreakfastLineEdit.setAddedQuantity(
                                        itemProductId: product.id,
                                        quantity: addedQuantity - 1,
                                      ),
                                    );
                                  },
                                  onIncrease: () {
                                    _applyEdit(
                                      BreakfastLineEdit.setAddedQuantity(
                                        itemProductId: product.id,
                                        quantity: addedQuantity + 1,
                                      ),
                                    );
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingMd),
                      _EditorSection(
                        title: 'Current Snapshot',
                        child: _session.modifiers.isEmpty
                            ? const Text(
                                'No customizations yet.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : Column(
                                key: const ValueKey<String>(
                                  'breakfast-snapshot',
                                ),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _session.modifiers
                                    .map((modifier) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          formatOrderModifierLabel(modifier),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
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
              const SizedBox(height: AppSizes.spacingMd),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _close,
                  child: Text(AppStrings.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            key: valueKey,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          child,
        ],
      ),
    );
  }
}

class _AdjustableRow extends StatelessWidget {
  const _AdjustableRow({
    required this.label,
    required this.subtitle,
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.decrementKey,
    required this.incrementKey,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String subtitle;
  final int quantity;
  final bool canDecrease;
  final bool canIncrease;
  final Key decrementKey;
  final Key incrementKey;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _MiniStepper(
            quantity: quantity,
            canDecrease: canDecrease,
            canIncrease: canIncrease,
            decrementKey: decrementKey,
            incrementKey: incrementKey,
            onDecrease: onDecrease,
            onIncrease: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.decrementKey,
    required this.incrementKey,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool canDecrease;
  final bool canIncrease;
  final Key decrementKey;
  final Key incrementKey;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepperButton(
          key: decrementKey,
          icon: Icons.remove,
          onPressed: canDecrease ? onDecrease : null,
        ),
        Container(
          width: 44,
          alignment: Alignment.center,
          child: Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        _StepperButton(
          key: incrementKey,
          icon: Icons.add,
          onPressed: canIncrease ? onIncrease : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
