import 'dart:convert';

import 'package:crypto/crypto.dart';

enum SecretKind { pin, password }

enum SecretVerificationStatus { valid, legacyPlainTextMatch, invalid }

class AuthSecurity {
  const AuthSecurity._();

  static const String _hashPrefix = 'sha256';
  static const String _seedAdminPin = '1234';
  static const String _seedCashierPin = '0000';

  static String get demoAdminPin => _seedAdminPin;
  static String get demoCashierPin => _seedCashierPin;

  static String hashPin(String pin) {
    return _hashSecret(pin, SecretKind.pin);
  }

  static String hashPassword(String password) {
    return _hashSecret(password, SecretKind.password);
  }

  static SecretVerificationStatus verifyPin({
    required String candidate,
    required String? storedValue,
  }) {
    return _verifySecret(
      candidate: candidate,
      storedValue: storedValue,
      kind: SecretKind.pin,
    );
  }

  static SecretVerificationStatus verifyPassword({
    required String candidate,
    required String? storedValue,
  }) {
    return _verifySecret(
      candidate: candidate,
      storedValue: storedValue,
      kind: SecretKind.password,
    );
  }

  static String _hashSecret(String value, SecretKind kind) {
    final String payload = '${kind.name}:$value';
    final String digest = sha256.convert(utf8.encode(payload)).toString();
    return '$_hashPrefix:$digest';
  }

  static SecretVerificationStatus _verifySecret({
    required String candidate,
    required String? storedValue,
    required SecretKind kind,
  }) {
    if (storedValue == null || storedValue.isEmpty) {
      return SecretVerificationStatus.invalid;
    }

    if (storedValue.startsWith('$_hashPrefix:')) {
      final String expectedHash = _hashSecret(candidate, kind);
      return storedValue == expectedHash
          ? SecretVerificationStatus.valid
          : SecretVerificationStatus.invalid;
    }

    return storedValue == candidate
        ? SecretVerificationStatus.legacyPlainTextMatch
        : SecretVerificationStatus.invalid;
  }
}
