import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/cart_models.dart';
import 'package:epos_app/presentation/providers/cart_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/pos_interaction_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

void main() {
  group('POS interaction controller', () {
    test('locked state blocks all cart and checkout mutations', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int categoryId = await insertCategory(db, name: 'Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Tea',
        priceMinor: 250,
      );
      await insertShift(
        db,
        openedBy: adminId,
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );

      late _SpyOrdersNotifier spyOrdersNotifier;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith((Ref ref) {
            spyOrdersNotifier = _SpyOrdersNotifier(ref);
            return spyOrdersNotifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
      container
          .read(cartNotifierProvider.notifier)
          .addProduct(_product(productId, categoryId));

      final PosInteractionController controller = container.read(
        posInteractionControllerProvider,
      );
      final String existingLocalId = container
          .read(cartNotifierProvider)
          .items
          .single
          .localId;

      expect(controller.addProduct(_product(productId, categoryId)), isFalse);
      expect(
        controller.addProduct(
          _product(productId, categoryId, hasModifiers: true),
          modifiers: const <CartModifier>[
            CartModifier(
              action: ModifierAction.add,
              itemName: 'Lemon',
              extraPriceMinor: 25,
            ),
          ],
        ),
        isFalse,
      );
      expect(controller.increaseQuantity(existingLocalId), isFalse);
      expect(controller.decreaseQuantity(existingLocalId), isFalse);
      expect(controller.removeItem(existingLocalId), isFalse);
      expect(
        controller.replaceModifiers(
          localId: existingLocalId,
          modifiers: const <CartModifier>[
            CartModifier(
              action: ModifierAction.remove,
              itemName: 'Sugar',
              extraPriceMinor: 0,
            ),
          ],
        ),
        isFalse,
      );
      expect(controller.clearCart(), isFalse);
      expect(
        await controller.createOrderFromCart(
          currentUser: container.read(authNotifierProvider).currentUser!,
        ),
        isNull,
      );
      expect(
        await controller.payNowFromCart(
          currentUser: container.read(authNotifierProvider).currentUser!,
          method: PaymentMethod.cash,
        ),
        isNull,
      );

      final CartState finalCartState = container.read(cartNotifierProvider);
      expect(finalCartState.items, hasLength(1));
      expect(finalCartState.items.single.localId, existingLocalId);
      expect(spyOrdersNotifier.createOrderCalls, 0);
    });

    test(
      'runtime transition to locked keeps existing cart visible but frozen',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int categoryId = await insertCategory(db, name: 'Drinks');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 250,
        );
        final int shiftId = await insertShift(db, openedBy: adminId);

        late _SpyOrdersNotifier spyOrdersNotifier;
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            ordersNotifierProvider.overrideWith((Ref ref) {
              spyOrdersNotifier = _SpyOrdersNotifier(ref);
              return spyOrdersNotifier;
            }),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(cashierId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

        final PosInteractionController controller = container.read(
          posInteractionControllerProvider,
        );
        expect(controller.addProduct(_product(productId, categoryId)), isTrue);

        await ShiftRepository(
          db,
        ).markCashierPreview(shiftId: shiftId, userId: cashierId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

        final PosInteractionPolicy policy = container.read(
          posInteractionProvider,
        );
        final String existingLocalId = container
            .read(cartNotifierProvider)
            .items
            .single
            .localId;

        expect(policy.effectiveShiftStatus, ShiftStatus.locked);
        expect(policy.canInteractWithPos, isFalse);
        expect(container.read(cartNotifierProvider).items, hasLength(1));
        expect(controller.increaseQuantity(existingLocalId), isFalse);
        expect(controller.clearCart(), isFalse);
        expect(
          await controller.createOrderFromCart(
            currentUser: container.read(authNotifierProvider).currentUser!,
          ),
          isNull,
        );
        expect(spyOrdersNotifier.createOrderCalls, 0);
        expect(container.read(cartNotifierProvider).items, hasLength(1));
      },
    );

    test(
      'runtime transition to closed keeps existing cart visible but frozen',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int categoryId = await insertCategory(db, name: 'Drinks');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 250,
        );
        final int shiftId = await insertShift(db, openedBy: adminId);

        late _SpyOrdersNotifier spyOrdersNotifier;
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            ordersNotifierProvider.overrideWith((Ref ref) {
              spyOrdersNotifier = _SpyOrdersNotifier(ref);
              return spyOrdersNotifier;
            }),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(cashierId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

        final PosInteractionController controller = container.read(
          posInteractionControllerProvider,
        );
        expect(controller.addProduct(_product(productId, categoryId)), isTrue);

        await ShiftRepository(db).closeShift(shiftId, adminId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

        final PosInteractionPolicy policy = container.read(
          posInteractionProvider,
        );
        final String existingLocalId = container
            .read(cartNotifierProvider)
            .items
            .single
            .localId;

        expect(policy.effectiveShiftStatus, ShiftStatus.closed);
        expect(policy.canInteractWithPos, isFalse);
        expect(container.read(cartNotifierProvider).items, hasLength(1));
        expect(controller.decreaseQuantity(existingLocalId), isFalse);
        expect(controller.removeItem(existingLocalId), isFalse);
        expect(
          await controller.payNowFromCart(
            currentUser: container.read(authNotifierProvider).currentUser!,
            method: PaymentMethod.card,
          ),
          isNull,
        );
        expect(spyOrdersNotifier.createOrderCalls, 0);
        expect(container.read(cartNotifierProvider).items, hasLength(1));
      },
    );

    test('hidden or inactive product cannot be added to cart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: adminId);

      late _SpyOrdersNotifier spyOrdersNotifier;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith((Ref ref) {
            spyOrdersNotifier = _SpyOrdersNotifier(ref);
            return spyOrdersNotifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      final PosInteractionController controller = container.read(
        posInteractionControllerProvider,
      );

      expect(
        () => controller.addProduct(
          _product(1, 1, isVisibleOnPos: false),
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Product is not available for sale.',
          ),
        ),
      );
      expect(
        () => controller.addProduct(_product(2, 1, isActive: false)),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Product is not available for sale.',
          ),
        ),
      );
      expect(container.read(cartNotifierProvider).items, isEmpty);
      expect(spyOrdersNotifier.createOrderCalls, 0);
    });
  });
}

Product _product(
  int productId,
  int categoryId, {
  bool hasModifiers = false,
  bool isActive = true,
  bool isVisibleOnPos = true,
}) {
  return Product(
    id: productId,
    categoryId: categoryId,
    name: 'Tea',
    priceMinor: 250,
    imageUrl: null,
    hasModifiers: hasModifiers,
    isActive: isActive,
    isVisibleOnPos: isVisibleOnPos,
    sortOrder: 0,
  );
}

class _SpyOrdersNotifier extends OrdersNotifier {
  _SpyOrdersNotifier(super.ref);

  int createOrderCalls = 0;

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }

  @override
  Future<Transaction?> createOrderFromCart({
    required User currentUser,
    int? tableNumber,
    PaymentMethod? immediatePaymentMethod,
  }) async {
    createOrderCalls += 1;
    return null;
  }
}
