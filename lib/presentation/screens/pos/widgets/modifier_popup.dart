import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/order_modifier.dart';
import '../../../../domain/models/product_modifier.dart';
import '../../../providers/cart_models.dart';
import '../../../providers/pos_interaction_provider.dart';

class ModifierPopup extends ConsumerStatefulWidget {
  const ModifierPopup({
    required this.productId,
    required this.productName,
    super.key,
  });

  final int productId;
  final String productName;

  @override
  ConsumerState<ModifierPopup> createState() => _ModifierPopupState();
}

class _ModifierPopupState extends ConsumerState<ModifierPopup> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ProductModifier> _included = const <ProductModifier>[];
  List<ProductModifier> _extras = const <ProductModifier>[];
  final Map<int, bool> _includedChecked = <int, bool>{};
  final Map<int, int> _extraCounts = <int, int>{};

  @override
  void initState() {
    super.initState();
    _loadModifiers();
  }

  Future<void> _loadModifiers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<ProductModifier> modifiers = await ref
          .read(catalogServiceProvider)
          .getProductModifiers(widget.productId);
      final List<ProductModifier> included = modifiers
          .where((ProductModifier m) => m.type == ModifierType.included)
          .toList(growable: false);
      final List<ProductModifier> extras = modifiers
          .where((ProductModifier m) => m.type == ModifierType.extra)
          .toList(growable: false);

      _includedChecked
        ..clear()
        ..addEntries(
          included.map((ProductModifier m) => MapEntry<int, bool>(m.id, true)),
        );
      _extraCounts
        ..clear()
        ..addEntries(
          extras.map((ProductModifier m) => MapEntry<int, int>(m.id, 0)),
        );

      setState(() {
        _included = included;
        _extras = extras;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = AppStrings.modifierLoadFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final interactionPolicy = ref.watch(posInteractionProvider);
    final bool isBlocked = !interactionPolicy.canOpenModifierDialog;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        '${AppStrings.modifierDialogTitle}: ${widget.productName}',
        style: const TextStyle(fontSize: AppSizes.fontMd),
      ),
      content: SizedBox(width: 520, child: _buildContent(isBlocked)),
      actions: <Widget>[
        SizedBox(
          height: AppSizes.minTouch,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppStrings.cancel,
              style: const TextStyle(fontSize: AppSizes.fontSm),
            ),
          ),
        ),
        SizedBox(
          height: AppSizes.minTouch,
          child: ElevatedButton(
            onPressed: _isLoading || isBlocked ? null : _submit,
            child: Text(
              AppStrings.addToCart,
              style: const TextStyle(fontSize: AppSizes.fontSm),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(bool isBlocked) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        style: const TextStyle(
          fontSize: AppSizes.fontSm,
          color: AppColors.error,
        ),
      );
    }

    if (_included.isEmpty && _extras.isEmpty) {
      return Text(
        AppStrings.modifierNotFound,
        style: const TextStyle(
          fontSize: AppSizes.fontSm,
          color: AppColors.textSecondary,
        ),
      );
    }

    return IgnorePointer(
      ignoring: isBlocked,
      child: Opacity(
        opacity: isBlocked ? 0.5 : 1,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (isBlocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                  child: Text(
                    ref.watch(posInteractionProvider).lockMessage ??
                        AppStrings.salesLockedAdminCloseRequired,
                    style: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_included.isNotEmpty) ...<Widget>[
                Text(
                  AppStrings.includedModifiers,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                ..._included.map(
                  (ProductModifier modifier) => CheckboxListTile(
                    value: _includedChecked[modifier.id] ?? true,
                    title: Text(
                      modifier.name,
                      style: const TextStyle(fontSize: AppSizes.fontSm),
                    ),
                    onChanged: (bool? checked) {
                      setState(() {
                        _includedChecked[modifier.id] = checked ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
              ],
              if (_extras.isNotEmpty) ...<Widget>[
                Text(
                  AppStrings.extraModifiers,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                ..._extras.map((ProductModifier modifier) {
                  final int count = _extraCounts[modifier.id] ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      modifier.name,
                      style: const TextStyle(fontSize: AppSizes.fontSm),
                    ),
                    subtitle: Text(
                      CurrencyFormatter.fromMinor(modifier.extraPriceMinor),
                      style: const TextStyle(fontSize: AppSizes.fontSm),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          onPressed: count <= 0
                              ? null
                              : () {
                                  setState(() {
                                    _extraCounts[modifier.id] = count - 1;
                                  });
                                },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: AppSizes.fontSm,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _extraCounts[modifier.id] = count + 1;
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final List<CartModifier> selected = <CartModifier>[];

    for (final ProductModifier modifier in _included) {
      final bool isChecked = _includedChecked[modifier.id] ?? true;
      if (!isChecked) {
        selected.add(
          CartModifier(
            action: ModifierAction.remove,
            itemName: modifier.name,
            extraPriceMinor: 0,
          ),
        );
      }
    }

    for (final ProductModifier modifier in _extras) {
      final int count = _extraCounts[modifier.id] ?? 0;
      for (int i = 0; i < count; i++) {
        selected.add(
          CartModifier(
            action: ModifierAction.add,
            itemName: modifier.name,
            extraPriceMinor: modifier.extraPriceMinor,
          ),
        );
      }
    }

    Navigator.of(context).pop(selected);
  }
}
