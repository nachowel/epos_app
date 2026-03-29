import 'package:epos_app/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyFormatter', () {
    test('editable major input formats minor units as pounds', () {
      expect(CurrencyFormatter.toEditableMajorInput(1250), '12.50');
      expect(CurrencyFormatter.toEditableMajorInput(0), '0.00');
    });

    test(
      'editable major input parsing converts currency strings to minor units',
      () {
        expect(CurrencyFormatter.tryParseEditableMajorInput('12.50'), 1250);
        expect(CurrencyFormatter.tryParseEditableMajorInput('£12.50'), 1250);
        expect(CurrencyFormatter.tryParseEditableMajorInput('12,50'), 1250);
        expect(CurrencyFormatter.tryParseEditableMajorInput('12'), 1200);
      },
    );

    test('editable major input parsing rejects invalid values', () {
      expect(CurrencyFormatter.tryParseEditableMajorInput(''), isNull);
      expect(CurrencyFormatter.tryParseEditableMajorInput('12.345'), isNull);
      expect(CurrencyFormatter.tryParseEditableMajorInput('abc'), isNull);
      expect(CurrencyFormatter.tryParseEditableMajorInput('-1.00'), isNull);
    });
  });
}
