import 'package:epos_app/presentation/screens/admin/admin_cash_movements_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCashMovementAmountMinor', () {
    test('"12" -> 1200', () {
      expect(parseCashMovementAmountMinor('12'), 1200);
    });

    test('"12.5" -> 1250', () {
      expect(parseCashMovementAmountMinor('12.5'), 1250);
    });

    test('"12.50" -> 1250', () {
      expect(parseCashMovementAmountMinor('12.50'), 1250);
    });

    test('"0.01" -> 1', () {
      expect(parseCashMovementAmountMinor('0.01'), 1);
    });

    test('"0" is rejected', () {
      expect(parseCashMovementAmountMinor('0'), isNull);
    });

    test('negative is rejected', () {
      expect(parseCashMovementAmountMinor('-1'), isNull);
    });

    test('invalid string is rejected', () {
      expect(parseCashMovementAmountMinor('abc'), isNull);
      expect(parseCashMovementAmountMinor('12.345'), isNull);
      expect(parseCashMovementAmountMinor('12..5'), isNull);
    });
  });
}
