import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/data/repositories/cash_movement_repository.dart';
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/repositories/system_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/printer_device_option.dart';
import 'package:epos_app/domain/models/printer_settings.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/models/sync_queue_item.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/admin_service.dart';
import 'package:epos_app/domain/services/audit_log_service.dart';
import 'package:epos_app/domain/services/cash_movement_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/payment_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:epos_app/presentation/providers/admin_printer_settings_provider.dart';
import 'package:epos_app/presentation/providers/admin_sync_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/products_provider.dart';
import 'package:epos_app/presentation/screens/admin/admin_audit_logs_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_categories_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_modifiers_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_printer_settings_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_products_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_report_settings_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_shifts_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_sync_screen.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_database.dart';

late SharedPreferences _testPrefs;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _testPrefs = await SharedPreferences.getInstance();
  });

  group('Phase 4 admin panel', () {
    testWidgets(
      'cashier admin route matrixinde tüm deep-linkleri redirect alır',
      (WidgetTester tester) async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        await insertUser(db, name: 'Cashier', role: 'cashier', pin: '0000');
        final int categoryId = await insertCategory(db, name: 'Drinks');
        await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 250,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(_testPrefs),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _TestRouterApp(),
          ),
        );
        await tester.pumpAndSettle();
        await _loginWithPin(tester, '0000');

        for (final _AdminRouteExpectation route in _adminRoutes) {
          container.read(appRouterProvider).go(route.path);
          await tester.pumpAndSettle();

          expect(
            find.byType(PosScreen),
            findsOneWidget,
            reason: '${route.path} cashier için POS’a dönmeli.',
          );
          expect(
            find.byType(route.screenType),
            findsNothing,
            reason: '${route.path} admin-only kalmalı.',
          );
        }
      },
    );

    testWidgets('admin navigation settings item opens report settings screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(_testPrefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestRouterApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _loginWithPin(tester, '9999');

      container.read(appRouterProvider).go('/admin');
      await tester.pumpAndSettle();

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.text(AppStrings.navSettings), findsOneWidget);

      await tester.tap(find.text(AppStrings.navSettings));
      await tester.pumpAndSettle();

      expect(find.byType(AdminReportSettingsScreen), findsOneWidget);
    });

    test('admin report gerçek veri görür', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'admin-real-report',
        shiftId: shiftId,
        userId: adminId,
        status: 'draft',
        totalAmountMinor: 1250,
      );
      final int categoryId = await insertCategory(db, name: 'Hot Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Latte',
        priceMinor: 1250,
      );

      await TransactionRepository(db).addLine(
        transactionId: transactionId,
        productId: productId,
        quantity: 1,
      );
      await _makeOrderService(db).sendOrder(
        transactionId: transactionId,
        currentUser: _adminUser(adminId),
      );
      await _makeOrderService(db).markOrderPaid(
        transactionId: transactionId,
        method: PaymentMethod.card,
        currentUser: _adminUser(adminId),
      );

      final ShiftReport report = await _makeReportService(
        db,
      ).getVisibleShiftReport(shiftId: shiftId, user: _adminUser(adminId));

      expect(report.paidTotalMinor, 1250);
      expect(report.cardTotalMinor, 1250);
      expect(report.paidCount, 1);
    });

    test('visibility_ratio değişince cashier view değişir', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'cashier-visibility-report',
        shiftId: shiftId,
        userId: adminId,
        status: 'draft',
        totalAmountMinor: 1000,
      );
      final int categoryId = await insertCategory(db, name: 'Breakfast');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Plate',
        priceMinor: 1000,
      );

      await TransactionRepository(db).addLine(
        transactionId: transactionId,
        productId: productId,
        quantity: 1,
      );
      await _makeOrderService(db).sendOrder(
        transactionId: transactionId,
        currentUser: _adminUser(adminId),
      );
      await _makeOrderService(db).markOrderPaid(
        transactionId: transactionId,
        method: PaymentMethod.cash,
        currentUser: _adminUser(adminId),
      );

      final ReportService reportService = _makeReportService(db);
      final SettingsRepository settingsRepository = SettingsRepository(db);
      final User cashier = User(
        id: cashierId,
        name: 'Cashier',
        pin: null,
        password: null,
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await settingsRepository.updateVisibilityRatio(0.5, userId: adminId);
      final ShiftReport halfVisible = await reportService.getVisibleShiftReport(
        shiftId: shiftId,
        user: cashier,
      );

      await settingsRepository.updateVisibilityRatio(0.2, userId: adminId);
      final ShiftReport reducedVisible = await reportService
          .getVisibleShiftReport(shiftId: shiftId, user: cashier);

      expect(halfVisible.paidTotalMinor, 500);
      expect(reducedVisible.paidTotalMinor, 200);
    });

    test('admin final close başarılıysa shift kapanır', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);

      final result = await _makeReportService(db)
          .runAdminFinalCloseWithCountedCash(
            user: _adminUser(adminId),
            countedCashMinor: 0,
          );

      final Shift? openShift = await ShiftRepository(db).getOpenShift();
      final Shift closedShift = (await _makeAdminService(
        db,
      ).getRecentShifts(user: _adminUser(adminId), limit: 1)).single;

      expect(result.shiftId, shiftId);
      expect(result.finalCloseCompleted, isTrue);
      expect(openShift, isNull);
      expect(closedShift.status, ShiftStatus.closed);
      expect(closedShift.closedBy, adminId);
      expect(closedShift.closedAt, isNotNull);
    });

    test('OPEN order varken admin final close reddedilir', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      await insertTransaction(
        db,
        uuid: 'open-order-blocks-close',
        shiftId: shiftId,
        userId: adminId,
        status: 'sent',
        totalAmountMinor: 900,
      );

      await expectLater(
        () => _makeReportService(db).runAdminFinalCloseWithCountedCash(
          user: _adminUser(adminId),
          countedCashMinor: 0,
        ),
        throwsA(
          isA<ShiftCloseBlockedException>().having(
            (ShiftCloseBlockedException error) =>
                error.readiness.sentOrderCount,
            'sentOrderCount',
            1,
          ),
        ),
      );

      final Shift? openShift = await ShiftRepository(db).getOpenShift();
      expect(openShift?.id, shiftId);
      expect(openShift?.status, ShiftStatus.open);
    });

    test('final close sonrası yeni order ve payment engellenir', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      await _makeReportService(db).runAdminFinalCloseWithCountedCash(
        user: _adminUser(adminId),
        countedCashMinor: 0,
      );

      await expectLater(
        () =>
            _makeOrderService(db).createOrder(currentUser: _adminUser(adminId)),
        throwsA(isA<ShiftNotActiveException>()),
      );

      final int closedShiftTransactionId = await insertTransaction(
        db,
        uuid: 'closed-shift-open-order',
        shiftId: shiftId,
        userId: adminId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      await expectLater(
        () => _makePaymentService(db).payOrder(
          transactionId: closedShiftTransactionId,
          method: PaymentMethod.cash,
          currentUser: _adminUser(adminId),
        ),
        throwsA(isA<ShiftNotActiveException>()),
      );

      final payment = await PaymentRepository(
        db,
      ).getByTransactionId(closedShiftTransactionId);
      expect(payment, isNull);
    });

    test(
      'sync monitor toplamları 100 kayıttan büyük queue için aggregate query ile hesaplanır',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        for (int index = 0; index < 120; index += 1) {
          await insertSyncQueueItem(
            db,
            tableName: 'transactions',
            recordUuid: 'pending-$index',
            status: 'pending',
          );
        }
        for (int index = 0; index < 7; index += 1) {
          await insertSyncQueueItem(
            db,
            tableName: 'payments',
            recordUuid: 'failed-$index',
            status: 'failed',
            attemptCount: 3,
            errorMessage: 'timeout',
          );
        }
        for (int index = 0; index < 5; index += 1) {
          await insertSyncQueueItem(
            db,
            tableName: 'transaction_lines',
            recordUuid: 'processing-$index',
            status: 'processing',
          );
        }

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(_testPrefs),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(adminId);
        await container.read(adminSyncNotifierProvider.notifier).load();

        final AdminSyncState state = container.read(adminSyncNotifierProvider);
        expect(state.pendingCount, 120);
        expect(state.failedCount, 7);
        expect(state.items.length, 100);
        expect(state.syncEnabled, isTrue);
        expect(state.isSupabaseConfigured, isFalse);
        expect(state.supabaseConfigurationLabel, 'Supabase config missing');
      },
    );

    test('sync retry sonrası count ve status doğru güncellenir', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'pending-before-retry',
        status: 'pending',
      );
      final int retriedItemId = await insertSyncQueueItem(
        db,
        tableName: 'payments',
        recordUuid: 'failed-retry-target',
        status: 'failed',
        attemptCount: 4,
        errorMessage: 'network timeout',
      );
      await insertSyncQueueItem(
        db,
        tableName: 'payments',
        recordUuid: 'failed-stays-failed',
        status: 'failed',
        attemptCount: 2,
        errorMessage: 'dns error',
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(_testPrefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(adminSyncNotifierProvider.notifier).load();

      var state = container.read(adminSyncNotifierProvider);
      expect(state.pendingCount, 1);
      expect(state.failedCount, 2);

      final bool retried = await container
          .read(adminSyncNotifierProvider.notifier)
          .retryItem(retriedItemId);
      expect(retried, isTrue);

      state = container.read(adminSyncNotifierProvider);
      final SyncQueueItem retriedItem = state.items.singleWhere(
        (SyncQueueItem item) => item.id == retriedItemId,
      );

      expect(state.pendingCount, 2);
      expect(state.failedCount, 1);
      expect(retriedItem.status, SyncQueueStatus.pending);
      expect(retriedItem.attemptCount, 0);
      expect(retriedItem.errorMessage, isNull);
    });

    test(
      'hidden and inactive products plus empty categories POSta görünmez ama admin tarafında görünür',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final AdminService adminService = _makeAdminService(db);
        final int activeCategoryId = await insertCategory(
          db,
          name: 'Visible Category',
        );
        final int hiddenOnlyCategoryId = await insertCategory(
          db,
          name: 'Hidden Only Category',
        );
        final int inactiveOnlyCategoryId = await insertCategory(
          db,
          name: 'Inactive Only Category',
        );
        final int visibleProductId = await insertProduct(
          db,
          categoryId: activeCategoryId,
          name: 'Visible Product',
          priceMinor: 400,
        );
        final int hiddenProductId = await insertProduct(
          db,
          categoryId: hiddenOnlyCategoryId,
          name: 'Hidden Product',
          priceMinor: 700,
          isVisibleOnPos: false,
        );
        final int inactiveProductId = await insertProduct(
          db,
          categoryId: inactiveOnlyCategoryId,
          name: 'Inactive Product',
          priceMinor: 550,
          isActive: false,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(_testPrefs),
          ],
        );
        addTearDown(container.dispose);

        await container.read(productsNotifierProvider.notifier).loadCatalog();
        var productsState = container.read(productsNotifierProvider);

        expect(
          productsState.categories.any(
            (category) => category.id == hiddenOnlyCategoryId,
          ),
          isFalse,
        );
        expect(
          productsState.categories.any(
            (category) => category.id == inactiveOnlyCategoryId,
          ),
          isFalse,
        );
        expect(
          productsState.products.any(
            (product) => product.id == visibleProductId,
          ),
          isTrue,
        );
        expect(
          productsState.products.any(
            (product) => product.id == hiddenProductId,
          ),
          isFalse,
        );
        expect(
          productsState.products.any(
            (product) => product.id == inactiveProductId,
          ),
          isFalse,
        );

        await container
            .read(productsNotifierProvider.notifier)
            .selectCategory(null);
        productsState = container.read(productsNotifierProvider);
        expect(
          productsState.products.any(
            (product) => product.id == hiddenProductId,
          ),
          isFalse,
        );
        expect(
          productsState.products.any(
            (product) => product.id == inactiveProductId,
          ),
          isFalse,
        );

        final List<Product> hiddenAdminProducts = await adminService
            .getProducts(categoryId: hiddenOnlyCategoryId);
        expect(
          hiddenAdminProducts.any(
            (Product product) => product.id == hiddenProductId,
          ),
          isTrue,
        );
        expect(
          hiddenAdminProducts
              .singleWhere((Product product) => product.id == hiddenProductId)
              .isVisibleOnPos,
          isFalse,
        );

        final List<Product> inactiveAdminProducts = await adminService
            .getProducts(categoryId: inactiveOnlyCategoryId);
        expect(
          inactiveAdminProducts.any(
            (Product product) => product.id == inactiveProductId,
          ),
          isTrue,
        );
        expect(
          inactiveAdminProducts
              .singleWhere((Product product) => product.id == inactiveProductId)
              .isActive,
          isFalse,
        );

        await adminService.toggleCategoryActive(
          user: _adminUser(adminId),
          id: activeCategoryId,
          isActive: false,
        );

        await container.read(productsNotifierProvider.notifier).loadCatalog();
        productsState = container.read(productsNotifierProvider);

        expect(productsState.categories, isEmpty);
        expect(productsState.products, isEmpty);

        final hiddenCategoryProducts = await container
            .read(catalogServiceProvider)
            .getProducts(categoryId: hiddenOnlyCategoryId);
        expect(hiddenCategoryProducts, isEmpty);
        final inactiveCategoryProducts = await container
            .read(catalogServiceProvider)
            .getProducts(categoryId: inactiveOnlyCategoryId);
        expect(inactiveCategoryProducts, isEmpty);
      },
    );

    test(
      'printer settings test print printer_service üzerinden gider',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        await insertPrinterSettings(
          db,
          deviceName: 'Counter Printer',
          deviceAddress: 'AA:BB:CC',
        );
        final _TrackingPrinterService printerService = _TrackingPrinterService(
          db,
          devices: const <PrinterDeviceOption>[
            PrinterDeviceOption(name: 'Counter Printer', address: 'AA:BB:CC'),
            PrinterDeviceOption(name: 'Backup Printer', address: 'DD:EE:FF'),
          ],
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            printerServiceProvider.overrideWithValue(printerService),
            sharedPreferencesProvider.overrideWithValue(_testPrefs),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(adminId);
        await container
            .read(adminPrinterSettingsNotifierProvider.notifier)
            .load();

        final bool printed = await container
            .read(adminPrinterSettingsNotifierProvider.notifier)
            .testPrint();

        final AdminPrinterSettingsState state = container.read(
          adminPrinterSettingsNotifierProvider,
        );
        expect(printed, isTrue);
        expect(printerService.testPrintCalls, 1);
        expect(printerService.lastDeviceName, 'Counter Printer');
        expect(printerService.lastDeviceAddress, 'AA:BB:CC');
        expect(printerService.lastPaperWidth, 80);
        expect(state.errorMessage, isNull);
      },
    );

    test(
      'printer test failure state mutation yaratmaz ve hata provider zincirinde görünür',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        await insertPrinterSettings(
          db,
          deviceName: 'Counter Printer',
          deviceAddress: 'AA:BB:CC',
        );
        final _TrackingPrinterService printerService = _TrackingPrinterService(
          db,
          devices: const <PrinterDeviceOption>[
            PrinterDeviceOption(name: 'Counter Printer', address: 'AA:BB:CC'),
          ],
          testPrintError: PrinterException('Bluetooth link lost.'),
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            printerServiceProvider.overrideWithValue(printerService),
            sharedPreferencesProvider.overrideWithValue(_testPrefs),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(adminId);
        await container
            .read(adminPrinterSettingsNotifierProvider.notifier)
            .load();

        final PrinterSettingsModel? before = await SettingsRepository(
          db,
        ).getActivePrinterSettings();
        final bool printed = await container
            .read(adminPrinterSettingsNotifierProvider.notifier)
            .testPrint();
        final PrinterSettingsModel? after = await SettingsRepository(
          db,
        ).getActivePrinterSettings();

        final AdminPrinterSettingsState state = container.read(
          adminPrinterSettingsNotifierProvider,
        );
        expect(printed, isFalse);
        expect(printerService.testPrintCalls, 1);
        expect(state.errorMessage, AppStrings.printRetryRecommended);
        expect(before, after);
        expect(state.selectedAddress, 'AA:BB:CC');
      },
    );

    test('product create/update POSta görünür', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int categoryId = await insertCategory(db, name: 'Bakery');
      final AdminService adminService = _makeAdminService(db);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(_testPrefs),
        ],
      );
      addTearDown(container.dispose);

      final int productId = await adminService.createProduct(
        user: _adminUser(adminId),
        categoryId: categoryId,
        name: 'Bagel',
        priceMinor: 450,
        hasModifiers: false,
        sortOrder: 0,
        isVisibleOnPos: true,
      );

      await container.read(productsNotifierProvider.notifier).loadCatalog();
      var productsState = container.read(productsNotifierProvider);
      expect(
        productsState.products.any((product) => product.id == productId),
        isTrue,
      );
      expect(
        productsState.products
            .firstWhere((product) => product.id == productId)
            .name,
        'Bagel',
      );

      await adminService.updateProduct(
        user: _adminUser(adminId),
        id: productId,
        categoryId: categoryId,
        name: 'Bagel Deluxe',
        priceMinor: 650,
        hasModifiers: true,
        sortOrder: 0,
        isActive: true,
        isVisibleOnPos: true,
      );

      await container
          .read(productsNotifierProvider.notifier)
          .selectCategory(categoryId);
      productsState = container.read(productsNotifierProvider);
      final updated = productsState.products.firstWhere(
        (product) => product.id == productId,
      );

      expect(updated.name, 'Bagel Deluxe');
      expect(updated.priceMinor, 650);
      expect(updated.hasModifiers, isTrue);
      expect(updated.isVisibleOnPos, isTrue);

      await adminService.toggleProductVisibilityOnPos(
        user: _adminUser(adminId),
        id: productId,
        isVisibleOnPos: false,
      );

      await container.read(productsNotifierProvider.notifier).loadCatalog();
      productsState = container.read(productsNotifierProvider);
      expect(
        productsState.products.any((product) => product.id == productId),
        isFalse,
      );

      final List<Product> adminProducts = await adminService.getProducts(
        categoryId: categoryId,
      );
      expect(
        adminProducts.any((Product product) => product.id == productId),
        isTrue,
      );
    });

    test('product update writes disciplined audit entries', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int categoryId = await insertCategory(db, name: 'Bakery');
      final AuditLogRepository auditLogRepository = AuditLogRepository(db);
      final AuditLogService auditLogService = PersistedAuditLogService(
        auditLogRepository: auditLogRepository,
        logger: const NoopAppLogger(),
      );
      final ShiftRepository shiftRepository = ShiftRepository(db);
      final TransactionRepository transactionRepository = TransactionRepository(
        db,
      );
      final SettingsRepository settingsRepository = SettingsRepository(db);
      final ShiftSessionService shiftSessionService = ShiftSessionService(
        shiftRepository,
        auditLogService: auditLogService,
      );
      final AdminService adminService = AdminService(
        categoryRepository: CategoryRepository(db),
        productRepository: ProductRepository(db),
        modifierRepository: ModifierRepository(db),
        shiftRepository: shiftRepository,
        transactionRepository: transactionRepository,
        syncQueueRepository: SyncQueueRepository(db),
        settingsRepository: settingsRepository,
        systemRepository: SystemRepository(
          db,
          databaseFileResolver: () async =>
              throw UnsupportedError('No file export in this test.'),
        ),
        reportService: ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: shiftSessionService,
          transactionRepository: transactionRepository,
          paymentRepository: PaymentRepository(db),
          settingsRepository: settingsRepository,
          reportVisibilityService: const ReportVisibilityService(),
          auditLogService: auditLogService,
        ),
        shiftSessionService: shiftSessionService,
        cashMovementService: CashMovementService(
          cashMovementRepository: CashMovementRepository(db),
          shiftSessionService: shiftSessionService,
          auditLogService: auditLogService,
        ),
        printerService: PrinterService(
          transactionRepository,
          paymentRepository: PaymentRepository(db),
          settingsRepository: settingsRepository,
          auditLogService: auditLogService,
        ),
        appConfig: AppConfig.fromValues(
          environment: 'test',
          appVersion: 'test',
        ),
        auditLogService: auditLogService,
      );

      final int productId = await adminService.createProduct(
        user: _adminUser(adminId),
        categoryId: categoryId,
        name: 'Bagel',
        priceMinor: 450,
        hasModifiers: false,
        sortOrder: 0,
        isVisibleOnPos: true,
      );

      await adminService.updateProduct(
        user: _adminUser(adminId),
        id: productId,
        categoryId: categoryId,
        name: 'Bagel Hidden',
        priceMinor: 500,
        hasModifiers: false,
        sortOrder: 0,
        isActive: true,
        isVisibleOnPos: false,
      );

      final logs = await auditLogRepository.listAuditLogs(limit: 10);
      expect(logs.map((log) => log.action), contains('product_created'));
      expect(logs.map((log) => log.action), contains('product_updated'));
      expect(
        logs.map((log) => log.action),
        contains('product_visibility_changed'),
      );
    });

    test(
      'historical transaction line snapshot product visibility değişince bozulmaz',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int categoryId = await insertCategory(db, name: 'Breakfast');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Snapshot Tea',
          priceMinor: 350,
        );
        final int transactionId = await insertTransaction(
          db,
          uuid: 'visibility-snapshot-order',
          shiftId: shiftId,
          userId: adminId,
          status: 'draft',
          totalAmountMinor: 350,
        );

        final TransactionRepository transactionRepository =
            TransactionRepository(db);
        await transactionRepository.addLine(
          transactionId: transactionId,
          productId: productId,
          quantity: 1,
        );

        await _makeAdminService(db).updateProduct(
          user: _adminUser(adminId),
          id: productId,
          categoryId: categoryId,
          name: 'Snapshot Tea Updated',
          priceMinor: 450,
          hasModifiers: false,
          sortOrder: 0,
          isActive: false,
          isVisibleOnPos: false,
        );

        final lines = await transactionRepository.getLines(transactionId);
        expect(lines, hasLength(1));
        expect(lines.single.productId, productId);
        expect(lines.single.productName, 'Snapshot Tea');
        expect(lines.single.unitPriceMinor, 350);
      },
    );

    test(
      'final close writes shift_closed and day_end_finalized audit logs',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final AuditLogRepository auditLogRepository = AuditLogRepository(db);
        final AuditLogService auditLogService = PersistedAuditLogService(
          auditLogRepository: auditLogRepository,
          logger: const NoopAppLogger(),
        );
        final ShiftRepository shiftRepository = ShiftRepository(db);
        final ShiftSessionService shiftSessionService = ShiftSessionService(
          shiftRepository,
          auditLogService: auditLogService,
        );
        final Shift shift = await shiftSessionService.openShiftManually(
          _adminUser(adminId),
        );

        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          paymentRepository: PaymentRepository(db),
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
          auditLogService: auditLogService,
        );

        await reportService.runAdminFinalCloseWithCountedCash(
          user: _adminUser(adminId),
          countedCashMinor: 0,
        );

        final logs = await auditLogRepository.listAuditLogsByEntity(
          entityType: 'shift',
          entityId: '${shift.id}',
        );

        expect(logs.map((log) => log.action), contains('shift_opened'));
        expect(logs.map((log) => log.action), contains('shift_closed'));
        expect(logs.map((log) => log.action), contains('day_end_finalized'));
      },
    );
  });
}

