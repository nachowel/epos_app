import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class AdminSortModeList<T> extends StatelessWidget {
  const AdminSortModeList({
    super.key,
    required this.items,
    required this.isBusy,
    required this.emptyMessage,
    required this.listKey,
    required this.itemIdBuilder,
    required this.itemContentBuilder,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMoveToTop,
    required this.onMoveToBottom,
  });

  final List<T> items;
  final bool isBusy;
  final String emptyMessage;
  final Key listKey;
  final Object Function(T item) itemIdBuilder;
  final Widget Function(BuildContext context, T item, int index)
  itemContentBuilder;
  final void Function(int index) onMoveUp;
  final void Function(int index) onMoveDown;
  final void Function(int index) onMoveToTop;
  final void Function(int index) onMoveToBottom;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _SortModeEmptyState(message: emptyMessage);
    }

    return ListView.separated(
      key: listKey,
      padding: const EdgeInsets.only(bottom: AppSizes.spacingLg),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.spacingSm),
      itemBuilder: (BuildContext context, int index) {
        final T item = items[index];
        final Object itemId = itemIdBuilder(item);
        return DecoratedBox(
          key: ValueKey<String>('sort-mode-row-$itemId'),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spacingMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: itemContentBuilder(context, item, index)),
                const SizedBox(width: AppSizes.spacingMd),
                AdminSortMoveControls(
                  itemId: '$itemId',
                  index: index,
                  itemCount: items.length,
                  isBusy: isBusy,
                  onMoveUp: () => onMoveUp(index),
                  onMoveDown: () => onMoveDown(index),
                  onMoveToTop: () => onMoveToTop(index),
                  onMoveToBottom: () => onMoveToBottom(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdminSortMoveControls extends StatelessWidget {
  const AdminSortMoveControls({
    super.key,
    required this.itemId,
    required this.index,
    required this.itemCount,
    required this.isBusy,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMoveToTop,
    required this.onMoveToBottom,
  });

  final String itemId;
  final int index;
  final int itemCount;
  final bool isBusy;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveToTop;
  final VoidCallback onMoveToBottom;

  @override
  Widget build(BuildContext context) {
    final bool isFirst = index == 0;
    final bool isLast = index == itemCount - 1;

    return Wrap(
      spacing: AppSizes.spacingXs,
      runSpacing: AppSizes.spacingXs,
      alignment: WrapAlignment.end,
      children: <Widget>[
        OutlinedButton(
          key: ValueKey<String>('sort-move-top-$itemId'),
          onPressed: isBusy || isFirst ? null : onMoveToTop,
          child: const Text('Başa al'),
        ),
        OutlinedButton(
          key: ValueKey<String>('sort-move-up-$itemId'),
          onPressed: isBusy || isFirst ? null : onMoveUp,
          child: const Text('Yukarı'),
        ),
        OutlinedButton(
          key: ValueKey<String>('sort-move-down-$itemId'),
          onPressed: isBusy || isLast ? null : onMoveDown,
          child: const Text('Aşağı'),
        ),
        OutlinedButton(
          key: ValueKey<String>('sort-move-bottom-$itemId'),
          onPressed: isBusy || isLast ? null : onMoveToBottom,
          child: const Text('Sona al'),
        ),
      ],
    );
  }
}

class _SortModeEmptyState extends StatelessWidget {
  const _SortModeEmptyState({required this.message});

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
