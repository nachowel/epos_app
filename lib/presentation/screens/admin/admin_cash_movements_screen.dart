import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/cash_movement.dart';
import '../../providers/admin_cash_movements_provider.dart';
import 'widgets/admin_scaffold.dart';

const String _cashMovementsTitle = 'Cash Movements';
const String _cashMovementsInfo =
    'Manual cash movements are separate from product sales and affect cash position only.';
const String _createMovementTitle = 'Record Manual Movement';
const String _typeLabel = 'Type';
const String _categoryLabel = 'Category';
const String _amountLabel = 'Amount';
const String _amountHint = 'Enter amount in pounds, e.g. 12.50';
const String _paymentMethodLabel = 'Payment Method';
const String _noteLabel = 'Note (optional)';
const String _incomeLabel = 'Income';
const String _expenseLabel = 'Expense';
const String _otherLabel = 'Other';
const String _recordMovementLabel = 'Record Movement';
const String _activeShiftRequired =
    'An active shift is required before recording manual cash movements.';
const String _manualMovementCreated = 'Manual cash movement recorded.';
const String _noMovements =
    'No cash movements recorded for the active shift yet.';
const String _shiftLabel = 'Active Shift';
const String _paymentBadgePrefix = 'Method';
const String _amountInvalid = 'Enter a valid amount greater than zero.';

class AdminCashMovementsScreen extends ConsumerStatefulWidget {
  const AdminCashMovementsScreen({super.key});

  @override
  ConsumerState<AdminCashMovementsScreen> createState() =>
      _AdminCashMovementsScreenState();
}

