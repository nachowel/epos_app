import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/models/user.dart';
import '../../domain/services/user_management_service.dart';
import 'auth_provider.dart';

class AdminUsersState {
  const AdminUsersState({
    required this.users,
    required this.isLoading,
    required this.errorMessage,
  });

  const AdminUsersState.initial()
      : users = const <User>[],
        isLoading = false,
        errorMessage = null;

  final List<User> users;
  final bool isLoading;
  final String? errorMessage;

  AdminUsersState copyWith({
    List<User>? users,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminUsersNotifier extends StateNotifier<AdminUsersState> {
  AdminUsersNotifier(this._ref, this._service)
      : super(const AdminUsersState.initial());

  final Ref _ref;
  final UserManagementService _service;

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final List<User> users = await _service.getAllUsers();
      state = state.copyWith(isLoading: false, users: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addCashier({required String name, required String pin}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) return;

    await _service.addCashier(
      name: name,
      pin: pin,
      createdBy: currentUser,
    );
    await loadUsers();
  }

  Future<void> updateUser({
    required int id,
    String? name,
    bool? isActive,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) return;

    await _service.updateUser(
      id: id,
      name: name,
      isActive: isActive,
      updatedBy: currentUser,
    );
    await loadUsers();

    if (id == currentUser.id) {
      unawaited(_ref.read(authNotifierProvider.notifier).loadUserById(id));
    }
  }

  Future<void> changePin({
    required int id,
    required String newPin,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) return;

    await _service.changePin(
      id: id,
      newPin: newPin,
      updatedBy: currentUser,
    );
    await loadUsers();

    if (id == currentUser.id) {
      unawaited(_ref.read(authNotifierProvider.notifier).loadUserById(id));
    }
  }
}

final StateNotifierProvider<AdminUsersNotifier, AdminUsersState>
    adminUsersNotifierProvider =
    StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((Ref ref) {
  return AdminUsersNotifier(ref, ref.watch(userManagementServiceProvider));
});

const Object _unset = Object();
