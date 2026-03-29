// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EPOS';

  @override
  String get loginTitle => 'PIN Login';

  @override
  String get pinLabel => 'PIN';

  @override
  String get loginButton => 'Sign In';

  @override
  String get loading => 'Loading...';

  @override
  String get errorGeneric => 'Operation failed.';

  @override
  String get enterPin => 'Enter PIN.';

  @override
  String get loginFailed => 'Login failed.';

  @override
  String get invalidPinOrInactiveUser => 'Invalid PIN or inactive user.';

  @override
  String get authLocked => 'Too many failed attempts. Wait 30 seconds.';

  @override
  String get navPos => 'POS';

  @override
  String get navOrders => 'Open Orders';

  @override
  String get navReports => 'Reports';

  @override
  String get navAdmin => 'Admin';

  @override
  String get navShifts => 'Shift Management';

  @override
  String get navSettings => 'Settings';

  @override
  String get navLogout => 'Logout';

  @override
  String get shiftActive => 'Active Shift';

  @override
  String get shiftInactive => 'No Shift';

  @override
  String get shiftOpen => 'Shift Open';

  @override
  String get shiftClosed => 'Shift Closed';

  @override
  String get shiftLocked => 'Shift Locked';

  @override
  String get recentShifts => 'Recent Shifts';

  @override
  String get noShiftHistory => 'No shift history yet';

  @override
  String get adminOnlyShiftMessage =>
      'Real end-of-day close can only be completed by an admin.';

  @override
  String get closeShiftConfirmation =>
      'The shift will be closed with the final Z report.';

  @override
  String get openOrdersBlockTitle => 'Close blocked — active orders remain';

  @override
  String get goToOpenOrders => 'Go to Open Orders';

  @override
  String get shiftOpened => 'Shift opened.';

  @override
  String get shiftClosedMessage => 'Shift closed — open a shift to continue';

  @override
  String get lastClosedShift => 'Last Closed Shift';

  @override
  String get openedBy => 'Opened by';

  @override
  String get closedBy => 'Closed by';

  @override
  String get cashierPreviewedBy => 'Cashier Preview By';

  @override
  String get cashierPreviewedAt => 'Cashier Preview Time';

  @override
  String get cashierPreviewPending => 'Cashier preview has not been taken yet.';

  @override
  String get noRecentActivity => 'No recent activity yet.';

  @override
  String get cashAwarenessTitle => 'Cash Awareness';

  @override
  String get goToPosNewOrder => 'POS / New Order';

  @override
  String get maskedCashCollected => 'Masked cash collected';

  @override
  String get manualCashMovements => 'Manual cash movements';

  @override
  String get netTillMovement => 'Net till movement';

  @override
  String get openedAt => 'Opened';

  @override
  String get closedAt => 'Closed';

  @override
  String get paidOrders => 'PAID Orders';

  @override
  String get cancelledOrders => 'CANCELLED Orders';

  @override
  String get allCategories => 'All';

  @override
  String get noCategories => 'No categories found';

  @override
  String get noProductsInCategory => 'No products in this category';

  @override
  String get cart => 'Cart';

  @override
  String get checkout => 'Checkout';

  @override
  String get emptyCart => 'Cart empty — add items';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get modifierTotal => 'Modifier Total';

  @override
  String get total => 'Total';

  @override
  String get orderNow => 'Order Now';

  @override
  String get payNow => 'Pay Now';

  @override
  String get payAction => 'Pay';

  @override
  String get saveAsOpenOrder => 'Save as Open Order';

  @override
  String get clear => 'Clear';

  @override
  String get modifierDialogTitle => 'Select Modifier';

  @override
  String get includedModifiers => 'Included';

  @override
  String get extraModifiers => 'Extra';

  @override
  String get addItem => 'Add to Cart';

  @override
  String get removeItem => 'Remove Item';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get close => 'Close';

  @override
  String get submit => 'Submit';

  @override
  String get paymentTitle => 'Payment';

  @override
  String get cash => 'Cash';

  @override
  String get card => 'Card';

  @override
  String get receivedAmount => 'Received Amount';

  @override
  String get change => 'Change';

  @override
  String get openOrdersTitle => 'Open Orders';

  @override
  String get noOpenOrders => 'No open orders';

  @override
  String get retry => 'Retry';

  @override
  String get orderDetails => 'Order Details';

  @override
  String get kitchenPrint => 'Print Kitchen';

  @override
  String get receiptPrint => 'Print Receipt';

  @override
  String get selectOpenOrderFirst => 'Select an open order first.';

  @override
  String get orderCreated => 'Order created.';

  @override
  String get orderSent => 'Order sent.';

  @override
  String get orderCancelled => 'Order cancelled.';

  @override
  String get paymentCompleted => 'Payment completed.';

  @override
  String get refundAction => 'Refund';

  @override
  String get refundCompleted => 'Refund completed.';

  @override
  String get refundDialogTitle => 'Refund Payment';

  @override
  String get refundReasonLabel => 'Refund reason';

  @override
  String get refundReasonHint => 'Enter the reason for the refund';

  @override
  String get refundReasonRequired => 'Refund reason is required.';

  @override
  String get refundAdminOnly =>
      'Only admins can refund or reverse paid orders.';

  @override
  String get refundBlockedNotPaid => 'Refund not allowed for unpaid order.';

  @override
  String get refundBlockedPaymentMissing =>
      'Refund not allowed — payment not found.';

  @override
  String get refundBlockedCancelled =>
      'Refund not allowed for cancelled order.';

  @override
  String get refundAlreadyProcessed =>
      'Refund already recorded for this payment.';

  @override
  String get refundStatusCompleted => 'Refund completed';

  @override
  String get refundedAt => 'Refunded at';

  @override
  String get paymentFailedOrderOpen =>
      'Payment failed. Order was not completed.';

  @override
  String get printFailed => 'Print failed — retry required.';

  @override
  String get printRetryRecommended =>
      'Print failed — retry from the order screen.';

  @override
  String get kitchenPrintSent => 'Kitchen ticket sent.';

  @override
  String get receiptPrintSent => 'Receipt printed.';

  @override
  String get kitchenPrintPending => 'Kitchen print pending.';

  @override
  String get receiptPrintPending => 'Receipt print pending.';

  @override
  String get kitchenPrintInProgress => 'Kitchen print in progress.';

  @override
  String get receiptPrintInProgress => 'Receipt print in progress.';

  @override
  String get kitchenPrintRetryRequired =>
      'Kitchen print failed. Retry from this order.';

  @override
  String get receiptPrintRetryRequired =>
      'Receipt print failed. Retry from this order.';

  @override
  String get cancelFailed => 'Cancellation failed.';

  @override
  String get shiftNotActiveError =>
      'No active shift. The next successful login starts a new shift automatically.';

  @override
  String get paymentUnavailable => 'Payment blocked — shift must be open.';

  @override
  String get paymentAlreadyCompleted =>
      'Payment already completed for this order.';

  @override
  String get paymentCancelledOrderBlocked => 'Cancelled orders cannot be paid.';

  @override
  String get paymentNotSentBlocked => 'Only sent orders can be paid.';

  @override
  String get salesLockedMessage =>
      'Sales locked — admin must complete end-of-day close';

  @override
  String get cartLockedMessage => 'Cart locked — shift action required';

  @override
  String get modifierLoadFailed => 'Failed to load modifiers.';

  @override
  String get modifierNotFound => 'No modifiers found.';

  @override
  String get confirmCancellation => 'Cancel this order?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get table => 'Table';

  @override
  String get time => 'Time';

  @override
  String get itemCount => 'Items';

  @override
  String get statusOpen => 'OPEN';

  @override
  String get statusClosed => 'CLOSED';

  @override
  String get statusLocked => 'LOCKED';

  @override
  String get statusDraft => 'DRAFT';

  @override
  String get statusSent => 'SENT';

  @override
  String get statusPaid => 'PAID';

  @override
  String get statusCancelled => 'CANCELLED';

  @override
  String get orderStatusLabel => 'Status';

  @override
  String get reports => 'Reports';

  @override
  String get zReport => 'Z Report';

  @override
  String get salesSummary => 'Sales Summary';

  @override
  String get categoryBreakdown => 'Category Breakdown';

  @override
  String get businessName => 'Business Name';

  @override
  String get businessAddress => 'Business Address';

  @override
  String get reportDate => 'Report Date';

  @override
  String get reportTime => 'Report Time';

  @override
  String get shiftNumber => 'Shift Number';

  @override
  String get operatorLabel => 'Operator';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get confirmZReportAction => 'Confirm Z Report';

  @override
  String get confirmFinalCloseAction => 'Confirm Final Close';

  @override
  String get endOfDay => 'End of Day';

  @override
  String get cashTotal => 'Cash Total';

  @override
  String get cardTotal => 'Card Total';

  @override
  String get paymentBreakdown => 'Payment Breakdown';

  @override
  String get noReportData => 'No report data found.';

  @override
  String get selectShift => 'Select Shift';

  @override
  String get totalOrders => 'Total Orders';

  @override
  String get activeShiftMissing => 'No active shift';

  @override
  String get reportForShift => 'Report for Shift';

  @override
  String get reportForLatestShift => 'Report for Latest Shift';

  @override
  String get accessDenied => 'Permission denied.';

  @override
  String get notFound => 'Record not found.';

  @override
  String get unknownUser => 'Unknown User';

  @override
  String get maskedZReportAction => 'Z Report';

  @override
  String get finalZReportAction => 'Take Final Z Report and Close Shift';

  @override
  String get print => 'Print';

  @override
  String get printZReportAction => 'Print Z Report';

  @override
  String get printUnavailable => 'Printing is unavailable on this screen.';

  @override
  String get zReportPrinted => 'Z report printed.';

  @override
  String get maskedReportTaken => 'Cashier masked end-of-day report taken.';

  @override
  String get finalReportTaken => 'Final Z report taken and shift closed.';

  @override
  String get currentBusinessShift => 'Current Business Shift';

  @override
  String get noBusinessShift => 'No open business shift';

  @override
  String get autoShiftOpenHint =>
      'If there is no active shift, the first successful login starts a new one.';

  @override
  String get finalCloseHint =>
      'Final close requires counted cash and admin approval.';

  @override
  String get visibilityRatioTitle => 'Cashier Visibility Ratio';

  @override
  String get visibilityRatioHint =>
      'How much of the real numbers should be visible in cashier reports?';

  @override
  String get cashierZReportPolicyTitle => 'Cashier Z Report Policy';

  @override
  String get cashierZReportPolicyHint =>
      'Configure how cashier-visible Z report totals are projected. These controls are admin-only and do not change the admin report view.';

  @override
  String get cashierProjectionModeLabel => 'Projection Mode';

  @override
  String get cashierProjectionModePercentage => 'Percentage';

  @override
  String get cashierProjectionModeCapAmount => 'Cap Amount';

  @override
  String get cashierProjectionPercentageHelp =>
      'Apply the selected ratio across cashier-visible totals, payment totals, and category totals.';

  @override
  String get cashierProjectionCapAmountLabel => 'Max Visible Total';

  @override
  String get cashierProjectionCapAmountHint => 'Example: 12.50';

  @override
  String get cashierProjectionCapAmountHelp =>
      'Enter the maximum cashier-visible total as currency. Example: 12.50.';

  @override
  String get businessIdentitySectionTitle => 'Business Identity';

  @override
  String get businessIdentitySectionHint =>
      'These values appear in cashier Z report headers and cashier-safe print output.';

  @override
  String get cashierProjectionPreviewTitle => 'Cashier Projection Preview';

  @override
  String get cashierProjectionPreviewHint =>
      'This preview uses the active shift\'s real report and the current draft policy.';

  @override
  String get cashierProjectionPreviewUnavailable =>
      'No active shift is available for projection preview.';

  @override
  String get realTotalLabel => 'Real Total';

  @override
  String get cashierVisibleTotalLabel => 'Cashier Visible Total';

  @override
  String get realCashLabel => 'Real Cash';

  @override
  String get cashierVisibleCashLabel => 'Cashier Visible Cash';

  @override
  String get realCardLabel => 'Real Card';

  @override
  String get cashierVisibleCardLabel => 'Cashier Visible Card';

  @override
  String get maxVisibleTotalRequired => 'Max visible total is required.';

  @override
  String get maxVisibleTotalInvalid =>
      'Enter a valid currency amount with up to 2 decimal places.';

  @override
  String get saveSettings => 'Save';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSaved => 'Settings saved.';

  @override
  String get editTable => 'Edit Table';

  @override
  String get addTable => 'Add Table';

  @override
  String get clearTable => 'Clear Table';

  @override
  String get tableNumberHint => 'Table number';

  @override
  String get tableUpdated => 'Table number updated.';

  @override
  String get tableUnassigned => 'No table assigned';

  @override
  String get shiftMonitorTitle => 'Shift Status';

  @override
  String get openShiftFromLogin =>
      'If there is no active shift, the next successful login opens one.';

  @override
  String get openShiftAdminOnly =>
      'A shift can be opened by admin or cashier on first login.';

  @override
  String get openShiftAction => 'Open Shift';

  @override
  String get closeShiftAction => 'Lock Shift';

  @override
  String get closeShiftFromZReport =>
      'Shift closing is only done from the Z report screen.';

  @override
  String get adminDashboardTitle => 'Admin Dashboard';

  @override
  String get totalSales => 'Total Sales';

  @override
  String get adminRealView => 'Admin real view';

  @override
  String get activeShiftOrders => 'Orders on the active shift';

  @override
  String get syncPendingTitle => 'Sync Pending';

  @override
  String get syncPendingSubtitle => 'Records waiting to be sent';

  @override
  String get syncFailedTitle => 'Sync Failed';

  @override
  String get syncFailedSubtitle => 'Records requiring admin intervention';

  @override
  String get manageProducts => 'Manage Products';

  @override
  String get shiftControl => 'Shift Control';

  @override
  String get syncMonitor => 'Sync Monitor';

  @override
  String get adminDashboardNoActiveShift =>
      'There is no active business shift. The next successful login opens a new shift.';

  @override
  String get categoryManagementTitle => 'Category Management';

  @override
  String get noCategoriesDefined => 'No categories defined yet.';

  @override
  String get categoryCreated => 'Category created.';

  @override
  String get categoryUpdated => 'Category updated.';

  @override
  String get operationFailed => 'Operation failed.';

  @override
  String get categoryToolbarMessage =>
      'The POS category bar depends on this list. Changes to order and active state affect the live POS view.';

  @override
  String get addCategory => 'Add Category';

  @override
  String get sortOrderLabel => 'Sort Order';

  @override
  String get edit => 'Edit';

  @override
  String get addCategoryDialogTitle => 'Add Category';

  @override
  String get editCategoryDialogTitle => 'Edit Category';

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get active => 'Active';

  @override
  String get productManagementTitle => 'Product Management';

  @override
  String get categoryFilterLabel => 'Category Filter';

  @override
  String get addProduct => 'Add Product';

  @override
  String get productListInfoMessage =>
      'All prices are managed as integer price_minor values. Float or decimal UI input is not used.';

  @override
  String get noProductsForSelection => 'No products in the selected category.';

  @override
  String get productCreated => 'Product created.';

  @override
  String get productUpdated => 'Product updated.';

  @override
  String get categoryLabel => 'Category';

  @override
  String get productNameLabel => 'Product name';

  @override
  String get priceMinorLabel => 'Price Minor';

  @override
  String get hasModifiersLabel => 'Has Modifiers';

  @override
  String get addProductDialogTitle => 'Add Product';

  @override
  String get editProductDialogTitle => 'Edit Product';

  @override
  String get modifierManagementTitle => 'Modifier Management';

  @override
  String get productLabel => 'Product';

  @override
  String get addModifier => 'Add Modifier';

  @override
  String get modifierInfoMessage =>
      'The distinction between included and extra modifiers affects totals directly. Included modifiers always keep extra_price_minor at 0.';

  @override
  String get noModifiersForProduct =>
      'No modifiers linked to the selected product.';

  @override
  String get modifierCreated => 'Modifier created.';

  @override
  String get modifierUpdated => 'Modifier updated.';

  @override
  String get addModifierDialogTitle => 'Add Modifier';

  @override
  String get editModifierDialogTitle => 'Edit Modifier';

  @override
  String get modifierNameLabel => 'Modifier name';

  @override
  String get typeLabel => 'Type';

  @override
  String get extraPriceMinorLabel => 'Extra Price Minor';

  @override
  String get shiftControlTitle => 'Shift Control';

  @override
  String get shiftControlBannerMessage =>
      'Shifts are not opened from the UI. The first successful login opens a shift. The only operational control here is the admin final close entry point.';

  @override
  String get shiftLockedMessage =>
      'Shift locked. Cashier sales remain blocked until admin final close.';

  @override
  String get finalCloseCompleted => 'Final close completed.';

  @override
  String get finalCloseFailed => 'Final close failed.';

  @override
  String get previousFinalCloseAttemptDetected =>
      'Previous final close attempt detected';

  @override
  String get resumeFinalCloseAction => 'Resume Final Close';

  @override
  String get discardAndReenterAction => 'Discard and Re-enter';

  @override
  String get finalCloseCashDialogTitle => 'Final Close Cash Reconciliation';

  @override
  String get enterCountedCashAction => 'Enter Counted Cash';

  @override
  String get expectedCash => 'Expected Cash';

  @override
  String get countedCash => 'Counted Cash';

  @override
  String get countedCashHint =>
      'Enter counted cash in minor units before final close';

  @override
  String get countedCashRequired =>
      'Counted cash is required before final close.';

  @override
  String get countedCashInvalid => 'Counted cash must be zero or greater.';

  @override
  String get countedAtLabel => 'Counted At';

  @override
  String get countedByLabel => 'Counted By';

  @override
  String get variance => 'Variance';

  @override
  String get grossSales => 'Gross Sales';

  @override
  String get refundTotal => 'Refund Total';

  @override
  String get netSales => 'Net Sales';

  @override
  String get grossCash => 'Gross Cash';

  @override
  String get netCash => 'Net Cash';

  @override
  String get grossCard => 'Gross Card';

  @override
  String get netCard => 'Net Card';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get noAuditEntries => 'No audit entries recorded yet.';

  @override
  String get shiftHistoryTitle => 'Shift History';

  @override
  String get noShiftHistoryYet => 'No shift history available yet.';

  @override
  String get nextLoginOpensShift =>
      'No active shift. The next successful login will open one.';

  @override
  String get adminFinalClose => 'Admin Final Close';

  @override
  String get openingLabel => 'Opening';

  @override
  String get closingLabel => 'Closing';

  @override
  String get openedByLabel => 'Opened By';

  @override
  String get closedByLabel => 'Closed By';

  @override
  String get syncMonitorTitle => 'Sync Monitor';

  @override
  String get pending => 'Pending';

  @override
  String get processing => 'Processing';

  @override
  String get syncedStatus => 'Synced';

  @override
  String get failed => 'Failed';

  @override
  String get stuck => 'Stuck';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get workerRunning => 'Worker Running';

  @override
  String get workerIdle => 'Worker Idle';

  @override
  String get syncEnabled => 'Sync Enabled';

  @override
  String get syncDisabled => 'Sync Disabled';

  @override
  String get retrying => 'Retrying...';

  @override
  String get retryAllFailed => 'Retry All Failed';

  @override
  String get lastSyncTitle => 'Last Sync';

  @override
  String get noSuccessfulSyncYet => 'No successful sync yet.';

  @override
  String get supabaseTitle => 'Supabase';

  @override
  String get supabaseConfiguredHidden =>
      'Client sync gateway configured. Secret values hidden.';

  @override
  String get syncFeatureDisabledForBuild =>
      'Sync feature is disabled for this build.';

  @override
  String get lastErrorTitle => 'Last Error';

  @override
  String get noLastError => 'No recent error.';

  @override
  String get syncQueueInfoMessage =>
      'Queue manipulation only happens through the repository. The worker processes pending and failed items in batches, applies retry backoff, and leaves max-attempt items stuck.';

  @override
  String get noSyncQueueItems =>
      'There are no pending, failed, or processing records.';

  @override
  String get retryAllSuccess =>
      'Failed records were moved back to pending and the worker was started again.';

  @override
  String get retryAllFailedMessage => 'Retry all failed.';

  @override
  String get retryItemSuccess =>
      'The sync record was moved back to pending for retry.';

  @override
  String get retryFailedMessage => 'Retry failed.';

  @override
  String get statusLabel => 'Status';

  @override
  String get attemptsLabel => 'Attempts';

  @override
  String get createdLabel => 'Created';

  @override
  String get lastAttemptLabel => 'Last Attempt';

  @override
  String get syncedLabel => 'Synced';

  @override
  String get errorLabel => 'Error';

  @override
  String get systemHealthTitle => 'System Health';

  @override
  String get debugLoggingOn => 'Debug Logging On';

  @override
  String get debugLoggingOff => 'Debug Logging Off';

  @override
  String get environmentTitle => 'Environment';

  @override
  String get appVersionLabel => 'App Version';

  @override
  String get environmentLabel => 'Environment';

  @override
  String get schemaVersionLabel => 'Schema Version';

  @override
  String get activeShiftLabel => 'Active Shift';

  @override
  String get none => 'None';

  @override
  String get syncStateTitle => 'Sync State';

  @override
  String get supabaseConfigured => 'Configured';

  @override
  String get supabaseNotConfigured => 'Not configured';

  @override
  String get configIssueLabel => 'Config Issue';

  @override
  String get lastSyncLabel => 'Last Sync';

  @override
  String get lastErrorLabel => 'Last Error';

  @override
  String get backupTitle => 'Backup';

  @override
  String get lastBackupLabel => 'Last Backup';

  @override
  String get exportInProgress => 'Exporting...';

  @override
  String get exportLocalDb => 'Export Local DB';

  @override
  String exportSuccess(String path) {
    return 'Backup exported to $path.';
  }

  @override
  String get exportFailed => 'Backup export failed.';

  @override
  String get migrationHistoryTitle => 'Migration History';

  @override
  String get noMigrationTelemetry => 'No migration telemetry recorded yet.';

  @override
  String get migrationStarted => 'Started';

  @override
  String get migrationSucceeded => 'Succeeded';

  @override
  String get migrationFailed => 'Failed';

  @override
  String get operationsControl => 'Operations Control';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get products => 'Products';

  @override
  String get categories => 'Categories';

  @override
  String get modifiers => 'Modifiers';

  @override
  String get shifts => 'Shifts';

  @override
  String get report => 'Report';

  @override
  String get printer => 'Printer';

  @override
  String get sync => 'Sync';

  @override
  String get system => 'System';

  @override
  String get printerSettingsTitle => 'Printer Settings';

  @override
  String get bluetoothPrinter => 'Bluetooth Printer';

  @override
  String get printerSelectionMessage =>
      'Printer selection and test flow run through printer_service. Errors are handled with try/catch; there is no silent failure.';

  @override
  String get bondedDevice => 'Bonded device';

  @override
  String get printerSettingSaved => 'Printer setting saved.';

  @override
  String get saveFailed => 'Save failed.';

  @override
  String get testPrintSent => 'Test print sent.';

  @override
  String get testPrintFailed => 'Test print failed.';

  @override
  String get testPrint => 'Test Print';

  @override
  String get reportSettingsTitle => 'Report Settings';

  @override
  String get reportSettingSaved => 'Report setting saved.';

  @override
  String get reportSettingsInfo =>
      'Mask calculations are not done in the UI. This screen only writes the ratio to the database; the real visibility rules stay in the domain report visibility service.';

  @override
  String get sendOrderAction => 'Send Order';

  @override
  String get currentShiftSummary => 'Current Shift Summary';

  @override
  String get shiftIdLabel => 'Shift ID';

  @override
  String get shiftScreenNoOpenShift =>
      'No shift is open. POS operations remain blocked until a shift is opened.';

  @override
  String get statusDraftStale => 'STALE DRAFT';

  @override
  String get discardDraftAction => 'Discard Draft';

  @override
  String get draftDiscarded => 'Draft discarded.';

  @override
  String get confirmDiscardDraft =>
      'Discard this draft? This removes the abandoned cart and does not count as a cancelled sale.';

  @override
  String get staleDraftDetailMessage =>
      'This draft is stale. It should be discarded before final close.';

  @override
  String get staleDraftCloseHelp =>
      'Stale drafts are cleanup items. Review them in Open Orders and discard them before final close.';

  @override
  String get sentOrdersPendingLabel => 'Sent Orders Blocking Close';

  @override
  String get freshDraftsPendingLabel => 'Fresh Drafts Blocking Close';

  @override
  String get staleDraftsPendingLabel => 'Stale Drafts Pending Cleanup';

  @override
  String shiftCloseBlockedSentOrders(int count) {
    return '$count sent order(s) still need payment or cancellation before final close.';
  }

  @override
  String shiftCloseBlockedFreshDrafts(int count) {
    return '$count fresh draft(s) still need to be sent or discarded before final close.';
  }

  @override
  String shiftCloseBlockedStaleDrafts(int count) {
    return '$count stale draft(s) must be discarded before final close.';
  }

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSettingsHint =>
      'Change the operator language at runtime. English stays as the default fallback.';

  @override
  String get english => 'English';

  @override
  String get turkish => 'Turkish';

  @override
  String get paperWidth58 => '58 mm';

  @override
  String get paperWidth80 => '80 mm';

  @override
  String orderCountLabel(int count) {
    return '$count orders';
  }

  @override
  String orderNumber(int id) {
    return 'Order #$id';
  }

  @override
  String openShiftLabel(int shiftId) {
    return 'Shift #$shiftId';
  }

  @override
  String get openOrderLoadCalm => 'No queue';

  @override
  String get openOrderLoadNormal => 'Normal';

  @override
  String get openOrderLoadHigh => 'High load';

  @override
  String get openOrderHighLoadWarning =>
      'Many open orders — consider clearing the queue';

  @override
  String get cashierPreviewTakenWarning =>
      'End-of-day preview already taken — cashier actions locked';

  @override
  String get noActiveShiftWarning => 'No active shift — all operations locked';

  @override
  String get cashAwarenessDisclaimer =>
      'Approximate awareness only — not a formal accounting balance';

  @override
  String get maskedCashFromSales => 'Cash from sales (masked)';

  @override
  String get manualCashMovementsNet => 'Manual movements (net)';

  @override
  String get netTillAwareness => 'Net till awareness';

  @override
  String get shiftNormalOperation => 'Normal operation';

  @override
  String get shiftPreviewNotTaken => 'Preview not yet taken';

  @override
  String get shiftPreviewTaken => 'Preview taken — cashier locked';
}
