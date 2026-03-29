import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/user.dart';
import '../database/app_database.dart' as db;

class UserRepository {
  const UserRepository(this._database);

  final db.AppDatabase _database;

  Future<List<User>> getAll() async {
    final List<db.User> rows =
        await (_database.select(_database.users)
              ..orderBy(<OrderingTerm Function(db.$UsersTable)>[
                (db.$UsersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    return rows.map(_mapUser).toList(growable: false);
  }

  Future<User?> getById(int id) async {
    final db.User? row = await (_database.select(
      _database.users,
    )..where((db.$UsersTable t) => t.id.equals(id))).getSingleOrNull();

    return row == null ? null : _mapUser(row);
  }

  Future<User?> getByPin(String pin) async {
    final db.User? row = await (_database.select(
      _database.users,
    )..where((db.$UsersTable t) => t.pin.equals(pin))).getSingleOrNull();

    return row == null ? null : _mapUser(row);
  }

  Future<List<User>> getByRole(UserRole role) async {
    final List<db.User> rows =
        await (_database.select(_database.users)
              ..where((db.$UsersTable t) => t.role.equals(_roleToDb(role)))
              ..orderBy(<OrderingTerm Function(db.$UsersTable)>[
                (db.$UsersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    return rows.map(_mapUser).toList(growable: false);
  }

  Future<int> insert({
    required String name,
    required UserRole role,
    String? pin,
    String? password,
    bool isActive = true,
    DateTime? createdAt,
  }) {
    return _database
        .into(_database.users)
        .insert(
          db.UsersCompanion.insert(
            name: name,
            role: _roleToDb(role),
            pin: Value<String?>(pin),
            password: Value<String?>(password),
            isActive: Value<bool>(isActive),
            createdAt: createdAt == null
                ? const Value<DateTime>.absent()
                : Value<DateTime>(createdAt),
          ),
        );
  }

  Future<bool> updateUser({
    required int id,
    String? name,
    String? pin,
    String? password,
    UserRole? role,
    bool? isActive,
  }) async {
    final int updatedCount =
        await (_database.update(
          _database.users,
        )..where((db.$UsersTable t) => t.id.equals(id))).write(
          db.UsersCompanion(
            name: name == null
                ? const Value<String>.absent()
                : Value<String>(name),
            pin: pin == null
                ? const Value<String?>.absent()
                : Value<String?>(pin),
            password: password == null
                ? const Value<String?>.absent()
                : Value<String?>(password),
            role: role == null
                ? const Value<String>.absent()
                : Value<String>(_roleToDb(role)),
            isActive: isActive == null
                ? const Value<bool>.absent()
                : Value<bool>(isActive),
          ),
        );

    return updatedCount > 0;
  }

  Future<bool> toggleActive(int id, bool isActive) async {
    final int updatedCount =
        await (_database.update(_database.users)
              ..where((db.$UsersTable t) => t.id.equals(id)))
            .write(db.UsersCompanion(isActive: Value<bool>(isActive)));

    return updatedCount > 0;
  }

  User _mapUser(db.User row) {
    return User(
      id: row.id,
      name: row.name,
      pin: row.pin,
      password: row.password,
      role: _roleFromDb(row.role),
      isActive: row.isActive,
      createdAt: row.createdAt,
    );
  }

  UserRole _roleFromDb(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
      case 'cashier':
        return UserRole.cashier;
      default:
        throw DatabaseException('Unknown user role: $role');
    }
  }

  String _roleToDb(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.cashier:
        return 'cashier';
    }
  }
}
