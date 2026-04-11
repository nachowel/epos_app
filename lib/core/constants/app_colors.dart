import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFFF4F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF8FAFB);
  static const Color surfaceMuted = surfaceAlt;
  static const Color border = Color(0xFFD9E2E7);
  static const Color borderStrong = Color(0xFFB8C7D1);

  static const Color primary = Color(0xFF2AA79B);
  static const Color primaryStrong = Color(0xFF1F8F85);
  static const Color primaryDarker = Color(0xFF18756D);
  static const Color primaryLight = Color(0xFFE7F7F5);
  static const Color primaryLighter = Color(0xFFF2FBFA);

  static const Color textPrimary = Color(0xFF102A43);
  static const Color textSecondary = Color(0xFF486581);
  static const Color textMuted = Color(0xFF7B8A97);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF16A34A);
  static const Color successStrong = Color(0xFF15803D);
  static const Color successLight = Color(0xFFEAF8EE);
  static const Color textOnSuccess = Color(0xFFFFFFFF);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningStrong = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFF6E5);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerStrong = Color(0xFFB91C1C);
  static const Color dangerLight = Color(0xFFFDECEC);
  static const Color textOnDanger = Color(0xFFFFFFFF);

  static const Color error = danger;
  static const Color chipSelectedBackground = primaryStrong;
  static const Color chipSelectedText = textOnPrimary;
}
