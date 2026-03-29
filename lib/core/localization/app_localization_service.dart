import 'dart:ui';

import 'package:epos_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class AppLocalizationService {
  AppLocalizationService._();

  static final AppLocalizationService instance = AppLocalizationService._();

  AppLocalizations _current = lookupAppLocalizations(const Locale('en'));

  AppLocalizations get current => _current;

  void setLocale(Locale locale) {
    Intl.defaultLocale = locale.toLanguageTag();
    _current = lookupAppLocalizations(locale);
  }
}
