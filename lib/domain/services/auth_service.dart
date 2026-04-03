import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthResponse, Supabase;

import '../../core/config/app_config.dart';
import '../../data/repositories/user_repository.dart';
import '../models/user.dart';
import 'auth_security.dart';
import 'shift_session_service.dart';

class AuthService {
  const AuthService(
    this._userRepository,
    this._shiftSessionService,
    this._config,
  );

  final UserRepository _userRepository;
  final ShiftSessionService _shiftSessionService;
  final AppConfig _config;

  Future<User?> loginWithPin(String pin) async {
    final List<User> users = await _userRepository.getAll();

    for (final User user in users) {
      if (!user.isActive) {
        continue;
      }

      final SecretVerificationStatus verification = AuthSecurity.verifyPin(
        candidate: pin,
        storedValue: user.pin,
      );
      if (verification == SecretVerificationStatus.invalid) {
        continue;
      }

      if (verification == SecretVerificationStatus.legacyPlainTextMatch) {
        await _userRepository.updateUser(
          id: user.id,
          pin: AuthSecurity.hashPin(pin),
        );
      }

      final User? refreshedUser = await _userRepository.getById(user.id);
      if (refreshedUser == null) {
        return null;
      }

      if (refreshedUser.role == UserRole.admin) {
        _signInToSupabase();
      }
      await _shiftSessionService.ensureShiftStartedForLogin(refreshedUser);
      return refreshedUser;
    }

    return null;
  }

  Future<User?> getUserById(int id) {
    return _userRepository.getById(id);
  }

  void _signInToSupabase() {
    final String email = _config.analyticsEmail;
    final String password = _config.analyticsPassword;
    if (email.isEmpty || password.isEmpty) {
      debugPrint(
        '[AuthService] Analytics credentials not configured — skipping Supabase sign-in.',
      );
      return;
    }
    Supabase.instance.client.auth
        .signInWithPassword(
          email: email,
          password: password,
        )
        .catchError((Object error) {
          debugPrint('[AuthService] Supabase analytics sign-in failed: $error');
          return AuthResponse();
        });
  }
}
