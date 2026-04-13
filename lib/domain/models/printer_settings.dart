import 'dart:convert';

enum PrinterConnectionType { bluetooth, ethernet }

class PrinterSettingsModel {
  static const int defaultEthernetPort = 9100;
  // Temporary compatibility storage only. The current printer_settings table
  // still has no dedicated columns for connection_type / ip_address / port, so
  // v2 transport metadata is embedded into device_name until a DB migration
  // introduces separate columns for those fields.
  static const String _storagePrefix = 'printercfg:v2:';

  const PrinterSettingsModel({
    required this.id,
    required this.deviceName,
    required this.deviceAddress,
    required this.paperWidth,
    required this.isActive,
    this.connectionType = PrinterConnectionType.bluetooth,
    this.ipAddress,
    this.port,
  });

  factory PrinterSettingsModel.fromStorage({
    required int id,
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
    required bool isActive,
  }) {
    // Read the temporary compatibility envelope first, then fall back to the
    // legacy shapes:
    // - plain bluetooth rows with raw device_name/device_address
    // - old ethernet fallback rows encoded as ethernet|host|port in
    //   device_address
    final _ParsedPrinterStorage parsed = _ParsedPrinterStorage.fromStorage(
      deviceName: deviceName,
      deviceAddress: deviceAddress,
    );
    return PrinterSettingsModel(
      id: id,
      deviceName: parsed.deviceName,
      deviceAddress: parsed.deviceAddress,
      paperWidth: paperWidth,
      isActive: isActive,
      connectionType: parsed.connectionType,
      ipAddress: parsed.ipAddress,
      port: parsed.port,
    );
  }

  final int id;
  final String deviceName;
  final String deviceAddress;
  final int paperWidth;
  final bool isActive;
  final PrinterConnectionType connectionType;
  final String? ipAddress;
  final int? port;

  bool get isBluetooth => connectionType == PrinterConnectionType.bluetooth;
  bool get isEthernet => connectionType == PrinterConnectionType.ethernet;

  static String normalizeEditableDeviceName(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final _StoredPrinterMetadata? metadata = _StoredPrinterMetadata.tryParse(
      trimmed,
    );
    if (metadata != null) {
      return metadata.deviceName;
    }
    if (_StoredPrinterMetadata.looksLikeStructuredEnvelope(trimmed)) {
      return _StoredPrinterMetadata.tryExtractName(trimmed) ?? '';
    }
    return trimmed;
  }

  String get resolvedAddress => switch (connectionType) {
    PrinterConnectionType.bluetooth => deviceAddress.trim(),
    PrinterConnectionType.ethernet => (ipAddress ?? deviceAddress).trim(),
  };

  int get resolvedPort => port ?? defaultEthernetPort;

  String get storageDeviceName {
    final String normalizedDeviceName = normalizeEditableDeviceName(deviceName);
    final Map<String, Object?> payload = <String, Object?>{
      // Keep a plain human-editable name inside the temporary envelope so a UI
      // text field cannot accidentally nest or persist the storage wrapper.
      'name': normalizedDeviceName,
      'connection_type': connectionType.name,
      'port': connectionType == PrinterConnectionType.ethernet
          ? resolvedPort
          : null,
    };
    return '$_storagePrefix${Uri.encodeComponent(jsonEncode(payload))}';
  }

  String get storageDeviceAddress => resolvedAddress;

  PrinterSettingsModel copyWith({
    int? id,
    String? deviceName,
    String? deviceAddress,
    int? paperWidth,
    bool? isActive,
    PrinterConnectionType? connectionType,
    Object? ipAddress = _unset,
    Object? port = _unset,
  }) {
    return PrinterSettingsModel(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      paperWidth: paperWidth ?? this.paperWidth,
      isActive: isActive ?? this.isActive,
      connectionType: connectionType ?? this.connectionType,
      ipAddress: ipAddress == _unset ? this.ipAddress : ipAddress as String?,
      port: port == _unset ? this.port : port as int?,
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
        other.isActive == isActive &&
        other.connectionType == connectionType &&
        other.ipAddress == ipAddress &&
        other.port == port;
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceName,
    deviceAddress,
    paperWidth,
    isActive,
    connectionType,
    ipAddress,
    port,
  );
}

class _ParsedPrinterStorage {
  const _ParsedPrinterStorage({
    required this.deviceName,
    required this.connectionType,
    required this.deviceAddress,
    required this.ipAddress,
    required this.port,
  });

