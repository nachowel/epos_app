import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/print_job_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/data/repositories/user_repository.dart';
import 'package:epos_app/domain/models/custom_sale.dart';
import 'package:epos_app/domain/models/checkout_item.dart';
import 'package:epos_app/domain/models/print_job.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/auth_security.dart';
import 'package:epos_app/domain/services/auth_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('OrderService custom sale phase 2', () {
    test(
      'normal product line creation keeps custom sale metadata null',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);

        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );
        final TransactionLine line = await fixture.service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.normalProductId,
        );

        final app_db.TransactionLine persisted = await _findPersistedLine(
          fixture.db,
          line.id,
        );

        _expectNonCustomMetadataNull(line);
        _expectPersistedNonCustomMetadataNull(persisted);
        expect(await fixture.service.isCustomSaleLine(line), isFalse);
      },
    );

    test(
      'normal product quantity updates keep custom sale metadata null',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);

        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );
        final TransactionLine line = await fixture.service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.normalProductId,
        );

        await fixture.repository.incrementLineQuantity(
          transactionLineId: line.id,
          incrementBy: 2,
        );
        final TransactionLine incremented = (await fixture.repository
            .getLineById(line.id))!;
        expect(incremented.quantity, 3);
        _expectNonCustomMetadataNull(incremented);
        _expectPersistedNonCustomMetadataNull(
          await _findPersistedLine(fixture.db, line.id),
        );

        await fixture.repository.decrementLineQuantityOrDelete(line.id);
        final TransactionLine decremented = (await fixture.repository
            .getLineById(line.id))!;
        expect(decremented.quantity, 2);
        _expectNonCustomMetadataNull(decremented);
        _expectPersistedNonCustomMetadataNull(
          await _findPersistedLine(fixture.db, line.id),
        );
      },
    );

    test(
      'normal product split clone keeps custom sale metadata null on both lines',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);

        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );
        final TransactionLine original = await fixture.service
            .addProductToOrder(
              transactionId: order.id,
              productId: fixture.normalProductId,
              quantity: 2,
            );

        final TransactionLine cloned = await fixture.repository
            .splitLineForIndependentEdit(original.id);
        final TransactionLine refreshedOriginal = (await fixture.repository
            .getLineById(original.id))!;

        expect(cloned.id, isNot(original.id));
        expect(cloned.quantity, 1);
        expect(refreshedOriginal.quantity, 1);
        _expectNonCustomMetadataNull(cloned);
        _expectNonCustomMetadataNull(refreshedOriginal);
        _expectPersistedNonCustomMetadataNull(
          await _findPersistedLine(fixture.db, cloned.id),
        );
        _expectPersistedNonCustomMetadataNull(
          await _findPersistedLine(fixture.db, refreshedOriginal.id),
        );
      },
    );

    test(
      'checkout cart can persist mixed normal and custom sale lines',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);

        final Transaction transaction = await fixture.service
            .markOrderPaidInCheckoutIfNeeded(
              currentUser: fixture.cashier,
              cartItems: <CheckoutItem>[
                CheckoutItem(
                  productId: fixture.normalProductId,
                  quantity: 1,
                  modifiers: const [],
                ),
                const CheckoutItem(
                  productId: 0,
                  quantity: 1,
                  modifiers: [],
                  customSaleRequest: CustomSaleWriteRequest(
                    amountMinor: 1200,
                    note: 'Manager approved sale',
                    overrideRequest: CustomSaleOverrideRequest(
                      adminPin: '9999',
                    ),
                  ),
                ),
              ],
              idempotencyKey: 'custom-sale-checkout-mixed',
              immediatePaymentMethod: null,
            );

        final List<TransactionLine> lines = await fixture.service.getOrderLines(
          transaction.id,
        );
        expect(lines, hasLength(2));

        final TransactionLine customLine = lines.firstWhere(
          (TransactionLine line) => line.productId == fixture.customProductId,
        );
        final TransactionLine normalLine = lines.firstWhere(
          (TransactionLine line) => line.productId == fixture.normalProductId,
        );

        expect(customLine.customNote, 'Manager approved sale');
        expect(customLine.createdByUserId, fixture.cashier.id);
        expect(customLine.adminOverrideUserId, fixture.admin.id);
        _expectNonCustomMetadataNull(normalLine);
      },
    );

    test(
      'creates an in-limit custom sale with manual amount and optional note',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);

        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );

        final TransactionLine line = await fixture.service.addCustomSaleToOrder(
          transactionId: order.id,
          currentUser: fixture.cashier,
          request: const CustomSaleWriteRequest(amountMinor: 1000),
        );

        final TransactionLine persisted = (await fixture.service.getOrderLines(
          order.id,
        )).single;

        expect(line.productId, fixture.customProductId);
        expect(persisted.unitPriceMinor, 1000);
        expect(persisted.lineTotalMinor, 1000);
        expect(persisted.customNote, isNull);
        expect(persisted.createdByUserId, fixture.cashier.id);
        expect(persisted.adminOverrideUserId, isNull);
        expect(await fixture.service.isCustomSaleLine(persisted), isTrue);
      },
    );

    test('rejects zero and negative custom sale amounts', () async {
      final _CustomSaleFixture fixture = await _createFixture(limitMinor: 1000);
      addTearDown(fixture.db.close);
      final order = await fixture.service
          .createPersistedEmptyDraftForTestingAccess(
            currentUser: fixture.cashier,
          );

      for (final int amount in <int>[0, -1]) {
        await expectLater(
          fixture.service.addCustomSaleToOrder(
            transactionId: order.id,
            currentUser: fixture.cashier,
            request: CustomSaleWriteRequest(amountMinor: amount),
          ),
          throwsA(
            isA<ValidationException>().having(
              (ValidationException error) => error.message,
              'message',
              'Custom Sale amount must be greater than zero.',
            ),
          ),
        );
      }
    });

    test('over-limit custom sale requires note and real admin override', () async {
      final _CustomSaleFixture fixture = await _createFixture(limitMinor: 1000);
      addTearDown(fixture.db.close);
      final order = await fixture.service
          .createPersistedEmptyDraftForTestingAccess(
            currentUser: fixture.cashier,
          );

      await expectLater(
        fixture.service.addCustomSaleToOrder(
          transactionId: order.id,
          currentUser: fixture.cashier,
          request: const CustomSaleWriteRequest(amountMinor: 1001),
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Custom Sale note is required when amount exceeds the configured limit.',
          ),
        ),
      );

      await expectLater(
        fixture.service.addCustomSaleToOrder(
          transactionId: order.id,
          currentUser: fixture.cashier,
          request: const CustomSaleWriteRequest(
            amountMinor: 1001,
            note: 'Large manual sale',
          ),
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Custom Sale admin PIN approval is required when amount exceeds the configured limit.',
          ),
        ),
      );

      await expectLater(
        fixture.service.addCustomSaleToOrder(
          transactionId: order.id,
          currentUser: fixture.cashier,
          request: const CustomSaleWriteRequest(
            amountMinor: 1001,
            note: 'Large manual sale',
            overrideRequest: CustomSaleOverrideRequest(adminPin: '1111'),
          ),
        ),
        throwsA(
          isA<UnauthorisedException>().having(
            (UnauthorisedException error) => error.message,
            'message',
            'Invalid admin PIN for Custom Sale override.',
          ),
        ),
      );
    });

    test(
      'edit revalidates and preserves creator while recording override separately',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);
        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );
        final TransactionLine created = await fixture.service
            .addCustomSaleToOrder(
              transactionId: order.id,
              currentUser: fixture.cashier,
              request: const CustomSaleWriteRequest(amountMinor: 700),
            );

        await expectLater(
          fixture.service.editCustomSaleLine(
            transactionLineId: created.id,
            currentUser: fixture.cashier,
            request: const CustomSaleWriteRequest(amountMinor: 1200),
          ),
          throwsA(isA<ValidationException>()),
        );

        final TransactionLine unchanged = (await fixture.repository.getLineById(
          created.id,
        ))!;
        expect(unchanged.unitPriceMinor, 700);
        expect(unchanged.adminOverrideUserId, isNull);
        expect(unchanged.createdByUserId, fixture.cashier.id);

        final TransactionLine overridden = await fixture.service
            .editCustomSaleLine(
              transactionLineId: created.id,
              currentUser: fixture.cashier,
              request: const CustomSaleWriteRequest(
                amountMinor: 1200,
                note: 'Manager approved increase',
                overrideRequest: CustomSaleOverrideRequest(adminPin: '9999'),
              ),
            );
        expect(overridden.unitPriceMinor, 1200);
        expect(overridden.customNote, 'Manager approved increase');
        expect(overridden.createdByUserId, fixture.cashier.id);
        expect(overridden.adminOverrideUserId, fixture.admin.id);

        final TransactionLine lowered = await fixture.service
            .editCustomSaleLine(
              transactionLineId: created.id,
              currentUser: fixture.cashier,
              request: const CustomSaleWriteRequest(amountMinor: 800),
            );
        expect(lowered.createdByUserId, fixture.cashier.id);
        expect(lowered.adminOverrideUserId, isNull);
        expect(lowered.customNote, isNull);
      },
    );

    test(
      'classification uses stable identity instead of product name',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);
        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );

        final TransactionLine namedLikeCustom = await fixture.service
            .addProductToOrder(
              transactionId: order.id,
              productId: fixture.sameNameNormalProductId,
            );
        final TransactionLine realCustom = await fixture.service
            .addCustomSaleToOrder(
              transactionId: order.id,
              currentUser: fixture.cashier,
              request: const CustomSaleWriteRequest(amountMinor: 500),
            );

        expect(
          await fixture.service.isCustomSaleLine(namedLikeCustom),
          isFalse,
        );
        expect(await fixture.service.isCustomSaleLine(realCustom), isTrue);
      },
    );

    test(
      'custom-only orders are non-kitchen and do not queue kitchen jobs on send',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);
        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );
        await fixture.service.addCustomSaleToOrder(
          transactionId: order.id,
          currentUser: fixture.cashier,
          request: const CustomSaleWriteRequest(amountMinor: 500),
        );

        expect(await fixture.service.isKitchenRequired(order.id), isFalse);
        expect(
          await fixture.service.getKitchenEligibleLines(order.id),
          isEmpty,
        );

        await fixture.service.sendOrder(
          transactionId: order.id,
          currentUser: fixture.cashier,
        );

        final PrintJob? kitchenJob = await fixture.printJobRepository
            .getByTransactionIdAndTarget(
              transactionId: order.id,
              target: PrintJobTarget.kitchen,
            );
        expect(kitchenJob, isNull);
      },
    );

    test(
      'mixed orders keep only normal lines kitchen-eligible and still queue kitchen jobs',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);
        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );
        await fixture.service.addCustomSaleToOrder(
          transactionId: order.id,
          currentUser: fixture.cashier,
          request: const CustomSaleWriteRequest(amountMinor: 450),
        );
        await fixture.service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.normalProductId,
        );

        final List<TransactionLine> kitchenLines = await fixture.service
            .getKitchenEligibleLines(order.id);
        expect(kitchenLines, hasLength(1));
        expect(kitchenLines.single.productId, fixture.normalProductId);
        expect(await fixture.service.isKitchenRequired(order.id), isTrue);

        await fixture.service.sendOrder(
          transactionId: order.id,
          currentUser: fixture.cashier,
        );

        final PrintJob? kitchenJob = await fixture.printJobRepository
            .getByTransactionIdAndTarget(
              transactionId: order.id,
              target: PrintJobTarget.kitchen,
            );
        expect(kitchenJob, isNotNull);
      },
    );

    test(
      'mixed orders keep custom sale metadata on custom lines only',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);

        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );
        final TransactionLine normalLine = await fixture.service
            .addProductToOrder(
              transactionId: order.id,
              productId: fixture.normalProductId,
            );
        final TransactionLine customLine = await fixture.service
            .addCustomSaleToOrder(
              transactionId: order.id,
              currentUser: fixture.cashier,
              request: const CustomSaleWriteRequest(
                amountMinor: 1200,
                note: 'Manager approved sale',
                overrideRequest: CustomSaleOverrideRequest(adminPin: '9999'),
              ),
            );

        final app_db.TransactionLine persistedNormal = await _findPersistedLine(
          fixture.db,
          normalLine.id,
        );
        final app_db.TransactionLine persistedCustom = await _findPersistedLine(
          fixture.db,
          customLine.id,
        );

        _expectNonCustomMetadataNull(normalLine);
        _expectPersistedNonCustomMetadataNull(persistedNormal);
        expect(await fixture.service.isCustomSaleLine(normalLine), isFalse);

        expect(customLine.customNote, 'Manager approved sale');
        expect(customLine.createdByUserId, fixture.cashier.id);
        expect(customLine.adminOverrideUserId, fixture.admin.id);
        expect(persistedCustom.customNote, 'Manager approved sale');
        expect(persistedCustom.createdByUserId, fixture.cashier.id);
        expect(persistedCustom.adminOverrideUserId, fixture.admin.id);
        expect(await fixture.service.isCustomSaleLine(customLine), isTrue);
      },
    );

    test(
      'normal product orders remain kitchen-required and unaffected',
      () async {
        final _CustomSaleFixture fixture = await _createFixture(
          limitMinor: 1000,
        );
        addTearDown(fixture.db.close);
        final order = await fixture.service
            .createPersistedEmptyDraftForTestingAccess(
              currentUser: fixture.cashier,
            );
        await fixture.service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.normalProductId,
        );

        final List<TransactionLine> kitchenLines = await fixture.service
            .getKitchenEligibleLines(order.id);
        expect(kitchenLines, hasLength(1));
        expect(kitchenLines.single.productId, fixture.normalProductId);
        expect(await fixture.service.isKitchenRequired(order.id), isTrue);
      },
    );
  });
}

