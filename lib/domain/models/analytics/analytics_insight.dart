enum AnalyticsInsightType { revenue, product, payment, aov }

class AnalyticsInsight {
  const AnalyticsInsight({required this.message, this.type, this.priority});

  final String message;
  final AnalyticsInsightType? type;
  final int? priority;

  AnalyticsInsight copyWith({
    String? message,
    Object? type = _unset,
    Object? priority = _unset,
  }) {
    return AnalyticsInsight(
      message: message ?? this.message,
      type: type == _unset ? this.type : type as AnalyticsInsightType?,
      priority: priority == _unset ? this.priority : priority as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AnalyticsInsight &&
        other.message == message &&
        other.type == type &&
        other.priority == priority;
  }

  @override
  int get hashCode => Object.hash(message, type, priority);
}

const Object _unset = Object();