  factory _ParsedPrinterStorage.fromStorage({
    required String deviceName,
    required String deviceAddress,
  }) {
    final String trimmedDeviceName = deviceName.trim();
    final _StoredPrinterMetadataHints hints =
        _StoredPrinterMetadataHints.fromEnvelope(trimmedDeviceName);
    final _StoredPrinterMetadata? metadata = _StoredPrinterMetadata.tryParse(
      trimmedDeviceName,
    );
    if (metadata != null) {
      // device_name currently carries temporary compatibility metadata. The
      // permanent solution is separate DB columns for connection_type,
      // ip_address and port.
      final String resolvedAddress = deviceAddress.trim();
      return _ParsedPrinterStorage(
        deviceName: metadata.deviceName,
        connectionType: metadata.connectionType,
        deviceAddress: resolvedAddress,
        ipAddress: metadata.connectionType == PrinterConnectionType.ethernet
            ? resolvedAddress
            : null,
        port: metadata.port,
      );
    }

    if (_StoredPrinterMetadata.looksLikeStructuredEnvelope(trimmedDeviceName)) {
      // Deterministic corrupted structured-envelope fallback:
      // 1) keep legacy ethernet rows readable if device_address still uses the
      //    old ethernet|host|port shape
      // 2) keep MAC-like addresses on bluetooth
      // 3) honor any still-readable connection_type/port hints from the broken
      //    payload when they are valid
      // 4) only infer ethernet from host-like addresses; ambiguous opaque
      //    values stay on the conservative bluetooth side
      return _fromCorruptedStructuredEnvelope(
        deviceName: trimmedDeviceName,
        deviceAddress: deviceAddress,
        hints: hints,
      );
    }

    if (!deviceAddress.startsWith('ethernet|')) {
      return _ParsedPrinterStorage(
        deviceName: PrinterSettingsModel.normalizeEditableDeviceName(
          deviceName,
        ),
        connectionType: PrinterConnectionType.bluetooth,
        deviceAddress: deviceAddress.trim(),
        ipAddress: null,
        port: null,
      );
    }

    final List<String> segments = deviceAddress.split('|');
    if (segments.length < 2) {
      return _ParsedPrinterStorage(
        deviceName: PrinterSettingsModel.normalizeEditableDeviceName(
          deviceName,
        ),
        connectionType: PrinterConnectionType.bluetooth,
        deviceAddress: deviceAddress.trim(),
        ipAddress: null,
        port: null,
      );
    }

    final String host = segments[1].trim();
    final int resolvedPort = segments.length >= 3
        ? int.tryParse(segments[2]) ?? PrinterSettingsModel.defaultEthernetPort
        : PrinterSettingsModel.defaultEthernetPort;

    return _ParsedPrinterStorage(
      // Legacy fallback: ethernet transport used to be inferred from the old
      // ethernet|host|port device_address encoding.
      deviceName: PrinterSettingsModel.normalizeEditableDeviceName(deviceName),
      connectionType: PrinterConnectionType.ethernet,
      deviceAddress: host,
      ipAddress: host,
      port: resolvedPort,
    );
  }

