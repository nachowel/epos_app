enum UserRole { admin, cashier }

class User {
  const User({
    required this.id,
    required this.name,
    required this.pin,
    required this.password,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String? pin;
  final String? password;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  User copyWith({
    int? id,
    String? name,
    Object? pin = _unset,
    Object? password = _unset,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin == _unset ? this.pin : pin as String?,
      password: password == _unset ? this.password : password as String?,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.pin == pin &&
        other.password == password &&
        other.role == role &&
        other.isActive == isActive &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, pin, password, role, isActive, createdAt);
}

const Object _unset = Object();
