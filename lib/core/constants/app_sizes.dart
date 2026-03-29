class AppSizes {
  const AppSizes._();

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static const double fontSm = 16;
  static const double fontMd = 18;
  static const double fontLg = 22;

  static const double minTouch = 80;
  static const double cartPanelWidth = 376;
  static const double cartPanelMinWidth = 264;
  static const double topBarHeight = 88;

  static double responsiveCartPanelWidth(double viewportWidth) {
    final double ratio = viewportWidth >= 1400
        ? 0.24
        : (viewportWidth >= 1100 ? 0.235 : 0.22);
    final double minWidth = viewportWidth >= 1100
        ? 280
        : cartPanelMinWidth;

    return (viewportWidth * ratio).clamp(minWidth, cartPanelWidth).toDouble();
  }
}