class _AdminCashMovementsScreenState
    extends ConsumerState<AdminCashMovementsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  CashMovementType _type = CashMovementType.expense;
  CashMovementPaymentMethod _paymentMethod = CashMovementPaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    Future<void>.microtask(
      () => ref.read(adminCashMovementsNotifierProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminCashMovementsNotifierProvider);

    return AdminScaffold(
      title: _cashMovementsTitle,
      currentRoute: '/admin/cash-movements',
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(adminCashMovementsNotifierProvider.notifier).load(),
        child: ListView(
          children: <Widget>[
            if (state.errorMessage != null)
              _MessageBox(message: state.errorMessage!, color: AppColors.error),
            const _MessageBox(
              message: _cashMovementsInfo,
              color: AppColors.primary,
            ),
            _ShiftBanner(shiftId: state.activeShift?.id),
            const SizedBox(height: AppSizes.spacingMd),
            _buildFormCard(context, state),
            const SizedBox(height: AppSizes.spacingLg),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spacingXl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.movements.isEmpty)
              const _EmptyState(message: _noMovements)
            else
              ...state.movements.map(
                (CashMovement movement) => _MovementTile(movement: movement),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context, AdminCashMovementsState state) {
    final bool disabled = state.isSaving || state.activeShift == null;
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              _createMovementTitle,
              style: TextStyle(
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Wrap(
              spacing: AppSizes.spacingMd,
              runSpacing: AppSizes.spacingMd,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<CashMovementType>(
                    value: _type,
                    decoration: const InputDecoration(labelText: _typeLabel),
                    items: CashMovementType.values
                        .map(
                          (CashMovementType type) =>
                              DropdownMenuItem<CashMovementType>(
                                value: type,
                                child: Text(_typeText(type)),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: disabled
                        ? null
                        : (CashMovementType? value) {
                            if (value != null) {
                              setState(() => _type = value);
                            }
                          },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: _categoryLabel,
                    ),
                    enabled: !disabled,
                    validator: (String? value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Category is required.';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: _amountLabel,
                      hintText: _amountHint,
                    ),
                    enabled: !disabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (String? value) =>
                        parseCashMovementAmountMinor(value) == null
                        ? _amountInvalid
                        : null,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<CashMovementPaymentMethod>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: _paymentMethodLabel,
                    ),
                    items: CashMovementPaymentMethod.values
                        .map(
                          (CashMovementPaymentMethod method) =>
                              DropdownMenuItem<CashMovementPaymentMethod>(
                                value: method,
                                child: Text(_paymentMethodText(method)),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: disabled
                        ? null
                        : (CashMovementPaymentMethod? value) {
                            if (value != null) {
                              setState(() => _paymentMethod = value);
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: _noteLabel),
              enabled: !disabled,
              maxLines: 2,
            ),
            const SizedBox(height: AppSizes.spacingLg),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: disabled ? null : () => _submit(context),
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text(_recordMovementLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int? amountMinor = parseCashMovementAmountMinor(
      _amountController.text,
    );
    if (amountMinor == null) {
      return;
    }

    final bool success = await ref
        .read(adminCashMovementsNotifierProvider.notifier)
        .createCashMovement(
          type: _type,
          category: _categoryController.text,
          amountMinor: amountMinor,
          paymentMethod: _paymentMethod,
          note: _noteController.text,
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? _manualMovementCreated
              : (ref.read(adminCashMovementsNotifierProvider).errorMessage ??
                    AppStrings.operationFailed),
        ),
      ),
    );

    if (success) {
      _categoryController.clear();
      _amountController.clear();
      _noteController.clear();
      setState(() {
        _type = CashMovementType.expense;
        _paymentMethod = CashMovementPaymentMethod.cash;
      });
    }
  }

  String _typeText(CashMovementType type) {
    switch (type) {
      case CashMovementType.income:
        return _incomeLabel;
      case CashMovementType.expense:
        return _expenseLabel;
    }
  }

  String _paymentMethodText(CashMovementPaymentMethod paymentMethod) {
    switch (paymentMethod) {
      case CashMovementPaymentMethod.cash:
        return AppStrings.cash;
      case CashMovementPaymentMethod.card:
        return AppStrings.card;
      case CashMovementPaymentMethod.other:
        return _otherLabel;
    }
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final CashMovement movement;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = movement.type == CashMovementType.income;
    final Color accent = isIncome ? AppColors.success : AppColors.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(
            isIncome
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: accent,
          ),
        ),
        title: Text(
          movement.category,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${_typeTextStatic(movement.type)} · ${DateFormatter.formatDefault(movement.createdAt)}',
            ),
            const SizedBox(height: AppSizes.spacingXs),
            Wrap(
              spacing: AppSizes.spacingXs,
              runSpacing: AppSizes.spacingXs,
              children: <Widget>[
                _StatusChip(
                  label:
                      '$_paymentBadgePrefix: ${_paymentMethodTextStatic(movement.paymentMethod)}',
                  color: AppColors.primary,
                ),
                _StatusChip(
                  label: 'Actor #${movement.createdByUserId}',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            if (movement.note != null && movement.note!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSizes.spacingXs),
              Text(
                movement.note!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
        trailing: Text(
          CurrencyFormatter.fromMinor(movement.amountMinor),
          style: TextStyle(
            fontSize: AppSizes.fontMd,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class _ShiftBanner extends StatelessWidget {
  const _ShiftBanner({required this.shiftId});

  final int? shiftId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        shiftId == null ? _activeShiftRequired : '$_shiftLabel: #$shiftId',
        style: TextStyle(
          color: shiftId == null ? AppColors.warning : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

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
      child: Text(label, style: TextStyle(color: color)),
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

int? parseCashMovementAmountMinor(String? input) {
  final String normalized = (input ?? '').trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }

  final RegExpMatch? match = RegExp(
    r'^([0-9]+)(?:\.([0-9]{1,2}))?$',
  ).firstMatch(normalized);
  if (match == null) {
    return null;
  }

  final int? wholeUnits = int.tryParse(match.group(1)!);
  if (wholeUnits == null) {
    return null;
  }

  final String decimalGroup = match.group(2) ?? '';
  final String minorDigits = decimalGroup.padRight(2, '0');
  final int? minorUnits = int.tryParse(
    minorDigits.isEmpty ? '00' : minorDigits,
  );
  if (minorUnits == null) {
    return null;
  }

  final int amountMinor = (wholeUnits * 100) + minorUnits;
  return amountMinor > 0 ? amountMinor : null;
}

String _typeTextStatic(CashMovementType type) {
  switch (type) {
    case CashMovementType.income:
      return _incomeLabel;
    case CashMovementType.expense:
      return _expenseLabel;
  }
}

String _paymentMethodTextStatic(CashMovementPaymentMethod paymentMethod) {
  switch (paymentMethod) {
    case CashMovementPaymentMethod.cash:
      return AppStrings.cash;
    case CashMovementPaymentMethod.card:
      return AppStrings.card;
    case CashMovementPaymentMethod.other:
      return _otherLabel;
  }
}