class _TestRouterApp extends ConsumerWidget {
  const _TestRouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(routerConfig: ref.watch(appRouterProvider));
  }
}

class _AdminRouteExpectation {
  const _AdminRouteExpectation(this.path, this.screenType);

  final String path;
  final Type screenType;
}

const List<_AdminRouteExpectation> _adminRoutes = <_AdminRouteExpectation>[
  _AdminRouteExpectation('/admin', AdminDashboardScreen),
  _AdminRouteExpectation('/admin/products', AdminProductsScreen),
  _AdminRouteExpectation('/admin/categories', AdminCategoriesScreen),
  _AdminRouteExpectation('/admin/modifiers', AdminModifiersScreen),
  _AdminRouteExpectation('/admin/audit', AdminAuditLogsScreen),
  _AdminRouteExpectation('/admin/settings', AdminReportSettingsScreen),
  _AdminRouteExpectation('/admin/shifts', AdminShiftsScreen),
  _AdminRouteExpectation('/admin/settings/printer', AdminPrinterSettingsScreen),
  _AdminRouteExpectation('/admin/settings/report', AdminReportSettingsScreen),
  _AdminRouteExpectation('/admin/sync', AdminSyncScreen),
];

class _TrackingPrinterService extends PrinterService {
  _TrackingPrinterService(
    AppDatabase db, {
    required List<PrinterDeviceOption> devices,
    this.testPrintError,
  }) : _devices = devices,
       super(
         TransactionRepository(db),
         paymentRepository: PaymentRepository(db),
         settingsRepository: SettingsRepository(db),
       );

