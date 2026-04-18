import '../../core/errors/exceptions.dart';
import 'transaction.dart';

class TransactionDiscountInput {
  const TransactionDiscountInput({
    required this.type,
    required this.valueMinor,
    this.reason,
  });

  final TransactionDiscountType type;
  final int valueMinor;
  final String? reason;

  TransactionDiscountInput copyWith({
    TransactionDiscountType? type,
    int? valueMinor,
    Object? reason = _unsetDiscountReason,
  }) {
    return TransactionDiscountInput(
      type: type ?? this.type,
      valueMinor: valueMinor ?? this.valueMinor,
      reason: identical(reason, _unsetDiscountReason)
          ? this.reason
          : reason as String?,
    );
  }

  void validate() {
    if (valueMinor < 0) {
      throw ValidationException('Discount value cannot be negative.');
    }
    if (type == TransactionDiscountType.percent && valueMinor > 100) {
      throw ValidationException('Percent discount must be between 0 and 100.');
    }
  }
}

class TransactionDiscountComputation {
  const TransactionDiscountComputation({
    required this.preDiscountTotalMinor,
    required this.discountAmountMinor,
    required this.totalAmountMinor,
  });

  final int preDiscountTotalMinor;
  final int discountAmountMinor;
  final int totalAmountMinor;
}

class TransactionDiscountMath {
  const TransactionDiscountMath._();

  static TransactionDiscountComputation compute({
    required int subtotalMinor,
    required int modifierTotalMinor,
    required TransactionDiscountType? discountType,
    required int discountValueMinor,
  }) {
    if (subtotalMinor < 0) {
      throw ValidationException('Subtotal cannot be negative.');
    }
    final int preDiscountTotalMinor = subtotalMinor + modifierTotalMinor;
    if (preDiscountTotalMinor < 0) {
      throw ValidationException('Pre-discount total cannot be negative.');
    }
    final int discountAmountMinor = switch (discountType) {
      null => 0,
      TransactionDiscountType.amount => discountValueMinor.clamp(
        0,
        preDiscountTotalMinor,
      ),
      TransactionDiscountType.percent => _percentDiscountAmount(
        baseMinor: preDiscountTotalMinor,
        percent: discountValueMinor,
      ),
    };
    final int totalAmountMinor = preDiscountTotalMinor - discountAmountMinor;
    return TransactionDiscountComputation(
      preDiscountTotalMinor: preDiscountTotalMinor,
      discountAmountMinor: discountAmountMinor,
      totalAmountMinor: totalAmountMinor < 0 ? 0 : totalAmountMinor,
    );
  }

  static int _percentDiscountAmount({
    required int baseMinor,
    required int percent,
  }) {
    if (percent < 0 || percent > 100) {
      throw ValidationException('Percent discount must be between 0 and 100.');
    }
    return ((baseMinor * percent) + 50) ~/ 100;
  }
}

const Object _unsetDiscountReason = Object();
