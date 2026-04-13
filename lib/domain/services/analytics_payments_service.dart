import '../../data/repositories/analytics_repository.dart';
import '../models/analytics/analytics_date_range.dart';
import '../models/analytics/payment_split_summary.dart';

class AnalyticsPaymentsService {
  const AnalyticsPaymentsService({
    required AnalyticsRepository repository,
  }) : _repository = repository;

  final AnalyticsRepository _repository;

  Future<PaymentSplitSummary> getPaymentSplitSummary(
    AnalyticsDateRange range,
  ) async {
    final PaymentSplitSummary summary = await _repository.getPaymentSplit(range);
    final int cashRevenueMinor = _normalizeMinor(summary.cashRevenueMinor);
    final int cardRevenueMinor = _normalizeMinor(summary.cardRevenueMinor);
    final int normalizedTotal = _normalizeMinor(summary.totalRevenueMinor);
    final int fallbackTotal = cashRevenueMinor + cardRevenueMinor;

    return PaymentSplitSummary(
      cashRevenueMinor: cashRevenueMinor,
      cardRevenueMinor: cardRevenueMinor,
      totalRevenueMinor: normalizedTotal > 0 ? normalizedTotal : fallbackTotal,
      cashOrderCount: _normalizeCount(summary.cashOrderCount),
      cardOrderCount: _normalizeCount(summary.cardOrderCount),
    );
  }

  int _normalizeMinor(int value) => value < 0 ? 0 : value;

  int _normalizeCount(int value) => value < 0 ? 0 : value;
}
