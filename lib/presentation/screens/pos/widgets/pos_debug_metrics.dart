import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';

enum PosMetricRating { acceptable, borderline, slow }

class PosMetricsThresholds {
  const PosMetricsThresholds._();

  static const int productTapAckTargetMs = 75;
  static const int productTapAckBorderlineMs = 120;
  static const int cartQuantityAckTargetMs = 60;
  static const int cartQuantityAckBorderlineMs = 100;
  static const int modifierSelectionTargetMs = 2500;
  static const int modifierSelectionBorderlineMs = 5000;

  static PosMetricRating rateProductTapAck(int elapsedMs) {
    return _rate(
      elapsedMs,
      targetMs: productTapAckTargetMs,
      borderlineMs: productTapAckBorderlineMs,
    );
  }

  static PosMetricRating rateCartQuantityAck(int elapsedMs) {
    return _rate(
      elapsedMs,
      targetMs: cartQuantityAckTargetMs,
      borderlineMs: cartQuantityAckBorderlineMs,
    );
  }

  static PosMetricRating rateModifierSelectionElapsed(int elapsedMs) {
    return _rate(
      elapsedMs,
      targetMs: modifierSelectionTargetMs,
      borderlineMs: modifierSelectionBorderlineMs,
    );
  }

  static String interpret(PosMetricRating rating) {
    switch (rating) {
      case PosMetricRating.acceptable:
        return 'meets target';
      case PosMetricRating.borderline:
        return 'watch';
      case PosMetricRating.slow:
        return 'action_needed';
    }
  }

  static PosMetricRating _rate(
    int elapsedMs, {
    required int targetMs,
    required int borderlineMs,
  }) {
    if (elapsedMs <= targetMs) {
      return PosMetricRating.acceptable;
    }
    if (elapsedMs <= borderlineMs) {
      return PosMetricRating.borderline;
    }
    return PosMetricRating.slow;
  }
}

class PosDebugSessionMetrics {
  static final List<int> _productTapAckMs = <int>[];
  static final List<int> _cartQuantityAckMs = <int>[];
  static final List<int> _modifierSelectionElapsedMs = <int>[];
  static final Map<String, int> _modifierUsageCounts = <String, int>{};

  static void recordProductTapAck(int elapsedMs) {
    _productTapAckMs.add(elapsedMs);
  }

  static void recordCartQuantityAck(int elapsedMs) {
    _cartQuantityAckMs.add(elapsedMs);
  }

  static void recordModifierSelectionElapsed(int elapsedMs) {
    _modifierSelectionElapsedMs.add(elapsedMs);
  }

  static void recordModifierUsage(Iterable<String> modifierLabels) {
    for (final String label in modifierLabels) {
      _modifierUsageCounts[label] = (_modifierUsageCounts[label] ?? 0) + 1;
    }
  }