  static _ParsedPrinterStorage _fromCorruptedStructuredEnvelope({
    required String deviceName,
    required String deviceAddress,
    required _StoredPrinterMetadataHints hints,
  }) {
    final String normalizedAddress = deviceAddress.trim();
    final String? salvagedName = hints.name;

    if (_isLegacyEthernetEncoded(normalizedAddress)) {
      final List<String> segments = deviceAddress.split('|');
      final String host = segments.length >= 2 ? segments[1].trim() : '';
      final int resolvedPort = segments.length >= 3
          ? int.tryParse(segments[2]) ??
                PrinterSettingsModel.defaultEthernetPort
          : PrinterSettingsModel.defaultEthernetPort;
      return _ParsedPrinterStorage(
        deviceName: salvagedName ?? _fallbackEthernetPrinterName(host: host),
        connectionType: PrinterConnectionType.ethernet,
        deviceAddress: host,
        ipAddress: host,
        port: hints.port ?? resolvedPort,
      );
    }

    if (hints.connectionType == PrinterConnectionType.bluetooth ||
        _looksLikeBluetoothAddress(normalizedAddress) ||
        normalizedAddress.isEmpty) {
      return _ParsedPrinterStorage(
        // Recovery note: when the envelope is broken but a valid bluetooth hint
        // survives, prefer that explicit hint. Without a hint, only MAC-like
        // addresses are treated as bluetooth automatically.
        deviceName:
            salvagedName ??
            _fallbackBluetoothPrinterName(address: normalizedAddress),
        connectionType: PrinterConnectionType.bluetooth,
        deviceAddress: normalizedAddress,
        ipAddress: null,
        port: null,
      );
    }

    if (hints.connectionType == PrinterConnectionType.ethernet ||
        _looksLikeEthernetHost(normalizedAddress)) {
      // Recovery note: this is still heuristic. We only infer ethernet for
      // host-like addresses (IPv4/hostname-ish). Ambiguous opaque values are
      // intentionally not forced to ethernet.
      final int resolvedPort =
          hints.port ?? PrinterSettingsModel.defaultEthernetPort;
      return _ParsedPrinterStorage(
        deviceName:
            salvagedName ??
            _fallbackEthernetPrinterName(host: normalizedAddress),
        connectionType: PrinterConnectionType.ethernet,
        deviceAddress: normalizedAddress,
        ipAddress: normalizedAddress,
        port: resolvedPort,
      );
    }

    return _ParsedPrinterStorage(
      deviceName:
          salvagedName ??
          _fallbackBluetoothPrinterName(address: normalizedAddress),
      connectionType: PrinterConnectionType.bluetooth,
      deviceAddress: normalizedAddress,
      ipAddress: null,
      port: null,
    );
  }

  static bool _isLegacyEthernetEncoded(String value) {
    return value.startsWith('ethernet|');
  }

  static bool _looksLikeBluetoothAddress(String value) {
    final String trimmed = value.trim();
    return RegExp(
      r'^([0-9A-Fa-f]{2}([:-])){2,7}[0-9A-Fa-f]{2}$',
    ).hasMatch(trimmed);
  }

  static bool _looksLikeEthernetHost(String value) {
    final String trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) {
      return false;
    }
    if (trimmed == 'localhost') {
      return true;
    }
    if (RegExp(
      r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$',
    ).hasMatch(trimmed)) {
      return true;
    }
    if (RegExp(r'^[0-9.]+$').hasMatch(trimmed)) {
      // Dot-separated numeric host strings are more likely broken IPv4 values
      // than bluetooth identifiers, so keep them on the ethernet side.
      return true;
    }
    return RegExp(
      r'^(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)(\.([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?))*$',
    ).hasMatch(trimmed);
  }

  static String _fallbackBluetoothPrinterName({required String address}) {
    final String? suffix = _bluetoothSuffix(address);
    return suffix == null ? 'Bluetooth Printer' : 'Bluetooth Printer ($suffix)';
  }

  static String _fallbackEthernetPrinterName({required String host}) {
    final String normalizedHost = host.trim();
    return normalizedHost.isEmpty
        ? 'Ethernet Printer'
        : 'Ethernet Printer ($normalizedHost)';
  }

