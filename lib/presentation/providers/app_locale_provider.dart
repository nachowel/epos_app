import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/app_providers.dart';

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier(this._preferences)
    : super(_readInitialLocale(_preferences));

  static const String _localeKey = 'app_locale';

  final SharedPreferences _preferences;

  Future<void> setLanguageCode(String languageCode) async {
    final Locale locale = Locale(languageCode);
    if (state == locale) {
      return;
    }
    state = locale;
    await _preferences.setString(_localeKey, languageCode);
  }

  static Locale _readInitialLocale(SharedPreferences preferences) {
    final String? saved = preferences.getString(_localeKey);
    if (saved == 'tr') {
      return const Locale('tr');
    }
    return const Locale('en');
  }
}

final StateNotifierProvider<AppLocaleNotifier, Locale> appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, Locale>(
      (Ref ref) => AppLocaleNotifier(ref.watch(sharedPreferencesProvider)),
    );
