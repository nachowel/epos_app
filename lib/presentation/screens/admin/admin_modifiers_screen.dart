import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_modifier.dart';
import '../../providers/admin_modifiers_provider.dart';
import 'widgets/admin_scaffold.dart';

const String _flatModifiersOnlyBanner =
    'This screen manages legacy flat modifiers (included/extra). Set products are configured via Set Builder on the Products screen.';
const String _semanticProductSelectedWarning =
    'This product is configured as a set product. Manage its items and choices through the Set Builder on the Products screen instead.';

class AdminModifiersScreen extends ConsumerStatefulWidget {
  const AdminModifiersScreen({super.key});

  @override
  ConsumerState<AdminModifiersScreen> createState() =>
      _AdminModifiersScreenState();
}

class _AdminModifiersScreenState extends ConsumerState<AdminModifiersScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminModifiersNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminModifiersNotifierProvider);

    return AdminScaffold(
      title: AppStrings.modifierManagementTitle,
      currentRoute: '/admin/modifiers',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: state.selectedProductId,
                  decoration: InputDecoration(
                    labelText: AppStrings.productLabel,
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  items: state.products
                      .map(
                        (Product product) => DropdownMenuItem<int?>(
                          value: product.id,
                          child: Text(product.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: state.isLoading
                      ? null
                      : (int? value) {
                          ref
                              .read(adminModifiersNotifierProvider.notifier)
                              .selectProduct(value);
                        },
                ),
              ),
              const SizedBox(width: AppSizes.spacingMd),
              ElevatedButton.icon(
                onPressed: state.selectedProductId == null || state.isSaving
                    ? null
                    : () => _openModifierDialog(
                        context,
                        productId: state.selectedProductId!,
                      ),
                icon: const Icon(Icons.add_rounded),
                label: Text(AppStrings.addModifier),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(adminModifiersNotifierProvider.notifier).load(),
              child: ListView(
                children: <Widget>[
                  if (state.errorMessage != null)
                    _MessageBox(
                      message: state.errorMessage!,
                      color: AppColors.error,
                    ),
                  const _MessageBox(
                    message: _flatModifiersOnlyBanner,
                    color: AppColors.primary,
                  ),
                  if (state.modifiers.any(
                    (ProductModifier m) => m.type == ModifierType.choice,
                  ))
                    const _MessageBox(
                      message: _semanticProductSelectedWarning,
                      color: AppColors.warning,
                    ),
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppSizes.spacingXl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.modifiers.isEmpty)
                    _EmptyState(message: AppStrings.noModifiersForProduct)
                  else
                    ...state.modifiers.map(
                      (ProductModifier modifier) => _ModifierTile(
                        modifier: modifier,
                        isSaving: state.isSaving,
                        onEdit: () => _openModifierDialog(
                          context,
                          productId: modifier.productId,
                          modifier: modifier,
                        ),
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

  Future<void> _openModifierDialog(
    BuildContext context, {
    required int productId,
    ProductModifier? modifier,
  }) async {
    final _ModifierFormResult? result = await showDialog<_ModifierFormResult>(
      context: context,
      builder: (BuildContext context) =>
          _ModifierDialog(productId: productId, modifier: modifier),
    );
    if (result == null) {
      return;
    }

    final notifier = ref.read(adminModifiersNotifierProvider.notifier);
    final bool success = modifier == null
        ? await notifier.createModifier(
            productId: productId,
            name: result.name,
            type: result.type,
            extraPriceMinor: result.extraPriceMinor,
            isActive: result.isActive,
          )
        : await notifier.updateModifier(
            id: modifier.id,
            productId: productId,
            name: result.name,
            type: result.type,
            extraPriceMinor: result.extraPriceMinor,
            isActive: result.isActive,
          );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (modifier == null
                    ? AppStrings.modifierCreated
                    : AppStrings.modifierUpdated)
              : (ref.read(adminModifiersNotifierProvider).errorMessage ??
                    AppStrings.operationFailed),
        ),
      ),
    );
  }
}

class _ModifierTile extends ConsumerWidget {
  const _ModifierTile({
    required this.modifier,
    required this.isSaving,
    required this.onEdit,
  });

  final ProductModifier modifier;
  final bool isSaving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: ListTile(
        title: Text(
          modifier.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_labelForType(modifier.type)} · ${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}',
        ),
        trailing: Wrap(
          spacing: AppSizes.spacingSm,
          children: <Widget>[
            Switch(
              value: modifier.isActive,
              onChanged: isSaving
                  ? null
                  : (bool value) {
                      ref
                          .read(adminModifiersNotifierProvider.notifier)
                          .toggleModifierActive(
                            id: modifier.id,
                            isActive: value,
                          );
                    },
            ),
            OutlinedButton(
              onPressed: isSaving || !modifier.isLegacyFlat ? null : onEdit,
              child: Text(AppStrings.edit),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModifierDialog extends StatefulWidget {
  const _ModifierDialog({required this.productId, this.modifier});

  final int productId;
  final ProductModifier? modifier;

  @override
  State<_ModifierDialog> createState() => _ModifierDialogState();
}

class _ModifierDialogState extends State<_ModifierDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late ModifierType _type;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.modifier?.name ?? '');
    _priceController = TextEditingController(
      text: '${widget.modifier?.extraPriceMinor ?? 0}',
    );
    _type = widget.modifier?.type ?? ModifierType.included;
    _isActive = widget.modifier?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.modifier == null
            ? AppStrings.addModifierDialogTitle
            : AppStrings.editModifierDialogTitle,
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppStrings.modifierNameLabel,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            DropdownButtonFormField<ModifierType>(
              value: _type,
              decoration: InputDecoration(labelText: AppStrings.typeLabel),
              items: ProductModifier.legacyFlatTypes
                  .map(
                    (ModifierType type) => DropdownMenuItem<ModifierType>(
                      value: type,
                      child: Text(_labelForType(type)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (ModifierType? value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              controller: _priceController,
              enabled: _type == ModifierType.extra,
              decoration: InputDecoration(
                labelText: AppStrings.extraPriceMinorLabel,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (bool value) => setState(() => _isActive = value),
              title: Text(AppStrings.active),
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
              _ModifierFormResult(
                name: _nameController.text,
                type: _type,
                extraPriceMinor: _type == ModifierType.extra
                    ? int.tryParse(_priceController.text) ?? -1
                    : 0,
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

String _labelForType(ModifierType type) {
  switch (type) {
    case ModifierType.included:
      return AppStrings.includedModifiers;
    case ModifierType.extra:
      return AppStrings.extraModifiers;
    case ModifierType.choice:
      return 'Set Choice (use Set Builder)';
  }
}

class _ModifierFormResult {
  const _ModifierFormResult({
    required this.name,
    required this.type,
    required this.extraPriceMinor,
    required this.isActive,
  });

  final String name;
  final ModifierType type;
  final int extraPriceMinor;
  final bool isActive;
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
