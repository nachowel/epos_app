import 'dart:ui';

import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/domain/models/interaction_block_reason.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/cart_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/pos_interaction_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

void main() {
  setUp(() {
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  group('POS interaction policy', () {
    test('open shift keeps POS fully interactive', () async {
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
      await insertShift(db, openedBy: adminId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith(
            (Ref ref) => _StaticOrdersNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
      container
          .read(cartNotifierProvider.notifier)
          .addProduct(
            Product(
              id: productId,
              categoryId: categoryId,
              name: 'Tea',
              priceMinor: 250,
              imageUrl: null,
              hasModifiers: false,
              isActive: true,
              sortOrder: 0,
            ),
          );

      final PosInteractionPolicy state = container.read(posInteractionProvider);

      expect(state.effectiveShiftStatus, ShiftStatus.open);
      expect(state.blockReason, isNull);
      expect(state.canInteractWithPos, isTrue);
      expect(state.isSalesLocked, isFalse);
      expect(state.isInteractionLocked, isFalse);
      expect(state.canMutateCart, isTrue);
      expect(state.canOpenModifierDialog, isTrue);
      expect(state.canCreateOrder, isTrue);
      expect(state.canTakePayment, isTrue);
      expect(state.canClearCart, isTrue);
    });

    test('closed shift blocks POS with no-open-shift reason', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

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

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith(
            (Ref ref) => _StaticOrdersNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
      container
          .read(cartNotifierProvider.notifier)
          .addProduct(
            Product(
              id: productId,
              categoryId: categoryId,
              name: 'Tea',
              priceMinor: 250,
              imageUrl: null,
              hasModifiers: false,
              isActive: true,
              sortOrder: 0,
            ),
          );

      final PosInteractionPolicy state = container.read(posInteractionProvider);

      expect(state.effectiveShiftStatus, ShiftStatus.closed);
      expect(state.blockReason, InteractionBlockReason.noOpenShift);
      expect(state.canInteractWithPos, isFalse);
      expect(state.isSalesLocked, isFalse);
      expect(state.isInteractionLocked, isTrue);
      expect(state.canMutateCart, isFalse);
      expect(state.canOpenModifierDialog, isFalse);
      expect(state.canCreateOrder, isFalse);
      expect(state.canTakePayment, isFalse);
      expect(state.canClearCart, isFalse);
      expect(state.lockMessage, AppStrings.shiftClosedOpenShiftRequired);
    });

    test('cashier preview lock hard-locks the whole POS', () async {
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

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith(
            (Ref ref) => _StaticOrdersNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
      container
          .read(cartNotifierProvider.notifier)
          .addProduct(
            Product(
              id: productId,
              categoryId: categoryId,
              name: 'Tea',
              priceMinor: 250,
              imageUrl: null,
              hasModifiers: false,
              isActive: true,
              sortOrder: 0,
            ),
          );

      final PosInteractionPolicy state = container.read(posInteractionProvider);

      expect(state.effectiveShiftStatus, ShiftStatus.locked);
      expect(state.blockReason, InteractionBlockReason.adminFinalCloseRequired);
      expect(state.canInteractWithPos, isFalse);
      expect(state.isSalesLocked, isTrue);
      expect(state.isInteractionLocked, isTrue);
      expect(state.canMutateCart, isFalse);
      expect(state.canOpenModifierDialog, isFalse);
      expect(state.canCreateOrder, isFalse);
      expect(state.canTakePayment, isFalse);
      expect(state.canClearCart, isFalse);
      expect(state.lockMessage, AppStrings.salesLockedAdminCloseRequired);
    });
  });
}

class _StaticOrdersNotifier extends OrdersNotifier {
  _StaticOrdersNotifier(super.ref);

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }
}
