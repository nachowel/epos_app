import 'package:epos_app/core/utils/report_category_display_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportCategoryDisplayFormatter', () {
    test('maps Turkish source names to English report labels', () {
      expect(
        ReportCategoryDisplayFormatter.toEnglish('Ana Yemekler'),
        'Main Courses',
      );
      expect(ReportCategoryDisplayFormatter.toEnglish('Kahvaltı'), 'Breakfast');
      expect(ReportCategoryDisplayFormatter.toEnglish('Tatlılar'), 'Desserts');
      expect(ReportCategoryDisplayFormatter.toEnglish('İçecekler'), 'Drinks');
    });

    test('preserves unknown names without altering them', () {
      expect(
        ReportCategoryDisplayFormatter.toEnglish('Seasonal Specials'),
        'Seasonal Specials',
      );
    });
  });
}
