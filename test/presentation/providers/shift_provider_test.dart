import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

void main() {
  group('ShiftNotifier final close', () {
    test(
      'surfaces explicit final close blocker message for sent orders',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        await insertTransaction(
          db,
          uuid: 'shift-provider-final-close-blocked',
          shiftId: shiftId,
          userId: adminId,
          status: 'sent',
          totalAmountMinor: 500,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(adminId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

        final bool success = await container
            .read(shiftNotifierProvider.notifier)
            .finalCloseShift(countedCashMinor: 0);
        final ShiftState state = container.read(shiftNotifierProvider);

        expect(success, isFalse);
        expect(state.errorMessage, AppStrings.shiftCloseBlockedSentOrders(1));
        expect(state.isLoading, isFalse);
      },
    );

    test(
      'surfaces stale final close recovery details instead of a dead-end error',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'shift-provider-stale-final-close-paid',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 800,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertPayment(
          db,
          uuid: 'shift-provider-stale-final-close-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 800,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertShiftReconciliation(
          db,
          uuid: 'shift-provider-existing-reconciliation',
          shiftId: shiftId,
          expectedCashMinor: 800,
          countedCashMinor: 800,
          varianceMinor: 0,
          countedBy: adminId,
          countedAt: DateTime(2026, 3, 28, 18, 0),
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(adminId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

        final bool success = await container
            .read(shiftNotifierProvider.notifier)
            .finalCloseShift(countedCashMinor: 800);
        final ShiftState state = container.read(shiftNotifierProvider);

        expect(success, isFalse);
        expect(state.errorMessage, isNull);
        expect(state.staleFinalCloseRecovery, isNotNull);
        expect(state.staleFinalCloseRecovery!.shiftId, shiftId);
        expect(state.staleFinalCloseRecovery!.reconciliationId, greaterThan(0));
        expect(state.staleFinalCloseRecovery!.expectedCashMinor, 800);
        expect(state.staleFinalCloseRecovery!.countedCashMinor, 800);
        expect(state.staleFinalCloseRecovery!.varianceMinor, 0);
        expect(state.staleFinalCloseRecovery!.countedByUserId, adminId);
        expect(state.staleFinalCloseRecovery!.countedByName, 'Admin');
      },
    );
  });
}
