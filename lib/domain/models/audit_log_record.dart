import 'dart:convert';

class AuditLogRecord {
  const AuditLogRecord({
    required this.id,
    required this.actorUserId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.metadataJson,
    required this.createdAt,
  });

  final int id;
  final int actorUserId;
  final String action;
  final String entityType;
  final String entityId;
  final String metadataJson;
  final DateTime createdAt;

  String get actionType => action;

  int get actorId => actorUserId;

  String? get actorRole => null;

  Map<String, Object?> get metadata {
    if (metadataJson.trim().isEmpty) {
      return const <String, Object?>{};
    }
    return Map<String, Object?>.from(
      jsonDecode(metadataJson) as Map<String, Object?>,
    );
  }

  AuditLogRecord copyWith({
    int? id,
    int? actorUserId,
    String? action,
    String? entityType,
    String? entityId,
    String? metadataJson,
    DateTime? createdAt,
  }) {
    return AuditLogRecord(
      id: id ?? this.id,
      actorUserId: actorUserId ?? this.actorUserId,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AuditLogRecord &&
        other.id == id &&
        other.actorUserId == actorUserId &&
        other.action == action &&
        other.entityType == entityType &&
        other.entityId == entityId &&
        other.metadataJson == metadataJson &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    actorUserId,
    action,
    entityType,
    entityId,
    metadataJson,
    createdAt,
  );
}
