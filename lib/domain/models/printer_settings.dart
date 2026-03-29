class PrinterSettingsModel {
  const PrinterSettingsModel({
    required this.id,
    required this.deviceName,
    required this.deviceAddress,
    required this.paperWidth,
    required this.isActive,
  });

  final int id;
  final String deviceName;
  final String deviceAddress;
  final int paperWidth;
  final bool isActive;

  PrinterSettingsModel copyWith({
    int? id,
    String? deviceName,
    String? deviceAddress,
    int? paperWidth,
    bool? isActive,
  }) {
    return PrinterSettingsModel(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      paperWidth: paperWidth ?? this.paperWidth,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PrinterSettingsModel &&
        other.id == id &&
        other.deviceName == deviceName &&
        other.deviceAddress == deviceAddress &&
        other.paperWidth == paperWidth &&
        other.isActive == isActive;
  }

  @override
  int get hashCode =>
      Object.hash(id, deviceName, deviceAddress, paperWidth, isActive);
}
