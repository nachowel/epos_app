import 'package:epos_app/domain/models/printer_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrinterSettingsModel', () {
    test('legacy bluetooth storage maps to bluetooth printer', () {
      final PrinterSettingsModel printer = PrinterSettingsModel.fromStorage(
        id: 1,
        deviceName: 'Counter Printer',
        deviceAddress: 'AA:BB:CC',
        paperWidth: 80,
        isActive: true,
      );

      expect(printer.connectionType, PrinterConnectionType.bluetooth);
      expect(printer.deviceAddress, 'AA:BB:CC');
      expect(printer.ipAddress, isNull);
      expect(printer.port, isNull);
      expect(printer.storageDeviceAddress, 'AA:BB:CC');
    });

    test('legacy ethernet hack format still parses as fallback', () {
      final PrinterSettingsModel printer = PrinterSettingsModel.fromStorage(
        id: 1,
        deviceName: 'Kitchen Ethernet',
        deviceAddress: 'ethernet|192.168.1.100|9100',
        paperWidth: 80,
        isActive: true,
      );

      expect(printer.connectionType, PrinterConnectionType.ethernet);
      expect(printer.deviceAddress, '192.168.1.100');
      expect(printer.ipAddress, '192.168.1.100');
      expect(printer.port, 9100);
      expect(printer.resolvedAddress, '192.168.1.100');
      expect(printer.storageDeviceAddress, '192.168.1.100');
    });

    test(
      'new structured persistence format parses from device name metadata',
      () {
        final PrinterSettingsModel stored = PrinterSettingsModel(
          id: 1,
          deviceName: 'Kitchen Ethernet',
          deviceAddress: '192.168.1.100',
          paperWidth: 80,
          isActive: true,
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: '192.168.1.100',
          port: 9100,
        );

        final PrinterSettingsModel printer = PrinterSettingsModel.fromStorage(
          id: 1,
          deviceName: stored.storageDeviceName,
          deviceAddress: stored.storageDeviceAddress,
          paperWidth: 80,
          isActive: true,
        );

        expect(printer.deviceName, 'Kitchen Ethernet');
        expect(printer.connectionType, PrinterConnectionType.ethernet);
        expect(printer.deviceAddress, '192.168.1.100');
        expect(printer.port, 9100);
        expect(printer.storageDeviceName, stored.storageDeviceName);
        expect(printer.storageDeviceAddress, '192.168.1.100');
      },
    );

    test(
      'temporary compatibility storage is normalized before user-visible edits are reused',
      () {
        final PrinterSettingsModel stored = PrinterSettingsModel(
          id: 1,
          deviceName: 'Kitchen Ethernet',
          deviceAddress: '192.168.1.100',
          paperWidth: 80,
          isActive: true,
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: '192.168.1.100',
          port: 9100,
        );

        expect(
          PrinterSettingsModel.normalizeEditableDeviceName(
            stored.storageDeviceName,
          ),
          'Kitchen Ethernet',
        );
      },
    );

    test(
      'malformed envelope normalize returns empty editable name when no name can be salvaged',
      () {
        expect(
          PrinterSettingsModel.normalizeEditableDeviceName(
            'printercfg:v2:%7Bbad-json',
          ),
          '',
        );
      },
    );

    test('partial metadata normalize extracts best-effort name', () {
      expect(
        PrinterSettingsModel.normalizeEditableDeviceName(
          'printercfg:v2:%7B%22name%22%3A%22Kitchen%20Partial%22%7D',
        ),
        'Kitchen Partial',
      );
    });
  });
}
