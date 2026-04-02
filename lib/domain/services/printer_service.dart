import 'dart:async';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/report_category_display_formatter.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/print_job_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/cashier_projected_report.dart';
import '../models/order_lifecycle_policy.dart';
import '../models/order_modifier.dart';
import '../models/payment.dart';
import '../models/print_job.dart';
import '../models/printer_device_option.dart';
import '../models/printer_settings.dart';
import '../models/shift_report.dart';
import '../models/transaction.dart';
import '../models/transaction_line.dart';
import 'audit_log_service.dart';
import 'breakfast_modifier_renderer.dart';

/// Handles ESC/POS printing through a serialized queue (in-memory mutex).
///
/// Callers must already have applied report visibility rules before calling
/// [printZReport]. This service prints the provided data as-is.
class PrinterService {
  PrinterService(
    TransactionRepository transactionRepository, {
    PaymentRepository? paymentRepository,
    PrintJobRepository? printJobRepository,
    SettingsRepository? settingsRepository,
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _transactionRepository = transactionRepository,
       _paymentRepository = paymentRepository,
       _printJobRepository = printJobRepository,
       _settingsRepository = settingsRepository,
       _auditLogService = auditLogService,
       _logger = logger;

  final TransactionRepository _transactionRepository;
  final PaymentRepository? _paymentRepository;
  final PrintJobRepository? _printJobRepository;
  final SettingsRepository? _settingsRepository;
  final AuditLogService _auditLogService;
  final AppLogger _logger;
  Future<void> _printQueue = Future<void>.value();

  Future<PrintJob> printKitchenTicket(
    int transactionId, {
    bool allowReprint = false,
  }) async {
    return _processPrintJob(
      transactionId: transactionId,
      target: PrintJobTarget.kitchen,
      allowReprint: allowReprint,
    );
  }

  Future<PrintJob> printReceipt(
    int transactionId, {
    bool allowReprint = false,
    int? actorUserId,
  }) async {
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

        await _sendToPrinter(printer: printer, bytes: bytes);
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

        await _sendToPrinter(printer: printer, bytes: bytes);
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
    } catch (error) {
      throw PrinterException('Failed to load bonded printers: $error');
    }
  }

  Future<void> savePrinterSettings({
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
  }) async {
    final SettingsRepository? settingsRepository = _settingsRepository;
    if (settingsRepository == null) {
      throw PrinterException('Printer settings repository is not configured.');
    }
    await settingsRepository.savePrinterSettings(
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      paperWidth: paperWidth,
    );
  }

  Future<void> printTestPage({
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
  }) async {
    await _runSerialized(() async {
      try {
        final PrinterSettingsModel printer = PrinterSettingsModel(
          id: 0,
          deviceName: deviceName,
          deviceAddress: deviceAddress,
          paperWidth: paperWidth,
          isActive: true,
        );
        final List<int> bytes = await _buildTestPageBytes(printer: printer);
        await _sendToPrinter(printer: printer, bytes: bytes);
        _logger.info(
          eventType: 'print_test_success',
          entityId: deviceAddress,
          message: 'Printer test page printed.',
          metadata: <String, Object?>{
            'device_name': deviceName,
            'paper_width': paperWidth,
          },
        );
      } on AppException {
        _logger.warn(
          eventType: 'print_test_failure',
          entityId: deviceAddress,
          message: 'Printer test page failed.',
          metadata: <String, Object?>{'device_name': deviceName},
        );
        rethrow;
      } catch (error) {
        _logger.error(
          eventType: 'print_test_failure',
          entityId: deviceAddress,
          message: 'Printer test page failed.',
          metadata: <String, Object?>{'device_name': deviceName},
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
      throw PrinterException('Printer settings repository is not configured.');
    }

    final PrinterSettingsModel? printer = await settingsRepository
        .getActivePrinterSettings();
    if (printer == null) {
      throw PrinterException('No active printer is configured.');
    }
    return printer;
  }

  Future<_PrintableOrder> _loadPrintableOrder(Transaction transaction) async {
    final List<TransactionLine> lines = await _transactionRepository.getLines(
      transaction.id,
    );
    final List<_PrintableLine> printableLines = <_PrintableLine>[];

    for (final TransactionLine line in lines) {
      final List<OrderModifier> modifiers =
          await _transactionRepository.getModifiersByLine(line.id);
      final bool isBreakfastLine =
          line.pricingMode == TransactionLinePricingMode.set;

      if (isBreakfastLine) {
        const BreakfastModifierRenderer renderer =
            BreakfastModifierRenderer();
        final List<BreakfastModifierRendered> rendered =
            renderer.renderAll(modifiers);
        printableLines.add(
          _PrintableLine(
            line: line,
            modifiers: rendered
                .map(
                  (BreakfastModifierRendered r) => _PrintableModifier(
                    label: r.label,
                    extraPriceMinor: r.priceEffectMinor,
                    isAdd: r.action != ModifierAction.remove,
                    showOnKitchen: r.showOnKitchen,
                    showOnReceipt: r.showOnReceipt,
                    kitchenLabel: renderer.kitchenLabel(modifiers.firstWhere(
                      (OrderModifier m) =>
                          m.itemProductId == r.itemProductId &&
                          m.chargeReason == r.chargeReason &&
                          m.action == r.action,
                      orElse: () => modifiers.first,
                    )),
                    chargeReason: r.chargeReason,
                  ),
                )
                .toList(growable: false),
          ),
        );
      } else {
        printableLines.add(
          _PrintableLine(
            line: line,
            modifiers: modifiers
                .map(
                  (OrderModifier modifier) => _PrintableModifier(
                    label:
                        '${modifier.action == ModifierAction.add ? '+' : '-'} ${modifier.itemName}',
                    extraPriceMinor: modifier.extraPriceMinor,
                    isAdd: modifier.action == ModifierAction.add,
                  ),
                )
                .toList(growable: false),
          ),
        );
      }
    }

    return _PrintableOrder(transaction: transaction, lines: printableLines);
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

    bytes.addAll(
      generator.text(
        'KITCHEN TICKET',
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
        'Order #${order.transaction.id}',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    if (order.transaction.tableNumber != null) {
      bytes.addAll(
        generator.text(
          'Table ${order.transaction.tableNumber}',
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    bytes.addAll(
      generator.text(
        DateFormatter.formatDefault(order.transaction.createdAt),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());

    for (final _PrintableLine line in order.lines) {
      bytes.addAll(
        generator.row(<PosColumn>[
          PosColumn(
            text: '${line.line.quantity}x ${line.line.productName}',
            width: 8,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: CurrencyFormatter.fromMinor(line.line.lineTotalMinor),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
      for (final _PrintableModifier modifier in line.modifiers) {
        if (!modifier.showOnKitchen) continue;
        final String displayLabel = modifier.kitchenLabel ?? modifier.label;
        bytes.addAll(
          generator.text(
            '  $displayLabel',
            styles: const PosStyles(),
          ),
        );
      }
      bytes.addAll(generator.feed(1));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'TOTAL ${CurrencyFormatter.fromMinor(order.transaction.totalAmountMinor)}',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    );
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<List<int>> _buildReceiptBytes({
    required PrinterSettingsModel printer,
    required _PrintableOrder order,
    required Payment payment,
  }) async {
    final Generator generator = await _buildGenerator(printer.paperWidth);
    final List<int> bytes = <int>[];

    bytes.addAll(
      generator.text(
        'RECEIPT',
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
        'Order #${order.transaction.id}',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    if (order.transaction.tableNumber != null) {
      bytes.addAll(
        generator.text(
          'Table ${order.transaction.tableNumber}',
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    bytes.addAll(
      generator.text(
        'Paid ${DateFormatter.formatDefault(payment.paidAt)}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.hr());

    for (final _PrintableLine line in order.lines) {
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
      for (final _PrintableModifier modifier in line.modifiers) {
        if (!modifier.showOnReceipt) continue;
        final String suffix = modifier.isAdd && modifier.extraPriceMinor > 0
            ? ' ${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}'
            : '';
        bytes.addAll(generator.text('  ${modifier.label}$suffix'));
      }
    }

    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row(<PosColumn>[
        PosColumn(text: 'Subtotal', width: 8),
        PosColumn(
          text: CurrencyFormatter.fromMinor(order.transaction.subtotalMinor),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      generator.row(<PosColumn>[
        PosColumn(text: 'Modifiers', width: 8),
        PosColumn(
          text: CurrencyFormatter.fromMinor(
            order.transaction.modifierTotalMinor,
          ),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(
      generator.row(<PosColumn>[
        PosColumn(text: 'TOTAL', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(
          text: CurrencyFormatter.fromMinor(order.transaction.totalAmountMinor),
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(
      generator.text(
        'Payment: ${payment.method.name.toUpperCase()}',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());
    return bytes;
  }

  Future<List<int>> _buildZReportBytes({
    required PrinterSettingsModel printer,
    required ShiftReport report,
  }) async {
    final Generator generator = await _buildGenerator(printer.paperWidth);
    final List<int> bytes = <int>[];

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

    bytes.addAll(
      generator.text(
        'PRINTER TEST',
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
        'Paper ${printer.paperWidth}mm',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(2));
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
    return Generator(
      paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80,
      profile,
    );
  }

  Future<void> _sendToPrinter({
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
      await connection?.finish();
    }
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
    return _runSerialized(() async {
      final Transaction transaction = await _requireTransaction(transactionId);
      final PrintJobRepository printJobRepository = _requiredPrintJobRepository;
      final PrintJob job = await _ensurePrintJobState(
        transaction: transaction,
        target: target,
      );
      if (job.isPrinted && !allowReprint) {
        return job;
      }
      if (job.isFailed && !allowReprint) {
        return job;
      }

      bool attemptStarted = false;
      try {
        final PrintJob inProgress = await printJobRepository.markInProgress(
          transactionId: transactionId,
          target: target,
          allowReprint: allowReprint,
        );
        if (inProgress.isPrinted && !allowReprint) {
          return inProgress;
        }
        attemptStarted = true;

        final _PrintableOrder printableOrder = await _loadPrintableOrder(
          transaction,
        );
        final PrinterSettingsModel printer = await _requireJobPrinterSettings(
          target,
        );
        final List<int> bytes = switch (target) {
          PrintJobTarget.kitchen => await _buildKitchenTicketBytes(
            printer: printer,
            order: printableOrder,
          ),
          PrintJobTarget.receipt => await _buildReceiptBytes(
            printer: printer,
            order: printableOrder,
            payment: await _requirePayment(transactionId),
          ),
        };

        await _sendToPrinter(printer: printer, bytes: bytes);
        await _transactionRepository.updatePrintFlag(
          transactionId: transactionId,
          kitchenPrinted: target == PrintJobTarget.kitchen ? true : null,
          receiptPrinted: target == PrintJobTarget.receipt ? true : null,
        );
        final PrintJob printed = await printJobRepository.markPrinted(
          transactionId: transactionId,
          target: target,
        );
        if (allowReprint &&
            target == PrintJobTarget.receipt &&
            actorUserId != null) {
          await _auditLogService.logActionSafely(
            actorUserId: actorUserId,
            action: 'receipt_reprinted',
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
        if (attemptStarted) {
          await printJobRepository.markFailed(
            transactionId: transactionId,
            target: target,
            error: error.toString(),
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
        if (attemptStarted) {
          await printJobRepository.markFailed(
            transactionId: transactionId,
            target: target,
            error: error.toString(),
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

    if (!canPrint && !alreadyPrinted) {
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
      return existing;
    }

    if (alreadyPrinted) {
      await printJobRepository.ensureQueued(
        transactionId: transaction.id,
        target: target,
      );
      return printJobRepository.markPrinted(
        transactionId: transaction.id,
        target: target,
      );
    }

    return printJobRepository.ensureQueued(
      transactionId: transaction.id,
      target: target,
    );
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
  const _PrintableLine({required this.line, required this.modifiers});

  final TransactionLine line;
  final List<_PrintableModifier> modifiers;
}

class _PrintableModifier {
  const _PrintableModifier({
    required this.label,
    required this.extraPriceMinor,
    required this.isAdd,
    this.showOnKitchen = true,
    this.showOnReceipt = true,
    this.kitchenLabel,
    this.chargeReason,
  });

  final String label;
  final int extraPriceMinor;
  final bool isAdd;
  final bool showOnKitchen;
  final bool showOnReceipt;
  final String? kitchenLabel;
  final ModifierChargeReason? chargeReason;
}
