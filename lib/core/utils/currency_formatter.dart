import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _gbp = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
    decimalDigits: 2,
  );

  static String fromMinor(int amountMinor) {
    return _gbp.format(amountMinor / 100);
  }

  static String toEditableMajorInput(int amountMinor) {
    return (amountMinor / 100).toStringAsFixed(2);
  }

  static int? tryParseEditableMajorInput(String input) {
    return _tryParseEditableMajorInput(input, allowNegative: false);
  }

  static int? tryParseSignedEditableMajorInput(String input) {
    return _tryParseEditableMajorInput(input, allowNegative: true);
  }

  static int? _tryParseEditableMajorInput(
    String input, {
    required bool allowNegative,
  }) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final String normalized = trimmed
        .replaceAll('£', '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(',', '.');
    final RegExp validPattern = allowNegative
        ? RegExp(r'^-?\d+(\.\d{1,2})?$')
        : RegExp(r'^\d+(\.\d{1,2})?$');
    if (!validPattern.hasMatch(normalized)) {
      return null;
    }

    final bool isNegative = normalized.startsWith('-');
    final String unsigned = isNegative ? normalized.substring(1) : normalized;
    if (unsigned.isEmpty) {
      return null;
    }

    final List<String> parts = unsigned.split('.');
    final int pounds = int.parse(parts.first);
    final String pence = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    final int amountMinor = (pounds * 100) + int.parse(pence.substring(0, 2));
    return isNegative ? -amountMinor : amountMinor;
  }
}
