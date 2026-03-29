import '../../data/repositories/user_repository.dart';
import '../models/user.dart';
import 'auth_security.dart';
import 'shift_session_service.dart';

class AuthService {
  const AuthService(this._userRepository, this._shiftSessionService);

  final UserRepository _userRepository;
  final ShiftSessionService _shiftSessionService;

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

      await _shiftSessionService.ensureShiftStartedForLogin(refreshedUser);
      return refreshedUser;
    }

    return null;
  }

  Future<User?> getUserById(int id) {
    return _userRepository.getById(id);
  }
}
