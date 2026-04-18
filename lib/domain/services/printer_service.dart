import 'dart:async';
import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/report_category_display_formatter.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/print_job_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/breakfast_cooking_instruction.dart';
import '../models/cashier_projected_report.dart';
import '../models/order_lifecycle_policy.dart';
import '../models/order_modifier.dart';
import '../models/payment.dart';
import '../models/print_job.dart';
import '../models/printer_device_option.dart';
import '../models/printer_settings.dart';
import '../models/product_modifier.dart';
import '../models/shift_report.dart';
import '../models/transaction.dart';
import '../models/transaction_line.dart';
import 'audit_log_service.dart';
import 'breakfast_modifier_renderer.dart';
import 'custom_sale_policy_service.dart';

typedef SocketConnector =
    Future<Socket> Function(String host, int port, Duration timeout);

/// Handles ESC/POS printing through a serialized queue (in-memory mutex).
///
/// Callers must already have applied report visibility rules before calling
/// [printZReport]. This service prints the provided data as-is.
class PrinterService {
  static const Duration _networkConnectTimeout = Duration(seconds: 5);
  static const Duration _networkWriteTimeout = Duration(seconds: 5);
  static const int _kitchenTicketWidth = 48;
  static const String _printerCodeTable = 'CP1252';
  static const String _businessName = 'HALFWAY CAFE';
  static const String _businessAddress = '176 Halfway St, Sidcup';
  static const String _businessPhone = '020 3343 5303';
  static const String _kitchenSeparator =
      '------------------------------------------------';

  PrinterService(
    TransactionRepository transactionRepository, {
    PaymentRepository? paymentRepository,
    PrintJobRepository? printJobRepository,
    ProductRepository? productRepository,
    SettingsRepository? settingsRepository,
    CustomSalePolicyService customSalePolicyService =
        const CustomSalePolicyService(),
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
    SocketConnector? socketConnector,
  }) : _transactionRepository = transactionRepository,
       _paymentRepository = paymentRepository,
       _printJobRepository = printJobRepository,
       _productRepository = productRepository,
       _settingsRepository = settingsRepository,
       _customSalePolicyService = customSalePolicyService,
       _auditLogService = auditLogService,
       _logger = logger,
       _socketConnector =
           socketConnector ??
           ((String host, int port, Duration timeout) {
             return Socket.connect(host, port, timeout: timeout);
           });

  final TransactionRepository _transactionRepository;
  final PaymentRepository? _paymentRepository;
  final PrintJobRepository? _printJobRepository;
  final ProductRepository? _productRepository;
  final SettingsRepository? _settingsRepository;
  final CustomSalePolicyService _customSalePolicyService;
  final AuditLogService _auditLogService;
  final AppLogger _logger;
  final SocketConnector _socketConnector;
  Future<void> _printQueue = Future<void>.value();

  Future<PrintJob> printKitchenTicket(
    int transactionId, {
    bool allowReprint = false,
    int? actorUserId,
  }) async {
    debugPrint(
      '[KITCHEN_PRINT] printKitchenTicket CALLED'
      ' tx=$transactionId allowReprint=$allowReprint',
    );
    return _processPrintJob(
      transactionId: transactionId,
      target: PrintJobTarget.kitchen,
      allowReprint: allowReprint,
      actorUserId: actorUserId,
    );
  }

  Future<PrintJob> printReceipt(
    int transactionId, {
    bool allowReprint = false,
    int? actorUserId,
  }) async {
    debugPrint(
      '[KITCHEN_PRINT] receipt print requested (manual)'
      ' tx=$transactionId allowReprint=$allowReprint',
    );
    return _processPrintJob(
      transactionId: transactionId,
      target: PrintJobTarget.receipt,
      allowReprint: allowReprint,
      actorUserId: actorUserId,
    );
  }

  Future<void> printZReport(ShiftReport report) async {
    await _runSerialized(() async {
      try {
        final PrinterSettingsModel printer = await _requirePrinterSettings();
        final List<int> bytes = await _buildZReportBytes(
          printer: printer,
          report: report,
        );

        await _sendBytesToPrinter(printer: printer, bytes: bytes);
        _logger.info(
          eventType: 'print_z_report_success',
          entityId: '${report.shiftId}',
          message: 'Z report printed.',
        );
      } on AppException {
        _logger.warn(
          eventType: 'print_z_report_failure',
          entityId: '${report.shiftId}',
          message: 'Z report print failed.',
        );
        rethrow;
      } catch (error) {
        _logger.error(
          eventType: 'print_z_report_failure',
          entityId: '${report.shiftId}',
          message: 'Z report print failed.',
          error: error,
        );
        throw PrinterException('Z report print failed: $error');
      }
    });
  }

  Future<void> printCashierZReport(CashierProjectedReport report) async {
    await _runSerialized(() async {
      final String entityId = '${report.shiftId ?? 0}';
      try {
        final PrinterSettingsModel printer = await _requirePrinterSettings();
        final List<int> bytes = await _buildCashierZReportBytes(
          printer: printer,
          report: report,
        );

        await _sendBytesToPrinter(printer: printer, bytes: bytes);
        _logger.info(
          eventType: 'print_cashier_z_report_success',
          entityId: entityId,
          message: 'Cashier Z report printed.',
        );
      } on AppException {
        _logger.warn(
          eventType: 'print_cashier_z_report_failure',
          entityId: entityId,
          message: 'Cashier Z report print failed.',
        );
        rethrow;
      } catch (error) {
        _logger.error(
          eventType: 'print_cashier_z_report_failure',
          entityId: entityId,
          message: 'Cashier Z report print failed.',
          error: error,
        );
        throw PrinterException('Cashier Z report print failed: $error');
      }
    });
  }

  /// Manual "Open Drawer" action shared by Category and POS screens.
  ///
  /// Uses the same ESC/POS pulse path as [openCashDrawer] but rethrows
  /// failures so the UI can surface them (unlike [openCashDrawer], which
  /// swallows errors to protect the post-payment lifecycle).
  Future<void> openCashDrawerManually({int? actorUserId}) async {
    await _runSerialized(() async {
      const String entityId = 'CASH_DRAWER_MANUAL';
      final PrinterSettingsModel printer = await _requirePrinterSettings();
      final List<int> bytes = <int>[27, 112, 0, 25, 250];
      try {
        _logger.info(
          eventType: 'open_cash_drawer_manual_attempt',
          entityId: printer.deviceAddress,
          message: 'Manual cash drawer open requested.',
          metadata: <String, Object?>{'actor_user_id': actorUserId},
        );
        await _sendBytesToPrinter(printer: printer, bytes: bytes);
        _logger.info(
          eventType: 'open_cash_drawer_manual_success',
          entityId: printer.deviceAddress,
          message: 'Manual cash drawer opened.',
          metadata: <String, Object?>{'actor_user_id': actorUserId},
        );
        if (actorUserId != null && actorUserId > 0) {
          await _auditLogService.logActionSafely(
            actorUserId: actorUserId,
            action: 'cash_drawer_opened_manual',
            entityType: 'cash_drawer',
            entityId: printer.deviceAddress,
            metadata: const <String, Object?>{},
          );
        }
      } on AppException catch (error) {
        _logger.warn(
          eventType: 'open_cash_drawer_manual_failure',
          entityId: entityId,
          message: 'Manual cash drawer open failed.',
          error: error,
        );
        rethrow;
      } catch (error) {
        _logger.error(
          eventType: 'open_cash_drawer_manual_failure',
          entityId: entityId,
          message: 'Manual cash drawer open failed.',
          error: error,
        );
        throw PrinterException('Cash drawer open failed: $error');
      }
    });
  }

  /// Sends an ESC/POS pulse command to open the cash drawer.
  ///
  /// Pulse command: ESC p m t1 t2
  /// - ESC p: 27, 112 (0x1B, 0x70)
  /// - m=0: Pin 2
  /// - t1=25: 50ms on
  /// - t2=250: 500ms off
  Future<void> openCashDrawer() async {
    await _runSerialized(() async {
      final String entityId = 'CASH_DRAWER';
      try {
        final PrinterSettingsModel printer = await _requirePrinterSettings();
        // ESC p 0 25 250
        final List<int> bytes = <int>[27, 112, 0, 25, 250];

        _logger.info(
          eventType: 'open_cash_drawer_attempt',
          entityId: printer.deviceAddress,
          message: 'Attempting to open cash drawer.',
        );

        await _sendBytesToPrinter(printer: printer, bytes: bytes);

        _logger.info(
          eventType: 'open_cash_drawer_success',
          entityId: printer.deviceAddress,
          message: 'Cash drawer opened.',
        );
      } on AppException catch (error) {
        _logger.warn(
          eventType: 'open_cash_drawer_failure',
          entityId: entityId,
          message: 'Cash drawer opening failed (AppException).',
          error: error,
        );
        // Requirement: "Ensure no crash if printer is disconnected"
        // Also "Do not affect print logic or transaction flow"
        // So we swallow the error after logging.
      } catch (error) {
        _logger.error(
          eventType: 'open_cash_drawer_failure',
          entityId: entityId,
          message: 'Cash drawer opening failed (Unexpected).',
          error: error,
        );
      }
    });
  }

