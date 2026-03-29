import 'transaction.dart';

class OpenOrderSummary {
  const OpenOrderSummary({
    required this.transaction,
    required this.itemCount,
    required this.shortContent,
  });

  final Transaction transaction;
  final int itemCount;
  final String shortContent;
}