  final List<PrinterDeviceOption> _devices;
  final PrinterException? testPrintError;
  int testPrintCalls = 0;
  String? lastDeviceName;
  String? lastDeviceAddress;
  int? lastPaperWidth;

  @override
  Future<List<PrinterDeviceOption>> getBondedDevices() async => _devices;

  @override
  Future<void> printTestPage({
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
  }) async {
    testPrintCalls += 1;
    lastDeviceName = deviceName;
    lastDeviceAddress = deviceAddress;
    lastPaperWidth = paperWidth;
    if (testPrintError != null) {
      throw testPrintError!;
    }
  }
}

Future<void> _loginWithPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(TextField), pin);
  await tester.tap(find.text(AppStrings.loginButton));
  await tester.pumpAndSettle();
  expect(find.byType(PosScreen), findsOneWidget);
}

User _adminUser(int id) {
  return User(
    id: id,
    name: 'Admin',
    pin: null,
    password: null,
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.now(),
  );
}

OrderService _makeOrderService(AppDatabase db) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  return OrderService(
    shiftSessionService: ShiftSessionService(shiftRepository),
    transactionRepository: TransactionRepository(db),
    transactionStateRepository: TransactionStateRepository(db),
    paymentRepository: PaymentRepository(db),
  );
}

PaymentService _makePaymentService(
  AppDatabase db, {
  PrinterService? printerService,
}) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  return PaymentService(
    orderService: OrderService(
      shiftSessionService: ShiftSessionService(shiftRepository),
      transactionRepository: TransactionRepository(db),
      transactionStateRepository: TransactionStateRepository(db),
      paymentRepository: PaymentRepository(db),
    ),
    printerService:
        printerService ??
        PrinterService(
          TransactionRepository(db),
          paymentRepository: PaymentRepository(db),
          settingsRepository: SettingsRepository(db),
        ),
  );
}