  Future<List<PrinterDeviceOption>> getBondedDevices() async {
    try {
      final List<BluetoothDevice> devices = await FlutterBluetoothSerial
          .instance
          .getBondedDevices();
      return devices
          .map(
            (BluetoothDevice device) => PrinterDeviceOption(
              name: device.name ?? device.address,
              address: device.address,
            ),
          )
          .toList(growable: false);
    } on MissingPluginException {
      // Bluetooth plugin is not available on this platform (e.g. Windows).
      // Return empty list so callers can degrade gracefully.
      return const <PrinterDeviceOption>[];
    } catch (error) {
      throw PrinterException('Failed to load bonded printers: $error');
    }
  }

  /// Returns `true` if the bluetooth serial plugin responds on this platform.
  Future<bool> isBluetoothAvailable() async {
    try {
      await FlutterBluetoothSerial.instance.getBondedDevices();
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      // Plugin exists but threw a runtime error (e.g. permission denied).
      // Bluetooth is still "available" on the platform — the user can fix it.
      return true;
    }
  }

  Future<void> savePrinterSettings({
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
    PrinterConnectionType connectionType = PrinterConnectionType.bluetooth,
    String? ipAddress,
    int? port,
  }) async {
    final SettingsRepository? settingsRepository = _settingsRepository;
    if (settingsRepository == null) {
      throw PrinterException('Printer settings repository is not configured.');
    }
    await settingsRepository.savePrinterSettings(
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      paperWidth: paperWidth,
      connectionType: connectionType,
      ipAddress: ipAddress,
      port: port,
    );
  }

  Future<void> printTestPage({
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
    PrinterConnectionType connectionType = PrinterConnectionType.bluetooth,
    String? ipAddress,
    int? port,
  }) async {
    await _runSerialized(() async {
      final String entityId = _printerEntityId(
        connectionType: connectionType,
        deviceAddress: deviceAddress,
        ipAddress: ipAddress,
        port: port,
      );
      try {
        final PrinterSettingsModel printer = PrinterSettingsModel(
          id: 0,
          deviceName: deviceName,
          deviceAddress: deviceAddress,
          paperWidth: paperWidth,
          isActive: true,
          connectionType: connectionType,
          ipAddress: ipAddress,
          port: port,
        );
        final List<int> bytes = await _buildTestPageBytes(printer: printer);
        await _sendBytesToPrinter(printer: printer, bytes: bytes);
        _logger.info(
          eventType: 'print_test_success',
          entityId: entityId,
          message: 'Printer test page printed.',
          metadata: <String, Object?>{
            'device_name': deviceName,
            'paper_width': paperWidth,
            'connection_type': connectionType.name,
          },
        );
      } on AppException {
        _logger.warn(
          eventType: 'print_test_failure',
          entityId: entityId,
          message: 'Printer test page failed.',
          metadata: <String, Object?>{
            'device_name': deviceName,
            'connection_type': connectionType.name,
          },
        );
        rethrow;
      } catch (error) {
        _logger.error(
          eventType: 'print_test_failure',
          entityId: entityId,
          message: 'Printer test page failed.',
          metadata: <String, Object?>{
            'device_name': deviceName,
            'connection_type': connectionType.name,
          },
          error: error,
        );
        throw PrinterException('Printer test page failed: $error');
      }
    });
  }

  Future<Transaction> _requireTransaction(int transactionId) async {
    final Transaction? transaction = await _transactionRepository.getById(
      transactionId,
    );
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    return transaction;
  }

  PrintJobRepository get _requiredPrintJobRepository {
    final PrintJobRepository? printJobRepository = _printJobRepository;
    if (printJobRepository == null) {
      throw PrinterException(
        'Print job repository is not configured.',
        operatorMessage: AppStrings.printRetryRecommended,
      );
    }
    return printJobRepository;
  }

  Future<PrinterSettingsModel> _requirePrinterSettings() async {
    final SettingsRepository? settingsRepository = _settingsRepository;
    if (settingsRepository == null) {
      debugPrint(
        '[KITCHEN_PRINT] _requirePrinterSettings'
        ' FAILED — settingsRepository is null',
      );
      throw PrinterException('Printer settings repository is not configured.');
    }

    final PrinterSettingsModel? printer = await settingsRepository
        .getActivePrinterSettings();
    if (printer == null) {
      debugPrint(
        '[KITCHEN_PRINT] _requirePrinterSettings'
        ' FAILED — no active printer row in DB',
      );
      throw PrinterException('No active printer is configured.');
    }
    debugPrint(
      '[KITCHEN_PRINT] _requirePrinterSettings'
      ' type=${printer.connectionType.name}'
      ' host=${printer.ipAddress} port=${printer.port}'
      ' deviceAddr=${printer.deviceAddress}',
    );
    return printer;
  }

  Future<_PrintableOrder> _loadPrintableOrder(
    Transaction transaction, {
    required PrintJobTarget target,
  }) async {
    final List<TransactionLine> lines = await _loadPrintableLines(
      transaction: transaction,
      target: target,
    );
    final List<_PrintableLine> printableLines = <_PrintableLine>[];

    for (final TransactionLine line in lines) {
      final List<OrderModifier> modifiers = await _transactionRepository
          .getModifiersByLine(line.id);
      final List<BreakfastCookingInstructionRecord> cookingInstructions =
          await _transactionRepository.getBreakfastCookingInstructionsByLine(
            line.id,
          );
      final bool isBreakfastLine =
          line.pricingMode == TransactionLinePricingMode.set;

      if (isBreakfastLine) {
        printableLines.add(
          _PrintableLine(
            line: line,
            modifiers: modifiers
                .map(
                  (OrderModifier modifier) => _PrintableModifier(
                    label: modifier.itemName,
                    receiptLabel: const BreakfastModifierRenderer()
                        .receiptLabel(modifier),
                    extraPriceMinor: modifier.priceEffectMinor > 0
                        ? modifier.priceEffectMinor
                        : modifier.extraPriceMinor,
                    isAdd: modifier.action == ModifierAction.add,
                    showOnKitchen: _showModifierOnKitchen(modifier),
                    showOnReceipt: _showModifierOnReceipt(modifier),
                    kitchenLabel: const BreakfastModifierRenderer()
                        .kitchenLabel(modifier),
                    chargeReason: modifier.chargeReason,
                    action: modifier.action,
                    sourceGroupId: modifier.sourceGroupId,
                    uiSection: modifier.uiSection,
                    quantity: modifier.quantity,
                    sortKey: modifier.sortKey,
                  ),
                )
                .toList(growable: false),
            cookingInstructions: cookingInstructions
                .map(
                  (BreakfastCookingInstructionRecord instruction) =>
                      _PrintableCookingInstruction(
                        itemName: instruction.itemName,
                        instructionLabel: instruction.instructionLabel,
                        quantity: instruction.appliedQuantity,
                        sortKey: instruction.sortKey,
                      ),
                )
                .toList(growable: false),
          ),
        );
      } else {
        final OrderModifier? breadTypeModifier =
            _detectKitchenSandwichBreadTypeModifier(modifiers);
        final String printableProductName = _mergeKitchenProductNameWithBread(
          productName: line.productName,
          breadTypeLabel: breadTypeModifier?.itemName,
        );
        printableLines.add(
          _PrintableLine(
            line: line.copyWith(productName: printableProductName),
            modifiers: modifiers
                .where(
                  (OrderModifier modifier) =>
                      breadTypeModifier == null ||
                      modifier.uuid != breadTypeModifier.uuid,
                )
                .map(
                  (OrderModifier modifier) => _PrintableModifier(
                    label: modifier.itemName,
                    receiptLabel:
                        '${modifier.action == ModifierAction.add ? '+' : '-'} ${modifier.itemName}',
                    extraPriceMinor: modifier.extraPriceMinor,
                    isAdd: modifier.action == ModifierAction.add,
                    showOnKitchen: true,
                    showOnReceipt: true,
                    kitchenLabel: modifier.itemName,
                    chargeReason: modifier.chargeReason,
                    action: modifier.action,
                    sourceGroupId: modifier.sourceGroupId,
                    uiSection: modifier.uiSection,
                    quantity: modifier.quantity,
                    sortKey: modifier.sortKey,
                  ),
                )
                .toList(growable: false),
            cookingInstructions: const <_PrintableCookingInstruction>[],
          ),
        );
      }
    }

    return _PrintableOrder(transaction: transaction, lines: printableLines);
  }