Future<_CustomSaleFixture> _createFixture({required int limitMinor}) async {
  final db = createTestDatabase();
  final int cashierId = await insertUser(
    db,
    name: 'Cashier',
    role: 'cashier',
    pin: AuthSecurity.hashPin('1111'),
  );
  final int adminId = await insertUser(
    db,
    name: 'Admin',
    role: 'admin',
    pin: AuthSecurity.hashPin('9999'),
  );
  await insertShift(db, openedBy: cashierId);
  final int categoryId = await insertCategory(db, name: 'Drinks');
  final int normalProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Tea',
    priceMinor: 250,
  );
  final int sameNameNormalProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Custom Sale',
    priceMinor: 300,
  );
  final int customProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Custom Sale',
    priceMinor: 0,
    isVisibleOnPos: false,
    isCustom: true,
  );
  await (db.update(db.menuSettings)).write(
    app_db.MenuSettingsCompanion(customSalesLimitMinor: Value<int>(limitMinor)),
  );

  final User cashier = User(
    id: cashierId,
    name: 'Cashier',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime.now(),
  );
  final User admin = User(
    id: adminId,
    name: 'Admin',
    pin: null,
    password: null,
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.now(),
  );

  final ShiftSessionService shiftSessionService = ShiftSessionService(
    ShiftRepository(db),
  );
  final AuthService authService = AuthService(
    UserRepository(db),
    shiftSessionService,
    AppConfig.fallback(issue: 'custom sale test'),
  );
  final TransactionRepository transactionRepository = TransactionRepository(db);
  final OrderService service = OrderService(
    shiftSessionService: shiftSessionService,
    transactionRepository: transactionRepository,
    transactionStateRepository: TransactionStateRepository(db),
    productRepository: ProductRepository(db),
    settingsRepository: SettingsRepository(db),
    authService: authService,
    printJobRepository: PrintJobRepository(db),
  );

  return _CustomSaleFixture(
    db: db,
    service: service,
    repository: transactionRepository,
    printJobRepository: PrintJobRepository(db),
    cashier: cashier,
    admin: admin,
    normalProductId: normalProductId,
    sameNameNormalProductId: sameNameNormalProductId,
    customProductId: customProductId,
  );
}

class _CustomSaleFixture {
  const _CustomSaleFixture({
    required this.db,
    required this.service,
    required this.repository,
    required this.printJobRepository,
    required this.cashier,
    required this.admin,
    required this.normalProductId,
    required this.sameNameNormalProductId,
    required this.customProductId,
  });

  final app_db.AppDatabase db;
  final OrderService service;
  final TransactionRepository repository;
  final PrintJobRepository printJobRepository;
  final User cashier;
  final User admin;
  final int normalProductId;
  final int sameNameNormalProductId;
  final int customProductId;
}

Future<app_db.TransactionLine> _findPersistedLine(
  app_db.AppDatabase db,
  int lineId,
) {
  return (db.select(db.transactionLines)
        ..where((app_db.$TransactionLinesTable t) {
          return t.id.equals(lineId);
        }))
      .getSingle();
}

void _expectNonCustomMetadataNull(TransactionLine line) {
  expect(line.customNote, isNull);
  expect(line.createdByUserId, isNull);
  expect(line.adminOverrideUserId, isNull);
}

void _expectPersistedNonCustomMetadataNull(app_db.TransactionLine line) {
  expect(line.customNote, isNull);
  expect(line.createdByUserId, isNull);
  expect(line.adminOverrideUserId, isNull);
}
