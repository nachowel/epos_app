import 'package:epos_app/domain/services/auth_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthSecurity', () {
    test('hashes and verifies a pin', () {
      final String hashedPin = AuthSecurity.hashPin('1234');

      expect(hashedPin, startsWith('sha256:'));
      expect(hashedPin, isNot('1234'));
      expect(
        AuthSecurity.verifyPin(candidate: '1234', storedValue: hashedPin),
        SecretVerificationStatus.valid,
      );
      expect(
        AuthSecurity.verifyPin(candidate: '9999', storedValue: hashedPin),
        SecretVerificationStatus.invalid,
      );
    });

    test('verifies password hashes and detects legacy plain text', () {
      final String hashedPassword = AuthSecurity.hashPassword('admin-secret');

      expect(
        AuthSecurity.verifyPassword(
          candidate: 'admin-secret',
          storedValue: hashedPassword,
        ),
        SecretVerificationStatus.valid,
      );
      expect(
        AuthSecurity.verifyPin(candidate: '0000', storedValue: '0000'),
        SecretVerificationStatus.legacyPlainTextMatch,
      );
    });
  });
}
