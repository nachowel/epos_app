import '../../core/errors/exceptions.dart';
import '../models/custom_sale.dart';
import '../models/product.dart';
import '../models/transaction_line.dart';

class CustomSalePolicyService {
  const CustomSalePolicyService();

  bool isCustomSaleProduct(Product product) => product.isCustom;

  bool isCustomSaleLine(
    TransactionLine line, {
    required int customSaleProductId,
  }) {
    return line.productId == customSaleProductId;
  }

  bool isKitchenRelevantLine(
    TransactionLine line, {
    required int customSaleProductId,
  }) {
    return !isCustomSaleLine(line, customSaleProductId: customSaleProductId);
  }

  List<TransactionLine> kitchenRelevantLines(
    Iterable<TransactionLine> lines, {
    required int customSaleProductId,
  }) {
    return lines
        .where(
          (TransactionLine line) => isKitchenRelevantLine(
            line,
            customSaleProductId: customSaleProductId,
          ),
        )
        .toList(growable: false);
  }

  bool orderRequiresKitchen(
    Iterable<TransactionLine> lines, {
    required int customSaleProductId,
  }) {
    for (final TransactionLine line in lines) {
      if (isKitchenRelevantLine(
        line,
        customSaleProductId: customSaleProductId,
      )) {
        return true;
      }
    }
    return false;
  }

  CustomSaleValidationResult validateWriteRequest({
    required CustomSaleWriteRequest request,
    required int limitMinor,
  }) {
    if (request.amountMinor <= 0) {
      throw ValidationException(
        'Custom Sale amount must be greater than zero.',
      );
    }
    if (limitMinor < 0) {
      throw ValidationException(
        'Custom Sale limit configuration cannot be negative.',
      );
    }

    final String? normalizedNote = normalizeNote(request.note);
    final bool requiresAdminOverride = request.amountMinor > limitMinor;
    if (requiresAdminOverride && normalizedNote == null) {
      throw ValidationException(
        'Custom Sale note is required when amount exceeds the configured limit.',
      );
    }

    return CustomSaleValidationResult(
      amountMinor: request.amountMinor,
      limitMinor: limitMinor,
      note: normalizedNote,
      requiresAdminOverride: requiresAdminOverride,
    );
  }

  String? normalizeNote(String? note) {
    if (note == null) {
      return null;
    }
    final String trimmed = note.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
