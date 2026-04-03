import 'dart:convert';

import 'analytics_period.dart';

class SavedAnalyticsView {
  const SavedAnalyticsView({
    required this.id,
    required this.name,
    required this.periodType,
    required this.preset,
    required this.start,
    required this.end,
    required this.comparisonMode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedAnalyticsView.create({
    required String id,
    required String name,
    required AnalyticsPeriodSelection periodSelection,
    required AnalyticsComparisonMode comparisonMode,
    required DateTime createdAt,
  }) {
    return SavedAnalyticsView(
      id: id,
      name: name.trim(),
      periodType: periodSelection.type,
      preset: periodSelection.preset == null
          ? null
          : AnalyticsPeriodSelection.preset(periodSelection.preset!).queryValue,
      start: periodSelection.start,
      end: periodSelection.end,
      comparisonMode: analyticsComparisonModeQueryValue(comparisonMode),
      createdAt: createdAt.toUtc(),
      updatedAt: createdAt.toUtc(),
    );
  }

  factory SavedAnalyticsView.fromJson(Map<String, Object?> json) {
    final String id = _readString(json, 'id');
    final String name = _readString(json, 'name');
    final String rawPeriodType = _readString(json, 'period_type');
    final AnalyticsPeriodType periodType = switch (rawPeriodType) {
      'preset' => AnalyticsPeriodType.preset,
      'custom' => AnalyticsPeriodType.custom,
      _ => throw const FormatException('Invalid saved analytics period_type.'),
    };
    final String? preset = _readOptionalString(json, 'preset');
    final DateTime? start = _readOptionalDate(json, 'start');
    final DateTime? end = _readOptionalDate(json, 'end');
    final String comparisonMode = _readString(json, 'comparison_mode');

    return SavedAnalyticsView(
      id: id,
      name: name,
      periodType: periodType,
      preset: preset,
      start: start,
      end: end,
      comparisonMode: comparisonMode,
      createdAt: _readDate(json, 'created_at'),
      updatedAt: _readDate(json, 'updated_at'),
    );
  }

  final String id;
  final String name;
  final AnalyticsPeriodType periodType;
  final String? preset;
  final DateTime? start;
  final DateTime? end;
  final String comparisonMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnalyticsPeriodSelection get periodSelection {
    if (periodType == AnalyticsPeriodType.custom &&
        start != null &&
        end != null &&
        !end!.isBefore(start!)) {
      return AnalyticsPeriodSelection.custom(start: start!, end: end!);
    }
    final AnalyticsPresetPeriod? resolvedPreset = switch (preset) {
      'today' => AnalyticsPresetPeriod.today,
      'this_week' => AnalyticsPresetPeriod.thisWeek,
      'this_month' => AnalyticsPresetPeriod.thisMonth,
      'last_14_days' => AnalyticsPresetPeriod.last14Days,
      _ => null,
    };
    return resolvedPreset == null
        ? AnalyticsPeriodSelection.fallback()
        : AnalyticsPeriodSelection.preset(resolvedPreset);
  }

  AnalyticsComparisonMode get resolvedComparisonMode =>
      analyticsComparisonModeFromQuery(comparisonMode);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'period_type': periodType == AnalyticsPeriodType.preset
          ? 'preset'
          : 'custom',
      'preset': preset,
      'start': _formatDate(start),
      'end': _formatDate(end),
      'comparison_mode': comparisonMode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SavedAnalyticsView touch({
    String? name,
    AnalyticsPeriodSelection? periodSelection,
    AnalyticsComparisonMode? comparisonMode,
    required DateTime updatedAt,
  }) {
    final AnalyticsPeriodSelection effectiveSelection =
        periodSelection ?? this.periodSelection;
    final AnalyticsComparisonMode effectiveComparisonMode =
        comparisonMode ?? resolvedComparisonMode;

    return SavedAnalyticsView(
      id: id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : this.name,
      periodType: effectiveSelection.type,
      preset: effectiveSelection.preset == null
          ? null
          : AnalyticsPeriodSelection.preset(effectiveSelection.preset!).queryValue,
      start: effectiveSelection.start,
      end: effectiveSelection.end,
      comparisonMode: analyticsComparisonModeQueryValue(
        effectiveComparisonMode,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt.toUtc(),
    );
  }

  static List<SavedAnalyticsView> decodeList(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const <SavedAnalyticsView>[];
    }
    final Object? decoded = jsonDecode(rawValue);
    if (decoded is! List) {
      return const <SavedAnalyticsView>[];
    }
    return decoded
        .whereType<Map>()
        .map((Map item) {
          try {
            return SavedAnalyticsView.fromJson(Map<String, Object?>.from(item));
          } on FormatException {
            return null;
          }
        })
        .whereType<SavedAnalyticsView>()
        .toList(growable: false);
  }

  static String encodeList(List<SavedAnalyticsView> views) {
    return jsonEncode(
      views.map((SavedAnalyticsView view) => view.toJson()).toList(),
    );
  }

  static String _readString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Saved analytics view missing $key.');
    }
    return value;
  }

  static String? _readOptionalString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  static DateTime _readDate(Map<String, Object?> json, String key) {
    final String value = _readString(json, key);
    return DateTime.parse(value).toUtc();
  }

  static DateTime? _readOptionalDate(Map<String, Object?> json, String key) {
    final String? value = _readOptionalString(json, key);
    if (value == null) {
      return null;
    }
    final DateTime parsed = DateTime.parse(value).toUtc();
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    final DateTime normalized = DateTime.utc(value.year, value.month, value.day);
    return normalized.toIso8601String().split('T').first;
  }
}
