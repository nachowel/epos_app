import 'package:shared_preferences/shared_preferences.dart';

/// Persists PIN brute-force lockout state across app restarts.
///
/// Uses SharedPreferences so the fail counter survives process death.
class AuthLockoutStore {
  AuthLockoutStore(this._prefs);

  static const String _failedAttemptsKey = 'auth_failed_attempts';
  static const String _lockedUntilKey = 'auth_locked_until_ms';

  final SharedPreferences _prefs;

  int getFailedAttempts() => _prefs.getInt(_failedAttemptsKey) ?? 0;

  DateTime? getLockedUntil() {
    final int? ms = _prefs.getInt(_lockedUntilKey);
    if (ms == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> setFailedAttempts(int count) async {
    await _prefs.setInt(_failedAttemptsKey, count);
  }

  Future<void> setLockedUntil(DateTime? value) async {
    if (value == null) {
      await _prefs.remove(_lockedUntilKey);
    } else {
      await _prefs.setInt(_lockedUntilKey, value.millisecondsSinceEpoch);
    }
  }

  Future<void> reset() async {
    await _prefs.remove(_failedAttemptsKey);
    await _prefs.remove(_lockedUntilKey);
  }
}