  static String? _bluetoothSuffix(String address) {
    final String hex = address.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (hex.length < 4) {
      return null;
    }
    return hex.substring(hex.length - 4).toUpperCase();
  }

  final String deviceName;
  final PrinterConnectionType connectionType;
  final String deviceAddress;
  final String? ipAddress;
  final int? port;
}

class _StoredPrinterMetadata {
  const _StoredPrinterMetadata({
    required this.deviceName,
    required this.connectionType,
    required this.port,
  });

  factory _StoredPrinterMetadata.parse(String value) {
    if (!looksLikeStructuredEnvelope(value)) {
      throw const FormatException('_not_structured_printer_metadata');
    }
    final Map<String, dynamic>? decoded = _tryDecodePayloadMap(value);
    if (decoded == null) {
      throw const FormatException('printer_metadata_payload_invalid');
    }

    final String deviceName = (decoded['name'] as String? ?? '').trim();
    final String connectionTypeValue =
        (decoded['connection_type'] as String? ?? '').trim();
    final PrinterConnectionType connectionType = switch (connectionTypeValue) {
      'ethernet' => PrinterConnectionType.ethernet,
      'bluetooth' => PrinterConnectionType.bluetooth,
      _ => throw const FormatException('printer_connection_type_invalid'),
    };

    final Object? rawPort = decoded['port'];
    final int? port = rawPort is int
        ? rawPort
        : rawPort is num
        ? rawPort.toInt()
        : null;

    return _StoredPrinterMetadata(
      deviceName: deviceName,
      connectionType: connectionType,
      port: connectionType == PrinterConnectionType.ethernet
          ? (port ?? PrinterSettingsModel.defaultEthernetPort)
          : null,
    );
  }

  static _StoredPrinterMetadata? tryParse(String value) {
    try {
      return _StoredPrinterMetadata.parse(value);
    } on FormatException {
      return null;
    }
  }

  static bool looksLikeStructuredEnvelope(String value) {
    return value.trim().startsWith(PrinterSettingsModel._storagePrefix);
  }

  static String? tryExtractName(String value) {
    final Map<String, dynamic>? decoded = _tryDecodePayloadMap(value);
    final String name = (decoded?['name'] as String? ?? '').trim();
    return name.isEmpty ? null : name;
  }

  static Map<String, dynamic>? _tryDecodePayloadMap(String value) {
    if (!looksLikeStructuredEnvelope(value)) {
      return null;
    }
    try {
      final String rawPayload = value.trim().substring(
        PrinterSettingsModel._storagePrefix.length,
      );
      final Object? decoded = jsonDecode(Uri.decodeComponent(rawPayload));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  final String deviceName;
  final PrinterConnectionType connectionType;
  final int? port;
}

class _StoredPrinterMetadataHints {
  const _StoredPrinterMetadataHints({
    required this.name,
    required this.connectionType,
    required this.port,
  });

  factory _StoredPrinterMetadataHints.fromEnvelope(String value) {
    final Map<String, dynamic>? decoded =
        _StoredPrinterMetadata._tryDecodePayloadMap(value);
    if (decoded == null) {
      return const _StoredPrinterMetadataHints(
        name: null,
        connectionType: null,
        port: null,
      );
    }

    final String? name = _StoredPrinterMetadata.tryExtractName(value);
    final String connectionTypeValue =
        (decoded['connection_type'] as String? ?? '').trim();
    final PrinterConnectionType? connectionType = switch (connectionTypeValue) {
      'ethernet' => PrinterConnectionType.ethernet,
      'bluetooth' => PrinterConnectionType.bluetooth,
      _ => null,
    };
    final Object? rawPort = decoded['port'];
    final int? port = rawPort is int
        ? rawPort
        : rawPort is num
        ? rawPort.toInt()
        : null;
    return _StoredPrinterMetadataHints(
      name: name,
      connectionType: connectionType,
      port: port,
    );
  }

  final String? name;
  final PrinterConnectionType? connectionType;
  final int? port;
}

const Object _unset = Object();