ReportService _makeReportService(AppDatabase db) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  return ReportService(
    shiftRepository: shiftRepository,
    shiftSessionService: ShiftSessionService(shiftRepository),
    transactionRepository: TransactionRepository(db),
    paymentRepository: PaymentRepository(db),
    settingsRepository: SettingsRepository(db),
    reportVisibilityService: const ReportVisibilityService(),
  );
}

AdminService _makeAdminService(AppDatabase db) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  final TransactionRepository transactionRepository = TransactionRepository(db);
  final SettingsRepository settingsRepository = SettingsRepository(db);
  final ShiftSessionService shiftSessionService = ShiftSessionService(
    shiftRepository,
  );
  return AdminService(
    categoryRepository: CategoryRepository(db),
    productRepository: ProductRepository(db),
    modifierRepository: ModifierRepository(db),
    shiftRepository: shiftRepository,
    transactionRepository: transactionRepository,
    syncQueueRepository: SyncQueueRepository(db),
    settingsRepository: settingsRepository,
    systemRepository: SystemRepository(
      db,
      databaseFileResolver: () async =>
          throw UnsupportedError('No file export in this test.'),
    ),
    reportService: ReportService(
      shiftRepository: shiftRepository,
      shiftSessionService: shiftSessionService,
      transactionRepository: transactionRepository,
      paymentRepository: PaymentRepository(db),
      settingsRepository: settingsRepository,
      reportVisibilityService: const ReportVisibilityService(),
    ),
    shiftSessionService: shiftSessionService,
    cashMovementService: CashMovementService(
      cashMovementRepository: CashMovementRepository(db),
      shiftSessionService: shiftSessionService,
    ),
    printerService: PrinterService(
      transactionRepository,
      paymentRepository: PaymentRepository(db),
      settingsRepository: settingsRepository,
    ),
    appConfig: AppConfig.fromValues(environment: 'test', appVersion: 'test'),
  );
}
