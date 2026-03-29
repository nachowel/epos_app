import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/presentation/providers/app_locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'app locale provider defaults to English and persists Turkish switch',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(appLocaleProvider).languageCode, 'en');
      AppLocalizationService.instance.setLocale(
        container.read(appLocaleProvider),
      );
      expect(AppStrings.payNow, 'Pay Now');
      expect(AppStrings.checkout, 'Checkout');
      expect(AppStrings.payAction, 'Pay');
      expect(AppStrings.saveAsOpenOrder, 'Save as Open Order');

      await container.read(appLocaleProvider.notifier).setLanguageCode('tr');

      expect(container.read(appLocaleProvider).languageCode, 'tr');
      AppLocalizationService.instance.setLocale(
        container.read(appLocaleProvider),
      );
      expect(AppStrings.payNow, 'Şimdi Öde');
      expect(AppStrings.checkout, 'Ödeme');
      expect(AppStrings.payAction, 'Öde');
      expect(AppStrings.saveAsOpenOrder, 'Açık Sipariş Olarak Kaydet');

      final ProviderContainer reloaded = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(reloaded.dispose);

      expect(reloaded.read(appLocaleProvider).languageCode, 'tr');
    },
  );
}
