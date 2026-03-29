import '../../core/constants/app_strings.dart';
import 'order_lifecycle_policy.dart';
import 'print_job.dart';
import 'transaction.dart';

class OrderPrintStatusView {
  const OrderPrintStatusView({
    required this.isVisible,
    required this.isFailure,
    required this.message,
  });

  final bool isVisible;
  final bool isFailure;
  final String? message;
}

class OrderPrintPolicy {
  const OrderPrintPolicy._();

  static OrderPrintStatusView resolve({
    required Transaction transaction,
    required PrintJobTarget target,
    required PrintJob? job,
  }) {
    final bool eligible = switch (target) {
      PrintJobTarget.kitchen => OrderLifecyclePolicy.canPrintKitchenTicket(
        transaction.status,
      ),
      PrintJobTarget.receipt => OrderLifecyclePolicy.canPrintReceipt(
        transaction.status,
      ),
    };
    final bool printed = switch (target) {
      PrintJobTarget.kitchen => transaction.kitchenPrinted,
      PrintJobTarget.receipt => transaction.receiptPrinted,
    };

    if (!eligible && !printed) {
      return const OrderPrintStatusView(
        isVisible: false,
        isFailure: false,
        message: null,
      );
    }

    if (job == null) {
      if (printed) {
        return const OrderPrintStatusView(
          isVisible: false,
          isFailure: false,
          message: null,
        );
      }
      return OrderPrintStatusView(
        isVisible: true,
        isFailure: false,
        message: _pendingMessage(target),
      );
    }

    switch (job.status) {
      case PrintJobStatus.pending:
        return OrderPrintStatusView(
          isVisible: true,
          isFailure: false,
          message: _pendingMessage(target),
        );
      case PrintJobStatus.printing:
        if (job.isRecoverablyStalePrinting()) {
          return OrderPrintStatusView(
            isVisible: true,
            isFailure: true,
            message: _failedMessage(target),
          );
        }
        return OrderPrintStatusView(
          isVisible: true,
          isFailure: false,
          message: _printingMessage(target),
        );
      case PrintJobStatus.failed:
        return OrderPrintStatusView(
          isVisible: true,
          isFailure: true,
          message: _failedMessage(target),
        );
      case PrintJobStatus.printed:
        return const OrderPrintStatusView(
          isVisible: false,
          isFailure: false,
          message: null,
        );
    }
  }

  static String _pendingMessage(PrintJobTarget target) {
    switch (target) {
      case PrintJobTarget.kitchen:
        return AppStrings.kitchenPrintPending;
      case PrintJobTarget.receipt:
        return AppStrings.receiptPrintPending;
    }
  }

  static String _printingMessage(PrintJobTarget target) {
    switch (target) {
      case PrintJobTarget.kitchen:
        return AppStrings.kitchenPrintInProgress;
      case PrintJobTarget.receipt:
        return AppStrings.receiptPrintInProgress;
    }
  }

  static String _failedMessage(PrintJobTarget target) {
    switch (target) {
      case PrintJobTarget.kitchen:
        return AppStrings.kitchenPrintRetryRequired;
      case PrintJobTarget.receipt:
        return AppStrings.receiptPrintRetryRequired;
    }
  }
}
