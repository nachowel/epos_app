import 'package:epos_app/l10n/app_localizations.dart';

import '../localization/app_localization_service.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/transaction.dart';

class AppStrings {
  const AppStrings._();

  static AppLocalizations get _t => AppLocalizationService.instance.current;

  static String get appName => _t.appTitle;
  static String get loginTitle => _t.loginTitle;
  static String get pinLabel => _t.pinLabel;
  static String get loginButton => _t.loginButton;
  static String get loading => _t.loading;
  static String get errorGeneric => _t.errorGeneric;
  static String get enterPin => _t.enterPin;
  static String get loginFailed => _t.loginFailed;
  static String get invalidPinOrInactiveUser => _t.invalidPinOrInactiveUser;
  static String get authLocked => _t.authLocked;
  static String get navPos => _t.navPos;
  static String get navOrders => _t.navOrders;
  static String get navReports => _t.navReports;
  static String get navAdmin => _t.navAdmin;
  static String get navShifts => _t.navShifts;
  static String get navSettings => _t.navSettings;
  static String get navLogout => _t.navLogout;
  static String get shiftActive => _t.shiftActive;
  static String get shiftInactive => _t.shiftInactive;
  static String get shiftOpen => _t.shiftOpen;
  static String get shiftClosed => _t.shiftClosed;
  static String get shiftLocked => _t.shiftLocked;
  static String get recentShifts => _t.recentShifts;
  static String get noShiftHistory => _t.noShiftHistory;
  static String get adminOnlyShiftMessage => _t.adminOnlyShiftMessage;
  static String get closeShiftConfirmation => _t.closeShiftConfirmation;
  static String get openOrdersBlockTitle => _t.openOrdersBlockTitle;
  static String get goToOpenOrders => _t.goToOpenOrders;
  static String get shiftOpened => _t.shiftOpened;
  static String get shiftClosedMessage => _t.shiftClosedMessage;
  static String get lastClosedShift => _t.lastClosedShift;
  static String get openedBy => _t.openedBy;
  static String get closedBy => _t.closedBy;
  static String get cashierPreviewedBy => _t.cashierPreviewedBy;
  static String get cashierPreviewedAt => _t.cashierPreviewedAt;
  static String get cashierPreviewPending => _t.cashierPreviewPending;
  static String get noRecentActivity => _t.noRecentActivity;
  static String get cashAwarenessTitle => _t.cashAwarenessTitle;
  static String get goToPosNewOrder => _t.goToPosNewOrder;
  static String get maskedCashCollected => _t.maskedCashCollected;
  static String get manualCashMovements => _t.manualCashMovements;
  static String get netTillMovement => _t.netTillMovement;
  static String get openedAt => _t.openedAt;
  static String get closedAt => _t.closedAt;
  static String get paidOrders => _t.paidOrders;
  static String get cancelledOrders => _t.cancelledOrders;
  static String get allCategories => _t.allCategories;
  static String get noCategories => _t.noCategories;
  static String get noProductsInCategory => _t.noProductsInCategory;
  static String get cartTitle => _t.cart;
  static String get checkout => _t.checkout;
  static String get cartEmpty => _t.emptyCart;
  static String get subtotal => _t.subtotal;
  static String get modifierTotal => _t.modifierTotal;
  static String get total => _t.total;
  static String get createOrder => _t.orderNow;
  static String get payNow => _t.payNow;
  static String get payAction => _t.payAction;
  static String get saveAsOpenOrder => _t.saveAsOpenOrder;
  static String get clearCart => _t.clear;
  static String get modifierDialogTitle => _t.modifierDialogTitle;
  static String get includedModifiers => _t.includedModifiers;
  static String get extraModifiers => _t.extraModifiers;
  static String get addToCart => _t.addItem;
  static String get cancel => _t.cancel;
  static String get close => _t.close;
  static String get print => _t.print;
  static String get paymentTitle => _t.paymentTitle;
  static String get cash => _t.cash;
  static String get card => _t.card;
  static String get receivedAmount => _t.receivedAmount;
  static String get change => _t.change;
  static String get pay => _t.submit;
  static String get openOrdersTitle => _t.openOrdersTitle;
  static String get noOpenOrders => _t.noOpenOrders;
  static String get retry => _t.retry;
  static String get refresh => _t.retry;
  static String get orderDetails => _t.orderDetails;
  static String get kitchenPrint => _t.kitchenPrint;
  static String get receiptPrint => _t.receiptPrint;
  static String get selectOpenOrderFirst => _t.selectOpenOrderFirst;
  static String get orderCreated => _t.orderCreated;
  static String get orderCancelled => _t.orderCancelled;
  static String get paymentCompleted => _t.paymentCompleted;
  static String get refundAction => _t.refundAction;
  static String get refundCompleted => _t.refundCompleted;
  static String get refundDialogTitle => _t.refundDialogTitle;
  static String get refundReasonLabel => _t.refundReasonLabel;
  static String get refundReasonHint => _t.refundReasonHint;
  static String get refundReasonRequired => _t.refundReasonRequired;
  static String get refundAdminOnly => _t.refundAdminOnly;
  static String get refundBlockedNotPaid => _t.refundBlockedNotPaid;
  static String get refundBlockedPaymentMissing =>
      _t.refundBlockedPaymentMissing;
  static String get refundBlockedCancelled => _t.refundBlockedCancelled;
  static String get refundAlreadyProcessed => _t.refundAlreadyProcessed;
  static String get refundStatusCompleted => _t.refundStatusCompleted;
  static String get refundedAt => _t.refundedAt;
  static String get paymentFailedOrderOpen => _t.paymentFailedOrderOpen;
  static String get printFailed => _t.printFailed;
  static String get printRetryRecommended => _t.printRetryRecommended;
  static String get kitchenPrintSent => _t.kitchenPrintSent;
  static String get receiptPrintSent => _t.receiptPrintSent;
  static String get kitchenPrintPending => _t.kitchenPrintPending;
  static String get receiptPrintPending => _t.receiptPrintPending;
  static String get kitchenPrintInProgress => _t.kitchenPrintInProgress;
  static String get receiptPrintInProgress => _t.receiptPrintInProgress;
  static String get kitchenPrintRetryRequired => _t.kitchenPrintRetryRequired;
  static String get receiptPrintRetryRequired => _t.receiptPrintRetryRequired;
  static String get cancelFailed => _t.cancelFailed;
  static String get shiftNotActiveError => _t.shiftNotActiveError;
  static String get paymentBlockedShiftClosed => _t.paymentUnavailable;
  static String get shiftClosedOpenShiftRequired => _t.shiftClosedMessage;
  static String get salesLockedAdminCloseRequired => _t.salesLockedMessage;
  static String get cashierPreviewLock => _t.salesLockedMessage;
  static String get salesLockedForCashier => _t.salesLockedMessage;
  static String get modifierLoadFailed => _t.modifierLoadFailed;
  static String get modifierNotFound => _t.modifierNotFound;
  static String get confirmCancellation => _t.confirmCancellation;
  static String get yes => _t.yes;
  static String get no => _t.no;
  static String get table => _t.table;
  static String get time => _t.time;
  static String get itemCount => _t.itemCount;
  static String get statusOpen => _t.statusOpen;
  static String get statusClosed => _t.statusClosed;
  static String get statusLocked => _t.statusLocked;
  static String get reportsTitle => _t.reports;
  static String get salesSummary => _t.salesSummary;
  static String get categoryBreakdown => _t.categoryBreakdown;
  static String get businessName => _t.businessName;
  static String get businessAddress => _t.businessAddress;
  static String get reportDate => _t.reportDate;
  static String get reportTime => _t.reportTime;
  static String get shiftNumber => _t.shiftNumber;
  static String get operatorLabel => _t.operatorLabel;
  static String get paymentBreakdown => _t.paymentBreakdown;
  static String get noReportData => _t.noReportData;
  static String get selectShift => _t.selectShift;
  static String get totalOrders => _t.totalOrders;
  static String get totalAmount => _t.totalAmount;
  static String get confirmZReportAction => _t.confirmZReportAction;
  static String get confirmFinalCloseAction => _t.confirmFinalCloseAction;
  static String get activeShiftMissing => _t.activeShiftMissing;
  static String get reportForShift => _t.reportForShift;
  static String get reportForLatestShift => _t.reportForLatestShift;
  static String get accessDenied => _t.accessDenied;
  static String get notFound => _t.notFound;
  static String get unknownUser => _t.unknownUser;
  static String get maskedZReportAction => _t.maskedZReportAction;
  static String get finalZReportAction => _t.finalZReportAction;
  static String get printZReportAction => _t.printZReportAction;
  static String get printUnavailable => _t.printUnavailable;
  static String get zReportPrinted => _t.zReportPrinted;
  static String get maskedReportTaken => _t.maskedReportTaken;
  static String get finalReportTaken => _t.finalReportTaken;
  static String get currentBusinessShift => _t.currentBusinessShift;
  static String get noBusinessShift => _t.noBusinessShift;
  static String get autoShiftOpenHint => _t.autoShiftOpenHint;
  static String get finalCloseHint => _t.finalCloseHint;
  static String get visibilityRatioTitle => _t.visibilityRatioTitle;
  static String get visibilityRatioHint => _t.visibilityRatioHint;
  static String get cashierZReportPolicyTitle => _t.cashierZReportPolicyTitle;
  static String get cashierZReportPolicyHint => _t.cashierZReportPolicyHint;
  static String get cashierProjectionModeLabel => _t.cashierProjectionModeLabel;
  static String get cashierProjectionModePercentage =>
      _t.cashierProjectionModePercentage;
  static String get cashierProjectionModeCapAmount =>
      _t.cashierProjectionModeCapAmount;
  static String get cashierProjectionPercentageHelp =>
      _t.cashierProjectionPercentageHelp;
  static String get cashierProjectionCapAmountLabel =>
      _t.cashierProjectionCapAmountLabel;
  static String get cashierProjectionCapAmountHint =>
      _t.cashierProjectionCapAmountHint;
  static String get cashierProjectionCapAmountHelp =>
      _t.cashierProjectionCapAmountHelp;
  static String get businessIdentitySectionTitle =>
      _t.businessIdentitySectionTitle;
  static String get businessIdentitySectionHint =>
      _t.businessIdentitySectionHint;
  static String get cashierProjectionPreviewTitle =>
      _t.cashierProjectionPreviewTitle;
  static String get cashierProjectionPreviewHint =>
      _t.cashierProjectionPreviewHint;
  static String get cashierProjectionPreviewUnavailable =>
      _t.cashierProjectionPreviewUnavailable;
  static String get realTotalLabel => _t.realTotalLabel;
  static String get cashierVisibleTotalLabel => _t.cashierVisibleTotalLabel;
  static String get realCashLabel => _t.realCashLabel;
  static String get cashierVisibleCashLabel => _t.cashierVisibleCashLabel;
  static String get realCardLabel => _t.realCardLabel;
  static String get cashierVisibleCardLabel => _t.cashierVisibleCardLabel;
  static String get maxVisibleTotalRequired => _t.maxVisibleTotalRequired;
  static String get maxVisibleTotalInvalid => _t.maxVisibleTotalInvalid;
  static String get saveSettings => _t.saveSettings;
  static String get settingsTitle => _t.settingsTitle;
  static String get settingsSaved => _t.settingsSaved;
  static String get editTable => _t.editTable;
  static String get addTable => _t.addTable;
  static String get clearTable => _t.clearTable;
  static String get tableNumberHint => _t.tableNumberHint;
  static String get tableUpdated => _t.tableUpdated;
  static String get tableUnassigned => _t.tableUnassigned;
  static String get shiftMonitorTitle => _t.shiftMonitorTitle;
  static String get openShiftFromLogin => _t.openShiftFromLogin;
  static String get openShiftAdminOnly => _t.openShiftAdminOnly;
  static String get openShiftAction => _t.openShiftAction;
  static String get closeShiftFromZReport => _t.closeShiftFromZReport;
  static String get adminDashboardTitle => _t.adminDashboardTitle;
  static String get todaySales => _t.totalSales;
  static String get totalSales => _t.totalSales;
  static String get adminRealView => _t.adminRealView;
  static String get activeShiftOrders => _t.activeShiftOrders;
  static String get syncPendingTitle => _t.syncPendingTitle;
  static String get syncPendingSubtitle => _t.syncPendingSubtitle;
  static String get syncFailedTitle => _t.syncFailedTitle;
  static String get syncFailedSubtitle => _t.syncFailedSubtitle;
  static String get manageProducts => _t.manageProducts;
  static String get shiftControl => _t.shiftControl;
  static String get syncMonitor => _t.syncMonitor;
  static String get adminDashboardNoActiveShift =>
      _t.adminDashboardNoActiveShift;
  static String get categoryManagementTitle => _t.categoryManagementTitle;
  static String get noCategoriesDefined => _t.noCategoriesDefined;
  static String get categoryCreated => _t.categoryCreated;
  static String get categoryUpdated => _t.categoryUpdated;
  static String get operationFailed => _t.operationFailed;
  static String get categoryToolbarMessage => _t.categoryToolbarMessage;
  static String get addCategory => _t.addCategory;
  static String get sortOrderLabel => _t.sortOrderLabel;
  static String get edit => _t.edit;
  static String get addCategoryDialogTitle => _t.addCategoryDialogTitle;
  static String get editCategoryDialogTitle => _t.editCategoryDialogTitle;
  static String get categoryNameLabel => _t.categoryNameLabel;
  static String get active => _t.active;
  static String get productManagementTitle => _t.productManagementTitle;
  static String get categoryFilterLabel => _t.categoryFilterLabel;
  static String get addProduct => _t.addProduct;
  static String get productListInfoMessage => _t.productListInfoMessage;
  static String get noProductsForSelection => _t.noProductsForSelection;
  static String get productCreated => _t.productCreated;
  static String get productUpdated => _t.productUpdated;
  static String get categoryLabel => _t.categoryLabel;
  static String get productNameLabel => _t.productNameLabel;
  static String get priceMinorLabel => _t.priceMinorLabel;
  static String get hasModifiersLabel => _t.hasModifiersLabel;
  static String get addProductDialogTitle => _t.addProductDialogTitle;
  static String get editProductDialogTitle => _t.editProductDialogTitle;
  static String get modifierManagementTitle => _t.modifierManagementTitle;
  static String get productLabel => _t.productLabel;
  static String get addModifier => _t.addModifier;
  static String get modifierInfoMessage => _t.modifierInfoMessage;
  static String get noModifiersForProduct => _t.noModifiersForProduct;
  static String get modifierCreated => _t.modifierCreated;
  static String get modifierUpdated => _t.modifierUpdated;
  static String get addModifierDialogTitle => _t.addModifierDialogTitle;
  static String get editModifierDialogTitle => _t.editModifierDialogTitle;
  static String get modifierNameLabel => _t.modifierNameLabel;
  static String get typeLabel => _t.typeLabel;
  static String get extraPriceMinorLabel => _t.extraPriceMinorLabel;
  static String get shiftControlTitle => _t.shiftControlTitle;
  static String get shiftControlBannerMessage => _t.shiftControlBannerMessage;
  static String get finalCloseCompleted => _t.finalCloseCompleted;
  static String get finalCloseFailed => _t.finalCloseFailed;
  static String get previousFinalCloseAttemptDetected =>
      _t.previousFinalCloseAttemptDetected;
  static String get resumeFinalCloseAction => _t.resumeFinalCloseAction;
  static String get discardAndReenterAction => _t.discardAndReenterAction;
  static String get finalCloseCashDialogTitle => _t.finalCloseCashDialogTitle;
  static String get enterCountedCashAction => _t.enterCountedCashAction;
  static String get expectedCash => _t.expectedCash;
  static String get countedCash => _t.countedCash;
  static String get countedCashHint => _t.countedCashHint;
  static String get countedCashRequired => _t.countedCashRequired;
  static String get countedCashInvalid => _t.countedCashInvalid;
  static String get countedAtLabel => _t.countedAtLabel;
  static String get countedByLabel => _t.countedByLabel;
  static String get variance => _t.variance;
  static String get grossSales => _t.grossSales;
  static String get refundTotal => _t.refundTotal;
  static String get netSales => _t.netSales;
  static String get grossCash => _t.grossCash;
  static String get netCash => _t.netCash;
  static String get grossCard => _t.grossCard;
  static String get netCard => _t.netCard;
  static String get recentActivity => _t.recentActivity;
  static String get noAuditEntries => _t.noAuditEntries;
  static String get shiftHistoryTitle => _t.shiftHistoryTitle;
  static String get noShiftHistoryYet => _t.noShiftHistoryYet;
  static String get nextLoginOpensShift => _t.nextLoginOpensShift;
  static String get adminFinalClose => _t.adminFinalClose;
  static String get openingLabel => _t.openingLabel;
  static String get closingLabel => _t.closingLabel;
  static String get openedByLabel => _t.openedByLabel;
  static String get closedByLabel => _t.closedByLabel;
  static String get syncMonitorTitle => _t.syncMonitorTitle;
  static String get pending => _t.pending;
  static String get processing => _t.processing;
  static String get syncedStatus => _t.syncedStatus;
  static String get failed => _t.failed;
  static String get stuck => _t.stuck;
  static String get online => _t.online;
  static String get offline => _t.offline;
  static String get workerRunning => _t.workerRunning;
  static String get workerIdle => _t.workerIdle;
  static String get syncEnabled => _t.syncEnabled;
  static String get syncDisabled => _t.syncDisabled;
  static String get retrying => _t.retrying;
  static String get retryAllFailed => _t.retryAllFailed;
  static String get lastSyncTitle => _t.lastSyncTitle;
  static String get noSuccessfulSyncYet => _t.noSuccessfulSyncYet;
  static String get supabaseTitle => _t.supabaseTitle;
  static String get supabaseConfiguredHidden => _t.supabaseConfiguredHidden;
  static String get syncFeatureDisabledForBuild =>
      _t.syncFeatureDisabledForBuild;
  static String get lastErrorTitle => _t.lastErrorTitle;
  static String get noLastError => _t.noLastError;
  static String get syncQueueInfoMessage => _t.syncQueueInfoMessage;
  static String get noSyncQueueItems => _t.noSyncQueueItems;
  static String get retryAllSuccess => _t.retryAllSuccess;
  static String get retryAllFailedMessage => _t.retryAllFailedMessage;
  static String get retryItemSuccess => _t.retryItemSuccess;
  static String get retryFailedMessage => _t.retryFailedMessage;
  static String get statusLabel => _t.statusLabel;
  static String get attemptsLabel => _t.attemptsLabel;
  static String get createdLabel => _t.createdLabel;
  static String get lastAttemptLabel => _t.lastAttemptLabel;
  static String get syncedLabel => _t.syncedLabel;
  static String get errorLabel => _t.errorLabel;
  static String get systemHealthTitle => _t.systemHealthTitle;
  static String get debugLoggingOn => _t.debugLoggingOn;
  static String get debugLoggingOff => _t.debugLoggingOff;
  static String get environmentTitle => _t.environmentTitle;
  static String get appVersionLabel => _t.appVersionLabel;
  static String get environmentLabel => _t.environmentLabel;
  static String get schemaVersionLabel => _t.schemaVersionLabel;
  static String get activeShiftLabel => _t.activeShiftLabel;
  static String get none => _t.none;
  static String get syncStateTitle => _t.syncStateTitle;
  static String get supabaseConfigured => _t.supabaseConfigured;
  static String get supabaseNotConfigured => _t.supabaseNotConfigured;
  static String get configIssueLabel => _t.configIssueLabel;
  static String get lastSyncLabel => _t.lastSyncLabel;
  static String get lastErrorLabel => _t.lastErrorLabel;
  static String get backupTitle => _t.backupTitle;
  static String get lastBackupLabel => _t.lastBackupLabel;
  static String get exportInProgress => _t.exportInProgress;
  static String get exportLocalDb => _t.exportLocalDb;
  static String get exportFailed => _t.exportFailed;
  static String get migrationHistoryTitle => _t.migrationHistoryTitle;
  static String get noMigrationTelemetry => _t.noMigrationTelemetry;
  static String get migrationStarted => _t.migrationStarted;
  static String get migrationSucceeded => _t.migrationSucceeded;
  static String get migrationFailed => _t.migrationFailed;
  static String get operationsControl => _t.operationsControl;
  static String get dashboard => _t.dashboard;
  static String get products => _t.products;
  static String get categories => _t.categories;
  static String get modifiers => _t.modifiers;
  static String get shifts => _t.shifts;
  static String get report => _t.report;
  static String get printer => _t.printer;
  static String get sync => _t.sync;
  static String get system => _t.system;
  static String get printerSettingsTitle => _t.printerSettingsTitle;
  static String get bluetoothPrinter => _t.bluetoothPrinter;
  static String get printerSelectionMessage => _t.printerSelectionMessage;
  static String get bondedDevice => _t.bondedDevice;
  static String get printerSettingSaved => _t.printerSettingSaved;
  static String get saveFailed => _t.saveFailed;
  static String get testPrintSent => _t.testPrintSent;
  static String get testPrintFailed => _t.testPrintFailed;
  static String get testPrint => _t.testPrint;
  static String get reportSettingsTitle => _t.reportSettingsTitle;
  static String get reportSettingSaved => _t.reportSettingSaved;
  static String get reportSettingsInfo => _t.reportSettingsInfo;
  static String get languageLabel => _t.languageLabel;
  static String get languageSettingsHint => _t.languageSettingsHint;
  static String get english => _t.english;
  static String get turkish => _t.turkish;
  static String get paperWidth58 => _t.paperWidth58;
  static String get paperWidth80 => _t.paperWidth80;
  static String get paymentUnavailable => _t.paymentUnavailable;
  static String get paymentAlreadyCompleted => _t.paymentAlreadyCompleted;
  static String get paymentCancelledOrderBlocked =>
      _t.paymentCancelledOrderBlocked;
  static String get paymentNotSentBlocked => _t.paymentNotSentBlocked;
  static String get cartLockedMessage => _t.cartLockedMessage;
  static String get zReport => _t.zReport;
  static String get endOfDay => _t.endOfDay;
  static String get cashTotal => _t.cashTotal;
  static String get cardTotal => _t.cardTotal;
  static String get statusDraft => _t.statusDraft;
  static String get statusDraftStale => _t.statusDraftStale;
  static String get statusSent => _t.statusSent;
  static String get statusPaid => _t.statusPaid;
  static String get statusCancelled => _t.statusCancelled;
  static String get orderStatusLabel => _t.orderStatusLabel;
  static String get orderSent => _t.orderSent;
  static String get sendOrderAction => _t.sendOrderAction;
  static String get closeShiftAction => _t.closeShiftAction;
  static String get shiftLockedMessage => _t.shiftLockedMessage;
  static String get currentShiftSummary => _t.currentShiftSummary;
  static String get shiftIdLabel => _t.shiftIdLabel;
  static String get shiftScreenNoOpenShift => _t.shiftScreenNoOpenShift;
  static String get discardDraftAction => _t.discardDraftAction;
  static String get draftDiscarded => _t.draftDiscarded;
  static String get confirmDiscardDraft => _t.confirmDiscardDraft;
  static String get staleDraftDetailMessage => _t.staleDraftDetailMessage;
  static String get staleDraftCloseHelp => _t.staleDraftCloseHelp;
  static String get sentOrdersPendingLabel => _t.sentOrdersPendingLabel;
  static String get freshDraftsPendingLabel => _t.freshDraftsPendingLabel;
  static String get staleDraftsPendingLabel => _t.staleDraftsPendingLabel;

