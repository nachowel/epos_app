import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/admin_breakfast_sets_provider.dart';
import 'widgets/admin_scaffold.dart';

const String _screenTitle = 'Breakfast Set Configuration';
const String _screenRoute = '/admin/breakfast-sets';
const String _screenInfoMessage =
    'Review breakfast set roots here before wiring the dedicated editor. This screen uses live repository data and shows whether each set is ready, incomplete, or invalid.';
const String _deleteStubMessage =
    'Breakfast set delete flow is not available yet.';
const String _createSuccessMessage =
    'Breakfast set created. Configure included items and choices.';

class AdminBreakfastSetsScreen extends ConsumerStatefulWidget {
  const AdminBreakfastSetsScreen({super.key});

  @override
  ConsumerState<AdminBreakfastSetsScreen> createState() =>
      _AdminBreakfastSetsScreenState();
}

class _AdminBreakfastSetsScreenState
    extends ConsumerState<AdminBreakfastSetsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminBreakfastSetsNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminBreakfastSetsState state = ref.watch(
      adminBreakfastSetsNotifierProvider,
    );

    return AdminScaffold(
      title: _screenTitle,
      currentRoute: _screenRoute,
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _screenTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSizes.spacingXs),
                    const Text(
                      'Set Breakfast category products only.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spacingMd),
              ElevatedButton.icon(
                key: const ValueKey<String>('breakfast-set-new'),
                onPressed:
                    state.hasBreakfastCategory &&
                        !state.isLoading &&
                        !state.isCreating
                    ? _openCreateSetDialog
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Set'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(adminBreakfastSetsNotifierProvider.notifier).load(),
              child: ListView(
                children: <Widget>[
                  if (state.errorMessage != null)
                    _MessageBox(
                      message: state.errorMessage!,
                      color: AppColors.error,
                    ),
                  const _MessageBox(
                    message: _screenInfoMessage,
                    color: AppColors.primary,
                  ),
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(AppSizes.spacingXl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!state.hasBreakfastCategory)
                    const _EmptyState(
                      message:
                          'No `Set Breakfast` category exists yet. Breakfast set roots will appear here once that category is available.',
                    )
                  else if (state.items.isEmpty)
                    const _EmptyState(
                      message:
                          'No breakfast set-root products found in `Set Breakfast` yet.',
                    )
                  else
                    ...state.items.map(
                      (AdminBreakfastSetListItem item) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSizes.spacingMd,
                        ),
                        child: _BreakfastSetCard(
                          item: item,
                          onEdit: () => context.go(
                            '/admin/breakfast-sets/${item.product.id}',
                          ),
                          onDelete: () => _showStubMessage(_deleteStubMessage),
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

  void _showStubMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreateSetDialog() async {
    final _CreateBreakfastSetFormResult? result =
        await showDialog<_CreateBreakfastSetFormResult>(
          context: context,
          builder: (BuildContext context) => const _CreateBreakfastSetDialog(),
        );
    if (result == null) {
      return;
    }

    final int? productId = await ref
        .read(adminBreakfastSetsNotifierProvider.notifier)
        .createBreakfastSetRoot(
          name: result.name,
          priceMinor: result.priceMinor,
          isActive: result.isActive,
          isVisibleOnPos: result.isVisibleOnPos,
        );
    if (!mounted) {
      return;
    }

    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(adminBreakfastSetsNotifierProvider).errorMessage ??
                'Failed to create breakfast set.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_createSuccessMessage)));
    context.go('/admin/breakfast-sets/$productId');
  }
}

class _BreakfastSetCard extends StatelessWidget {
  const _BreakfastSetCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminBreakfastSetListItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey<String>('breakfast-set-card-${item.product.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingLg),
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
                        item.product.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingXs),
                      Text(
                        item.categoryName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spacingMd),
                Wrap(
                  spacing: AppSizes.spacingSm,
                  runSpacing: AppSizes.spacingSm,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    _ValidationBadge(state: item.validationState),
                    if (!item.product.isActive)
                      const _InfoBadge(
                        label: 'Archived',
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Wrap(
              spacing: AppSizes.spacingMd,
              runSpacing: AppSizes.spacingMd,
              children: <Widget>[
                _SummaryStat(label: 'Category', value: item.categoryName),
                _SummaryStat(
                  label: 'Included Units',
                  value: '${item.includedUnitCount}',
                ),
                _SummaryStat(
                  label: 'Choice Groups',
                  value: '${item.profile.choiceGroupCount}',
                ),
                _SummaryStat(
                  label: 'Validation',
                  value: item.validationSummary,
                  wide: true,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingLg),
            Wrap(
              spacing: AppSizes.spacingSm,
              runSpacing: AppSizes.spacingSm,
              children: <Widget>[
                OutlinedButton(
                  key: ValueKey<String>(
                    'breakfast-set-edit-${item.product.id}',
                  ),
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
                TextButton(
                  key: ValueKey<String>(
                    'breakfast-set-delete-${item.product.id}',
                  ),
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationBadge extends StatelessWidget {
  const _ValidationBadge({required this.state});

  final BreakfastSetValidationState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case BreakfastSetValidationState.valid:
        return const _InfoBadge(label: 'Valid', color: AppColors.success);
      case BreakfastSetValidationState.incomplete:
        return const _InfoBadge(label: 'Incomplete', color: AppColors.warning);
      case BreakfastSetValidationState.invalid:
        return const _InfoBadge(label: 'Invalid', color: AppColors.error);
    }
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, required this.color});

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

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: wide ? 280 : 140),
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

class _CreateBreakfastSetDialog extends StatefulWidget {
  const _CreateBreakfastSetDialog();

  @override
  State<_CreateBreakfastSetDialog> createState() =>
      _CreateBreakfastSetDialogState();
}

class _CreateBreakfastSetDialogState extends State<_CreateBreakfastSetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  bool _isActive = true;
  bool _isVisibleOnPos = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _priceController = TextEditingController(
      text: CurrencyFormatter.toEditableMajorInput(0),
    );
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
      title: const Text('Create Breakfast Set'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                key: const ValueKey<String>('breakfast-set-create-name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Set Name'),
                textInputAction: TextInputAction.next,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Set name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.spacingMd),
              TextFormField(
                key: const ValueKey<String>('breakfast-set-create-price'),
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Base Price',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Base price is required.';
                  }
                  final int? priceMinor =
                      CurrencyFormatter.tryParseEditableMajorInput(value);
                  if (priceMinor == null) {
                    return 'Enter a valid base price.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.spacingMd),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (bool value) => setState(() => _isActive = value),
                title: const Text('Active'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isVisibleOnPos,
                onChanged: (bool value) =>
                    setState(() => _isVisibleOnPos = value),
                title: const Text('Visible on POS'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey<String>('breakfast-set-create-submit'),
          onPressed: _submit,
          child: const Text('Create Set'),
        ),
      ],
    );
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final int? priceMinor = CurrencyFormatter.tryParseEditableMajorInput(
      _priceController.text,
    );
    if (priceMinor == null) {
      return;
    }

    Navigator.of(context).pop(
      _CreateBreakfastSetFormResult(
        name: _nameController.text.trim(),
        priceMinor: priceMinor,
        isActive: _isActive,
        isVisibleOnPos: _isVisibleOnPos,
      ),
    );
  }
}

class _CreateBreakfastSetFormResult {
  const _CreateBreakfastSetFormResult({
    required this.name,
    required this.priceMinor,
    required this.isActive,
    required this.isVisibleOnPos,
  });

  final String name;
  final int priceMinor;
  final bool isActive;
  final bool isVisibleOnPos;
}
