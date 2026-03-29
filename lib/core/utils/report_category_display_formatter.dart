class ReportCategoryDisplayFormatter {
  const ReportCategoryDisplayFormatter._();

  static const Map<String, String> _englishDisplayNames = <String, String>{
    'ana yemekler': 'Main Courses',
    'kahvalti': 'Breakfast',
    'icecekler': 'Drinks',
    'tatlilar': 'Desserts',
    'sandvicler': 'Sandwiches',
  };

  static String toEnglish(String rawCategoryName) {
    final String trimmed = rawCategoryName.trim();
    if (trimmed.isEmpty) {
      return rawCategoryName;
    }

    final String normalizedKey = _normalizeKey(trimmed);
    return _englishDisplayNames[normalizedKey] ?? trimmed;
  }

  static String _normalizeKey(String value) {
    return value
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
