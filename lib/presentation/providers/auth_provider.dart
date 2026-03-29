import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repositories/auth_lockout_store.dart';
import '../../domain/models/user.dart';

class AuthState {
  const AuthState({
    required this.currentUser,
    required this.isLoading,
    required this.errorMessage,
    required this.failedAttempts,
    required this.lockedUntil,
  });

  const AuthState.initial()
    : currentUser = null,
      isLoading = false,
      errorMessage = null,
      failedAttempts = 0,
      lockedUntil = null;

  final User? currentUser;
  final bool isLoading;
  final String? errorMessage;
  final int failedAttempts;
  final DateTime? lockedUntil;

  bool get isAuthenticated => currentUser != null;
  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  AuthState copyWith({
    Object? currentUser = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
    int? failedAttempts,
    Object? lockedUntil = _unset,
  }) {
    return AuthState(
      currentUser: currentUser == _unset
          ? this.currentUser
          : currentUser as User?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil == _unset
          ? this.lockedUntil
          : lockedUntil as DateTime?,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref, this._lockoutStore)
    : super(
        AuthState(
          currentUser: null,
          isLoading: false,
          errorMessage: null,
          failedAttempts: _lockoutStore.getFailedAttempts(),
          lockedUntil: _lockoutStore.getLockedUntil(),
        ),
      );

  final Ref _ref;
  final AuthLockoutStore _lockoutStore;
  static const int _maxFailedAttempts = 3;
  static const Duration _lockDuration = Duration(seconds: 30);

  Future<User?> loginWithPin(String pin) async {
    _pruneExpiredLock();
    if (state.isLocked) {
      state = state.copyWith(
        errorMessage: AppStrings.authLocked,
        currentUser: null,
      );
      return null;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _ref.read(authServiceProvider).loginWithPin(pin);
      if (user == null) {
        final int nextFailedAttempts = state.failedAttempts + 1;
        final bool shouldLock = nextFailedAttempts >= _maxFailedAttempts;
        final DateTime? lockUntil = shouldLock
            ? DateTime.now().add(_lockDuration)
            : null;
        final int newCount = shouldLock ? 0 : nextFailedAttempts;

        await _lockoutStore.setFailedAttempts(newCount);
        await _lockoutStore.setLockedUntil(lockUntil);

        state = state.copyWith(
          isLoading: false,
          errorMessage: shouldLock
              ? AppStrings.authLocked
              : AppStrings.invalidPinOrInactiveUser,
          currentUser: null,
          failedAttempts: newCount,
          lockedUntil: lockUntil,
        );
        return null;
      }

      await _lockoutStore.reset();
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        currentUser: user,
        failedAttempts: 0,
        lockedUntil: null,
      );
      return user;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'auth_login_failed',
          stackTrace: stackTrace,
        ),
        currentUser: null,
      );
      return null;
    }
  }

  Future<void> loadUserById(int userId) async {
    _pruneExpiredLock();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _ref.read(authServiceProvider).getUserById(userId);
      state = state.copyWith(
        currentUser: user,
        isLoading: false,
        errorMessage: user == null ? 'User not found.' : null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'auth_load_user_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void logout() {
    state = AuthState(
      currentUser: null,
      isLoading: false,
      errorMessage: null,
      failedAttempts: _lockoutStore.getFailedAttempts(),
      lockedUntil: _lockoutStore.getLockedUntil(),
    );
  }

  void _pruneExpiredLock() {
    if (state.lockedUntil == null || state.isLocked) {
      return;
    }
    _lockoutStore.reset();
    state = state.copyWith(
      failedAttempts: 0,
      lockedUntil: null,
      errorMessage: null,
    );
  }
}

final StateNotifierProvider<AuthNotifier, AuthState> authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
      (Ref ref) => AuthNotifier(ref, ref.watch(authLockoutStoreProvider)),
    );

const Object _unset = Object();
