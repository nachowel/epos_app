import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../data/repositories/user_repository.dart';
import '../models/user.dart';
import 'auth_security.dart';
import 'audit_log_service.dart';

class UserManagementService {
  const UserManagementService({
    required UserRepository userRepository,
    required AuditLogService auditLogService,
    required AppLogger logger,
  })  : _userRepository = userRepository,
        _auditLogService = auditLogService,
        _logger = logger;

  final UserRepository _userRepository;
  final AuditLogService _auditLogService;
  final AppLogger _logger;

  Future<List<User>> getAllUsers() async {
    return _userRepository.getAll();
  }

  Future<User> addCashier({
    required String name,
    required String pin,
    required User createdBy,
  }) async {
    if (name.trim().isEmpty) {
      throw const ValidationException('Name cannot be empty.');
    }
    
    final String hashedPin;
    try {
      hashedPin = AuthSecurity.hashPin(pin);
    } on FormatException catch (e) {
      throw ValidationException(e.message);
    }

    final int id = await _userRepository.insert(
      name: name.trim(),
      role: UserRole.cashier,
      pin: hashedPin,
      isActive: true,
      createdAt: DateTime.now().toUtc(),
    );

    final User? newUser = await _userRepository.getById(id);
    if (newUser == null) {
      throw const DatabaseException('Failed to retrieve newly created user.');
    }

    await _auditLogService.logActionSafely(
      actorUserId: createdBy.id,
      action: 'user_created',
      entityType: 'user',
      entityId: '$id',
      metadata: <String, dynamic>{
        'role': 'cashier',
        'name': name.trim(),
      },
    );

    _logger.info(
      eventType: 'cashier_created',
      message: 'New cashier added',
      metadata: <String, dynamic>{'userId': id, 'name': name.trim()},
    );

    return newUser;
  }

  Future<void> updateUser({
    required int id,
    String? name,
    bool? isActive,
    required User updatedBy,
  }) async {
    final User? targetUser = await _userRepository.getById(id);
    if (targetUser == null) {
      throw ValidationException('User not found.');
    }

    if (name != null && name.trim().isEmpty) {
      throw const ValidationException('Name cannot be empty.');
    }

    // Safety rule: Cannot deactivate yourself.
    if (isActive == false && id == updatedBy.id) {
      throw const ValidationException('You cannot deactivate your own account.');
    }

    // Safety rule: Cannot deactivate the last active admin
    if (isActive == false && targetUser.role == UserRole.admin) {
      final List<User> admins = await _userRepository.getByRole(UserRole.admin);
      final int activeAdmins = admins.where((User u) => u.isActive && u.id != id).length;
      if (activeAdmins == 0) {
        throw const ValidationException('Cannot deactivate the last active admin.');
      }
    }

    await _userRepository.updateUser(
      id: id,
      name: name?.trim(),
      isActive: isActive,
    );

    await _auditLogService.logActionSafely(
      actorUserId: updatedBy.id,
      action: 'user_updated',
      entityType: 'user',
      entityId: '$id',
      metadata: <String, dynamic>{
        if (name != null) 'name': name.trim(),
        if (isActive != null) 'isActive': isActive,
      },
    );

    _logger.info(
      eventType: 'user_updated',
      message: 'User updated',
      metadata: <String, dynamic>{'userId': id},
    );
  }

  Future<void> changePin({
    required int id,
    required String newPin,
    required User updatedBy,
  }) async {
    final User? targetUser = await _userRepository.getById(id);
    if (targetUser == null) {
      throw const ValidationException('User not found.');
    }

    final String hashedPin;
    try {
      hashedPin = AuthSecurity.hashPin(newPin);
    } on FormatException catch (e) {
      throw ValidationException(e.message);
    }

    await _userRepository.updateUser(id: id, pin: hashedPin);

    await _auditLogService.logActionSafely(
      actorUserId: updatedBy.id,
      action: 'user_pin_changed',
      entityType: 'user',
      entityId: '$id',
    );

    _logger.info(
      eventType: 'user_pin_changed',
      message: 'User PIN changed',
      metadata: <String, dynamic>{'userId': id},
    );
  }
}
