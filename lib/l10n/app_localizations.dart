import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'EPOS'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'PIN Login'**
  String get loginTitle;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pinLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Operation failed.'**
  String get errorGeneric;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN.'**
  String get enterPin;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed.'**
  String get loginFailed;

  /// No description provided for @invalidPinOrInactiveUser.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN or inactive user.'**
  String get invalidPinOrInactiveUser;

  /// No description provided for @authLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Wait 30 seconds.'**
  String get authLocked;

  /// No description provided for @navPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get navPos;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'Open Orders'**
  String get navOrders;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navAdmin;

  /// No description provided for @navShifts.
  ///
  /// In en, this message translates to:
  /// **'Shift Management'**
  String get navShifts;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get navLogout;

  /// No description provided for @shiftActive.
  ///
  /// In en, this message translates to:
  /// **'Active Shift'**
  String get shiftActive;

  /// No description provided for @shiftInactive.
  ///
  /// In en, this message translates to:
  /// **'No Shift'**
  String get shiftInactive;

  /// No description provided for @shiftOpen.
  ///
  /// In en, this message translates to:
  /// **'Shift Open'**
  String get shiftOpen;

  /// No description provided for @shiftClosed.
  ///
  /// In en, this message translates to:
  /// **'Shift Closed'**
  String get shiftClosed;

  /// No description provided for @shiftLocked.
  ///
  /// In en, this message translates to:
  /// **'Shift Locked'**
  String get shiftLocked;

  /// No description provided for @recentShifts.
  ///
  /// In en, this message translates to:
  /// **'Recent Shifts'**
  String get recentShifts;

  /// No description provided for @noShiftHistory.
  ///
  /// In en, this message translates to:
  /// **'No shift history yet'**
  String get noShiftHistory;

  /// No description provided for @adminOnlyShiftMessage.
  ///
  /// In en, this message translates to:
  /// **'Real end-of-day close can only be completed by an admin.'**
  String get adminOnlyShiftMessage;

  /// No description provided for @closeShiftConfirmation.
  ///
  /// In en, this message translates to:
  /// **'The shift will be closed with the final Z report.'**
  String get closeShiftConfirmation;

  /// No description provided for @openOrdersBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Close blocked — active orders remain'**
  String get openOrdersBlockTitle;

  /// No description provided for @goToOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'Go to Open Orders'**
  String get goToOpenOrders;

  /// No description provided for @shiftOpened.
  ///
  /// In en, this message translates to:
  /// **'Shift opened.'**
  String get shiftOpened;

  /// No description provided for @shiftClosedMessage.
  ///
  /// In en, this message translates to:
  /// **'Shift closed — open a shift to continue'**
  String get shiftClosedMessage;

  /// No description provided for @lastClosedShift.
  ///
  /// In en, this message translates to:
  /// **'Last Closed Shift'**
  String get lastClosedShift;

  /// No description provided for @openedBy.
  ///
  /// In en, this message translates to:
  /// **'Opened by'**
  String get openedBy;

  /// No description provided for @closedBy.
  ///
  /// In en, this message translates to:
  /// **'Closed by'**
  String get closedBy;

  /// No description provided for @cashierPreviewedBy.
  ///
  /// In en, this message translates to:
  /// **'Cashier Preview By'**
  String get cashierPreviewedBy;

  /// No description provided for @cashierPreviewedAt.
  ///
  /// In en, this message translates to:
  /// **'Cashier Preview Time'**
  String get cashierPreviewedAt;

  /// No description provided for @cashierPreviewPending.
  ///
  /// In en, this message translates to:
  /// **'Cashier preview has not been taken yet.'**
  String get cashierPreviewPending;

  /// No description provided for @noRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity yet.'**
  String get noRecentActivity;

  /// No description provided for @cashAwarenessTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash Awareness'**
  String get cashAwarenessTitle;

  /// No description provided for @goToPosNewOrder.
  ///
  /// In en, this message translates to:
  /// **'POS / New Order'**
  String get goToPosNewOrder;

  /// No description provided for @maskedCashCollected.
  ///
  /// In en, this message translates to:
  /// **'Masked cash collected'**
  String get maskedCashCollected;

  /// No description provided for @manualCashMovements.
  ///
  /// In en, this message translates to:
  /// **'Manual cash movements'**
  String get manualCashMovements;

  /// No description provided for @netTillMovement.
  ///
  /// In en, this message translates to:
  /// **'Net till movement'**
  String get netTillMovement;

  /// No description provided for @openedAt.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get openedAt;

  /// No description provided for @closedAt.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closedAt;

  /// No description provided for @paidOrders.
  ///
  /// In en, this message translates to:
  /// **'PAID Orders'**
  String get paidOrders;

  /// No description provided for @cancelledOrders.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED Orders'**
  String get cancelledOrders;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get noCategories;

  /// No description provided for @noProductsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No products in this category'**
  String get noProductsInCategory;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @emptyCart.
  ///
  /// In en, this message translates to:
  /// **'Cart empty — add items'**
  String get emptyCart;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @modifierTotal.
  ///
  /// In en, this message translates to:
  /// **'Modifier Total'**
  String get modifierTotal;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @orderNow.
  ///
  /// In en, this message translates to:
  /// **'Order Now'**
  String get orderNow;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @payAction.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get payAction;

  /// No description provided for @saveAsOpenOrder.
  ///
  /// In en, this message translates to:
  /// **'Save as Open Order'**
  String get saveAsOpenOrder;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @modifierDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Modifier'**
  String get modifierDialogTitle;

  /// No description provided for @includedModifiers.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get includedModifiers;

  /// No description provided for @extraModifiers.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get extraModifiers;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addItem;

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove Item'**
  String get removeItem;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @paymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentTitle;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @receivedAmount.
  ///
  /// In en, this message translates to:
  /// **'Received Amount'**
  String get receivedAmount;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @openOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Orders'**
  String get openOrdersTitle;

  /// No description provided for @noOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'No open orders'**
  String get noOpenOrders;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @kitchenPrint.
  ///
  /// In en, this message translates to:
  /// **'Print Kitchen'**
  String get kitchenPrint;

  /// No description provided for @receiptPrint.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get receiptPrint;

  /// No description provided for @selectOpenOrderFirst.
  ///
  /// In en, this message translates to:
  /// **'Select an open order first.'**
  String get selectOpenOrderFirst;

  /// No description provided for @orderCreated.
  ///
  /// In en, this message translates to:
  /// **'Order created.'**
  String get orderCreated;

  /// No description provided for @orderSent.
  ///
  /// In en, this message translates to:
  /// **'Order sent.'**
  String get orderSent;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled.'**
  String get orderCancelled;

  /// No description provided for @paymentCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment completed.'**
  String get paymentCompleted;

  /// No description provided for @refundAction.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get refundAction;

  /// No description provided for @refundCompleted.
  ///
  /// In en, this message translates to:
  /// **'Refund completed.'**
  String get refundCompleted;

  /// No description provided for @refundDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund Payment'**
  String get refundDialogTitle;

  /// No description provided for @refundReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund reason'**
  String get refundReasonLabel;

  /// No description provided for @refundReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the reason for the refund'**
  String get refundReasonHint;

  /// No description provided for @refundReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Refund reason is required.'**
  String get refundReasonRequired;

  /// No description provided for @refundAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only admins can refund or reverse paid orders.'**
  String get refundAdminOnly;

  /// No description provided for @refundBlockedNotPaid.
  ///
  /// In en, this message translates to:
  /// **'Refund not allowed for unpaid order.'**
  String get refundBlockedNotPaid;

  /// No description provided for @refundBlockedPaymentMissing.
  ///
  /// In en, this message translates to:
  /// **'Refund not allowed — payment not found.'**
  String get refundBlockedPaymentMissing;

  /// No description provided for @refundBlockedCancelled.
  ///
  /// In en, this message translates to:
  /// **'Refund not allowed for cancelled order.'**
  String get refundBlockedCancelled;

  /// No description provided for @refundAlreadyProcessed.
  ///
  /// In en, this message translates to:
  /// **'Refund already recorded for this payment.'**
  String get refundAlreadyProcessed;

  /// No description provided for @refundStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Refund completed'**
  String get refundStatusCompleted;

  /// No description provided for @refundedAt.
  ///
  /// In en, this message translates to:
  /// **'Refunded at'**
  String get refundedAt;

  /// No description provided for @paymentFailedOrderOpen.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Order was not completed.'**
  String get paymentFailedOrderOpen;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed — retry required.'**
  String get printFailed;

  /// No description provided for @printRetryRecommended.
  ///
  /// In en, this message translates to:
  /// **'Print failed — retry from the order screen.'**
  String get printRetryRecommended;

  /// No description provided for @kitchenPrintSent.
  ///
  /// In en, this message translates to:
  /// **'Kitchen ticket sent.'**
  String get kitchenPrintSent;

  /// No description provided for @receiptPrintSent.
  ///
  /// In en, this message translates to:
  /// **'Receipt printed.'**
  String get receiptPrintSent;

  /// No description provided for @kitchenPrintPending.
  ///
  /// In en, this message translates to:
  /// **'Kitchen print pending.'**
  String get kitchenPrintPending;

  /// No description provided for @receiptPrintPending.
  ///
  /// In en, this message translates to:
  /// **'Receipt print pending.'**
  String get receiptPrintPending;

  /// No description provided for @kitchenPrintInProgress.
  ///
  /// In en, this message translates to:
  /// **'Kitchen print in progress.'**
  String get kitchenPrintInProgress;

  /// No description provided for @receiptPrintInProgress.
  ///
  /// In en, this message translates to:
  /// **'Receipt print in progress.'**
  String get receiptPrintInProgress;

  /// No description provided for @kitchenPrintRetryRequired.
  ///
  /// In en, this message translates to:
  /// **'Kitchen print failed. Retry from this order.'**
  String get kitchenPrintRetryRequired;

  /// No description provided for @receiptPrintRetryRequired.
  ///
  /// In en, this message translates to:
  /// **'Receipt print failed. Retry from this order.'**
  String get receiptPrintRetryRequired;

  /// No description provided for @cancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancellation failed.'**
  String get cancelFailed;

  /// No description provided for @shiftNotActiveError.
  ///
  /// In en, this message translates to:
  /// **'No active shift. The next successful login starts a new shift automatically.'**
  String get shiftNotActiveError;

  /// No description provided for @paymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment blocked — shift must be open.'**
  String get paymentUnavailable;

  /// No description provided for @paymentAlreadyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment already completed for this order.'**
  String get paymentAlreadyCompleted;

  /// No description provided for @paymentCancelledOrderBlocked.
  ///
  /// In en, this message translates to:
  /// **'Cancelled orders cannot be paid.'**
  String get paymentCancelledOrderBlocked;

  /// No description provided for @paymentNotSentBlocked.
  ///
  /// In en, this message translates to:
  /// **'Only sent orders can be paid.'**
  String get paymentNotSentBlocked;

  /// No description provided for @salesLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sales locked — admin must complete end-of-day close'**
  String get salesLockedMessage;

  /// No description provided for @cartLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Cart locked — shift action required'**
  String get cartLockedMessage;

  /// No description provided for @modifierLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load modifiers.'**
  String get modifierLoadFailed;

  /// No description provided for @modifierNotFound.
  ///
  /// In en, this message translates to:
  /// **'No modifiers found.'**
  String get modifierNotFound;

  /// No description provided for @confirmCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get confirmCancellation;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @table.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get table;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemCount;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get statusOpen;

  /// No description provided for @statusClosed.
  ///
  /// In en, this message translates to:
  /// **'CLOSED'**
  String get statusClosed;

  /// No description provided for @statusLocked.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get statusLocked;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'DRAFT'**
  String get statusDraft;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'SENT'**
  String get statusSent;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'PAID'**
  String get statusPaid;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get statusCancelled;

  /// No description provided for @orderStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get orderStatusLabel;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @zReport.
  ///
  /// In en, this message translates to:
  /// **'Z Report'**
  String get zReport;

  /// No description provided for @salesSummary.
  ///
  /// In en, this message translates to:
  /// **'Sales Summary'**
  String get salesSummary;

  /// No description provided for @categoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get categoryBreakdown;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get businessName;

  /// No description provided for @businessAddress.
  ///
  /// In en, this message translates to:
  /// **'Business Address'**
  String get businessAddress;

  /// No description provided for @reportDate.
  ///
  /// In en, this message translates to:
  /// **'Report Date'**
  String get reportDate;

  /// No description provided for @reportTime.
  ///
  /// In en, this message translates to:
  /// **'Report Time'**
  String get reportTime;

  /// No description provided for @shiftNumber.
  ///
  /// In en, this message translates to:
  /// **'Shift Number'**
  String get shiftNumber;

  /// No description provided for @operatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get operatorLabel;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @confirmZReportAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm Z Report'**
  String get confirmZReportAction;

  /// No description provided for @confirmFinalCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm Final Close'**
  String get confirmFinalCloseAction;

  /// No description provided for @endOfDay.
  ///
  /// In en, this message translates to:
  /// **'End of Day'**
  String get endOfDay;

  /// No description provided for @cashTotal.
  ///
  /// In en, this message translates to:
  /// **'Cash Total'**
  String get cashTotal;

  /// No description provided for @cardTotal.
  ///
  /// In en, this message translates to:
  /// **'Card Total'**
  String get cardTotal;

  /// No description provided for @paymentBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Payment Breakdown'**
  String get paymentBreakdown;

  /// No description provided for @noReportData.
  ///
  /// In en, this message translates to:
  /// **'No report data found.'**
  String get noReportData;

  /// No description provided for @selectShift.
  ///
  /// In en, this message translates to:
  /// **'Select Shift'**
  String get selectShift;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get totalOrders;

  /// No description provided for @activeShiftMissing.
  ///
  /// In en, this message translates to:
  /// **'No active shift'**
  String get activeShiftMissing;

  /// No description provided for @reportForShift.
  ///
  /// In en, this message translates to:
  /// **'Report for Shift'**
  String get reportForShift;

  /// No description provided for @reportForLatestShift.
  ///
  /// In en, this message translates to:
  /// **'Report for Latest Shift'**
  String get reportForLatestShift;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied.'**
  String get accessDenied;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Record not found.'**
  String get notFound;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get unknownUser;

  /// No description provided for @maskedZReportAction.
  ///
  /// In en, this message translates to:
  /// **'Z Report'**
  String get maskedZReportAction;

  /// No description provided for @finalZReportAction.
  ///
  /// In en, this message translates to:
  /// **'Take Final Z Report and Close Shift'**
  String get finalZReportAction;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @printZReportAction.
  ///
  /// In en, this message translates to:
  /// **'Print Z Report'**
  String get printZReportAction;

  /// No description provided for @printUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Printing is unavailable on this screen.'**
  String get printUnavailable;

  /// No description provided for @zReportPrinted.
  ///
  /// In en, this message translates to:
  /// **'Z report printed.'**
  String get zReportPrinted;

  /// No description provided for @maskedReportTaken.
  ///
  /// In en, this message translates to:
  /// **'Cashier masked end-of-day report taken.'**
  String get maskedReportTaken;

  /// No description provided for @finalReportTaken.
  ///
  /// In en, this message translates to:
  /// **'Final Z report taken and shift closed.'**
  String get finalReportTaken;

  /// No description provided for @currentBusinessShift.
  ///
  /// In en, this message translates to:
  /// **'Current Business Shift'**
  String get currentBusinessShift;

  /// No description provided for @noBusinessShift.
  ///
  /// In en, this message translates to:
  /// **'No open business shift'**
  String get noBusinessShift;

  /// No description provided for @autoShiftOpenHint.
  ///
  /// In en, this message translates to:
  /// **'If there is no active shift, the first successful login starts a new one.'**
  String get autoShiftOpenHint;

  /// No description provided for @finalCloseHint.
  ///
  /// In en, this message translates to:
  /// **'Final close requires counted cash and admin approval.'**
  String get finalCloseHint;

  /// No description provided for @visibilityRatioTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier Visibility Ratio'**
  String get visibilityRatioTitle;

  /// No description provided for @visibilityRatioHint.
  ///
  /// In en, this message translates to:
  /// **'How much of the real numbers should be visible in cashier reports?'**
  String get visibilityRatioHint;

  /// No description provided for @cashierZReportPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier Z Report Policy'**
  String get cashierZReportPolicyTitle;

  /// No description provided for @cashierZReportPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'Configure how cashier-visible Z report totals are projected. These controls are admin-only and do not change the admin report view.'**
  String get cashierZReportPolicyHint;

  /// No description provided for @cashierProjectionModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Projection Mode'**
  String get cashierProjectionModeLabel;

  /// No description provided for @cashierProjectionModePercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get cashierProjectionModePercentage;

  /// No description provided for @cashierProjectionModeCapAmount.
  ///
  /// In en, this message translates to:
  /// **'Cap Amount'**
  String get cashierProjectionModeCapAmount;

  /// No description provided for @cashierProjectionPercentageHelp.
  ///
  /// In en, this message translates to:
  /// **'Apply the selected ratio across cashier-visible totals, payment totals, and category totals.'**
  String get cashierProjectionPercentageHelp;

  /// No description provided for @cashierProjectionCapAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Visible Total'**
  String get cashierProjectionCapAmountLabel;

  /// No description provided for @cashierProjectionCapAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Example: 12.50'**
  String get cashierProjectionCapAmountHint;

  /// No description provided for @cashierProjectionCapAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the maximum cashier-visible total as currency. Example: 12.50.'**
  String get cashierProjectionCapAmountHelp;

  /// No description provided for @businessIdentitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Business Identity'**
  String get businessIdentitySectionTitle;

  /// No description provided for @businessIdentitySectionHint.
  ///
  /// In en, this message translates to:
  /// **'These values appear in cashier Z report headers and cashier-safe print output.'**
  String get businessIdentitySectionHint;

  /// No description provided for @cashierProjectionPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier Projection Preview'**
  String get cashierProjectionPreviewTitle;

  /// No description provided for @cashierProjectionPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'This preview uses the active shift\'s real report and the current draft policy.'**
  String get cashierProjectionPreviewHint;

  /// No description provided for @cashierProjectionPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No active shift is available for projection preview.'**
  String get cashierProjectionPreviewUnavailable;

  /// No description provided for @realTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Real Total'**
  String get realTotalLabel;

  /// No description provided for @cashierVisibleTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Cashier Visible Total'**
  String get cashierVisibleTotalLabel;

  /// No description provided for @realCashLabel.
  ///
  /// In en, this message translates to:
  /// **'Real Cash'**
  String get realCashLabel;

  /// No description provided for @cashierVisibleCashLabel.
  ///
  /// In en, this message translates to:
  /// **'Cashier Visible Cash'**
  String get cashierVisibleCashLabel;

  /// No description provided for @realCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Real Card'**
  String get realCardLabel;

  /// No description provided for @cashierVisibleCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Cashier Visible Card'**
  String get cashierVisibleCardLabel;

  /// No description provided for @maxVisibleTotalRequired.
  ///
  /// In en, this message translates to:
  /// **'Max visible total is required.'**
  String get maxVisibleTotalRequired;

  /// No description provided for @maxVisibleTotalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid currency amount with up to 2 decimal places.'**
  String get maxVisibleTotalInvalid;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get settingsSaved;

  /// No description provided for @editTable.
  ///
  /// In en, this message translates to:
  /// **'Edit Table'**
  String get editTable;

  /// No description provided for @addTable.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get addTable;

  /// No description provided for @clearTable.
  ///
  /// In en, this message translates to:
  /// **'Clear Table'**
  String get clearTable;

  /// No description provided for @tableNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Table number'**
  String get tableNumberHint;

  /// No description provided for @tableUpdated.
  ///
  /// In en, this message translates to:
  /// **'Table number updated.'**
  String get tableUpdated;

  /// No description provided for @tableUnassigned.
  ///
  /// In en, this message translates to:
  /// **'No table assigned'**
  String get tableUnassigned;

  /// No description provided for @shiftMonitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Status'**
  String get shiftMonitorTitle;

  /// No description provided for @openShiftFromLogin.
  ///
  /// In en, this message translates to:
  /// **'If there is no active shift, the next successful login opens one.'**
  String get openShiftFromLogin;

  /// No description provided for @openShiftAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'A shift can be opened by admin or cashier on first login.'**
  String get openShiftAdminOnly;

  /// No description provided for @openShiftAction.
  ///
  /// In en, this message translates to:
  /// **'Open Shift'**
  String get openShiftAction;

  /// No description provided for @closeShiftAction.
  ///
  /// In en, this message translates to:
  /// **'Lock Shift'**
  String get closeShiftAction;

  /// No description provided for @closeShiftFromZReport.
  ///
  /// In en, this message translates to:
  /// **'Shift closing is only done from the Z report screen.'**
  String get closeShiftFromZReport;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboardTitle;

  /// No description provided for @totalSales.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get totalSales;

  /// No description provided for @adminRealView.
  ///
  /// In en, this message translates to:
  /// **'Admin real view'**
  String get adminRealView;

  /// No description provided for @activeShiftOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders on the active shift'**
  String get activeShiftOrders;

  /// No description provided for @syncPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Pending'**
  String get syncPendingTitle;

  /// No description provided for @syncPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Records waiting to be sent'**
  String get syncPendingSubtitle;

  /// No description provided for @syncFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Failed'**
  String get syncFailedTitle;

  /// No description provided for @syncFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Records requiring admin intervention'**
  String get syncFailedSubtitle;

  /// No description provided for @manageProducts.
  ///
  /// In en, this message translates to:
  /// **'Manage Products'**
  String get manageProducts;

  /// No description provided for @shiftControl.
  ///
  /// In en, this message translates to:
  /// **'Shift Control'**
  String get shiftControl;

  /// No description provided for @syncMonitor.
  ///
  /// In en, this message translates to:
  /// **'Sync Monitor'**
  String get syncMonitor;

  /// No description provided for @adminDashboardNoActiveShift.
  ///
  /// In en, this message translates to:
  /// **'There is no active business shift. The next successful login opens a new shift.'**
  String get adminDashboardNoActiveShift;

  /// No description provided for @categoryManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Management'**
  String get categoryManagementTitle;

  /// No description provided for @noCategoriesDefined.
  ///
  /// In en, this message translates to:
  /// **'No categories defined yet.'**
  String get noCategoriesDefined;

  /// No description provided for @categoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Category created.'**
  String get categoryCreated;

  /// No description provided for @categoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Category updated.'**
  String get categoryUpdated;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed.'**
  String get operationFailed;

  /// No description provided for @categoryToolbarMessage.
  ///
  /// In en, this message translates to:
  /// **'The POS category bar depends on this list. Changes to order and active state affect the live POS view.'**
  String get categoryToolbarMessage;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @sortOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort Order'**
  String get sortOrderLabel;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @addCategoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategoryDialogTitle;

  /// No description provided for @editCategoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategoryDialogTitle;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryNameLabel;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @productManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Management'**
  String get productManagementTitle;

  /// No description provided for @categoryFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Category Filter'**
  String get categoryFilterLabel;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @productListInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'All prices are managed as integer price_minor values. Float or decimal UI input is not used.'**
  String get productListInfoMessage;

  /// No description provided for @noProductsForSelection.
  ///
  /// In en, this message translates to:
  /// **'No products in the selected category.'**
  String get noProductsForSelection;

  /// No description provided for @productCreated.
  ///
  /// In en, this message translates to:
  /// **'Product created.'**
  String get productCreated;

  /// No description provided for @productUpdated.
  ///
  /// In en, this message translates to:
  /// **'Product updated.'**
  String get productUpdated;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productNameLabel;

  /// No description provided for @priceMinorLabel.
  ///
  /// In en, this message translates to:
  /// **'Price Minor'**
  String get priceMinorLabel;

  /// No description provided for @hasModifiersLabel.
  ///
  /// In en, this message translates to:
  /// **'Has Modifiers'**
  String get hasModifiersLabel;

  /// No description provided for @addProductDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProductDialogTitle;

  /// No description provided for @editProductDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProductDialogTitle;

  /// No description provided for @modifierManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Modifier Management'**
  String get modifierManagementTitle;

  /// No description provided for @productLabel.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productLabel;

  /// No description provided for @addModifier.
  ///
  /// In en, this message translates to:
  /// **'Add Modifier'**
  String get addModifier;

  /// No description provided for @modifierInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'The distinction between included and extra modifiers affects totals directly. Included modifiers always keep extra_price_minor at 0.'**
  String get modifierInfoMessage;

  /// No description provided for @noModifiersForProduct.
  ///
  /// In en, this message translates to:
  /// **'No modifiers linked to the selected product.'**
  String get noModifiersForProduct;

  /// No description provided for @modifierCreated.
  ///
  /// In en, this message translates to:
  /// **'Modifier created.'**
  String get modifierCreated;

  /// No description provided for @modifierUpdated.
  ///
  /// In en, this message translates to:
  /// **'Modifier updated.'**
  String get modifierUpdated;

  /// No description provided for @addModifierDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Modifier'**
  String get addModifierDialogTitle;

  /// No description provided for @editModifierDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Modifier'**
  String get editModifierDialogTitle;

  /// No description provided for @modifierNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Modifier name'**
  String get modifierNameLabel;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @extraPriceMinorLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra Price Minor'**
  String get extraPriceMinorLabel;

  /// No description provided for @shiftControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Control'**
  String get shiftControlTitle;

  /// No description provided for @shiftControlBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Shifts are not opened from the UI. The first successful login opens a shift. The only operational control here is the admin final close entry point.'**
  String get shiftControlBannerMessage;

  /// No description provided for @shiftLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Shift locked. Cashier sales remain blocked until admin final close.'**
  String get shiftLockedMessage;

  /// No description provided for @finalCloseCompleted.
  ///
  /// In en, this message translates to:
  /// **'Final close completed.'**
  String get finalCloseCompleted;

  /// No description provided for @finalCloseFailed.
  ///
  /// In en, this message translates to:
  /// **'Final close failed.'**
  String get finalCloseFailed;

  /// No description provided for @previousFinalCloseAttemptDetected.
  ///
  /// In en, this message translates to:
  /// **'Previous final close attempt detected'**
  String get previousFinalCloseAttemptDetected;

  /// No description provided for @resumeFinalCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Resume Final Close'**
  String get resumeFinalCloseAction;

  /// No description provided for @discardAndReenterAction.
  ///
  /// In en, this message translates to:
  /// **'Discard and Re-enter'**
  String get discardAndReenterAction;

  /// No description provided for @finalCloseCashDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Final Close Cash Reconciliation'**
  String get finalCloseCashDialogTitle;

  /// No description provided for @enterCountedCashAction.
  ///
  /// In en, this message translates to:
  /// **'Enter Counted Cash'**
  String get enterCountedCashAction;

  /// No description provided for @expectedCash.
  ///
  /// In en, this message translates to:
  /// **'Expected Cash'**
  String get expectedCash;

  /// No description provided for @countedCash.
  ///
  /// In en, this message translates to:
  /// **'Counted Cash'**
  String get countedCash;

  /// No description provided for @countedCashHint.
  ///
  /// In en, this message translates to:
  /// **'Enter counted cash in minor units before final close'**
  String get countedCashHint;

  /// No description provided for @countedCashRequired.
  ///
  /// In en, this message translates to:
  /// **'Counted cash is required before final close.'**
  String get countedCashRequired;

  /// No description provided for @countedCashInvalid.
  ///
  /// In en, this message translates to:
  /// **'Counted cash must be zero or greater.'**
  String get countedCashInvalid;

  /// No description provided for @countedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Counted At'**
  String get countedAtLabel;

  /// No description provided for @countedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Counted By'**
  String get countedByLabel;

  /// No description provided for @variance.
  ///
  /// In en, this message translates to:
  /// **'Variance'**
  String get variance;

  /// No description provided for @grossSales.
  ///
  /// In en, this message translates to:
  /// **'Gross Sales'**
  String get grossSales;

  /// No description provided for @refundTotal.
  ///
  /// In en, this message translates to:
  /// **'Refund Total'**
  String get refundTotal;

  /// No description provided for @netSales.
  ///
  /// In en, this message translates to:
  /// **'Net Sales'**
  String get netSales;

  /// No description provided for @grossCash.
  ///
  /// In en, this message translates to:
  /// **'Gross Cash'**
  String get grossCash;

  /// No description provided for @netCash.
  ///
  /// In en, this message translates to:
  /// **'Net Cash'**
  String get netCash;

  /// No description provided for @grossCard.
  ///
  /// In en, this message translates to:
  /// **'Gross Card'**
  String get grossCard;

  /// No description provided for @netCard.
  ///
  /// In en, this message translates to:
  /// **'Net Card'**
  String get netCard;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noAuditEntries.
  ///
  /// In en, this message translates to:
  /// **'No audit entries recorded yet.'**
  String get noAuditEntries;

  /// No description provided for @shiftHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift History'**
  String get shiftHistoryTitle;

  /// No description provided for @noShiftHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No shift history available yet.'**
  String get noShiftHistoryYet;

  /// No description provided for @nextLoginOpensShift.
  ///
  /// In en, this message translates to:
  /// **'No active shift. The next successful login will open one.'**
  String get nextLoginOpensShift;

  /// No description provided for @adminFinalClose.
  ///
  /// In en, this message translates to:
  /// **'Admin Final Close'**
  String get adminFinalClose;

  /// No description provided for @openingLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get openingLabel;

  /// No description provided for @closingLabel.
  ///
  /// In en, this message translates to:
  /// **'Closing'**
  String get closingLabel;

  /// No description provided for @openedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Opened By'**
  String get openedByLabel;

  /// No description provided for @closedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Closed By'**
  String get closedByLabel;

  /// No description provided for @syncMonitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Monitor'**
  String get syncMonitorTitle;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @syncedStatus.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncedStatus;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @stuck.
  ///
  /// In en, this message translates to:
  /// **'Stuck'**
  String get stuck;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @workerRunning.
  ///
  /// In en, this message translates to:
  /// **'Worker Running'**
  String get workerRunning;

  /// No description provided for @workerIdle.
  ///
  /// In en, this message translates to:
  /// **'Worker Idle'**
  String get workerIdle;

  /// No description provided for @syncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sync Enabled'**
  String get syncEnabled;

  /// No description provided for @syncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sync Disabled'**
  String get syncDisabled;

  /// No description provided for @retrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get retrying;

  /// No description provided for @retryAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry All Failed'**
  String get retryAllFailed;

  /// No description provided for @lastSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Last Sync'**
  String get lastSyncTitle;

  /// No description provided for @noSuccessfulSyncYet.
  ///
  /// In en, this message translates to:
  /// **'No successful sync yet.'**
  String get noSuccessfulSyncYet;

  /// No description provided for @supabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Supabase'**
  String get supabaseTitle;

  /// No description provided for @supabaseConfiguredHidden.
  ///
  /// In en, this message translates to:
  /// **'Client sync gateway configured. Secret values hidden.'**
  String get supabaseConfiguredHidden;

  /// No description provided for @syncFeatureDisabledForBuild.
  ///
  /// In en, this message translates to:
  /// **'Sync feature is disabled for this build.'**
  String get syncFeatureDisabledForBuild;

  /// No description provided for @lastErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Last Error'**
  String get lastErrorTitle;

  /// No description provided for @noLastError.
  ///
  /// In en, this message translates to:
  /// **'No recent error.'**
  String get noLastError;

  /// No description provided for @syncQueueInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'Queue manipulation only happens through the repository. The worker processes pending and failed items in batches, applies retry backoff, and leaves max-attempt items stuck.'**
  String get syncQueueInfoMessage;

  /// No description provided for @noSyncQueueItems.
  ///
  /// In en, this message translates to:
  /// **'There are no pending, failed, or processing records.'**
  String get noSyncQueueItems;

  /// No description provided for @retryAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'Failed records were moved back to pending and the worker was started again.'**
  String get retryAllSuccess;

  /// No description provided for @retryAllFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Retry all failed.'**
  String get retryAllFailedMessage;

  /// No description provided for @retryItemSuccess.
  ///
  /// In en, this message translates to:
  /// **'The sync record was moved back to pending for retry.'**
  String get retryItemSuccess;

  /// No description provided for @retryFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Retry failed.'**
  String get retryFailedMessage;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @attemptsLabel.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get attemptsLabel;

  /// No description provided for @createdLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdLabel;

  /// No description provided for @lastAttemptLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Attempt'**
  String get lastAttemptLabel;

  /// No description provided for @syncedLabel.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncedLabel;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorLabel;

  /// No description provided for @systemHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'System Health'**
  String get systemHealthTitle;

  /// No description provided for @debugLoggingOn.
  ///
  /// In en, this message translates to:
  /// **'Debug Logging On'**
  String get debugLoggingOn;

  /// No description provided for @debugLoggingOff.
  ///
  /// In en, this message translates to:
  /// **'Debug Logging Off'**
  String get debugLoggingOff;

  /// No description provided for @environmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environmentTitle;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersionLabel;

  /// No description provided for @environmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environmentLabel;

  /// No description provided for @schemaVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Schema Version'**
  String get schemaVersionLabel;

  /// No description provided for @activeShiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Shift'**
  String get activeShiftLabel;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @syncStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync State'**
  String get syncStateTitle;

  /// No description provided for @supabaseConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get supabaseConfigured;

  /// No description provided for @supabaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get supabaseNotConfigured;

  /// No description provided for @configIssueLabel.
  ///
  /// In en, this message translates to:
  /// **'Config Issue'**
  String get configIssueLabel;

  /// No description provided for @lastSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Sync'**
  String get lastSyncLabel;

  /// No description provided for @lastErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Error'**
  String get lastErrorLabel;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @lastBackupLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Backup'**
  String get lastBackupLabel;

  /// No description provided for @exportInProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exportInProgress;

  /// No description provided for @exportLocalDb.
  ///
  /// In en, this message translates to:
  /// **'Export Local DB'**
  String get exportLocalDb;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup exported to {path}.'**
  String exportSuccess(String path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup export failed.'**
  String get exportFailed;

  /// No description provided for @migrationHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration History'**
  String get migrationHistoryTitle;

  /// No description provided for @noMigrationTelemetry.
  ///
  /// In en, this message translates to:
  /// **'No migration telemetry recorded yet.'**
  String get noMigrationTelemetry;

  /// No description provided for @migrationStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get migrationStarted;

  /// No description provided for @migrationSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get migrationSucceeded;

  /// No description provided for @migrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get migrationFailed;

  /// No description provided for @operationsControl.
  ///
  /// In en, this message translates to:
  /// **'Operations Control'**
  String get operationsControl;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @modifiers.
  ///
  /// In en, this message translates to:
  /// **'Modifiers'**
  String get modifiers;

  /// No description provided for @shifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get shifts;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @printer.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get printer;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @printerSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Printer Settings'**
  String get printerSettingsTitle;

  /// No description provided for @bluetoothPrinter.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Printer'**
  String get bluetoothPrinter;

  /// No description provided for @printerSelectionMessage.
  ///
  /// In en, this message translates to:
  /// **'Printer selection and test flow run through printer_service. Errors are handled with try/catch; there is no silent failure.'**
  String get printerSelectionMessage;

  /// No description provided for @bondedDevice.
  ///
  /// In en, this message translates to:
  /// **'Bonded device'**
  String get bondedDevice;

  /// No description provided for @printerSettingSaved.
  ///
  /// In en, this message translates to:
  /// **'Printer setting saved.'**
  String get printerSettingSaved;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed.'**
  String get saveFailed;

  /// No description provided for @testPrintSent.
  ///
  /// In en, this message translates to:
  /// **'Test print sent.'**
  String get testPrintSent;

  /// No description provided for @testPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Test print failed.'**
  String get testPrintFailed;

  /// No description provided for @testPrint.
  ///
  /// In en, this message translates to:
  /// **'Test Print'**
  String get testPrint;

  /// No description provided for @reportSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Settings'**
  String get reportSettingsTitle;

  /// No description provided for @reportSettingSaved.
  ///
  /// In en, this message translates to:
  /// **'Report setting saved.'**
  String get reportSettingSaved;

  /// No description provided for @reportSettingsInfo.
  ///
  /// In en, this message translates to:
  /// **'Mask calculations are not done in the UI. This screen only writes the ratio to the database; the real visibility rules stay in the domain report visibility service.'**
  String get reportSettingsInfo;

  /// No description provided for @sendOrderAction.
  ///
  /// In en, this message translates to:
  /// **'Send Order'**
  String get sendOrderAction;

  /// No description provided for @currentShiftSummary.
  ///
  /// In en, this message translates to:
  /// **'Current Shift Summary'**
  String get currentShiftSummary;

  /// No description provided for @shiftIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift ID'**
  String get shiftIdLabel;

  /// No description provided for @shiftScreenNoOpenShift.
  ///
  /// In en, this message translates to:
  /// **'No shift is open. POS operations remain blocked until a shift is opened.'**
  String get shiftScreenNoOpenShift;

  /// No description provided for @statusDraftStale.
  ///
  /// In en, this message translates to:
  /// **'STALE DRAFT'**
  String get statusDraftStale;

  /// No description provided for @discardDraftAction.
  ///
  /// In en, this message translates to:
  /// **'Discard Draft'**
  String get discardDraftAction;

  /// No description provided for @draftDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Draft discarded.'**
  String get draftDiscarded;

  /// No description provided for @confirmDiscardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard this draft? This removes the abandoned cart and does not count as a cancelled sale.'**
  String get confirmDiscardDraft;

  /// No description provided for @staleDraftDetailMessage.
  ///
  /// In en, this message translates to:
  /// **'This draft is stale. It should be discarded before final close.'**
  String get staleDraftDetailMessage;

  /// No description provided for @staleDraftCloseHelp.
  ///
  /// In en, this message translates to:
  /// **'Stale drafts are cleanup items. Review them in Open Orders and discard them before final close.'**
  String get staleDraftCloseHelp;

  /// No description provided for @sentOrdersPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Sent Orders Blocking Close'**
  String get sentOrdersPendingLabel;

  /// No description provided for @freshDraftsPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Fresh Drafts Blocking Close'**
  String get freshDraftsPendingLabel;

  /// No description provided for @staleDraftsPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Stale Drafts Pending Cleanup'**
  String get staleDraftsPendingLabel;

  /// No description provided for @shiftCloseBlockedSentOrders.
  ///
  /// In en, this message translates to:
  /// **'{count} sent order(s) still need payment or cancellation before final close.'**
  String shiftCloseBlockedSentOrders(int count);

  /// No description provided for @shiftCloseBlockedFreshDrafts.
  ///
  /// In en, this message translates to:
  /// **'{count} fresh draft(s) still need to be sent or discarded before final close.'**
  String shiftCloseBlockedFreshDrafts(int count);

  /// No description provided for @shiftCloseBlockedStaleDrafts.
  ///
  /// In en, this message translates to:
  /// **'{count} stale draft(s) must be discarded before final close.'**
  String shiftCloseBlockedStaleDrafts(int count);

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Change the operator language at runtime. English stays as the default fallback.'**
  String get languageSettingsHint;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// No description provided for @paperWidth58.
  ///
  /// In en, this message translates to:
  /// **'58 mm'**
  String get paperWidth58;

  /// No description provided for @paperWidth80.
  ///
  /// In en, this message translates to:
  /// **'80 mm'**
  String get paperWidth80;

  /// No description provided for @orderCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} orders'**
  String orderCountLabel(int count);

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderNumber(int id);

  /// No description provided for @openShiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift #{shiftId}'**
  String openShiftLabel(int shiftId);

  /// No description provided for @openOrderLoadCalm.
  ///
  /// In en, this message translates to:
  /// **'No queue'**
  String get openOrderLoadCalm;

  /// No description provided for @openOrderLoadNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get openOrderLoadNormal;

  /// No description provided for @openOrderLoadHigh.
  ///
  /// In en, this message translates to:
  /// **'High load'**
  String get openOrderLoadHigh;

  /// No description provided for @openOrderHighLoadWarning.
  ///
  /// In en, this message translates to:
  /// **'Many open orders — consider clearing the queue'**
  String get openOrderHighLoadWarning;

  /// No description provided for @cashierPreviewTakenWarning.
  ///
  /// In en, this message translates to:
  /// **'End-of-day preview already taken — cashier actions locked'**
  String get cashierPreviewTakenWarning;

  /// No description provided for @noActiveShiftWarning.
  ///
  /// In en, this message translates to:
  /// **'No active shift — all operations locked'**
  String get noActiveShiftWarning;

  /// No description provided for @cashAwarenessDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Approximate awareness only — not a formal accounting balance'**
  String get cashAwarenessDisclaimer;

  /// No description provided for @maskedCashFromSales.
  ///
  /// In en, this message translates to:
  /// **'Cash from sales (masked)'**
  String get maskedCashFromSales;

  /// No description provided for @manualCashMovementsNet.
  ///
  /// In en, this message translates to:
  /// **'Manual movements (net)'**
  String get manualCashMovementsNet;

  /// No description provided for @netTillAwareness.
  ///
  /// In en, this message translates to:
  /// **'Net till awareness'**
  String get netTillAwareness;

  /// No description provided for @shiftNormalOperation.
  ///
  /// In en, this message translates to:
  /// **'Normal operation'**
  String get shiftNormalOperation;

  /// No description provided for @shiftPreviewNotTaken.
  ///
  /// In en, this message translates to:
  /// **'Preview not yet taken'**
  String get shiftPreviewNotTaken;

  /// No description provided for @shiftPreviewTaken.
  ///
  /// In en, this message translates to:
  /// **'Preview taken — cashier locked'**
  String get shiftPreviewTaken;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