  Future<List<TransactionLine>> _loadPrintableLines({
    required Transaction transaction,
    required PrintJobTarget target,
  }) async {
    final List<TransactionLine> lines = await _transactionRepository.getLines(
      transaction.id,
    );
    if (target != PrintJobTarget.kitchen) {
      return lines;
    }
    return _loadKitchenEligibleLines(lines);
  }

  Future<List<TransactionLine>> _loadKitchenEligibleLines(
    List<TransactionLine> lines,
  ) async {
    final ProductRepository? productRepository = _productRepository;
    if (productRepository == null) {
      return List<TransactionLine>.from(lines, growable: false);
    }

    final product = await productRepository.getSystemCustomSaleProduct();
    if (product == null ||
        !_customSalePolicyService.isCustomSaleProduct(product)) {
      return List<TransactionLine>.from(lines, growable: false);
    }

    return _customSalePolicyService.kitchenRelevantLines(
      lines,
      customSaleProductId: product.id,
    );
  }

  Future<bool> _shouldSkipKitchenPrintForTransaction(
    Transaction transaction,
  ) async {
    final List<TransactionLine> lines = await _transactionRepository.getLines(
      transaction.id,
    );
    if (lines.isEmpty) {
      return false;
    }
    final List<TransactionLine> kitchenEligibleLines =
        await _loadKitchenEligibleLines(lines);
    return kitchenEligibleLines.isEmpty;
  }

  PrintJob _buildSkippedKitchenPrintJob(int transactionId) {
    final DateTime now = DateTime.now();
    return PrintJob(
      id: 0,
      transactionId: transactionId,
      target: PrintJobTarget.kitchen,
      status: PrintJobStatus.printed,
      createdAt: now,
      updatedAt: now,
      attemptCount: 0,
      lastAttemptAt: null,
      completedAt: now,
      lastError: null,
    );
  }

  PaymentRepository get _requiredPaymentRepository {
    final PaymentRepository? paymentRepository = _paymentRepository;
    if (paymentRepository == null) {
      throw PrinterException('Payment repository is not configured.');
    }
    return paymentRepository;
  }