  static Map<String, Object?> summaryMetadata() {
    final int averageProductTapAckMs = _average(_productTapAckMs);
    final int averageCartQuantityAckMs = _average(_cartQuantityAckMs);
    final int averageModifierSelectionElapsedMs = _average(
      _modifierSelectionElapsedMs,
    );
    final PosMetricRating? productTapRating = _productTapAckMs.isEmpty
        ? null
        : PosMetricsThresholds.rateProductTapAck(averageProductTapAckMs);
    final PosMetricRating? cartQuantityRating = _cartQuantityAckMs.isEmpty
        ? null
        : PosMetricsThresholds.rateCartQuantityAck(averageCartQuantityAckMs);
    final PosMetricRating? modifierSelectionRating =
        _modifierSelectionElapsedMs.isEmpty
        ? null
        : PosMetricsThresholds.rateModifierSelectionElapsed(
            averageModifierSelectionElapsedMs,
          );

    return <String, Object?>{
      'product_tap_ack_samples': _productTapAckMs.length,
      'avg_product_tap_ack_ms': averageProductTapAckMs,
      'product_tap_ack_target_ms': PosMetricsThresholds.productTapAckTargetMs,
      'product_tap_ack_borderline_ms':
          PosMetricsThresholds.productTapAckBorderlineMs,
      'product_tap_ack_rating': _ratingName(productTapRating),
      'product_tap_ack_interpretation': _interpretationName(productTapRating),
      'cart_quantity_ack_samples': _cartQuantityAckMs.length,
      'avg_cart_quantity_ack_ms': averageCartQuantityAckMs,
      'cart_quantity_ack_target_ms':
          PosMetricsThresholds.cartQuantityAckTargetMs,
      'cart_quantity_ack_borderline_ms':
          PosMetricsThresholds.cartQuantityAckBorderlineMs,
      'cart_quantity_ack_rating': _ratingName(cartQuantityRating),
      'cart_quantity_ack_interpretation': _interpretationName(
        cartQuantityRating,
      ),
      'modifier_selection_samples': _modifierSelectionElapsedMs.length,
      'avg_modifier_selection_elapsed_ms': averageModifierSelectionElapsedMs,
      'modifier_selection_target_ms':
          PosMetricsThresholds.modifierSelectionTargetMs,
      'modifier_selection_borderline_ms':
          PosMetricsThresholds.modifierSelectionBorderlineMs,
      'modifier_selection_rating': _ratingName(modifierSelectionRating),
      'modifier_selection_interpretation': _interpretationName(
        modifierSelectionRating,
      ),
      'most_used_modifiers': _topModifierUsage(),
    };
  }

  static int _average(List<int> values) {
    if (values.isEmpty) {
      return 0;
    }
    final int total = values.fold(0, (int sum, int value) => sum + value);
    return (total / values.length).round();
  }

  static String _ratingName(PosMetricRating? rating) {
    return rating?.name ?? 'no_data';
  }

  static String _interpretationName(PosMetricRating? rating) {
    if (rating == null) {
      return 'no_data';
    }
    return PosMetricsThresholds.interpret(rating);
  }

  static List<String> _topModifierUsage() {
    final List<MapEntry<String, int>> ranked =
        _modifierUsageCounts.entries.toList(growable: false)
          ..sort((MapEntry<String, int> left, MapEntry<String, int> right) {
            final int countCompare = right.value.compareTo(left.value);
            if (countCompare != 0) {
              return countCompare;
            }
            return left.key.compareTo(right.key);
          });
    return ranked
        .take(5)
        .map((MapEntry<String, int> entry) => '${entry.key}:${entry.value}')
        .toList(growable: false);
  }
}

void logPosDebugMetric(
  BuildContext context, {
  required String eventType,
  String? message,
  String? entityId,
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final bool debugLoggingEnabled = container
      .read(appConfigProvider)
      .featureFlags
      .debugLoggingEnabled;
  if (!debugLoggingEnabled) {
    return;
  }

  container
      .read(appLoggerProvider)
      .info(
        eventType: eventType,
        message: message,
        entityId: entityId,
        metadata: metadata,
      );
}

void logPosDebugSummary(BuildContext context) {
  logPosDebugMetric(
    context,
    eventType: 'pos_operator_speed_session_summary_debug',
    metadata: PosDebugSessionMetrics.summaryMetadata(),
  );
}

class PosDebugThresholdBanner extends StatelessWidget {
  const PosDebugThresholdBanner({
    required this.label,
    required this.elapsedMs,
    required this.rating,
    super.key,
  });

  final String label;
  final int elapsedMs;
  final PosMetricRating rating;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (rating) {
      PosMetricRating.acceptable => const Color(0xFF1F7A45),
      PosMetricRating.borderline => const Color(0xFF9A5B00),
      PosMetricRating.slow => const Color(0xFFB42318),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.bug_report_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label ${rating.name} ${elapsedMs}ms',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
