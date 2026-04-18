import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/domain/models/report_settings_policy.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

void main() {
  group('SettingsNotifier', () {
    test(
      'percentage mode saves valid ratio and reloads persisted settings',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
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
        await container.read(settingsNotifierProvider.notifier).load();
        container
            .read(settingsNotifierProvider.notifier)
            .setDraftMode(CashierReportMode.percentage);
        container.read(settingsNotifierProvider.notifier).setDraftRatio(0.4);
        container
            .read(settingsNotifierProvider.notifier)
            .setBusinessName('Cafe Rialto');
        container
            .read(settingsNotifierProvider.notifier)
            .setBusinessAddress('123 Market Street');

        final bool saved = await container
            .read(settingsNotifierProvider.notifier)
            .save(
              currentUser: container.read(authNotifierProvider).currentUser!,
            );

        expect(saved, isTrue);
        final settings = await SettingsRepository(
          db,
        ).getCashierZReportSettings();
        expect(settings.policy.cashierReportMode, CashierReportMode.percentage);
        expect(settings.policy.visibilityRatio, 0.4);
        expect(settings.policy.maxVisibleTotalMinor, isNull);
        expect(settings.businessIdentity.businessName, 'Cafe Rialto');
        expect(settings.businessIdentity.businessAddress, '123 Market Street');

        final ProviderContainer reloadContainer = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(reloadContainer.dispose);

        await reloadContainer
            .read(authNotifierProvider.notifier)
            .loadUserById(adminId);
        await reloadContainer.read(settingsNotifierProvider.notifier).load();

        final SettingsState state = reloadContainer.read(
          settingsNotifierProvider,
        );
        expect(state.cashierReportMode, CashierReportMode.percentage);
        expect(state.visibilityRatio, 0.4);
        expect(state.customSalesLimitInput, '1000.00');
        expect(state.businessName, 'Cafe Rialto');
        expect(state.businessAddress, '123 Market Street');
      },
    );

    test('cap amount mode saves valid max amount', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(settingsNotifierProvider.notifier).load();
      container
          .read(settingsNotifierProvider.notifier)
          .setCustomSalesLimitInput('250.50');
      container
          .read(settingsNotifierProvider.notifier)
          .setDraftMode(CashierReportMode.capAmount);
      container
          .read(settingsNotifierProvider.notifier)
          .setMaxVisibleTotalInput('12.00');

      final bool saved = await container
          .read(settingsNotifierProvider.notifier)
          .save(currentUser: container.read(authNotifierProvider).currentUser!);

      expect(saved, isTrue);
      final settings = await SettingsRepository(db).getCashierZReportSettings();
      expect(settings.policy.cashierReportMode, CashierReportMode.capAmount);
      expect(settings.policy.maxVisibleTotalMinor, 1200);
      expect(await SettingsRepository(db).getCustomSalesLimitMinor(), 25050);
    });

    test('cap amount currency input parses pounds into minor units', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(settingsNotifierProvider.notifier).load();
      container
          .read(settingsNotifierProvider.notifier)
          .setCustomSalesLimitInput('500.00');
      container
          .read(settingsNotifierProvider.notifier)
          .setDraftMode(CashierReportMode.capAmount);
      container
          .read(settingsNotifierProvider.notifier)
          .setMaxVisibleTotalInput('£12.50');

      final bool saved = await container
          .read(settingsNotifierProvider.notifier)
          .save(currentUser: container.read(authNotifierProvider).currentUser!);

      expect(saved, isTrue);
      final settings = await SettingsRepository(db).getCashierZReportSettings();
      expect(settings.policy.maxVisibleTotalMinor, 1250);
      expect(await SettingsRepository(db).getCustomSalesLimitMinor(), 50000);
    });

    test(
      'loads and saves custom sale limit in pounds while persisting minor units',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
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
        await container.read(settingsNotifierProvider.notifier).load();

        expect(
          container.read(settingsNotifierProvider).customSalesLimitInput,
          '1000.00',
        );

        container
            .read(settingsNotifierProvider.notifier)
            .setCustomSalesLimitInput('123.45');

        final bool saved = await container
            .read(settingsNotifierProvider.notifier)
            .save(
              currentUser: container.read(authNotifierProvider).currentUser!,
            );

        expect(saved, isTrue);
        expect(await SettingsRepository(db).getCustomSalesLimitMinor(), 12345);
      },
    );

    test(
      'invalid cap amount combinations are rejected and not persisted',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
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
        await container.read(settingsNotifierProvider.notifier).load();
        container
            .read(settingsNotifierProvider.notifier)
            .setDraftMode(CashierReportMode.capAmount);
        container
            .read(settingsNotifierProvider.notifier)
            .setMaxVisibleTotalInput('');

        final bool saved = await container
            .read(settingsNotifierProvider.notifier)
            .save(
              currentUser: container.read(authNotifierProvider).currentUser!,
            );

        expect(saved, isFalse);
        expect(
          container.read(settingsNotifierProvider).errorMessage,
          AppStrings.maxVisibleTotalRequired,
        );

        final settings = await SettingsRepository(
          db,
        ).getCashierZReportSettings();
        expect(settings.policy.cashierReportMode, CashierReportMode.percentage);
        expect(settings.policy.maxVisibleTotalMinor, isNull);
      },
    );

    test(
      'invalid cap amount currency input is rejected and not persisted',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
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
        await container.read(settingsNotifierProvider.notifier).load();
        container
            .read(settingsNotifierProvider.notifier)
            .setDraftMode(CashierReportMode.capAmount);
        container
            .read(settingsNotifierProvider.notifier)
            .setMaxVisibleTotalInput('12.345');

        final bool saved = await container
            .read(settingsNotifierProvider.notifier)
            .save(
              currentUser: container.read(authNotifierProvider).currentUser!,
            );

        expect(saved, isFalse);
        expect(
          container.read(settingsNotifierProvider).errorMessage,
          AppStrings.maxVisibleTotalInvalid,
        );

        final settings = await SettingsRepository(
          db,
        ).getCashierZReportSettings();
        expect(settings.policy.cashierReportMode, CashierReportMode.percentage);
        expect(settings.policy.maxVisibleTotalMinor, isNull);
      },
    );

    test('invalid custom sale limit is rejected and not persisted', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(settingsNotifierProvider.notifier).load();
      container
          .read(settingsNotifierProvider.notifier)
          .setCustomSalesLimitInput('0');

      final bool saved = await container
          .read(settingsNotifierProvider.notifier)
          .save(currentUser: container.read(authNotifierProvider).currentUser!);

      expect(saved, isFalse);
      expect(
        container.read(settingsNotifierProvider).errorMessage,
        'Custom sale limit must be greater than 0.',
      );
      expect(await SettingsRepository(db).getCustomSalesLimitMinor(), 100000);
    });
  });
}