  Future<List<int>> _buildKitchenTicketBytes({
    required PrinterSettingsModel printer,
    required _PrintableOrder order,
  }) async {
    final Generator generator = await _buildGenerator(printer.paperWidth);
    final List<int> bytes = <int>[];
    bytes.addAll(generator.reset());
    final List<String> headerLines = _buildKitchenHeaderLines(
      order.transaction,
    );

    bytes.addAll(
      generator.text(
        'HALFWAY CAFE',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    for (final String headerLine in headerLines) {
      bytes.addAll(
        generator.text(
          _sanitizeKitchenLine(headerLine),
          styles: headerLine.trimLeft().startsWith('Order #')
              ? const PosStyles(align: PosAlign.left, bold: true)
              : const PosStyles(align: PosAlign.left),
        ),
      );
    }
    bytes.addAll(generator.feed(1));

    for (int index = 0; index < order.lines.length; index += 1) {
      final _PrintableLine line = order.lines[index];
      bytes.addAll(
        generator.text(
          _sanitizeKitchenLine(_formatKitchenMainLine(line)),
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
      );
      for (final _KitchenTextRow row in _buildKitchenProductDetailRows(line)) {
        bytes.addAll(
          generator.text(
            _sanitizeKitchenLine(row.text),
            styles: _kitchenTextRowStyles(row.kind),
          ),
        );
      }
      if (index != order.lines.length - 1) {
        bytes.addAll(generator.feed(1));
        bytes.addAll(
          generator.text(
            _sanitizeKitchenLine('-------------------------'),
            styles: const PosStyles(align: PosAlign.left),
          ),
        );
      }
    }

    bytes.addAll(
      generator.text(
        _sanitizeKitchenLine(_kitchenSeparator),
        styles: const PosStyles(align: PosAlign.left),
      ),
    );
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  PosStyles _kitchenTextRowStyles(_KitchenTextRowKind kind) {
    switch (kind) {
      case _KitchenTextRowKind.standard:
        return const PosStyles(align: PosAlign.left);
      case _KitchenTextRowKind.instruction:
        return const PosStyles(align: PosAlign.left, bold: true);
      case _KitchenTextRowKind.extra:
        return const PosStyles(align: PosAlign.left);
    }
  }

  Future<List<int>> _buildReceiptBytes({
    required PrinterSettingsModel printer,
    required _PrintableOrder order,
    required Payment payment,
  }) async {
    final Generator generator = await _buildGenerator(printer.paperWidth);
    final List<int> bytes = <int>[];
    bytes.addAll(generator.reset());

    bytes.addAll(
      generator.text(
        _businessName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        _businessAddress,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        _businessPhone,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        _kitchenSeparator,
        styles: const PosStyles(align: PosAlign.left),
      ),
    );
    bytes.addAll(
      generator.text(
        'Receipt',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Order #${order.transaction.id}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        DateFormatter.formatDefault(payment.paidAt),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        _kitchenSeparator,
        styles: const PosStyles(align: PosAlign.left),
      ),
    );

    for (int index = 0; index < order.lines.length; index += 1) {
      final _PrintableLine line = order.lines[index];
      bytes.addAll(
        generator.row(<PosColumn>[
          PosColumn(
            text: '${line.line.quantity}x ${line.line.productName}',
            width: 8,
          ),
          PosColumn(
            text: CurrencyFormatter.fromMinor(line.line.lineTotalMinor),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
      for (final _ReceiptModifierRow modifier in _buildReceiptModifierRows(
        line.modifiers,
      )) {
        bytes.addAll(generator.text(modifier.label));
      }
      for (final _PrintableCookingInstruction instruction
          in line.cookingInstructions) {
        bytes.addAll(generator.text(_buildReceiptInstructionLine(instruction)));
      }
      if (index != order.lines.length - 1) {
        bytes.addAll(generator.feed(1));
      }
    }

    bytes.addAll(
      generator.text(
        _kitchenSeparator,
        styles: const PosStyles(align: PosAlign.left),
      ),
    );
    if (order.transaction.discountAmountMinor > 0) {
      bytes.addAll(
        generator.row(<PosColumn>[
          PosColumn(
            text: 'Discount',
            width: 8,
            styles: PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text:
                '-${CurrencyFormatter.fromMinor(order.transaction.discountAmountMinor)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    bytes.addAll(
      generator.row(<PosColumn>[
        PosColumn(
          text: 'TOTAL',
          width: 8,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: CurrencyFormatter.fromMinor(order.transaction.totalAmountMinor),
          width: 4,
          styles: const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
          ),
        ),
      ]),
    );
    bytes.addAll(
      generator.text(
        _kitchenSeparator,
        styles: const PosStyles(align: PosAlign.left),
      ),
    );
    bytes.addAll(
      generator.text(
        'Payment: ${payment.method.name.toUpperCase()}',
        styles: const PosStyles(align: PosAlign.left),
      ),
    );
    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        'Thank you for your visit!',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  List<String> _buildKitchenProductBlock(_PrintableLine line) {
    final List<String> rows = <String>[_formatKitchenMainLine(line)];
    rows.addAll(_buildKitchenProductDetailRows(line).map((row) => row.text));
    return rows;
  }

  List<_ReceiptModifierRow> _buildReceiptModifierRows(
    List<_PrintableModifier> modifiers,
  ) {
    final List<_ReceiptModifierRow> rows = <_ReceiptModifierRow>[];
    for (final _PrintableModifier modifier in modifiers) {
      if (!modifier.showOnReceipt) continue;
      final String prefix = modifier.action == ModifierAction.remove
          ? '-'
          : '+';
      final String quantitySuffix = modifier.quantity > 1
          ? ' x${modifier.quantity}'
          : '';
      final String label =
          '  $prefix ${_sanitizeReceiptText(modifier.label)}$quantitySuffix';
      rows.add(_ReceiptModifierRow(label: label));
    }
    return rows;
  }

  String _buildReceiptInstructionLine(
    _PrintableCookingInstruction instruction,
  ) {
    return '  ${_sanitizeReceiptText(instruction.itemName)}: '
        '${_sanitizeReceiptText(instruction.instructionLabel).toUpperCase()}';
  }

  String _sanitizeReceiptText(String value) {
    final String indent = RegExp(r'^\s*').stringMatch(value) ?? '';
    final String content = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return '$indent${_sanitizeKitchenLine(content)}';
  }

  String _formatReceiptColumns({required String left, required String right}) {
    final String safeLeft = _sanitizeReceiptText(left);
    final String safeRight = _sanitizeReceiptText(right);
    final int spacing =
        (_kitchenTicketWidth - safeLeft.length - safeRight.length).clamp(
          1,
          _kitchenTicketWidth,
        );
    return '$safeLeft${' ' * spacing}$safeRight';
  }

  List<_KitchenTextRow> _buildKitchenProductDetailRows(_PrintableLine line) {
    final List<_KitchenTextRow> rows = <_KitchenTextRow>[];
    final _KitchenModifierSections sections = _buildKitchenModifierSections(
      line,
    );
    final List<_PrintableCookingInstruction> notes =
        line.cookingInstructions.toList(growable: false)..sort(
          (_PrintableCookingInstruction a, _PrintableCookingInstruction b) =>
              a.sortKey.compareTo(b.sortKey),
        );
    if (sections.included.isNotEmpty) {
      rows.addAll(
        _wrapKitchenJoinedItems(
          prefix: '  ',
          values: sections.included,
          separator: ' | ',
        ).map(
          (text) =>
              _KitchenTextRow(text: text, kind: _KitchenTextRowKind.standard),
        ),
      );
    }
    final List<_KitchenSectionBlock> blocks = <_KitchenSectionBlock>[
      _KitchenSectionBlock(
        title: 'REMOVE:',
        prefix: '  - ',
        values: sections.removes,
      ),
      _KitchenSectionBlock(
        title: 'ADD:',
        prefix: '  + ',
        values: sections.adds,
      ),
      _KitchenSectionBlock(
        title: 'SAUCE:',
        prefix: '  + ',
        values: sections.sauces,
      ),
      _KitchenSectionBlock(
        title: 'NOTE:',
        prefix: '  ',
        values: notes
            .map(_formatKitchenInstructionValue)
            .toList(growable: false),
      ),
    ];

    bool hasPreviousSection = false;
    for (final _KitchenSectionBlock block in blocks) {
      if (block.values.isEmpty) continue;
      final bool needsLeadingGap =
          hasPreviousSection || rows.isNotEmpty || block.title == 'SAUCE:';
      if (needsLeadingGap) {
        rows.add(
          const _KitchenTextRow(text: '', kind: _KitchenTextRowKind.standard),
        );
      }
      if (block.title.isNotEmpty) {
        rows.add(
          _KitchenTextRow(
            text: block.title,
            kind: _KitchenTextRowKind.standard,
          ),
        );
      }
      for (final String value in block.values) {
        rows.addAll(
          _wrapKitchenValue(prefix: block.prefix, value: value).map(
            (text) =>
                _KitchenTextRow(text: text, kind: _KitchenTextRowKind.standard),
          ),
        );
      }
      hasPreviousSection = true;
    }
    return rows;
  }

  _KitchenModifierSections _buildKitchenModifierSections(_PrintableLine line) {
    final bool separateSauces = _shouldSeparateKitchenSauces(line);
    final List<_PrintableModifier> sorted =
        line.modifiers
            .where((modifier) => modifier.showOnKitchen)
            .toList(growable: true)
          ..sort(
            (_PrintableModifier a, _PrintableModifier b) =>
                a.sortKey.compareTo(b.sortKey),
          );
    final List<String> included = <String>[];
    final List<String> adds = <String>[];
    final List<String> sauces = <String>[];
    final List<String> removes = <String>[];

    for (final _PrintableModifier modifier in sorted) {
      switch (modifier.chargeReason) {
        case ModifierChargeReason.includedChoice:
          if (separateSauces && _isKitchenSauceModifier(modifier)) {
            sauces.add(_formatModifierValue(modifier));
          } else {
            included.add(_formatModifierValue(modifier));
          }
          break;
        case ModifierChargeReason.freeSwap:
        case ModifierChargeReason.paidSwap:
          _appendKitchenAddOrSauce(
            target: modifier,
            adds: adds,
            sauces: sauces,
            separateSauces: separateSauces,
          );
          break;
        case ModifierChargeReason.extraAdd:
          _appendKitchenAddOrSauce(
            target: modifier,
            adds: adds,
            sauces: sauces,
            separateSauces: separateSauces,
          );
          break;
        case ModifierChargeReason.removalDiscount:
        case ModifierChargeReason.comboDiscount:
          break;
        case null:
          switch (modifier.action) {
            case ModifierAction.choice:
              if (separateSauces && _isKitchenSauceModifier(modifier)) {
                sauces.add(_formatModifierValue(modifier));
              } else {
                included.add(_formatModifierValue(modifier));
              }
              break;
            case ModifierAction.remove:
              removes.add(_formatModifierValue(modifier));
              break;
            case ModifierAction.add:
              _appendKitchenAddOrSauce(
                target: modifier,
                adds: adds,
                sauces: sauces,
                separateSauces: separateSauces,
              );
              break;
          }
          break;
      }
    }

    return _KitchenModifierSections(
      included: included,
      adds: adds,
      sauces: sauces,
      removes: removes,
    );
  }

  List<String> _buildKitchenHeaderLines(Transaction transaction) {
    return <String>[
      _kitchenSeparator,
      'KITCHEN TICKET',
      'Order #${transaction.id}',
      _alignKitchenRight(_formatKitchenTime(transaction.createdAt)),
      _alignKitchenRight(_formatKitchenDate(transaction.createdAt)),
      _kitchenSeparator,
    ];
  }

  String _formatKitchenMainLine(_PrintableLine line) {
    return _formatKitchenColumns(
      left:
          '${line.line.quantity}x ${_normalizeKitchenText(line.line.productName)}',
      right: CurrencyFormatter.fromMinor(line.line.lineTotalMinor),
      uppercaseLeft: false,
    );
  }

  OrderModifier? _detectKitchenSandwichBreadTypeModifier(
    List<OrderModifier> modifiers,
  ) {
    for (final OrderModifier modifier in modifiers) {
      if (modifier.action != ModifierAction.choice) {
        continue;
      }
      final String normalized = _normalizeKitchenText(modifier.itemName);
      if (normalized == 'ROLL' ||
          normalized == 'SANDWICH' ||
          normalized == 'BAGUETTE') {
        return modifier;
      }
    }
    return null;
  }

  String _mergeKitchenProductNameWithBread({
    required String productName,
    required String? breadTypeLabel,
  }) {
    if (breadTypeLabel == null || breadTypeLabel.trim().isEmpty) {
      return productName;
    }
    final String normalizedProductName = _normalizeKitchenText(productName);
    final String normalizedBreadType = _normalizeKitchenText(breadTypeLabel);
    if (normalizedProductName.endsWith(' $normalizedBreadType') ||
        normalizedProductName == normalizedBreadType) {
      return productName;
    }
    return '${productName.trim()} ${breadTypeLabel.trim()}';
  }

  String _formatKitchenInstructionValue(
    _PrintableCookingInstruction instruction,
  ) {
    final String item = _normalizeKitchenText(instruction.itemName);
    final String label = _normalizeKitchenText(instruction.instructionLabel);
    return '$item: $label';
  }

  void _appendKitchenAddOrSauce({
    required _PrintableModifier target,
    required List<String> adds,
    required List<String> sauces,
    required bool separateSauces,
  }) {
    final String value = _formatModifierValue(target);
    if (separateSauces && _isKitchenSauceModifier(target)) {
      sauces.add(value);
      return;
    }
    adds.add(value);
  }

  bool _isBurgerKitchenProduct(_PrintableLine line) {
    final String productName = _normalizeKitchenText(line.line.productName);
    return productName.contains('BURGER');
  }

  bool _isSandwichKitchenProduct(_PrintableLine line) {
    if (line.line.pricingMode == TransactionLinePricingMode.set) {
      return false;
    }
    final String productName = _normalizeKitchenText(line.line.productName);
    return productName.endsWith(' ROLL') ||
        productName.endsWith(' SANDWICH') ||
        productName.endsWith(' BAGUETTE');
  }

  bool _shouldSeparateKitchenSauces(_PrintableLine line) {
    return _isBurgerKitchenProduct(line) || _isSandwichKitchenProduct(line);
  }

  bool _isKitchenSauceModifier(_PrintableModifier modifier) {
    if (modifier.uiSection == ModifierUiSection.sauces) {
      return true;
    }
    final String label = _normalizeKitchenText(modifier.label);
    return label.contains('SAUCE') || label == 'MAYO' || label == 'BBQ';
  }

  List<String> _wrapKitchenJoinedItems({
    required String prefix,
    required List<String> values,
    required String separator,
  }) {
    final List<String> rows = <String>[];
    String current = prefix;
    for (final String value in values) {
      final String token = _normalizeKitchenText(value);
      final String candidate = current == prefix
          ? '$prefix$token'
          : '$current$separator$token';
      if (candidate.length <= _kitchenTicketWidth) {
        current = candidate;
        continue;
      }
      if (current != prefix) {
        rows.add(current);
      }
      final List<String> wrapped = _wrapKitchenValue(
        prefix: prefix,
        value: token,
      );
      if (wrapped.isEmpty) {
        current = prefix;
        continue;
      }
      rows.addAll(wrapped.take(wrapped.length - 1));
      current = wrapped.last;
    }
    if (current != prefix) {
      rows.add(current);
    }
    return rows;
  }

  List<String> _wrapKitchenValue({
    required String prefix,
    required String value,
  }) {
    final String normalized = _normalizeKitchenText(value);
    final int contentWidth = _kitchenTicketWidth - prefix.length;
    if (contentWidth <= 0) {
      return <String>[prefix];
    }
    if (normalized.length <= contentWidth) {
      return <String>['$prefix$normalized'];
    }

    final List<String> rows = <String>[];
    for (final String chunk in _wrapKitchenPlainText(
      value: normalized,
      width: contentWidth,
    )) {
      rows.add('$prefix$chunk');
    }
    return rows;
  }

  String _formatKitchenColumns({
    required String left,
    required String right,
    bool uppercaseLeft = true,
  }) {
    final String safeRight = _sanitizeKitchenLine(right.trim());
    final String safeLeft = uppercaseLeft
        ? _normalizeKitchenText(left)
        : _sanitizeKitchenLine(left.trim());
    final int spacing =
        (_kitchenTicketWidth - safeLeft.length - safeRight.length).clamp(
          1,
          _kitchenTicketWidth,
        );
    return '$safeLeft${' ' * spacing}$safeRight';
  }

  String _alignKitchenRight(String value) {
    final String normalized = _sanitizeKitchenLine(value.trim());
    if (normalized.length >= _kitchenTicketWidth) {
      return normalized;
    }
    return '${' ' * (_kitchenTicketWidth - normalized.length)}$normalized';
  }

  String _centerKitchenText(String value) {
    final String normalized = value.trim();
    if (normalized.length >= _kitchenTicketWidth) {
      return normalized;
    }
    final int leftPadding = (_kitchenTicketWidth - normalized.length) ~/ 2;
    return '${' ' * leftPadding}$normalized';
  }

  String _formatModifierValue(_PrintableModifier modifier) {
    final String normalized = _normalizeKitchenText(modifier.label);
    if (modifier.quantity > 1) {
      return '$normalized x${modifier.quantity}';
    }
    return normalized;
  }

  String _formatKitchenTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatKitchenDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String year = value.year.toString();
    return '$day/$month/$year';
  }

  String _normalizeKitchenText(String value) {
    return _sanitizeKitchenLine(
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase(),
    );
  }

  List<String> _wrapKitchenPlainText({
    required String value,
    required int width,
  }) {
    final String normalized = _sanitizeKitchenLine(
      value.trim().replaceAll(RegExp(r'\s+'), ' '),
    );
    if (width <= 0 || normalized.isEmpty) {
      return <String>[];
    }
    if (normalized.length <= width) {
      return <String>[normalized];
    }

    final List<String> rows = <String>[];
    String remaining = normalized;
    while (remaining.isNotEmpty) {
      if (remaining.length <= width) {
        rows.add(remaining);
        break;
      }
      int splitIndex = remaining.lastIndexOf(' ', width);
      if (splitIndex <= 0) {
        splitIndex = width;
      }
      rows.add(remaining.substring(0, splitIndex).trimRight());
      remaining = remaining.substring(splitIndex).trimLeft();
    }
    return rows;
  }

  String _sanitizeKitchenLine(String value) {
    final String normalized = value
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2012', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2015', '-')
        .replaceAll('\u2212', '-')
        .replaceAll('\u2026', '...')
        .replaceAll('\u2018', '\'')
        .replaceAll('\u2019', '\'')
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2022', '-');
    final StringBuffer buffer = StringBuffer();
    for (final int rune in normalized.runes) {
      if (rune == 163 || (rune >= 32 && rune <= 126)) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().trimRight();
  }

  @visibleForTesting
  Future<String> buildKitchenTicketPreviewForTesting({
    required int transactionId,
  }) async {
    final Transaction transaction = await _requireTransaction(transactionId);
    final _PrintableOrder order = await _loadPrintableOrder(
      transaction,
      target: PrintJobTarget.kitchen,
    );
    final List<String> lines = <String>[
      _centerKitchenText('HALFWAY CAFE'),
      ..._buildKitchenHeaderLines(order.transaction),
      '',
    ];
    final List<List<String>> blocks = order.lines
        .map(_buildKitchenProductBlock)
        .where((List<String> block) => block.isNotEmpty)
        .toList(growable: false);
    for (int index = 0; index < blocks.length; index += 1) {
      lines.addAll(blocks[index]);
      if (index != blocks.length - 1) {
        lines.add('');
        lines.add('-------------------------');
      }
    }
    lines.add(_kitchenSeparator);
    return lines.map(_sanitizeKitchenLine).join('\n');
  }

  @visibleForTesting
  Future<String> buildReceiptPreviewForTesting({
    required int transactionId,
  }) async {
    final Transaction transaction = await _requireTransaction(transactionId);
    final _PrintableOrder order = await _loadPrintableOrder(
      transaction,
      target: PrintJobTarget.receipt,
    );
    final Payment payment = await _requirePayment(transactionId);
    final List<String> lines = <String>[
      _centerKitchenText(_businessName),
      _centerKitchenText(_businessAddress),
      _centerKitchenText(_businessPhone),
      _kitchenSeparator,
      _centerKitchenText('Receipt'),
      _centerKitchenText('Order #${order.transaction.id}'),
      _centerKitchenText(DateFormatter.formatDefault(payment.paidAt)),
      _kitchenSeparator,
    ];

    for (int index = 0; index < order.lines.length; index += 1) {
      final _PrintableLine line = order.lines[index];
      lines.add(
        _formatReceiptColumns(
          left: '${line.line.quantity}x ${line.line.productName}',
          right: CurrencyFormatter.fromMinor(line.line.lineTotalMinor),
        ),
      );
      for (final _ReceiptModifierRow modifier in _buildReceiptModifierRows(
        line.modifiers,
      )) {
        lines.add(modifier.label);
      }
      for (final _PrintableCookingInstruction instruction
          in line.cookingInstructions) {
        lines.add(_buildReceiptInstructionLine(instruction));
      }
      if (index != order.lines.length - 1) {
        lines.add('');
      }
    }

    lines.add(_kitchenSeparator);
    if (order.transaction.discountAmountMinor > 0) {
      lines.add(
        _formatReceiptColumns(
          left: 'Discount',
          right:
              '-${CurrencyFormatter.fromMinor(order.transaction.discountAmountMinor)}',
        ),
      );
    }
    lines.add(
      _formatReceiptColumns(
        left: 'TOTAL',
        right: CurrencyFormatter.fromMinor(order.transaction.totalAmountMinor),
      ),
    );
    lines.add(_kitchenSeparator);
    lines.add('Payment: ${payment.method.name.toUpperCase()}');
    lines.add('');
    lines.add(_centerKitchenText('Thank you for your visit!'));

    return lines.map(_sanitizeKitchenLine).join('\n');
  }

  bool _showModifierOnKitchen(OrderModifier modifier) {
    return modifier.chargeReason != ModifierChargeReason.removalDiscount &&
        modifier.chargeReason != ModifierChargeReason.comboDiscount;
  }

  bool _showModifierOnReceipt(OrderModifier modifier) {
    return _showModifierOnKitchen(modifier);
  }

  Future<List<int>> _buildZReportBytes({
    required PrinterSettingsModel printer,
    required ShiftReport report,
  }) async {
    final Generator generator = await _buildGenerator(printer.paperWidth);
    final List<int> bytes = <int>[];
    bytes.addAll(generator.reset());

    bytes.addAll(
      generator.text(
        'Z REPORT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        'Shift #${report.shiftId}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(_reportRow(generator, 'Paid Orders', report.paidCount));
    bytes.addAll(_amountRow(generator, 'Gross Sales', report.paidTotalMinor));
    bytes.addAll(_reportRow(generator, 'Refund Count', report.refundCount));
    bytes.addAll(
      _amountRow(generator, 'Refund Total', report.refundTotalMinor),
    );
    bytes.addAll(_amountRow(generator, 'Net Sales', report.netSalesMinor));
    bytes.addAll(_reportRow(generator, 'Open Orders', report.openCount));
    bytes.addAll(_amountRow(generator, 'Open Total', report.openTotalMinor));
    bytes.addAll(
      _reportRow(generator, 'Cancelled Orders', report.cancelledCount),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(_reportRow(generator, 'Cash Payments', report.cashCount));
    bytes.addAll(_amountRow(generator, 'Cash Total', report.cashTotalMinor));
    bytes.addAll(_reportRow(generator, 'Card Payments', report.cardCount));
    bytes.addAll(_amountRow(generator, 'Card Total', report.cardTotalMinor));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<List<int>> _buildCashierZReportBytes({
    required PrinterSettingsModel printer,
    required CashierProjectedReport report,
  }) async {
    final Generator generator = await _buildGenerator(printer.paperWidth);
    final List<int> bytes = <int>[];
    bytes.addAll(generator.reset());
    final DateTime generatedAt = report.generatedAt ?? DateTime.now();

    bytes.addAll(
      generator.text(
        'Z REPORT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    if (_hasText(report.businessName)) {
      bytes.addAll(
        generator.text(
          report.businessName!,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }
    if (_hasText(report.businessAddress)) {
      bytes.addAll(
        generator.text(
          report.businessAddress!,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    bytes.addAll(
      generator.text(
        DateFormatter.formatDate(generatedAt),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        DateFormatter.formatTime(generatedAt),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    if (report.shiftId != null) {
      bytes.addAll(
        generator.text(
          'Shift #${report.shiftId}',
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (_hasText(report.operatorName)) {
      bytes.addAll(
        generator.text(
          'Operator: ${report.operatorName}',
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    bytes.addAll(generator.hr());
    bytes.addAll(
      _amountRow(generator, 'Gross Sales', report.visibleGrossSalesMinor),
    );
    bytes.addAll(
      _amountRow(generator, 'Refund Total', report.visibleRefundTotalMinor),
    );
    bytes.addAll(
      _amountRow(generator, 'Net Sales', report.visibleNetSalesMinor),
    );
    bytes.addAll(_reportRow(generator, 'Open Orders', report.openOrdersCount));
    bytes.addAll(
      _amountRow(generator, 'Open Total', report.visibleOpenOrdersTotalMinor),
    );
    if (report.cancelledOrdersCount > 0) {
      bytes.addAll(
        _reportRow(generator, 'Cancelled Orders', report.cancelledOrdersCount),
      );
    }
    bytes.addAll(generator.hr());
    bytes.addAll(
      _amountRow(generator, 'Gross Cash', report.visibleGrossCashMinor),
    );
    bytes.addAll(_amountRow(generator, 'Net Cash', report.visibleCashMinor));
    bytes.addAll(
      _amountRow(generator, 'Gross Card', report.visibleGrossCardMinor),
    );
    bytes.addAll(_amountRow(generator, 'Net Card', report.visibleCardMinor));
    bytes.addAll(
      _reportRow(generator, 'Total Orders', report.totalOrdersCount),
    );
    bytes.addAll(
      _amountRow(generator, 'Total Amount', report.visibleTotalMinor),
    );
    if (report.categoryBreakdown.isNotEmpty) {
      bytes.addAll(generator.hr());
      bytes.addAll(
        generator.text(
          'CATEGORY BREAKDOWN',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
      for (final line in report.categoryBreakdown) {
        bytes.addAll(
          _amountRow(
            generator,
            ReportCategoryDisplayFormatter.toEnglish(line.categoryName),
            line.visibleAmountMinor,
          ),
        );
      }
    }
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<List<int>> _buildTestPageBytes({
    required PrinterSettingsModel printer,
  }) async {
    final Generator generator = await _buildGenerator(printer.paperWidth);
    final List<int> bytes = <int>[];
    bytes.addAll(generator.reset());

    bytes.addAll(
      generator.text(
        'TEST PRINT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        printer.deviceName,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      generator.text(
        printer.deviceAddress,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        printer.connectionType == PrinterConnectionType.ethernet
            ? 'ETHERNET ${printer.resolvedAddress}:${printer.resolvedPort}'
            : 'BLUETOOTH',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        'Paper ${printer.paperWidth}mm',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(2));
    bytes.addAll(
      generator.text(
        'Currency ${CurrencyFormatter.fromMinor(1250)}',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      generator.text(
        DateFormatter.formatDefault(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<List<int>> _buildPrintJobBytes({
    required PrintJobTarget target,
    required PrinterSettingsModel printer,
    required _PrintableOrder order,
    required int transactionId,
  }) async {
    switch (target) {
      case PrintJobTarget.kitchen:
        return _buildKitchenTicketBytes(printer: printer, order: order);
      case PrintJobTarget.receipt:
        return _buildReceiptBytes(
          printer: printer,
          order: order,
          payment: await _requirePayment(transactionId),
        );
    }
  }

  List<int> _reportRow(Generator generator, String label, int count) {
    return generator.row(<PosColumn>[
      PosColumn(text: label, width: 8),
      PosColumn(
        text: '$count',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  List<int> _amountRow(Generator generator, String label, int amountMinor) {
    return generator.row(<PosColumn>[
      PosColumn(text: label, width: 8),
      PosColumn(
        text: CurrencyFormatter.fromMinor(amountMinor),
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  Future<Generator> _buildGenerator(int paperWidth) async {
    final CapabilityProfile profile = await CapabilityProfile.load();
    final Generator generator = Generator(
      paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80,
      profile,
    );
    generator.setGlobalCodeTable(_printerCodeTable);
    return generator;
  }

  @visibleForTesting
  Future<List<int>> buildZReportBytesForTesting({
    required PrinterSettingsModel printer,
    required ShiftReport report,
  }) {
    return _buildZReportBytes(printer: printer, report: report);
  }

  @visibleForTesting
  Future<List<int>> buildKitchenTicketBytesForTesting({
    required PrinterSettingsModel printer,
    required int transactionId,
  }) async {
    final Transaction transaction = await _requireTransaction(transactionId);
    final _PrintableOrder order = await _loadPrintableOrder(
      transaction,
      target: PrintJobTarget.kitchen,
    );
    return _buildKitchenTicketBytes(printer: printer, order: order);
  }

  Future<void> _sendBytesToPrinter({
    required PrinterSettingsModel printer,
    required List<int> bytes,
  }) async {
    debugPrint(
      '[KITCHEN_PRINT] _sendBytesToPrinter'
      ' transport=${printer.connectionType.name}'
      ' bytes=${bytes.length}'
      ' resolvedAddr=${printer.resolvedAddress}'
      ' resolvedPort=${printer.resolvedPort}',
    );
    switch (printer.connectionType) {
      case PrinterConnectionType.bluetooth:
        await _sendBytesViaBluetooth(printer: printer, bytes: bytes);
        return;
      case PrinterConnectionType.ethernet:
        await _sendBytesViaEthernet(printer: printer, bytes: bytes);
        return;
    }
  }

  Future<void> _sendBytesViaBluetooth({
    required PrinterSettingsModel printer,
    required List<int> bytes,
  }) async {
    BluetoothConnection? connection;
    try {
      connection = await BluetoothConnection.toAddress(printer.deviceAddress);
      connection.output.add(Uint8List.fromList(bytes));
      await connection.output.allSent;
    } catch (error) {
      throw PrinterException(
        'Failed to send data to printer ${printer.deviceName}: $error',
      );
    } finally {
      try {
        await connection?.finish();
      } catch (error, stackTrace) {
        _logger.warn(
          eventType: 'printer_bluetooth_close_failure',
          entityId: printer.deviceAddress,
          message: 'Bluetooth printer connection close failed.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<Socket> _connectNetworkPrinter(PrinterSettingsModel printer) async {
    final String host = printer.resolvedAddress;
    final int port = printer.resolvedPort;
    if (host.isEmpty) {
      throw PrinterException('Network printer host is not configured.');
    }

    try {
      return await _socketConnector(
        host,
        port,
        _networkConnectTimeout,
      ).timeout(_networkConnectTimeout);
    } on TimeoutException {
      throw PrinterException(
        'Timed out connecting to network printer $host:$port.',
      );
    } on SocketException catch (error) {
      throw PrinterException(
        'Failed to connect to network printer $host:$port: $error',
      );
    } catch (error) {
      throw PrinterException(
        'Failed to connect to network printer $host:$port: $error',
      );
    }
  }

  Future<void> _sendBytesViaEthernet({
    required PrinterSettingsModel printer,
    required List<int> bytes,
  }) async {
    Socket? socket;
    final String endpoint =
        '${printer.resolvedAddress}:${printer.resolvedPort}';
    try {
      socket = await _connectNetworkPrinter(printer);
      await _writeBytesToEthernetSocket(
        socket: socket,
        bytes: bytes,
        endpoint: endpoint,
      );
    } on AppException {
      rethrow;
    } finally {
      await _closeNetworkPrinterSocket(socket, endpoint);
    }
  }

  Future<void> _writeBytesToEthernetSocket({
    required Socket socket,
    required List<int> bytes,
    required String endpoint,
  }) async {
    try {
      socket.add(Uint8List.fromList(bytes));
    } on SocketException catch (error) {
      throw PrinterException(
        'Network printer write failed for $endpoint: $error',
      );
    } catch (error) {
      throw PrinterException(
        'Failed to write bytes to network printer $endpoint: $error',
      );
    }

    try {
      await socket.flush().timeout(_networkWriteTimeout);
    } on TimeoutException {
      throw PrinterException(
        'Timed out flushing print data to network printer $endpoint. The printer may have received a partial job.',
      );
    } on SocketException catch (error) {
      throw PrinterException(
        'Network printer flush failed for $endpoint: $error. The printer may have received a partial job.',
      );
    } catch (error) {
      throw PrinterException(
        'Failed to flush print data to network printer $endpoint: $error. The printer may have received a partial job.',
      );
    }
  }

  Future<void> _closeNetworkPrinterSocket(
    Socket? socket,
    String endpoint,
  ) async {
    if (socket == null) {
      return;
    }

    try {
      await socket.close().timeout(_networkWriteTimeout);
    } catch (error, stackTrace) {
      _logger.warn(
        eventType: 'printer_network_close_failure',
        entityId: endpoint,
        message: 'Network printer socket close failed; destroying socket.',
        error: error,
        stackTrace: stackTrace,
      );
      socket.destroy();
    }
  }

  String _printerEntityId({
    required PrinterConnectionType connectionType,
    required String deviceAddress,
    String? ipAddress,
    int? port,
  }) {
    if (connectionType == PrinterConnectionType.ethernet) {
      final String host = (ipAddress ?? deviceAddress).trim();
      final int resolvedPort = port ?? PrinterSettingsModel.defaultEthernetPort;
      return '$host:$resolvedPort';
    }
    return deviceAddress;
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  Future<PrintJob> _processPrintJob({
    required int transactionId,
    required PrintJobTarget target,
    required bool allowReprint,
    int? actorUserId,
  }) async {
    debugPrint(
      '[KITCHEN_PRINT] _processPrintJob entered'
      ' tx=$transactionId target=${target.name}'
      ' allowReprint=$allowReprint',
    );
    return _runSerialized(() async {
      _validateManualReprintContext(
        target: target,
        allowReprint: allowReprint,
        actorUserId: actorUserId,
      );
      final Transaction transaction = await _requireTransaction(transactionId);
      debugPrint(
        '[KITCHEN_PRINT] tx=$transactionId'
        ' status=${transaction.status.name}'
        ' kitchenPrinted=${transaction.kitchenPrinted}',
      );
      if (target == PrintJobTarget.kitchen &&
          await _shouldSkipKitchenPrintForTransaction(transaction)) {
        debugPrint(
          '[KITCHEN_PRINT] skipped — no kitchen-eligible lines'
          ' tx=$transactionId',
        );
        _logger.info(
          eventType: 'print_kitchen_skipped_not_required',
          entityId: transaction.uuid,
          message:
              'Kitchen print skipped because the order has no kitchen-eligible lines.',
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'manual_reprint': allowReprint,
          },
        );
        return _buildSkippedKitchenPrintJob(transactionId);
      }
      final PrintJobRepository printJobRepository = _requiredPrintJobRepository;
      final PrintJob job = await _ensurePrintJobState(
        transaction: transaction,
        target: target,
      );
      debugPrint(
        '[KITCHEN_PRINT] printJob state tx=$transactionId'
        ' jobStatus=${job.status.name}'
        ' attempts=${job.attemptCount}',
      );
      debugPrint(
        '[KITCHEN_PRINT] existing job reused'
        ' tx=$transactionId target=${target.name}'
        ' status=${job.status.name}',
      );
      if (job.isPrinted && !allowReprint) {
        debugPrint(
          '[KITCHEN_PRINT] early exit printed'
          ' tx=$transactionId target=${target.name}',
        );
        return job;
      }
      if (job.isFailed && !allowReprint) {
        debugPrint(
          '[KITCHEN_PRINT] early exit failed'
          ' tx=$transactionId target=${target.name}',
        );
        return job;
      }
      if (job.isFailed && allowReprint) {
        debugPrint(
          '[KITCHEN_PRINT] retrying failed job'
          ' tx=$transactionId target=${target.name}',
        );
      }

      bool attemptStarted = false;
      try {
        final PrintJob inProgress;
        try {
          inProgress = await printJobRepository.markInProgress(
            transactionId: transactionId,
            target: target,
            allowReprint: allowReprint,
          );
        } on PrintJobInProgressException {
          debugPrint(
            '[KITCHEN_PRINT] already printing — skip'
            ' tx=$transactionId target=${target.name}',
          );
          return printJobRepository.requireByTransactionIdAndTarget(
            transactionId: transactionId,
            target: target,
          );
        }
        debugPrint(
          '[KITCHEN_PRINT] markInProgress'
          ' tx=$transactionId target=${target.name}'
          ' jobStatus=${inProgress.status.name}',
        );
        if (inProgress.isPrinted && !allowReprint) {
          debugPrint(
            '[KITCHEN_PRINT] early exit printed'
            ' tx=$transactionId target=${target.name}',
          );
          return inProgress;
        }
        attemptStarted = true;

        final _PrintableOrder printableOrder = await _loadPrintableOrder(
          transaction,
          target: target,
        );
        debugPrint(
          '[KITCHEN_PRINT] order loaded tx=$transactionId'
          ' lines=${printableOrder.lines.length}',
        );
        final PrinterSettingsModel printer = await _requireJobPrinterSettings(
          target,
        );
        debugPrint(
          '[KITCHEN_PRINT] printer resolved tx=$transactionId'
          ' type=${printer.connectionType.name}'
          ' host=${printer.ipAddress}'
          ' port=${printer.port}'
          ' deviceAddress=${printer.deviceAddress}',
        );
        final List<int> bytes = await _buildPrintJobBytes(
          target: target,
          printer: printer,
          order: printableOrder,
          transactionId: transactionId,
        );
        debugPrint(
          '[KITCHEN_PRINT] bytes generated tx=$transactionId'
          ' count=${bytes.length}',
        );

        debugPrint(
          '[KITCHEN_PRINT] sending to printer tx=$transactionId'
          ' transport=${printer.connectionType.name}',
        );
        await _sendBytesToPrinter(printer: printer, bytes: bytes);
        debugPrint('[KITCHEN_PRINT] send SUCCESS tx=$transactionId');
        await _transactionRepository.updatePrintFlag(
          transactionId: transactionId,
          kitchenPrinted: target == PrintJobTarget.kitchen ? true : null,
          receiptPrinted: target == PrintJobTarget.receipt ? true : null,
        );
        final PrintJob printed = await printJobRepository.markPrinted(
          transactionId: transactionId,
          target: target,
        );
        debugPrint(
          '[KITCHEN_PRINT] markPrinted'
          ' tx=$transactionId target=${target.name}'
          ' attempts=${printed.attemptCount}',
        );
        if (allowReprint && actorUserId != null) {
          await _auditLogService.logActionSafely(
            actorUserId: actorUserId,
            action: switch (target) {
              PrintJobTarget.kitchen => 'kitchen_ticket_reprinted',
              PrintJobTarget.receipt => 'receipt_reprinted',
            },
            entityType: 'transaction',
            entityId: transaction.uuid,
            metadata: <String, Object?>{
              'transaction_id': transactionId,
              'target': target.name,
              'attempt_count': printed.attemptCount,
            },
          );
        }
        _logger.info(
          eventType: _successEventType(target),
          entityId: transaction.uuid,
          message: '${target.name} print completed.',
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'attempt_count': printed.attemptCount,
            'manual_reprint': allowReprint,
          },
        );
        return printed;
      } on AppException catch (error, stackTrace) {
        debugPrint(
          '[KITCHEN_PRINT] AppException tx=$transactionId'
          ' error=$error',
        );
        if (attemptStarted) {
          await printJobRepository.markFailed(
            transactionId: transactionId,
            target: target,
            error: error.toString(),
          );
          debugPrint(
            '[KITCHEN_PRINT] markFailed'
            ' tx=$transactionId target=${target.name}',
          );
        }
        _logger.warn(
          eventType: _failureEventType(target),
          entityId: transaction.uuid,
          message: '${target.name} print failed.',
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'manual_reprint': allowReprint,
          },
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      } catch (error, stackTrace) {
        debugPrint(
          '[KITCHEN_PRINT] unexpected error tx=$transactionId'
          ' error=$error',
        );
        if (attemptStarted) {
          await printJobRepository.markFailed(
            transactionId: transactionId,
            target: target,
            error: error.toString(),
          );
          debugPrint(
            '[KITCHEN_PRINT] markFailed'
            ' tx=$transactionId target=${target.name}',
          );
        }
        _logger.error(
          eventType: _failureEventType(target),
          entityId: transaction.uuid,
          message: '${target.name} print failed.',
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'manual_reprint': allowReprint,
          },
          error: error,
          stackTrace: stackTrace,
        );
        throw PrinterException(
          '${target.name} print failed: $error',
          operatorMessage: _operatorMessageForTarget(target),
        );
      }
    });
  }

  Future<PrintJob> _ensurePrintJobState({
    required Transaction transaction,
    required PrintJobTarget target,
  }) async {
    final PrintJobRepository printJobRepository = _requiredPrintJobRepository;
    final bool canPrint = switch (target) {
      PrintJobTarget.kitchen => OrderLifecyclePolicy.canPrintKitchenTicket(
        transaction.status,
      ),
      PrintJobTarget.receipt => OrderLifecyclePolicy.canPrintReceipt(
        transaction.status,
      ),
    };
    final bool alreadyPrinted = switch (target) {
      PrintJobTarget.kitchen => transaction.kitchenPrinted,
      PrintJobTarget.receipt => transaction.receiptPrinted,
    };
    debugPrint(
      '[KITCHEN_PRINT] _ensurePrintJobState'
      ' tx=${transaction.id} target=${target.name}'
      ' canPrint=$canPrint alreadyPrinted=$alreadyPrinted',
    );

    if (!canPrint && !alreadyPrinted) {
      debugPrint(
        '[KITCHEN_PRINT] REJECTED — status=${transaction.status.name}'
        ' does not allow ${target.name} print',
      );
      throw InvalidStateTransitionException(switch (target) {
        PrintJobTarget.kitchen =>
          'Kitchen ticket can be printed only for sent or paid transactions.',
        PrintJobTarget.receipt =>
          'Receipt can be printed only for paid transactions.',
      });
    }

    final PrintJob? existing = await printJobRepository
        .getByTransactionIdAndTarget(
          transactionId: transaction.id,
          target: target,
        );
    if (existing != null) {
      debugPrint(
        '[KITCHEN_PRINT] existing job found'
        ' tx=${transaction.id} status=${existing.status.name}',
      );
      return existing;
    }
    debugPrint(
      '[KITCHEN_PRINT] missing expected job row'
      ' tx=${transaction.id} target=${target.name}'
      ' alreadyPrinted=$alreadyPrinted',
    );
    throw DatabaseException(
      'Missing ${target.name} print job for transaction ${transaction.id}.',
    );
  }

  void _validateManualReprintContext({
    required PrintJobTarget target,
    required bool allowReprint,
    required int? actorUserId,
  }) {
    if (!allowReprint) {
      return;
    }
    if (actorUserId == null || actorUserId <= 0) {
      throw ValidationException(
        'Manual ${target.name} reprint requires a valid actor user id.',
      );
    }
  }

  Future<Payment> _requirePayment(int transactionId) async {
    final Payment? payment = await _requiredPaymentRepository
        .getByTransactionId(transactionId);
    if (payment == null) {
      throw NotFoundException(
        'Payment not found for transaction: $transactionId',
      );
    }
    return payment;
  }

  Future<PrinterSettingsModel> _requireJobPrinterSettings(
    PrintJobTarget target,
  ) async {
    try {
      return await _requirePrinterSettings();
    } on PrinterException catch (error) {
      throw PrinterException(
        error.message,
        operatorMessage: _operatorMessageForTarget(target),
      );
    }
  }

  String _successEventType(PrintJobTarget target) {
    switch (target) {
      case PrintJobTarget.kitchen:
        return 'print_kitchen_success';
      case PrintJobTarget.receipt:
        return 'print_receipt_success';
    }
  }

  String _failureEventType(PrintJobTarget target) {
    switch (target) {
      case PrintJobTarget.kitchen:
        return 'print_kitchen_failure';
      case PrintJobTarget.receipt:
        return 'print_receipt_failure';
    }
  }

  String _operatorMessageForTarget(PrintJobTarget target) {
    switch (target) {
      case PrintJobTarget.kitchen:
        return AppStrings.kitchenPrintRetryRequired;
      case PrintJobTarget.receipt:
        return AppStrings.receiptPrintRetryRequired;
    }
  }

  Future<T> _runSerialized<T>(Future<T> Function() action) {
    final Completer<void> release = Completer<void>();
    final Future<void> previous = _printQueue;
    _printQueue = release.future;

    return previous.then((_) => action()).whenComplete(() {
      if (!release.isCompleted) {
        release.complete();
      }
    });
  }
}

class _PrintableOrder {
  const _PrintableOrder({required this.transaction, required this.lines});

  final Transaction transaction;
  final List<_PrintableLine> lines;
}

class _PrintableLine {
  const _PrintableLine({
    required this.line,
    required this.modifiers,
    required this.cookingInstructions,
  });

  final TransactionLine line;
  final List<_PrintableModifier> modifiers;
  final List<_PrintableCookingInstruction> cookingInstructions;
}

class _PrintableModifier {
  const _PrintableModifier({
    required this.label,
    this.receiptLabel,
    required this.extraPriceMinor,
    required this.isAdd,
    required this.action,
    required this.quantity,
    required this.sortKey,
    this.showOnKitchen = true,
    this.showOnReceipt = true,
    this.kitchenLabel,
    this.chargeReason,
    this.sourceGroupId,
    this.uiSection,
  });

  final String label;
  final String? receiptLabel;
  final int extraPriceMinor;
  final bool isAdd;
  final ModifierAction action;
  final int quantity;
  final int sortKey;
  final bool showOnKitchen;
  final bool showOnReceipt;
  final String? kitchenLabel;
  final ModifierChargeReason? chargeReason;
  final int? sourceGroupId;
  final ModifierUiSection? uiSection;
}

class _PrintableCookingInstruction {
  const _PrintableCookingInstruction({
    required this.itemName,
    required this.instructionLabel,
    required this.quantity,
    required this.sortKey,
  });

  final String itemName;
  final String instructionLabel;
  final int quantity;
  final int sortKey;
}

enum _KitchenTextRowKind { standard, instruction, extra }

class _KitchenTextRow {
  const _KitchenTextRow({required this.text, required this.kind});

  final String text;
  final _KitchenTextRowKind kind;
}

class _ReceiptModifierRow {
  const _ReceiptModifierRow({required this.label});

  final String label;
}

class _KitchenSectionBlock {
  const _KitchenSectionBlock({
    required this.title,
    required this.prefix,
    required this.values,
  });

  final String title;
  final String prefix;
  final List<String> values;
}

class _KitchenModifierSections {
  const _KitchenModifierSections({
    required this.included,
    required this.adds,
    required this.sauces,
    required this.removes,
  });

  final List<String> included;
  final List<String> adds;
  final List<String> sauces;
  final List<String> removes;
}