  static String get openOrderLoadCalm => _t.openOrderLoadCalm;
  static String get openOrderLoadNormal => _t.openOrderLoadNormal;
  static String get openOrderLoadHigh => _t.openOrderLoadHigh;
  static String get openOrderHighLoadWarning => _t.openOrderHighLoadWarning;
  static String get cashierPreviewTakenWarning => _t.cashierPreviewTakenWarning;
  static String get noActiveShiftWarning => _t.noActiveShiftWarning;
  static String get cashAwarenessDisclaimer => _t.cashAwarenessDisclaimer;
  static String get maskedCashFromSales => _t.maskedCashFromSales;
  static String get manualCashMovementsNet => _t.manualCashMovementsNet;
  static String get netTillAwareness => _t.netTillAwareness;
  static String get shiftNormalOperation => _t.shiftNormalOperation;
  static String get shiftPreviewNotTaken => _t.shiftPreviewNotTaken;
  static String get shiftPreviewTaken => _t.shiftPreviewTaken;

  static String orderNumber(int id) => _t.orderNumber(id);
  static String openShiftLabel(int shiftId) => _t.openShiftLabel(shiftId);
  static String orderCountLabel(int count) => _t.orderCountLabel(count);
  static String exportSuccess(String path) => _t.exportSuccess(path);
  static String shiftCloseBlockedSentOrders(int count) =>
      _t.shiftCloseBlockedSentOrders(count);
  static String shiftCloseBlockedFreshDrafts(int count) =>
      _t.shiftCloseBlockedFreshDrafts(count);
  static String shiftCloseBlockedStaleDrafts(int count) =>
      _t.shiftCloseBlockedStaleDrafts(count);

  static String orderStatusText(
    TransactionStatus status, {
    bool isStaleDraft = false,
  }) {
    switch (status) {
      case TransactionStatus.draft:
        return isStaleDraft ? statusDraftStale : statusDraft;
      case TransactionStatus.sent:
        return statusSent;
      case TransactionStatus.paid:
        return statusPaid;
      case TransactionStatus.cancelled:
        return statusCancelled;
    }
  }

  static String shiftStatusText(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.open:
        return shiftOpen;
      case ShiftStatus.closed:
        return shiftClosed;
      case ShiftStatus.locked:
        return shiftLocked;
    }
  }
}
