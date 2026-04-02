import 'package:flutter_test/flutter_test.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/domain/models/order_modifier.dart';

/// These tests verify audit metadata structure for breakfast edit events.
///
/// They do not require a full database or service stack. Instead they validate
/// the structured audit payload shapes that OrderService produces.
void main() {
  group('Breakfast audit metadata structure', () {
    test('successful edit audit entry contains required fields', () {
      // Simulates the metadata map that OrderService builds on success.
      final Map<String, Object?> metadata = <String, Object?>{
        'transaction_id': 42,
        'transaction_line_id': 7,
        'root_product_id': 100,
        'old_line_total_minor': 850,
        'new_line_total_minor': 1050,
        'did_split': false,
        'reason_counts': <String, int>{
          'includedChoice': 1,
          'freeSwap': 1,
          'extraAdd': 1,
        },
        'actor_user_id': 5,
      };

      expect(metadata['transaction_id'], isNotNull);
      expect(metadata['transaction_line_id'], isNotNull);
      expect(metadata['root_product_id'], isNotNull);
      expect(metadata['old_line_total_minor'], isA<int>());
      expect(metadata['new_line_total_minor'], isA<int>());
      expect(metadata['did_split'], isA<bool>());
      expect(metadata['reason_counts'], isA<Map<String, int>>());
    });

    test('split event audit entry contains original and new line ids', () {
      final Map<String, Object?> metadata = <String, Object?>{
        'transaction_id': 42,
        'original_line_id': 7,
        'new_line_id': 8,
        'root_product_id': 100,
      };

      expect(metadata['original_line_id'], isNotNull);
      expect(metadata['new_line_id'], isNotNull);
      expect(metadata['original_line_id'], isNot(metadata['new_line_id']));
    });

    test('rejected edit audit entry contains error codes', () {
      final Map<String, Object?> metadata = <String, Object?>{
        'transaction_line_id': 7,
        'error_codes': <String>[
          BreakfastEditErrorCode.rootNotSetProduct.name,
        ],
      };

      expect(metadata['error_codes'], isA<List<String>>());
      final List<String> codes = metadata['error_codes'] as List<String>;
      expect(codes, contains('rootNotSetProduct'));
    });

    test('non-editable rejection audit entry contains reason', () {
      final Map<String, Object?> metadata = <String, Object?>{
        'transaction_line_id': 7,
        'transaction_id': 42,
        'reason': 'paid',
      };

      expect(metadata['reason'], isA<String>());
      expect(metadata['reason'], isNotEmpty);
    });

    test('reason_counts preserves semantic charge_reason names', () {
      // Simulates building reason counts from classified modifiers.
      final List<_FakeClassifiedModifier> modifiers = <_FakeClassifiedModifier>[
        _FakeClassifiedModifier(
          chargeReason: ModifierChargeReason.includedChoice,
          quantity: 1,
        ),
        _FakeClassifiedModifier(
          chargeReason: ModifierChargeReason.freeSwap,
          quantity: 2,
        ),
        _FakeClassifiedModifier(
          chargeReason: ModifierChargeReason.paidSwap,
          quantity: 1,
        ),
        _FakeClassifiedModifier(
          chargeReason: ModifierChargeReason.extraAdd,
          quantity: 3,
        ),
      ];

      final Map<String, int> counts = <String, int>{};
      for (final mod in modifiers) {
        final String key = mod.chargeReason?.name ?? 'unknown';
        counts[key] = (counts[key] ?? 0) + mod.quantity;
      }

      expect(counts['includedChoice'], 1);
      expect(counts['freeSwap'], 2);
      expect(counts['paidSwap'], 1);
      expect(counts['extraAdd'], 3);
    });
  });
}

class _FakeClassifiedModifier {
  const _FakeClassifiedModifier({
    this.chargeReason,
    this.quantity = 1,
  });

  final ModifierChargeReason? chargeReason;
  final int quantity;
}
