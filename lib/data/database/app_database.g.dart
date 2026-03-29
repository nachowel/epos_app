// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinMeta = const VerificationMeta('pin');
  @override
  late final GeneratedColumn<String> pin = GeneratedColumn<String>(
    'pin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passwordMeta = const VerificationMeta(
    'password',
  );
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
    'password',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    pin,
    password,
    role,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pin')) {
      context.handle(
        _pinMeta,
        pin.isAcceptableOrUnknown(data['pin']!, _pinMeta),
      );
    }
    if (data.containsKey('password')) {
      context.handle(
        _passwordMeta,
        password.isAcceptableOrUnknown(data['password']!, _passwordMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      pin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin'],
      ),
      password: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String name;
  final String? pin;
  final String? password;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  const User({
    required this.id,
    required this.name,
    this.pin,
    this.password,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || pin != null) {
      map['pin'] = Variable<String>(pin);
    }
    if (!nullToAbsent || password != null) {
      map['password'] = Variable<String>(password);
    }
    map['role'] = Variable<String>(role);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      pin: pin == null && nullToAbsent ? const Value.absent() : Value(pin),
      password: password == null && nullToAbsent
          ? const Value.absent()
          : Value(password),
      role: Value(role),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      pin: serializer.fromJson<String?>(json['pin']),
      password: serializer.fromJson<String?>(json['password']),
      role: serializer.fromJson<String>(json['role']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'pin': serializer.toJson<String?>(pin),
      'password': serializer.toJson<String?>(password),
      'role': serializer.toJson<String>(role),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  User copyWith({
    int? id,
    String? name,
    Value<String?> pin = const Value.absent(),
    Value<String?> password = const Value.absent(),
    String? role,
    bool? isActive,
    DateTime? createdAt,
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    pin: pin.present ? pin.value : this.pin,
    password: password.present ? password.value : this.password,
    role: role ?? this.role,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      pin: data.pin.present ? data.pin.value : this.pin,
      password: data.password.present ? data.password.value : this.password,
      role: data.role.present ? data.role.value : this.role,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pin: $pin, ')
          ..write('password: $password, ')
          ..write('role: $role, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, pin, password, role, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.pin == this.pin &&
          other.password == this.password &&
          other.role == this.role &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> pin;
  final Value<String?> password;
  final Value<String> role;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.pin = const Value.absent(),
    this.password = const Value.absent(),
    this.role = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.pin = const Value.absent(),
    this.password = const Value.absent(),
    required String role,
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       role = Value(role);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? pin,
    Expression<String>? password,
    Expression<String>? role,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pin != null) 'pin': pin,
      if (password != null) 'password': password,
      if (role != null) 'role': role,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? pin,
    Value<String?>? password,
    Value<String>? role,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      password: password ?? this.password,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pin.present) {
      map['pin'] = Variable<String>(pin.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pin: $pin, ')
          ..write('password: $password, ')
          ..write('role: $role, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    imageUrl,
    sortOrder,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  const Category({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.sortOrder,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    Value<String?> imageUrl = const Value.absent(),
    int? sortOrder,
    bool? isActive,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, imageUrl, sortOrder, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.imageUrl == this.imageUrl &&
          other.sortOrder == this.sortOrder &&
          other.isActive == this.isActive);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> imageUrl;
  final Value<int> sortOrder;
  final Value<bool> isActive;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.imageUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? imageUrl,
    Expression<int>? sortOrder,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (imageUrl != null) 'image_url': imageUrl,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? imageUrl,
    Value<int>? sortOrder,
    Value<bool>? isActive,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "categories" ("id")',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMinorMeta = const VerificationMeta(
    'priceMinor',
  );
  @override
  late final GeneratedColumn<int> priceMinor = GeneratedColumn<int>(
    'price_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasModifiersMeta = const VerificationMeta(
    'hasModifiers',
  );
  @override
  late final GeneratedColumn<bool> hasModifiers = GeneratedColumn<bool>(
    'has_modifiers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_modifiers" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isVisibleOnPosMeta = const VerificationMeta(
    'isVisibleOnPos',
  );
  @override
  late final GeneratedColumn<bool> isVisibleOnPos = GeneratedColumn<bool>(
    'is_visible_on_pos',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_visible_on_pos" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    name,
    priceMinor,
    imageUrl,
    hasModifiers,
    isActive,
    isVisibleOnPos,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price_minor')) {
      context.handle(
        _priceMinorMeta,
        priceMinor.isAcceptableOrUnknown(data['price_minor']!, _priceMinorMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMinorMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('has_modifiers')) {
      context.handle(
        _hasModifiersMeta,
        hasModifiers.isAcceptableOrUnknown(
          data['has_modifiers']!,
          _hasModifiersMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('is_visible_on_pos')) {
      context.handle(
        _isVisibleOnPosMeta,
        isVisibleOnPos.isAcceptableOrUnknown(
          data['is_visible_on_pos']!,
          _isVisibleOnPosMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      priceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_minor'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      hasModifiers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_modifiers'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      isVisibleOnPos: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_visible_on_pos'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final int id;
  final int categoryId;
  final String name;
  final int priceMinor;
  final String? imageUrl;
  final bool hasModifiers;
  final bool isActive;
  final bool isVisibleOnPos;
  final int sortOrder;
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceMinor,
    this.imageUrl,
    required this.hasModifiers,
    required this.isActive,
    required this.isVisibleOnPos,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category_id'] = Variable<int>(categoryId);
    map['name'] = Variable<String>(name);
    map['price_minor'] = Variable<int>(priceMinor);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['has_modifiers'] = Variable<bool>(hasModifiers);
    map['is_active'] = Variable<bool>(isActive);
    map['is_visible_on_pos'] = Variable<bool>(isVisibleOnPos);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      name: Value(name),
      priceMinor: Value(priceMinor),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      hasModifiers: Value(hasModifiers),
      isActive: Value(isActive),
      isVisibleOnPos: Value(isVisibleOnPos),
      sortOrder: Value(sortOrder),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      priceMinor: serializer.fromJson<int>(json['priceMinor']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      hasModifiers: serializer.fromJson<bool>(json['hasModifiers']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      isVisibleOnPos: serializer.fromJson<bool>(json['isVisibleOnPos']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int>(categoryId),
      'name': serializer.toJson<String>(name),
      'priceMinor': serializer.toJson<int>(priceMinor),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'hasModifiers': serializer.toJson<bool>(hasModifiers),
      'isActive': serializer.toJson<bool>(isActive),
      'isVisibleOnPos': serializer.toJson<bool>(isVisibleOnPos),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Product copyWith({
    int? id,
    int? categoryId,
    String? name,
    int? priceMinor,
    Value<String?> imageUrl = const Value.absent(),
    bool? hasModifiers,
    bool? isActive,
    bool? isVisibleOnPos,
    int? sortOrder,
  }) => Product(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    priceMinor: priceMinor ?? this.priceMinor,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    hasModifiers: hasModifiers ?? this.hasModifiers,
    isActive: isActive ?? this.isActive,
    isVisibleOnPos: isVisibleOnPos ?? this.isVisibleOnPos,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      priceMinor: data.priceMinor.present
          ? data.priceMinor.value
          : this.priceMinor,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      hasModifiers: data.hasModifiers.present
          ? data.hasModifiers.value
          : this.hasModifiers,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      isVisibleOnPos: data.isVisibleOnPos.present
          ? data.isVisibleOnPos.value
          : this.isVisibleOnPos,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('hasModifiers: $hasModifiers, ')
          ..write('isActive: $isActive, ')
          ..write('isVisibleOnPos: $isVisibleOnPos, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    name,
    priceMinor,
    imageUrl,
    hasModifiers,
    isActive,
    isVisibleOnPos,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.priceMinor == this.priceMinor &&
          other.imageUrl == this.imageUrl &&
          other.hasModifiers == this.hasModifiers &&
          other.isActive == this.isActive &&
          other.isVisibleOnPos == this.isVisibleOnPos &&
          other.sortOrder == this.sortOrder);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<int> id;
  final Value<int> categoryId;
  final Value<String> name;
  final Value<int> priceMinor;
  final Value<String?> imageUrl;
  final Value<bool> hasModifiers;
  final Value<bool> isActive;
  final Value<bool> isVisibleOnPos;
  final Value<int> sortOrder;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.priceMinor = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.hasModifiers = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isVisibleOnPos = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.id = const Value.absent(),
    required int categoryId,
    required String name,
    required int priceMinor,
    this.imageUrl = const Value.absent(),
    this.hasModifiers = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isVisibleOnPos = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : categoryId = Value(categoryId),
       name = Value(name),
       priceMinor = Value(priceMinor);
  static Insertable<Product> custom({
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<String>? name,
    Expression<int>? priceMinor,
    Expression<String>? imageUrl,
    Expression<bool>? hasModifiers,
    Expression<bool>? isActive,
    Expression<bool>? isVisibleOnPos,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (priceMinor != null) 'price_minor': priceMinor,
      if (imageUrl != null) 'image_url': imageUrl,
      if (hasModifiers != null) 'has_modifiers': hasModifiers,
      if (isActive != null) 'is_active': isActive,
      if (isVisibleOnPos != null) 'is_visible_on_pos': isVisibleOnPos,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  ProductsCompanion copyWith({
    Value<int>? id,
    Value<int>? categoryId,
    Value<String>? name,
    Value<int>? priceMinor,
    Value<String?>? imageUrl,
    Value<bool>? hasModifiers,
    Value<bool>? isActive,
    Value<bool>? isVisibleOnPos,
    Value<int>? sortOrder,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      priceMinor: priceMinor ?? this.priceMinor,
      imageUrl: imageUrl ?? this.imageUrl,
      hasModifiers: hasModifiers ?? this.hasModifiers,
      isActive: isActive ?? this.isActive,
      isVisibleOnPos: isVisibleOnPos ?? this.isVisibleOnPos,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (priceMinor.present) {
      map['price_minor'] = Variable<int>(priceMinor.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (hasModifiers.present) {
      map['has_modifiers'] = Variable<bool>(hasModifiers.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (isVisibleOnPos.present) {
      map['is_visible_on_pos'] = Variable<bool>(isVisibleOnPos.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('hasModifiers: $hasModifiers, ')
          ..write('isActive: $isActive, ')
          ..write('isVisibleOnPos: $isVisibleOnPos, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ProductModifiersTable extends ProductModifiers
    with TableInfo<$ProductModifiersTable, ProductModifier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductModifiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "products" ("id")',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extraPriceMinorMeta = const VerificationMeta(
    'extraPriceMinor',
  );
  @override
  late final GeneratedColumn<int> extraPriceMinor = GeneratedColumn<int>(
    'extra_price_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    name,
    type,
    extraPriceMinor,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_modifiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductModifier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('extra_price_minor')) {
      context.handle(
        _extraPriceMinorMeta,
        extraPriceMinor.isAcceptableOrUnknown(
          data['extra_price_minor']!,
          _extraPriceMinorMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductModifier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductModifier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      extraPriceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}extra_price_minor'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $ProductModifiersTable createAlias(String alias) {
    return $ProductModifiersTable(attachedDatabase, alias);
  }
}

class ProductModifier extends DataClass implements Insertable<ProductModifier> {
  final int id;
  final int productId;
  final String name;
  final String type;
  final int extraPriceMinor;
  final bool isActive;
  const ProductModifier({
    required this.id,
    required this.productId,
    required this.name,
    required this.type,
    required this.extraPriceMinor,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<int>(productId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['extra_price_minor'] = Variable<int>(extraPriceMinor);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ProductModifiersCompanion toCompanion(bool nullToAbsent) {
    return ProductModifiersCompanion(
      id: Value(id),
      productId: Value(productId),
      name: Value(name),
      type: Value(type),
      extraPriceMinor: Value(extraPriceMinor),
      isActive: Value(isActive),
    );
  }

  factory ProductModifier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductModifier(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<int>(json['productId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      extraPriceMinor: serializer.fromJson<int>(json['extraPriceMinor']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<int>(productId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'extraPriceMinor': serializer.toJson<int>(extraPriceMinor),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  ProductModifier copyWith({
    int? id,
    int? productId,
    String? name,
    String? type,
    int? extraPriceMinor,
    bool? isActive,
  }) => ProductModifier(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    name: name ?? this.name,
    type: type ?? this.type,
    extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
    isActive: isActive ?? this.isActive,
  );
  ProductModifier copyWithCompanion(ProductModifiersCompanion data) {
    return ProductModifier(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      extraPriceMinor: data.extraPriceMinor.present
          ? data.extraPriceMinor.value
          : this.extraPriceMinor,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductModifier(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('extraPriceMinor: $extraPriceMinor, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, productId, name, type, extraPriceMinor, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductModifier &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.name == this.name &&
          other.type == this.type &&
          other.extraPriceMinor == this.extraPriceMinor &&
          other.isActive == this.isActive);
}

class ProductModifiersCompanion extends UpdateCompanion<ProductModifier> {
  final Value<int> id;
  final Value<int> productId;
  final Value<String> name;
  final Value<String> type;
  final Value<int> extraPriceMinor;
  final Value<bool> isActive;
  const ProductModifiersCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.extraPriceMinor = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  ProductModifiersCompanion.insert({
    this.id = const Value.absent(),
    required int productId,
    required String name,
    required String type,
    this.extraPriceMinor = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : productId = Value(productId),
       name = Value(name),
       type = Value(type);
  static Insertable<ProductModifier> custom({
    Expression<int>? id,
    Expression<int>? productId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? extraPriceMinor,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (extraPriceMinor != null) 'extra_price_minor': extraPriceMinor,
      if (isActive != null) 'is_active': isActive,
    });
  }

  ProductModifiersCompanion copyWith({
    Value<int>? id,
    Value<int>? productId,
    Value<String>? name,
    Value<String>? type,
    Value<int>? extraPriceMinor,
    Value<bool>? isActive,
  }) {
    return ProductModifiersCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      type: type ?? this.type,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (extraPriceMinor.present) {
      map['extra_price_minor'] = Variable<int>(extraPriceMinor.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductModifiersCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('extraPriceMinor: $extraPriceMinor, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $ShiftsTable extends Shifts with TableInfo<$ShiftsTable, Shift> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _openedByMeta = const VerificationMeta(
    'openedBy',
  );
  @override
  late final GeneratedColumn<int> openedBy = GeneratedColumn<int>(
    'opened_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "users" ("id")',
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _closedByMeta = const VerificationMeta(
    'closedBy',
  );
  @override
  late final GeneratedColumn<int> closedBy = GeneratedColumn<int>(
    'closed_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES "users" ("id")',
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashierPreviewedByMeta =
      const VerificationMeta('cashierPreviewedBy');
  @override
  late final GeneratedColumn<int> cashierPreviewedBy = GeneratedColumn<int>(
    'cashier_previewed_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES "users" ("id")',
  );
  static const VerificationMeta _cashierPreviewedAtMeta =
      const VerificationMeta('cashierPreviewedAt');
  @override
  late final GeneratedColumn<DateTime> cashierPreviewedAt =
      GeneratedColumn<DateTime>(
        'cashier_previewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    openedBy,
    openedAt,
    closedBy,
    closedAt,
    cashierPreviewedBy,
    cashierPreviewedAt,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shifts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Shift> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('opened_by')) {
      context.handle(
        _openedByMeta,
        openedBy.isAcceptableOrUnknown(data['opened_by']!, _openedByMeta),
      );
    } else if (isInserting) {
      context.missing(_openedByMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('closed_by')) {
      context.handle(
        _closedByMeta,
        closedBy.isAcceptableOrUnknown(data['closed_by']!, _closedByMeta),
      );
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('cashier_previewed_by')) {
      context.handle(
        _cashierPreviewedByMeta,
        cashierPreviewedBy.isAcceptableOrUnknown(
          data['cashier_previewed_by']!,
          _cashierPreviewedByMeta,
        ),
      );
    }
    if (data.containsKey('cashier_previewed_at')) {
      context.handle(
        _cashierPreviewedAtMeta,
        cashierPreviewedAt.isAcceptableOrUnknown(
          data['cashier_previewed_at']!,
          _cashierPreviewedAtMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Shift map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shift(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      openedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_by'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      )!,
      closedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_by'],
      ),
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      cashierPreviewedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cashier_previewed_by'],
      ),
      cashierPreviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cashier_previewed_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $ShiftsTable createAlias(String alias) {
    return $ShiftsTable(attachedDatabase, alias);
  }
}

class Shift extends DataClass implements Insertable<Shift> {
  final int id;
  final int openedBy;
  final DateTime openedAt;
  final int? closedBy;
  final DateTime? closedAt;
  final int? cashierPreviewedBy;
  final DateTime? cashierPreviewedAt;
  final String status;
  const Shift({
    required this.id,
    required this.openedBy,
    required this.openedAt,
    this.closedBy,
    this.closedAt,
    this.cashierPreviewedBy,
    this.cashierPreviewedAt,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['opened_by'] = Variable<int>(openedBy);
    map['opened_at'] = Variable<DateTime>(openedAt);
    if (!nullToAbsent || closedBy != null) {
      map['closed_by'] = Variable<int>(closedBy);
    }
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    if (!nullToAbsent || cashierPreviewedBy != null) {
      map['cashier_previewed_by'] = Variable<int>(cashierPreviewedBy);
    }
    if (!nullToAbsent || cashierPreviewedAt != null) {
      map['cashier_previewed_at'] = Variable<DateTime>(cashierPreviewedAt);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  ShiftsCompanion toCompanion(bool nullToAbsent) {
    return ShiftsCompanion(
      id: Value(id),
      openedBy: Value(openedBy),
      openedAt: Value(openedAt),
      closedBy: closedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(closedBy),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      cashierPreviewedBy: cashierPreviewedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(cashierPreviewedBy),
      cashierPreviewedAt: cashierPreviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cashierPreviewedAt),
      status: Value(status),
    );
  }

  factory Shift.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Shift(
      id: serializer.fromJson<int>(json['id']),
      openedBy: serializer.fromJson<int>(json['openedBy']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
      closedBy: serializer.fromJson<int?>(json['closedBy']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      cashierPreviewedBy: serializer.fromJson<int?>(json['cashierPreviewedBy']),
      cashierPreviewedAt: serializer.fromJson<DateTime?>(
        json['cashierPreviewedAt'],
      ),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'openedBy': serializer.toJson<int>(openedBy),
      'openedAt': serializer.toJson<DateTime>(openedAt),
      'closedBy': serializer.toJson<int?>(closedBy),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'cashierPreviewedBy': serializer.toJson<int?>(cashierPreviewedBy),
      'cashierPreviewedAt': serializer.toJson<DateTime?>(cashierPreviewedAt),
      'status': serializer.toJson<String>(status),
    };
  }

  Shift copyWith({
    int? id,
    int? openedBy,
    DateTime? openedAt,
    Value<int?> closedBy = const Value.absent(),
    Value<DateTime?> closedAt = const Value.absent(),
    Value<int?> cashierPreviewedBy = const Value.absent(),
    Value<DateTime?> cashierPreviewedAt = const Value.absent(),
    String? status,
  }) => Shift(
    id: id ?? this.id,
    openedBy: openedBy ?? this.openedBy,
    openedAt: openedAt ?? this.openedAt,
    closedBy: closedBy.present ? closedBy.value : this.closedBy,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    cashierPreviewedBy: cashierPreviewedBy.present
        ? cashierPreviewedBy.value
        : this.cashierPreviewedBy,
    cashierPreviewedAt: cashierPreviewedAt.present
        ? cashierPreviewedAt.value
        : this.cashierPreviewedAt,
    status: status ?? this.status,
  );
  Shift copyWithCompanion(ShiftsCompanion data) {
    return Shift(
      id: data.id.present ? data.id.value : this.id,
      openedBy: data.openedBy.present ? data.openedBy.value : this.openedBy,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      closedBy: data.closedBy.present ? data.closedBy.value : this.closedBy,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      cashierPreviewedBy: data.cashierPreviewedBy.present
          ? data.cashierPreviewedBy.value
          : this.cashierPreviewedBy,
      cashierPreviewedAt: data.cashierPreviewedAt.present
          ? data.cashierPreviewedAt.value
          : this.cashierPreviewedAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Shift(')
          ..write('id: $id, ')
          ..write('openedBy: $openedBy, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedBy: $closedBy, ')
          ..write('closedAt: $closedAt, ')
          ..write('cashierPreviewedBy: $cashierPreviewedBy, ')
          ..write('cashierPreviewedAt: $cashierPreviewedAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    openedBy,
    openedAt,
    closedBy,
    closedAt,
    cashierPreviewedBy,
    cashierPreviewedAt,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shift &&
          other.id == this.id &&
          other.openedBy == this.openedBy &&
          other.openedAt == this.openedAt &&
          other.closedBy == this.closedBy &&
          other.closedAt == this.closedAt &&
          other.cashierPreviewedBy == this.cashierPreviewedBy &&
          other.cashierPreviewedAt == this.cashierPreviewedAt &&
          other.status == this.status);
}

class ShiftsCompanion extends UpdateCompanion<Shift> {
  final Value<int> id;
  final Value<int> openedBy;
  final Value<DateTime> openedAt;
  final Value<int?> closedBy;
  final Value<DateTime?> closedAt;
  final Value<int?> cashierPreviewedBy;
  final Value<DateTime?> cashierPreviewedAt;
  final Value<String> status;
  const ShiftsCompanion({
    this.id = const Value.absent(),
    this.openedBy = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.closedBy = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.cashierPreviewedBy = const Value.absent(),
    this.cashierPreviewedAt = const Value.absent(),
    this.status = const Value.absent(),
  });
  ShiftsCompanion.insert({
    this.id = const Value.absent(),
    required int openedBy,
    this.openedAt = const Value.absent(),
    this.closedBy = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.cashierPreviewedBy = const Value.absent(),
    this.cashierPreviewedAt = const Value.absent(),
    this.status = const Value.absent(),
  }) : openedBy = Value(openedBy);
  static Insertable<Shift> custom({
    Expression<int>? id,
    Expression<int>? openedBy,
    Expression<DateTime>? openedAt,
    Expression<int>? closedBy,
    Expression<DateTime>? closedAt,
    Expression<int>? cashierPreviewedBy,
    Expression<DateTime>? cashierPreviewedAt,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (openedBy != null) 'opened_by': openedBy,
      if (openedAt != null) 'opened_at': openedAt,
      if (closedBy != null) 'closed_by': closedBy,
      if (closedAt != null) 'closed_at': closedAt,
      if (cashierPreviewedBy != null)
        'cashier_previewed_by': cashierPreviewedBy,
      if (cashierPreviewedAt != null)
        'cashier_previewed_at': cashierPreviewedAt,
      if (status != null) 'status': status,
    });
  }

  ShiftsCompanion copyWith({
    Value<int>? id,
    Value<int>? openedBy,
    Value<DateTime>? openedAt,
    Value<int?>? closedBy,
    Value<DateTime?>? closedAt,
    Value<int?>? cashierPreviewedBy,
    Value<DateTime?>? cashierPreviewedAt,
    Value<String>? status,
  }) {
    return ShiftsCompanion(
      id: id ?? this.id,
      openedBy: openedBy ?? this.openedBy,
      openedAt: openedAt ?? this.openedAt,
      closedBy: closedBy ?? this.closedBy,
      closedAt: closedAt ?? this.closedAt,
      cashierPreviewedBy: cashierPreviewedBy ?? this.cashierPreviewedBy,
      cashierPreviewedAt: cashierPreviewedAt ?? this.cashierPreviewedAt,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (openedBy.present) {
      map['opened_by'] = Variable<int>(openedBy.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (closedBy.present) {
      map['closed_by'] = Variable<int>(closedBy.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (cashierPreviewedBy.present) {
      map['cashier_previewed_by'] = Variable<int>(cashierPreviewedBy.value);
    }
    if (cashierPreviewedAt.present) {
      map['cashier_previewed_at'] = Variable<DateTime>(
        cashierPreviewedAt.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftsCompanion(')
          ..write('id: $id, ')
          ..write('openedBy: $openedBy, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedBy: $closedBy, ')
          ..write('closedAt: $closedAt, ')
          ..write('cashierPreviewedBy: $cashierPreviewedBy, ')
          ..write('cashierPreviewedAt: $cashierPreviewedAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<int> shiftId = GeneratedColumn<int>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "shifts" ("id")',
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "users" ("id")',
  );
  static const VerificationMeta _tableNumberMeta = const VerificationMeta(
    'tableNumber',
  );
  @override
  late final GeneratedColumn<int> tableNumber = GeneratedColumn<int>(
    'table_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _subtotalMinorMeta = const VerificationMeta(
    'subtotalMinor',
  );
  @override
  late final GeneratedColumn<int> subtotalMinor = GeneratedColumn<int>(
    'subtotal_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modifierTotalMinorMeta =
      const VerificationMeta('modifierTotalMinor');
  @override
  late final GeneratedColumn<int> modifierTotalMinor = GeneratedColumn<int>(
    'modifier_total_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalAmountMinorMeta = const VerificationMeta(
    'totalAmountMinor',
  );
  @override
  late final GeneratedColumn<int> totalAmountMinor = GeneratedColumn<int>(
    'total_amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cancelledAtMeta = const VerificationMeta(
    'cancelledAt',
  );
  @override
  late final GeneratedColumn<DateTime> cancelledAt = GeneratedColumn<DateTime>(
    'cancelled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cancelledByMeta = const VerificationMeta(
    'cancelledBy',
  );
  @override
  late final GeneratedColumn<int> cancelledBy = GeneratedColumn<int>(
    'cancelled_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES "users" ("id")',
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _kitchenPrintedMeta = const VerificationMeta(
    'kitchenPrinted',
  );
  @override
  late final GeneratedColumn<bool> kitchenPrinted = GeneratedColumn<bool>(
    'kitchen_printed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("kitchen_printed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _receiptPrintedMeta = const VerificationMeta(
    'receiptPrinted',
  );
  @override
  late final GeneratedColumn<bool> receiptPrinted = GeneratedColumn<bool>(
    'receipt_printed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("receipt_printed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    shiftId,
    userId,
    tableNumber,
    status,
    subtotalMinor,
    modifierTotalMinor,
    totalAmountMinor,
    createdAt,
    paidAt,
    updatedAt,
    cancelledAt,
    cancelledBy,
    idempotencyKey,
    kitchenPrinted,
    receiptPrinted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shiftIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('table_number')) {
      context.handle(
        _tableNumberMeta,
        tableNumber.isAcceptableOrUnknown(
          data['table_number']!,
          _tableNumberMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('subtotal_minor')) {
      context.handle(
        _subtotalMinorMeta,
        subtotalMinor.isAcceptableOrUnknown(
          data['subtotal_minor']!,
          _subtotalMinorMeta,
        ),
      );
    }
    if (data.containsKey('modifier_total_minor')) {
      context.handle(
        _modifierTotalMinorMeta,
        modifierTotalMinor.isAcceptableOrUnknown(
          data['modifier_total_minor']!,
          _modifierTotalMinorMeta,
        ),
      );
    }
    if (data.containsKey('total_amount_minor')) {
      context.handle(
        _totalAmountMinorMeta,
        totalAmountMinor.isAcceptableOrUnknown(
          data['total_amount_minor']!,
          _totalAmountMinorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('cancelled_at')) {
      context.handle(
        _cancelledAtMeta,
        cancelledAt.isAcceptableOrUnknown(
          data['cancelled_at']!,
          _cancelledAtMeta,
        ),
      );
    }
    if (data.containsKey('cancelled_by')) {
      context.handle(
        _cancelledByMeta,
        cancelledBy.isAcceptableOrUnknown(
          data['cancelled_by']!,
          _cancelledByMeta,
        ),
      );
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('kitchen_printed')) {
      context.handle(
        _kitchenPrintedMeta,
        kitchenPrinted.isAcceptableOrUnknown(
          data['kitchen_printed']!,
          _kitchenPrintedMeta,
        ),
      );
    }
    if (data.containsKey('receipt_printed')) {
      context.handle(
        _receiptPrintedMeta,
        receiptPrinted.isAcceptableOrUnknown(
          data['receipt_printed']!,
          _receiptPrintedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shift_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      )!,
      tableNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}table_number'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      subtotalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal_minor'],
      )!,
      modifierTotalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modifier_total_minor'],
      )!,
      totalAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_amount_minor'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      cancelledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cancelled_at'],
      ),
      cancelledBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cancelled_by'],
      ),
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      kitchenPrinted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}kitchen_printed'],
      )!,
      receiptPrinted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}receipt_printed'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;
  final String uuid;
  final int shiftId;
  final int userId;
  final int? tableNumber;
  final String status;
  final int subtotalMinor;
  final int modifierTotalMinor;
  final int totalAmountMinor;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;
  final int? cancelledBy;
  final String idempotencyKey;
  final bool kitchenPrinted;
  final bool receiptPrinted;
  const Transaction({
    required this.id,
    required this.uuid,
    required this.shiftId,
    required this.userId,
    this.tableNumber,
    required this.status,
    required this.subtotalMinor,
    required this.modifierTotalMinor,
    required this.totalAmountMinor,
    required this.createdAt,
    this.paidAt,
    required this.updatedAt,
    this.cancelledAt,
    this.cancelledBy,
    required this.idempotencyKey,
    required this.kitchenPrinted,
    required this.receiptPrinted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['shift_id'] = Variable<int>(shiftId);
    map['user_id'] = Variable<int>(userId);
    if (!nullToAbsent || tableNumber != null) {
      map['table_number'] = Variable<int>(tableNumber);
    }
    map['status'] = Variable<String>(status);
    map['subtotal_minor'] = Variable<int>(subtotalMinor);
    map['modifier_total_minor'] = Variable<int>(modifierTotalMinor);
    map['total_amount_minor'] = Variable<int>(totalAmountMinor);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<DateTime>(paidAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt);
    }
    if (!nullToAbsent || cancelledBy != null) {
      map['cancelled_by'] = Variable<int>(cancelledBy);
    }
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['kitchen_printed'] = Variable<bool>(kitchenPrinted);
    map['receipt_printed'] = Variable<bool>(receiptPrinted);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      shiftId: Value(shiftId),
      userId: Value(userId),
      tableNumber: tableNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(tableNumber),
      status: Value(status),
      subtotalMinor: Value(subtotalMinor),
      modifierTotalMinor: Value(modifierTotalMinor),
      totalAmountMinor: Value(totalAmountMinor),
      createdAt: Value(createdAt),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
      updatedAt: Value(updatedAt),
      cancelledAt: cancelledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAt),
      cancelledBy: cancelledBy == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledBy),
      idempotencyKey: Value(idempotencyKey),
      kitchenPrinted: Value(kitchenPrinted),
      receiptPrinted: Value(receiptPrinted),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      shiftId: serializer.fromJson<int>(json['shiftId']),
      userId: serializer.fromJson<int>(json['userId']),
      tableNumber: serializer.fromJson<int?>(json['tableNumber']),
      status: serializer.fromJson<String>(json['status']),
      subtotalMinor: serializer.fromJson<int>(json['subtotalMinor']),
      modifierTotalMinor: serializer.fromJson<int>(json['modifierTotalMinor']),
      totalAmountMinor: serializer.fromJson<int>(json['totalAmountMinor']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      cancelledAt: serializer.fromJson<DateTime?>(json['cancelledAt']),
      cancelledBy: serializer.fromJson<int?>(json['cancelledBy']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      kitchenPrinted: serializer.fromJson<bool>(json['kitchenPrinted']),
      receiptPrinted: serializer.fromJson<bool>(json['receiptPrinted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'shiftId': serializer.toJson<int>(shiftId),
      'userId': serializer.toJson<int>(userId),
      'tableNumber': serializer.toJson<int?>(tableNumber),
      'status': serializer.toJson<String>(status),
      'subtotalMinor': serializer.toJson<int>(subtotalMinor),
      'modifierTotalMinor': serializer.toJson<int>(modifierTotalMinor),
      'totalAmountMinor': serializer.toJson<int>(totalAmountMinor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'cancelledAt': serializer.toJson<DateTime?>(cancelledAt),
      'cancelledBy': serializer.toJson<int?>(cancelledBy),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'kitchenPrinted': serializer.toJson<bool>(kitchenPrinted),
      'receiptPrinted': serializer.toJson<bool>(receiptPrinted),
    };
  }

  Transaction copyWith({
    int? id,
    String? uuid,
    int? shiftId,
    int? userId,
    Value<int?> tableNumber = const Value.absent(),
    String? status,
    int? subtotalMinor,
    int? modifierTotalMinor,
    int? totalAmountMinor,
    DateTime? createdAt,
    Value<DateTime?> paidAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> cancelledAt = const Value.absent(),
    Value<int?> cancelledBy = const Value.absent(),
    String? idempotencyKey,
    bool? kitchenPrinted,
    bool? receiptPrinted,
  }) => Transaction(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    shiftId: shiftId ?? this.shiftId,
    userId: userId ?? this.userId,
    tableNumber: tableNumber.present ? tableNumber.value : this.tableNumber,
    status: status ?? this.status,
    subtotalMinor: subtotalMinor ?? this.subtotalMinor,
    modifierTotalMinor: modifierTotalMinor ?? this.modifierTotalMinor,
    totalAmountMinor: totalAmountMinor ?? this.totalAmountMinor,
    createdAt: createdAt ?? this.createdAt,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
    cancelledBy: cancelledBy.present ? cancelledBy.value : this.cancelledBy,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    kitchenPrinted: kitchenPrinted ?? this.kitchenPrinted,
    receiptPrinted: receiptPrinted ?? this.receiptPrinted,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      userId: data.userId.present ? data.userId.value : this.userId,
      tableNumber: data.tableNumber.present
          ? data.tableNumber.value
          : this.tableNumber,
      status: data.status.present ? data.status.value : this.status,
      subtotalMinor: data.subtotalMinor.present
          ? data.subtotalMinor.value
          : this.subtotalMinor,
      modifierTotalMinor: data.modifierTotalMinor.present
          ? data.modifierTotalMinor.value
          : this.modifierTotalMinor,
      totalAmountMinor: data.totalAmountMinor.present
          ? data.totalAmountMinor.value
          : this.totalAmountMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cancelledAt: data.cancelledAt.present
          ? data.cancelledAt.value
          : this.cancelledAt,
      cancelledBy: data.cancelledBy.present
          ? data.cancelledBy.value
          : this.cancelledBy,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      kitchenPrinted: data.kitchenPrinted.present
          ? data.kitchenPrinted.value
          : this.kitchenPrinted,
      receiptPrinted: data.receiptPrinted.present
          ? data.receiptPrinted.value
          : this.receiptPrinted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('shiftId: $shiftId, ')
          ..write('userId: $userId, ')
          ..write('tableNumber: $tableNumber, ')
          ..write('status: $status, ')
          ..write('subtotalMinor: $subtotalMinor, ')
          ..write('modifierTotalMinor: $modifierTotalMinor, ')
          ..write('totalAmountMinor: $totalAmountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('paidAt: $paidAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelledBy: $cancelledBy, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('kitchenPrinted: $kitchenPrinted, ')
          ..write('receiptPrinted: $receiptPrinted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    shiftId,
    userId,
    tableNumber,
    status,
    subtotalMinor,
    modifierTotalMinor,
    totalAmountMinor,
    createdAt,
    paidAt,
    updatedAt,
    cancelledAt,
    cancelledBy,
    idempotencyKey,
    kitchenPrinted,
    receiptPrinted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.shiftId == this.shiftId &&
          other.userId == this.userId &&
          other.tableNumber == this.tableNumber &&
          other.status == this.status &&
          other.subtotalMinor == this.subtotalMinor &&
          other.modifierTotalMinor == this.modifierTotalMinor &&
          other.totalAmountMinor == this.totalAmountMinor &&
          other.createdAt == this.createdAt &&
          other.paidAt == this.paidAt &&
          other.updatedAt == this.updatedAt &&
          other.cancelledAt == this.cancelledAt &&
          other.cancelledBy == this.cancelledBy &&
          other.idempotencyKey == this.idempotencyKey &&
          other.kitchenPrinted == this.kitchenPrinted &&
          other.receiptPrinted == this.receiptPrinted);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> shiftId;
  final Value<int> userId;
  final Value<int?> tableNumber;
  final Value<String> status;
  final Value<int> subtotalMinor;
  final Value<int> modifierTotalMinor;
  final Value<int> totalAmountMinor;
  final Value<DateTime> createdAt;
  final Value<DateTime?> paidAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> cancelledAt;
  final Value<int?> cancelledBy;
  final Value<String> idempotencyKey;
  final Value<bool> kitchenPrinted;
  final Value<bool> receiptPrinted;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.userId = const Value.absent(),
    this.tableNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.subtotalMinor = const Value.absent(),
    this.modifierTotalMinor = const Value.absent(),
    this.totalAmountMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelledBy = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.kitchenPrinted = const Value.absent(),
    this.receiptPrinted = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int shiftId,
    required int userId,
    this.tableNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.subtotalMinor = const Value.absent(),
    this.modifierTotalMinor = const Value.absent(),
    this.totalAmountMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.paidAt = const Value.absent(),
    required DateTime updatedAt,
    this.cancelledAt = const Value.absent(),
    this.cancelledBy = const Value.absent(),
    required String idempotencyKey,
    this.kitchenPrinted = const Value.absent(),
    this.receiptPrinted = const Value.absent(),
  }) : uuid = Value(uuid),
       shiftId = Value(shiftId),
       userId = Value(userId),
       updatedAt = Value(updatedAt),
       idempotencyKey = Value(idempotencyKey);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? shiftId,
    Expression<int>? userId,
    Expression<int>? tableNumber,
    Expression<String>? status,
    Expression<int>? subtotalMinor,
    Expression<int>? modifierTotalMinor,
    Expression<int>? totalAmountMinor,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? paidAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? cancelledAt,
    Expression<int>? cancelledBy,
    Expression<String>? idempotencyKey,
    Expression<bool>? kitchenPrinted,
    Expression<bool>? receiptPrinted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (shiftId != null) 'shift_id': shiftId,
      if (userId != null) 'user_id': userId,
      if (tableNumber != null) 'table_number': tableNumber,
      if (status != null) 'status': status,
      if (subtotalMinor != null) 'subtotal_minor': subtotalMinor,
      if (modifierTotalMinor != null)
        'modifier_total_minor': modifierTotalMinor,
      if (totalAmountMinor != null) 'total_amount_minor': totalAmountMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (paidAt != null) 'paid_at': paidAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (cancelledBy != null) 'cancelled_by': cancelledBy,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (kitchenPrinted != null) 'kitchen_printed': kitchenPrinted,
      if (receiptPrinted != null) 'receipt_printed': receiptPrinted,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? shiftId,
    Value<int>? userId,
    Value<int?>? tableNumber,
    Value<String>? status,
    Value<int>? subtotalMinor,
    Value<int>? modifierTotalMinor,
    Value<int>? totalAmountMinor,
    Value<DateTime>? createdAt,
    Value<DateTime?>? paidAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? cancelledAt,
    Value<int?>? cancelledBy,
    Value<String>? idempotencyKey,
    Value<bool>? kitchenPrinted,
    Value<bool>? receiptPrinted,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      shiftId: shiftId ?? this.shiftId,
      userId: userId ?? this.userId,
      tableNumber: tableNumber ?? this.tableNumber,
      status: status ?? this.status,
      subtotalMinor: subtotalMinor ?? this.subtotalMinor,
      modifierTotalMinor: modifierTotalMinor ?? this.modifierTotalMinor,
      totalAmountMinor: totalAmountMinor ?? this.totalAmountMinor,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      kitchenPrinted: kitchenPrinted ?? this.kitchenPrinted,
      receiptPrinted: receiptPrinted ?? this.receiptPrinted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<int>(shiftId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (tableNumber.present) {
      map['table_number'] = Variable<int>(tableNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (subtotalMinor.present) {
      map['subtotal_minor'] = Variable<int>(subtotalMinor.value);
    }
    if (modifierTotalMinor.present) {
      map['modifier_total_minor'] = Variable<int>(modifierTotalMinor.value);
    }
    if (totalAmountMinor.present) {
      map['total_amount_minor'] = Variable<int>(totalAmountMinor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (cancelledAt.present) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt.value);
    }
    if (cancelledBy.present) {
      map['cancelled_by'] = Variable<int>(cancelledBy.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (kitchenPrinted.present) {
      map['kitchen_printed'] = Variable<bool>(kitchenPrinted.value);
    }
    if (receiptPrinted.present) {
      map['receipt_printed'] = Variable<bool>(receiptPrinted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('shiftId: $shiftId, ')
          ..write('userId: $userId, ')
          ..write('tableNumber: $tableNumber, ')
          ..write('status: $status, ')
          ..write('subtotalMinor: $subtotalMinor, ')
          ..write('modifierTotalMinor: $modifierTotalMinor, ')
          ..write('totalAmountMinor: $totalAmountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('paidAt: $paidAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelledBy: $cancelledBy, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('kitchenPrinted: $kitchenPrinted, ')
          ..write('receiptPrinted: $receiptPrinted')
          ..write(')'))
        .toString();
  }
}

class $TransactionLinesTable extends TransactionLines
    with TableInfo<$TransactionLinesTable, TransactionLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "transactions" ("id")',
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "products" ("id")',
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceMinorMeta = const VerificationMeta(
    'unitPriceMinor',
  );
  @override
  late final GeneratedColumn<int> unitPriceMinor = GeneratedColumn<int>(
    'unit_price_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lineTotalMinorMeta = const VerificationMeta(
    'lineTotalMinor',
  );
  @override
  late final GeneratedColumn<int> lineTotalMinor = GeneratedColumn<int>(
    'line_total_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    transactionId,
    productId,
    productName,
    unitPriceMinor,
    quantity,
    lineTotalMinor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('unit_price_minor')) {
      context.handle(
        _unitPriceMinorMeta,
        unitPriceMinor.isAcceptableOrUnknown(
          data['unit_price_minor']!,
          _unitPriceMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMinorMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('line_total_minor')) {
      context.handle(
        _lineTotalMinorMeta,
        lineTotalMinor.isAcceptableOrUnknown(
          data['line_total_minor']!,
          _lineTotalMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lineTotalMinorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      unitPriceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_minor'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      lineTotalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_total_minor'],
      )!,
    );
  }

  @override
  $TransactionLinesTable createAlias(String alias) {
    return $TransactionLinesTable(attachedDatabase, alias);
  }
}

class TransactionLine extends DataClass implements Insertable<TransactionLine> {
  final int id;
  final String uuid;
  final int transactionId;
  final int productId;
  final String productName;
  final int unitPriceMinor;
  final int quantity;
  final int lineTotalMinor;
  const TransactionLine({
    required this.id,
    required this.uuid,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.unitPriceMinor,
    required this.quantity,
    required this.lineTotalMinor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['transaction_id'] = Variable<int>(transactionId);
    map['product_id'] = Variable<int>(productId);
    map['product_name'] = Variable<String>(productName);
    map['unit_price_minor'] = Variable<int>(unitPriceMinor);
    map['quantity'] = Variable<int>(quantity);
    map['line_total_minor'] = Variable<int>(lineTotalMinor);
    return map;
  }

  TransactionLinesCompanion toCompanion(bool nullToAbsent) {
    return TransactionLinesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      transactionId: Value(transactionId),
      productId: Value(productId),
      productName: Value(productName),
      unitPriceMinor: Value(unitPriceMinor),
      quantity: Value(quantity),
      lineTotalMinor: Value(lineTotalMinor),
    );
  }

  factory TransactionLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionLine(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      productId: serializer.fromJson<int>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      unitPriceMinor: serializer.fromJson<int>(json['unitPriceMinor']),
      quantity: serializer.fromJson<int>(json['quantity']),
      lineTotalMinor: serializer.fromJson<int>(json['lineTotalMinor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'transactionId': serializer.toJson<int>(transactionId),
      'productId': serializer.toJson<int>(productId),
      'productName': serializer.toJson<String>(productName),
      'unitPriceMinor': serializer.toJson<int>(unitPriceMinor),
      'quantity': serializer.toJson<int>(quantity),
      'lineTotalMinor': serializer.toJson<int>(lineTotalMinor),
    };
  }

  TransactionLine copyWith({
    int? id,
    String? uuid,
    int? transactionId,
    int? productId,
    String? productName,
    int? unitPriceMinor,
    int? quantity,
    int? lineTotalMinor,
  }) => TransactionLine(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    transactionId: transactionId ?? this.transactionId,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
    quantity: quantity ?? this.quantity,
    lineTotalMinor: lineTotalMinor ?? this.lineTotalMinor,
  );
  TransactionLine copyWithCompanion(TransactionLinesCompanion data) {
    return TransactionLine(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      unitPriceMinor: data.unitPriceMinor.present
          ? data.unitPriceMinor.value
          : this.unitPriceMinor,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      lineTotalMinor: data.lineTotalMinor.present
          ? data.lineTotalMinor.value
          : this.lineTotalMinor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionLine(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionId: $transactionId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('unitPriceMinor: $unitPriceMinor, ')
          ..write('quantity: $quantity, ')
          ..write('lineTotalMinor: $lineTotalMinor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    transactionId,
    productId,
    productName,
    unitPriceMinor,
    quantity,
    lineTotalMinor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionLine &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.transactionId == this.transactionId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.unitPriceMinor == this.unitPriceMinor &&
          other.quantity == this.quantity &&
          other.lineTotalMinor == this.lineTotalMinor);
}

class TransactionLinesCompanion extends UpdateCompanion<TransactionLine> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> transactionId;
  final Value<int> productId;
  final Value<String> productName;
  final Value<int> unitPriceMinor;
  final Value<int> quantity;
  final Value<int> lineTotalMinor;
  const TransactionLinesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.unitPriceMinor = const Value.absent(),
    this.quantity = const Value.absent(),
    this.lineTotalMinor = const Value.absent(),
  });
  TransactionLinesCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int transactionId,
    required int productId,
    required String productName,
    required int unitPriceMinor,
    this.quantity = const Value.absent(),
    required int lineTotalMinor,
  }) : uuid = Value(uuid),
       transactionId = Value(transactionId),
       productId = Value(productId),
       productName = Value(productName),
       unitPriceMinor = Value(unitPriceMinor),
       lineTotalMinor = Value(lineTotalMinor);
  static Insertable<TransactionLine> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? transactionId,
    Expression<int>? productId,
    Expression<String>? productName,
    Expression<int>? unitPriceMinor,
    Expression<int>? quantity,
    Expression<int>? lineTotalMinor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (transactionId != null) 'transaction_id': transactionId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (unitPriceMinor != null) 'unit_price_minor': unitPriceMinor,
      if (quantity != null) 'quantity': quantity,
      if (lineTotalMinor != null) 'line_total_minor': lineTotalMinor,
    });
  }

  TransactionLinesCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? transactionId,
    Value<int>? productId,
    Value<String>? productName,
    Value<int>? unitPriceMinor,
    Value<int>? quantity,
    Value<int>? lineTotalMinor,
  }) {
    return TransactionLinesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      quantity: quantity ?? this.quantity,
      lineTotalMinor: lineTotalMinor ?? this.lineTotalMinor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (unitPriceMinor.present) {
      map['unit_price_minor'] = Variable<int>(unitPriceMinor.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (lineTotalMinor.present) {
      map['line_total_minor'] = Variable<int>(lineTotalMinor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionLinesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionId: $transactionId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('unitPriceMinor: $unitPriceMinor, ')
          ..write('quantity: $quantity, ')
          ..write('lineTotalMinor: $lineTotalMinor')
          ..write(')'))
        .toString();
  }
}

class $OrderModifiersTable extends OrderModifiers
    with TableInfo<$OrderModifiersTable, OrderModifier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderModifiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _transactionLineIdMeta = const VerificationMeta(
    'transactionLineId',
  );
  @override
  late final GeneratedColumn<int> transactionLineId = GeneratedColumn<int>(
    'transaction_line_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "transaction_lines" ("id")',
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemNameMeta = const VerificationMeta(
    'itemName',
  );
  @override
  late final GeneratedColumn<String> itemName = GeneratedColumn<String>(
    'item_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extraPriceMinorMeta = const VerificationMeta(
    'extraPriceMinor',
  );
  @override
  late final GeneratedColumn<int> extraPriceMinor = GeneratedColumn<int>(
    'extra_price_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    transactionLineId,
    action,
    itemName,
    extraPriceMinor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_modifiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrderModifier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('transaction_line_id')) {
      context.handle(
        _transactionLineIdMeta,
        transactionLineId.isAcceptableOrUnknown(
          data['transaction_line_id']!,
          _transactionLineIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionLineIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('item_name')) {
      context.handle(
        _itemNameMeta,
        itemName.isAcceptableOrUnknown(data['item_name']!, _itemNameMeta),
      );
    } else if (isInserting) {
      context.missing(_itemNameMeta);
    }
    if (data.containsKey('extra_price_minor')) {
      context.handle(
        _extraPriceMinorMeta,
        extraPriceMinor.isAcceptableOrUnknown(
          data['extra_price_minor']!,
          _extraPriceMinorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrderModifier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderModifier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      transactionLineId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_line_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      itemName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_name'],
      )!,
      extraPriceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}extra_price_minor'],
      )!,
    );
  }

  @override
  $OrderModifiersTable createAlias(String alias) {
    return $OrderModifiersTable(attachedDatabase, alias);
  }
}

class OrderModifier extends DataClass implements Insertable<OrderModifier> {
  final int id;
  final String uuid;
  final int transactionLineId;
  final String action;
  final String itemName;
  final int extraPriceMinor;
  const OrderModifier({
    required this.id,
    required this.uuid,
    required this.transactionLineId,
    required this.action,
    required this.itemName,
    required this.extraPriceMinor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['transaction_line_id'] = Variable<int>(transactionLineId);
    map['action'] = Variable<String>(action);
    map['item_name'] = Variable<String>(itemName);
    map['extra_price_minor'] = Variable<int>(extraPriceMinor);
    return map;
  }

  OrderModifiersCompanion toCompanion(bool nullToAbsent) {
    return OrderModifiersCompanion(
      id: Value(id),
      uuid: Value(uuid),
      transactionLineId: Value(transactionLineId),
      action: Value(action),
      itemName: Value(itemName),
      extraPriceMinor: Value(extraPriceMinor),
    );
  }

  factory OrderModifier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderModifier(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      transactionLineId: serializer.fromJson<int>(json['transactionLineId']),
      action: serializer.fromJson<String>(json['action']),
      itemName: serializer.fromJson<String>(json['itemName']),
      extraPriceMinor: serializer.fromJson<int>(json['extraPriceMinor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'transactionLineId': serializer.toJson<int>(transactionLineId),
      'action': serializer.toJson<String>(action),
      'itemName': serializer.toJson<String>(itemName),
      'extraPriceMinor': serializer.toJson<int>(extraPriceMinor),
    };
  }

  OrderModifier copyWith({
    int? id,
    String? uuid,
    int? transactionLineId,
    String? action,
    String? itemName,
    int? extraPriceMinor,
  }) => OrderModifier(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    transactionLineId: transactionLineId ?? this.transactionLineId,
    action: action ?? this.action,
    itemName: itemName ?? this.itemName,
    extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
  );
  OrderModifier copyWithCompanion(OrderModifiersCompanion data) {
    return OrderModifier(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      transactionLineId: data.transactionLineId.present
          ? data.transactionLineId.value
          : this.transactionLineId,
      action: data.action.present ? data.action.value : this.action,
      itemName: data.itemName.present ? data.itemName.value : this.itemName,
      extraPriceMinor: data.extraPriceMinor.present
          ? data.extraPriceMinor.value
          : this.extraPriceMinor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderModifier(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionLineId: $transactionLineId, ')
          ..write('action: $action, ')
          ..write('itemName: $itemName, ')
          ..write('extraPriceMinor: $extraPriceMinor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    transactionLineId,
    action,
    itemName,
    extraPriceMinor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderModifier &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.transactionLineId == this.transactionLineId &&
          other.action == this.action &&
          other.itemName == this.itemName &&
          other.extraPriceMinor == this.extraPriceMinor);
}

class OrderModifiersCompanion extends UpdateCompanion<OrderModifier> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> transactionLineId;
  final Value<String> action;
  final Value<String> itemName;
  final Value<int> extraPriceMinor;
  const OrderModifiersCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.transactionLineId = const Value.absent(),
    this.action = const Value.absent(),
    this.itemName = const Value.absent(),
    this.extraPriceMinor = const Value.absent(),
  });
  OrderModifiersCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int transactionLineId,
    required String action,
    required String itemName,
    this.extraPriceMinor = const Value.absent(),
  }) : uuid = Value(uuid),
       transactionLineId = Value(transactionLineId),
       action = Value(action),
       itemName = Value(itemName);
  static Insertable<OrderModifier> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? transactionLineId,
    Expression<String>? action,
    Expression<String>? itemName,
    Expression<int>? extraPriceMinor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (transactionLineId != null) 'transaction_line_id': transactionLineId,
      if (action != null) 'action': action,
      if (itemName != null) 'item_name': itemName,
      if (extraPriceMinor != null) 'extra_price_minor': extraPriceMinor,
    });
  }

  OrderModifiersCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? transactionLineId,
    Value<String>? action,
    Value<String>? itemName,
    Value<int>? extraPriceMinor,
  }) {
    return OrderModifiersCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionLineId: transactionLineId ?? this.transactionLineId,
      action: action ?? this.action,
      itemName: itemName ?? this.itemName,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (transactionLineId.present) {
      map['transaction_line_id'] = Variable<int>(transactionLineId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (itemName.present) {
      map['item_name'] = Variable<String>(itemName.value);
    }
    if (extraPriceMinor.present) {
      map['extra_price_minor'] = Variable<int>(extraPriceMinor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderModifiersCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionLineId: $transactionLineId, ')
          ..write('action: $action, ')
          ..write('itemName: $itemName, ')
          ..write('extraPriceMinor: $extraPriceMinor')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments with TableInfo<$PaymentsTable, Payment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'UNIQUE NOT NULL REFERENCES "transactions" ("id")',
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    transactionId,
    method,
    amountMinor,
    paidAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Payment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Payment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      )!,
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }
}

class Payment extends DataClass implements Insertable<Payment> {
  final int id;
  final String uuid;
  final int transactionId;
  final String method;
  final int amountMinor;
  final DateTime paidAt;
  const Payment({
    required this.id,
    required this.uuid,
    required this.transactionId,
    required this.method,
    required this.amountMinor,
    required this.paidAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['transaction_id'] = Variable<int>(transactionId);
    map['method'] = Variable<String>(method);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['paid_at'] = Variable<DateTime>(paidAt);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      transactionId: Value(transactionId),
      method: Value(method),
      amountMinor: Value(amountMinor),
      paidAt: Value(paidAt),
    );
  }

  factory Payment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payment(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      method: serializer.fromJson<String>(json['method']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      paidAt: serializer.fromJson<DateTime>(json['paidAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'transactionId': serializer.toJson<int>(transactionId),
      'method': serializer.toJson<String>(method),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'paidAt': serializer.toJson<DateTime>(paidAt),
    };
  }

  Payment copyWith({
    int? id,
    String? uuid,
    int? transactionId,
    String? method,
    int? amountMinor,
    DateTime? paidAt,
  }) => Payment(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    transactionId: transactionId ?? this.transactionId,
    method: method ?? this.method,
    amountMinor: amountMinor ?? this.amountMinor,
    paidAt: paidAt ?? this.paidAt,
  );
  Payment copyWithCompanion(PaymentsCompanion data) {
    return Payment(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      method: data.method.present ? data.method.value : this.method,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payment(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionId: $transactionId, ')
          ..write('method: $method, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('paidAt: $paidAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uuid, transactionId, method, amountMinor, paidAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payment &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.transactionId == this.transactionId &&
          other.method == this.method &&
          other.amountMinor == this.amountMinor &&
          other.paidAt == this.paidAt);
}

class PaymentsCompanion extends UpdateCompanion<Payment> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> transactionId;
  final Value<String> method;
  final Value<int> amountMinor;
  final Value<DateTime> paidAt;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.method = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.paidAt = const Value.absent(),
  });
  PaymentsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int transactionId,
    required String method,
    required int amountMinor,
    this.paidAt = const Value.absent(),
  }) : uuid = Value(uuid),
       transactionId = Value(transactionId),
       method = Value(method),
       amountMinor = Value(amountMinor);
  static Insertable<Payment> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? transactionId,
    Expression<String>? method,
    Expression<int>? amountMinor,
    Expression<DateTime>? paidAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (transactionId != null) 'transaction_id': transactionId,
      if (method != null) 'method': method,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (paidAt != null) 'paid_at': paidAt,
    });
  }

  PaymentsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? transactionId,
    Value<String>? method,
    Value<int>? amountMinor,
    Value<DateTime>? paidAt,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionId: transactionId ?? this.transactionId,
      method: method ?? this.method,
      amountMinor: amountMinor ?? this.amountMinor,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionId: $transactionId, ')
          ..write('method: $method, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('paidAt: $paidAt')
          ..write(')'))
        .toString();
  }
}

class $PaymentAdjustmentsTable extends PaymentAdjustments
    with TableInfo<$PaymentAdjustmentsTable, PaymentAdjustment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentAdjustmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _paymentIdMeta = const VerificationMeta(
    'paymentId',
  );
  @override
  late final GeneratedColumn<int> paymentId = GeneratedColumn<int>(
    'payment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'UNIQUE NOT NULL REFERENCES "payments" ("id")',
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "transactions" ("id")',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('refund'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('completed'),
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "users" ("id")',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    paymentId,
    transactionId,
    type,
    status,
    amountMinor,
    reason,
    createdBy,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payment_adjustments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentAdjustment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('payment_id')) {
      context.handle(
        _paymentIdMeta,
        paymentId.isAcceptableOrUnknown(data['payment_id']!, _paymentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_paymentIdMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaymentAdjustment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentAdjustment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      paymentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payment_id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PaymentAdjustmentsTable createAlias(String alias) {
    return $PaymentAdjustmentsTable(attachedDatabase, alias);
  }
}

class PaymentAdjustment extends DataClass
    implements Insertable<PaymentAdjustment> {
  final int id;
  final String uuid;
  final int paymentId;
  final int transactionId;
  final String type;
  final String status;
  final int amountMinor;
  final String reason;
  final int createdBy;
  final DateTime createdAt;
  const PaymentAdjustment({
    required this.id,
    required this.uuid,
    required this.paymentId,
    required this.transactionId,
    required this.type,
    required this.status,
    required this.amountMinor,
    required this.reason,
    required this.createdBy,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['payment_id'] = Variable<int>(paymentId);
    map['transaction_id'] = Variable<int>(transactionId);
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['reason'] = Variable<String>(reason);
    map['created_by'] = Variable<int>(createdBy);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PaymentAdjustmentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentAdjustmentsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      paymentId: Value(paymentId),
      transactionId: Value(transactionId),
      type: Value(type),
      status: Value(status),
      amountMinor: Value(amountMinor),
      reason: Value(reason),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
    );
  }

  factory PaymentAdjustment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentAdjustment(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      paymentId: serializer.fromJson<int>(json['paymentId']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      reason: serializer.fromJson<String>(json['reason']),
      createdBy: serializer.fromJson<int>(json['createdBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'paymentId': serializer.toJson<int>(paymentId),
      'transactionId': serializer.toJson<int>(transactionId),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'reason': serializer.toJson<String>(reason),
      'createdBy': serializer.toJson<int>(createdBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PaymentAdjustment copyWith({
    int? id,
    String? uuid,
    int? paymentId,
    int? transactionId,
    String? type,
    String? status,
    int? amountMinor,
    String? reason,
    int? createdBy,
    DateTime? createdAt,
  }) => PaymentAdjustment(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    paymentId: paymentId ?? this.paymentId,
    transactionId: transactionId ?? this.transactionId,
    type: type ?? this.type,
    status: status ?? this.status,
    amountMinor: amountMinor ?? this.amountMinor,
    reason: reason ?? this.reason,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
  );
  PaymentAdjustment copyWithCompanion(PaymentAdjustmentsCompanion data) {
    return PaymentAdjustment(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      paymentId: data.paymentId.present ? data.paymentId.value : this.paymentId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentAdjustment(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('paymentId: $paymentId, ')
          ..write('transactionId: $transactionId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('reason: $reason, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    paymentId,
    transactionId,
    type,
    status,
    amountMinor,
    reason,
    createdBy,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentAdjustment &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.paymentId == this.paymentId &&
          other.transactionId == this.transactionId &&
          other.type == this.type &&
          other.status == this.status &&
          other.amountMinor == this.amountMinor &&
          other.reason == this.reason &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt);
}

class PaymentAdjustmentsCompanion extends UpdateCompanion<PaymentAdjustment> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> paymentId;
  final Value<int> transactionId;
  final Value<String> type;
  final Value<String> status;
  final Value<int> amountMinor;
  final Value<String> reason;
  final Value<int> createdBy;
  final Value<DateTime> createdAt;
  const PaymentAdjustmentsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.paymentId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PaymentAdjustmentsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int paymentId,
    required int transactionId,
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    required int amountMinor,
    required String reason,
    required int createdBy,
    this.createdAt = const Value.absent(),
  }) : uuid = Value(uuid),
       paymentId = Value(paymentId),
       transactionId = Value(transactionId),
       amountMinor = Value(amountMinor),
       reason = Value(reason),
       createdBy = Value(createdBy);
  static Insertable<PaymentAdjustment> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? paymentId,
    Expression<int>? transactionId,
    Expression<String>? type,
    Expression<String>? status,
    Expression<int>? amountMinor,
    Expression<String>? reason,
    Expression<int>? createdBy,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (paymentId != null) 'payment_id': paymentId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (reason != null) 'reason': reason,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PaymentAdjustmentsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? paymentId,
    Value<int>? transactionId,
    Value<String>? type,
    Value<String>? status,
    Value<int>? amountMinor,
    Value<String>? reason,
    Value<int>? createdBy,
    Value<DateTime>? createdAt,
  }) {
    return PaymentAdjustmentsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      paymentId: paymentId ?? this.paymentId,
      transactionId: transactionId ?? this.transactionId,
      type: type ?? this.type,
      status: status ?? this.status,
      amountMinor: amountMinor ?? this.amountMinor,
      reason: reason ?? this.reason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (paymentId.present) {
      map['payment_id'] = Variable<int>(paymentId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentAdjustmentsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('paymentId: $paymentId, ')
          ..write('transactionId: $transactionId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('reason: $reason, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ShiftReconciliationsTable extends ShiftReconciliations
    with TableInfo<$ShiftReconciliationsTable, ShiftReconciliation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftReconciliationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<int> shiftId = GeneratedColumn<int>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "shifts" ("id")',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('final_close'),
  );
  static const VerificationMeta _expectedCashMinorMeta = const VerificationMeta(
    'expectedCashMinor',
  );
  @override
  late final GeneratedColumn<int> expectedCashMinor = GeneratedColumn<int>(
    'expected_cash_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countedCashMinorMeta = const VerificationMeta(
    'countedCashMinor',
  );
  @override
  late final GeneratedColumn<int> countedCashMinor = GeneratedColumn<int>(
    'counted_cash_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _varianceMinorMeta = const VerificationMeta(
    'varianceMinor',
  );
  @override
  late final GeneratedColumn<int> varianceMinor = GeneratedColumn<int>(
    'variance_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countedCashSourceMeta = const VerificationMeta(
    'countedCashSource',
  );
  @override
  late final GeneratedColumn<String> countedCashSource =
      GeneratedColumn<String>(
        'counted_cash_source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('entered'),
      );
  static const VerificationMeta _countedByMeta = const VerificationMeta(
    'countedBy',
  );
  @override
  late final GeneratedColumn<int> countedBy = GeneratedColumn<int>(
    'counted_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "users" ("id")',
  );
  static const VerificationMeta _countedAtMeta = const VerificationMeta(
    'countedAt',
  );
  @override
  late final GeneratedColumn<DateTime> countedAt = GeneratedColumn<DateTime>(
    'counted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    shiftId,
    kind,
    expectedCashMinor,
    countedCashMinor,
    varianceMinor,
    countedCashSource,
    countedBy,
    countedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shift_reconciliations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShiftReconciliation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shiftIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('expected_cash_minor')) {
      context.handle(
        _expectedCashMinorMeta,
        expectedCashMinor.isAcceptableOrUnknown(
          data['expected_cash_minor']!,
          _expectedCashMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedCashMinorMeta);
    }
    if (data.containsKey('counted_cash_minor')) {
      context.handle(
        _countedCashMinorMeta,
        countedCashMinor.isAcceptableOrUnknown(
          data['counted_cash_minor']!,
          _countedCashMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countedCashMinorMeta);
    }
    if (data.containsKey('variance_minor')) {
      context.handle(
        _varianceMinorMeta,
        varianceMinor.isAcceptableOrUnknown(
          data['variance_minor']!,
          _varianceMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_varianceMinorMeta);
    }
    if (data.containsKey('counted_cash_source')) {
      context.handle(
        _countedCashSourceMeta,
        countedCashSource.isAcceptableOrUnknown(
          data['counted_cash_source']!,
          _countedCashSourceMeta,
        ),
      );
    }
    if (data.containsKey('counted_by')) {
      context.handle(
        _countedByMeta,
        countedBy.isAcceptableOrUnknown(data['counted_by']!, _countedByMeta),
      );
    } else if (isInserting) {
      context.missing(_countedByMeta);
    }
    if (data.containsKey('counted_at')) {
      context.handle(
        _countedAtMeta,
        countedAt.isAcceptableOrUnknown(data['counted_at']!, _countedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShiftReconciliation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftReconciliation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shift_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      expectedCashMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_cash_minor'],
      )!,
      countedCashMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_cash_minor'],
      )!,
      varianceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}variance_minor'],
      )!,
      countedCashSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counted_cash_source'],
      )!,
      countedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_by'],
      )!,
      countedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}counted_at'],
      )!,
    );
  }

  @override
  $ShiftReconciliationsTable createAlias(String alias) {
    return $ShiftReconciliationsTable(attachedDatabase, alias);
  }
}

class ShiftReconciliation extends DataClass
    implements Insertable<ShiftReconciliation> {
  final int id;
  final String uuid;
  final int shiftId;
  final String kind;
  final int expectedCashMinor;
  final int countedCashMinor;
  final int varianceMinor;
  final String countedCashSource;
  final int countedBy;
  final DateTime countedAt;
  const ShiftReconciliation({
    required this.id,
    required this.uuid,
    required this.shiftId,
    required this.kind,
    required this.expectedCashMinor,
    required this.countedCashMinor,
    required this.varianceMinor,
    required this.countedCashSource,
    required this.countedBy,
    required this.countedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['shift_id'] = Variable<int>(shiftId);
    map['kind'] = Variable<String>(kind);
    map['expected_cash_minor'] = Variable<int>(expectedCashMinor);
    map['counted_cash_minor'] = Variable<int>(countedCashMinor);
    map['variance_minor'] = Variable<int>(varianceMinor);
    map['counted_cash_source'] = Variable<String>(countedCashSource);
    map['counted_by'] = Variable<int>(countedBy);
    map['counted_at'] = Variable<DateTime>(countedAt);
    return map;
  }

  ShiftReconciliationsCompanion toCompanion(bool nullToAbsent) {
    return ShiftReconciliationsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      shiftId: Value(shiftId),
      kind: Value(kind),
      expectedCashMinor: Value(expectedCashMinor),
      countedCashMinor: Value(countedCashMinor),
      varianceMinor: Value(varianceMinor),
      countedCashSource: Value(countedCashSource),
      countedBy: Value(countedBy),
      countedAt: Value(countedAt),
    );
  }

  factory ShiftReconciliation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftReconciliation(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      shiftId: serializer.fromJson<int>(json['shiftId']),
      kind: serializer.fromJson<String>(json['kind']),
      expectedCashMinor: serializer.fromJson<int>(json['expectedCashMinor']),
      countedCashMinor: serializer.fromJson<int>(json['countedCashMinor']),
      varianceMinor: serializer.fromJson<int>(json['varianceMinor']),
      countedCashSource: serializer.fromJson<String>(json['countedCashSource']),
      countedBy: serializer.fromJson<int>(json['countedBy']),
      countedAt: serializer.fromJson<DateTime>(json['countedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'shiftId': serializer.toJson<int>(shiftId),
      'kind': serializer.toJson<String>(kind),
      'expectedCashMinor': serializer.toJson<int>(expectedCashMinor),
      'countedCashMinor': serializer.toJson<int>(countedCashMinor),
      'varianceMinor': serializer.toJson<int>(varianceMinor),
      'countedCashSource': serializer.toJson<String>(countedCashSource),
      'countedBy': serializer.toJson<int>(countedBy),
      'countedAt': serializer.toJson<DateTime>(countedAt),
    };
  }

  ShiftReconciliation copyWith({
    int? id,
    String? uuid,
    int? shiftId,
    String? kind,
    int? expectedCashMinor,
    int? countedCashMinor,
    int? varianceMinor,
    String? countedCashSource,
    int? countedBy,
    DateTime? countedAt,
  }) => ShiftReconciliation(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    shiftId: shiftId ?? this.shiftId,
    kind: kind ?? this.kind,
    expectedCashMinor: expectedCashMinor ?? this.expectedCashMinor,
    countedCashMinor: countedCashMinor ?? this.countedCashMinor,
    varianceMinor: varianceMinor ?? this.varianceMinor,
    countedCashSource: countedCashSource ?? this.countedCashSource,
    countedBy: countedBy ?? this.countedBy,
    countedAt: countedAt ?? this.countedAt,
  );
  ShiftReconciliation copyWithCompanion(ShiftReconciliationsCompanion data) {
    return ShiftReconciliation(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      kind: data.kind.present ? data.kind.value : this.kind,
      expectedCashMinor: data.expectedCashMinor.present
          ? data.expectedCashMinor.value
          : this.expectedCashMinor,
      countedCashMinor: data.countedCashMinor.present
          ? data.countedCashMinor.value
          : this.countedCashMinor,
      varianceMinor: data.varianceMinor.present
          ? data.varianceMinor.value
          : this.varianceMinor,
      countedCashSource: data.countedCashSource.present
          ? data.countedCashSource.value
          : this.countedCashSource,
      countedBy: data.countedBy.present ? data.countedBy.value : this.countedBy,
      countedAt: data.countedAt.present ? data.countedAt.value : this.countedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftReconciliation(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('shiftId: $shiftId, ')
          ..write('kind: $kind, ')
          ..write('expectedCashMinor: $expectedCashMinor, ')
          ..write('countedCashMinor: $countedCashMinor, ')
          ..write('varianceMinor: $varianceMinor, ')
          ..write('countedCashSource: $countedCashSource, ')
          ..write('countedBy: $countedBy, ')
          ..write('countedAt: $countedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    shiftId,
    kind,
    expectedCashMinor,
    countedCashMinor,
    varianceMinor,
    countedCashSource,
    countedBy,
    countedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftReconciliation &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.shiftId == this.shiftId &&
          other.kind == this.kind &&
          other.expectedCashMinor == this.expectedCashMinor &&
          other.countedCashMinor == this.countedCashMinor &&
          other.varianceMinor == this.varianceMinor &&
          other.countedCashSource == this.countedCashSource &&
          other.countedBy == this.countedBy &&
          other.countedAt == this.countedAt);
}

class ShiftReconciliationsCompanion
    extends UpdateCompanion<ShiftReconciliation> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> shiftId;
  final Value<String> kind;
  final Value<int> expectedCashMinor;
  final Value<int> countedCashMinor;
  final Value<int> varianceMinor;
  final Value<String> countedCashSource;
  final Value<int> countedBy;
  final Value<DateTime> countedAt;
  const ShiftReconciliationsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.kind = const Value.absent(),
    this.expectedCashMinor = const Value.absent(),
    this.countedCashMinor = const Value.absent(),
    this.varianceMinor = const Value.absent(),
    this.countedCashSource = const Value.absent(),
    this.countedBy = const Value.absent(),
    this.countedAt = const Value.absent(),
  });
  ShiftReconciliationsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int shiftId,
    this.kind = const Value.absent(),
    required int expectedCashMinor,
    required int countedCashMinor,
    required int varianceMinor,
    this.countedCashSource = const Value.absent(),
    required int countedBy,
    this.countedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       shiftId = Value(shiftId),
       expectedCashMinor = Value(expectedCashMinor),
       countedCashMinor = Value(countedCashMinor),
       varianceMinor = Value(varianceMinor),
       countedBy = Value(countedBy);
  static Insertable<ShiftReconciliation> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? shiftId,
    Expression<String>? kind,
    Expression<int>? expectedCashMinor,
    Expression<int>? countedCashMinor,
    Expression<int>? varianceMinor,
    Expression<String>? countedCashSource,
    Expression<int>? countedBy,
    Expression<DateTime>? countedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (shiftId != null) 'shift_id': shiftId,
      if (kind != null) 'kind': kind,
      if (expectedCashMinor != null) 'expected_cash_minor': expectedCashMinor,
      if (countedCashMinor != null) 'counted_cash_minor': countedCashMinor,
      if (varianceMinor != null) 'variance_minor': varianceMinor,
      if (countedCashSource != null) 'counted_cash_source': countedCashSource,
      if (countedBy != null) 'counted_by': countedBy,
      if (countedAt != null) 'counted_at': countedAt,
    });
  }

  ShiftReconciliationsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? shiftId,
    Value<String>? kind,
    Value<int>? expectedCashMinor,
    Value<int>? countedCashMinor,
    Value<int>? varianceMinor,
    Value<String>? countedCashSource,
    Value<int>? countedBy,
    Value<DateTime>? countedAt,
  }) {
    return ShiftReconciliationsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      shiftId: shiftId ?? this.shiftId,
      kind: kind ?? this.kind,
      expectedCashMinor: expectedCashMinor ?? this.expectedCashMinor,
      countedCashMinor: countedCashMinor ?? this.countedCashMinor,
      varianceMinor: varianceMinor ?? this.varianceMinor,
      countedCashSource: countedCashSource ?? this.countedCashSource,
      countedBy: countedBy ?? this.countedBy,
      countedAt: countedAt ?? this.countedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<int>(shiftId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (expectedCashMinor.present) {
      map['expected_cash_minor'] = Variable<int>(expectedCashMinor.value);
    }
    if (countedCashMinor.present) {
      map['counted_cash_minor'] = Variable<int>(countedCashMinor.value);
    }
    if (varianceMinor.present) {
      map['variance_minor'] = Variable<int>(varianceMinor.value);
    }
    if (countedCashSource.present) {
      map['counted_cash_source'] = Variable<String>(countedCashSource.value);
    }
    if (countedBy.present) {
      map['counted_by'] = Variable<int>(countedBy.value);
    }
    if (countedAt.present) {
      map['counted_at'] = Variable<DateTime>(countedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftReconciliationsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('shiftId: $shiftId, ')
          ..write('kind: $kind, ')
          ..write('expectedCashMinor: $expectedCashMinor, ')
          ..write('countedCashMinor: $countedCashMinor, ')
          ..write('varianceMinor: $varianceMinor, ')
          ..write('countedCashSource: $countedCashSource, ')
          ..write('countedBy: $countedBy, ')
          ..write('countedAt: $countedAt')
          ..write(')'))
        .toString();
  }
}

class $CashMovementsTable extends CashMovements
    with TableInfo<$CashMovementsTable, CashMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CashMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<int> shiftId = GeneratedColumn<int>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "shifts" ("id")',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByUserIdMeta = const VerificationMeta(
    'createdByUserId',
  );
  @override
  late final GeneratedColumn<int> createdByUserId = GeneratedColumn<int>(
    'created_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "users" ("id")',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shiftId,
    type,
    category,
    amountMinor,
    paymentMethod,
    note,
    createdByUserId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cash_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<CashMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shiftIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_by_user_id')) {
      context.handle(
        _createdByUserIdMeta,
        createdByUserId.isAcceptableOrUnknown(
          data['created_by_user_id']!,
          _createdByUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByUserIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CashMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CashMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shift_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by_user_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CashMovementsTable createAlias(String alias) {
    return $CashMovementsTable(attachedDatabase, alias);
  }
}

class CashMovement extends DataClass implements Insertable<CashMovement> {
  final int id;
  final int shiftId;
  final String type;
  final String category;
  final int amountMinor;
  final String paymentMethod;
  final String? note;
  final int createdByUserId;
  final DateTime createdAt;
  const CashMovement({
    required this.id,
    required this.shiftId,
    required this.type,
    required this.category,
    required this.amountMinor,
    required this.paymentMethod,
    this.note,
    required this.createdByUserId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['shift_id'] = Variable<int>(shiftId);
    map['type'] = Variable<String>(type);
    map['category'] = Variable<String>(category);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['payment_method'] = Variable<String>(paymentMethod);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_by_user_id'] = Variable<int>(createdByUserId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CashMovementsCompanion toCompanion(bool nullToAbsent) {
    return CashMovementsCompanion(
      id: Value(id),
      shiftId: Value(shiftId),
      type: Value(type),
      category: Value(category),
      amountMinor: Value(amountMinor),
      paymentMethod: Value(paymentMethod),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdByUserId: Value(createdByUserId),
      createdAt: Value(createdAt),
    );
  }

  factory CashMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CashMovement(
      id: serializer.fromJson<int>(json['id']),
      shiftId: serializer.fromJson<int>(json['shiftId']),
      type: serializer.fromJson<String>(json['type']),
      category: serializer.fromJson<String>(json['category']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      note: serializer.fromJson<String?>(json['note']),
      createdByUserId: serializer.fromJson<int>(json['createdByUserId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shiftId': serializer.toJson<int>(shiftId),
      'type': serializer.toJson<String>(type),
      'category': serializer.toJson<String>(category),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'note': serializer.toJson<String?>(note),
      'createdByUserId': serializer.toJson<int>(createdByUserId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CashMovement copyWith({
    int? id,
    int? shiftId,
    String? type,
    String? category,
    int? amountMinor,
    String? paymentMethod,
    Value<String?> note = const Value.absent(),
    int? createdByUserId,
    DateTime? createdAt,
  }) => CashMovement(
    id: id ?? this.id,
    shiftId: shiftId ?? this.shiftId,
    type: type ?? this.type,
    category: category ?? this.category,
    amountMinor: amountMinor ?? this.amountMinor,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    note: note.present ? note.value : this.note,
    createdByUserId: createdByUserId ?? this.createdByUserId,
    createdAt: createdAt ?? this.createdAt,
  );
  CashMovement copyWithCompanion(CashMovementsCompanion data) {
    return CashMovement(
      id: data.id.present ? data.id.value : this.id,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      type: data.type.present ? data.type.value : this.type,
      category: data.category.present ? data.category.value : this.category,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      note: data.note.present ? data.note.value : this.note,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CashMovement(')
          ..write('id: $id, ')
          ..write('shiftId: $shiftId, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('note: $note, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shiftId,
    type,
    category,
    amountMinor,
    paymentMethod,
    note,
    createdByUserId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CashMovement &&
          other.id == this.id &&
          other.shiftId == this.shiftId &&
          other.type == this.type &&
          other.category == this.category &&
          other.amountMinor == this.amountMinor &&
          other.paymentMethod == this.paymentMethod &&
          other.note == this.note &&
          other.createdByUserId == this.createdByUserId &&
          other.createdAt == this.createdAt);
}

class CashMovementsCompanion extends UpdateCompanion<CashMovement> {
  final Value<int> id;
  final Value<int> shiftId;
  final Value<String> type;
  final Value<String> category;
  final Value<int> amountMinor;
  final Value<String> paymentMethod;
  final Value<String?> note;
  final Value<int> createdByUserId;
  final Value<DateTime> createdAt;
  const CashMovementsCompanion({
    this.id = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.type = const Value.absent(),
    this.category = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.note = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CashMovementsCompanion.insert({
    this.id = const Value.absent(),
    required int shiftId,
    required String type,
    required String category,
    required int amountMinor,
    required String paymentMethod,
    this.note = const Value.absent(),
    required int createdByUserId,
    this.createdAt = const Value.absent(),
  }) : shiftId = Value(shiftId),
       type = Value(type),
       category = Value(category),
       amountMinor = Value(amountMinor),
       paymentMethod = Value(paymentMethod),
       createdByUserId = Value(createdByUserId);
  static Insertable<CashMovement> custom({
    Expression<int>? id,
    Expression<int>? shiftId,
    Expression<String>? type,
    Expression<String>? category,
    Expression<int>? amountMinor,
    Expression<String>? paymentMethod,
    Expression<String>? note,
    Expression<int>? createdByUserId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shiftId != null) 'shift_id': shiftId,
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (note != null) 'note': note,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CashMovementsCompanion copyWith({
    Value<int>? id,
    Value<int>? shiftId,
    Value<String>? type,
    Value<String>? category,
    Value<int>? amountMinor,
    Value<String>? paymentMethod,
    Value<String?>? note,
    Value<int>? createdByUserId,
    Value<DateTime>? createdAt,
  }) {
    return CashMovementsCompanion(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      type: type ?? this.type,
      category: category ?? this.category,
      amountMinor: amountMinor ?? this.amountMinor,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<int>(shiftId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<int>(createdByUserId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CashMovementsCompanion(')
          ..write('id: $id, ')
          ..write('shiftId: $shiftId, ')
          ..write('type: $type, ')
          ..write('category: $category, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('note: $note, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<int> actorUserId = GeneratedColumn<int>(
    'actor_user_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "users" ("id")',
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    actorUserId,
    action,
    entityType,
    entityId,
    metadataJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorUserIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_metadataJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actor_user_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLog extends DataClass implements Insertable<AuditLog> {
  final int id;
  final int actorUserId;
  final String action;
  final String entityType;
  final String entityId;
  final String metadataJson;
  final DateTime createdAt;
  const AuditLog({
    required this.id,
    required this.actorUserId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.metadataJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['actor_user_id'] = Variable<int>(actorUserId);
    map['action'] = Variable<String>(action);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['metadata_json'] = Variable<String>(metadataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      actorUserId: Value(actorUserId),
      action: Value(action),
      entityType: Value(entityType),
      entityId: Value(entityId),
      metadataJson: Value(metadataJson),
      createdAt: Value(createdAt),
    );
  }

  factory AuditLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLog(
      id: serializer.fromJson<int>(json['id']),
      actorUserId: serializer.fromJson<int>(json['actorUserId']),
      action: serializer.fromJson<String>(json['action']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'actorUserId': serializer.toJson<int>(actorUserId),
      'action': serializer.toJson<String>(action),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AuditLog copyWith({
    int? id,
    int? actorUserId,
    String? action,
    String? entityType,
    String? entityId,
    String? metadataJson,
    DateTime? createdAt,
  }) => AuditLog(
    id: id ?? this.id,
    actorUserId: actorUserId ?? this.actorUserId,
    action: action ?? this.action,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    metadataJson: metadataJson ?? this.metadataJson,
    createdAt: createdAt ?? this.createdAt,
  );
  AuditLog copyWithCompanion(AuditLogsCompanion data) {
    return AuditLog(
      id: data.id.present ? data.id.value : this.id,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      action: data.action.present ? data.action.value : this.action,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLog(')
          ..write('id: $id, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    actorUserId,
    action,
    entityType,
    entityId,
    metadataJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLog &&
          other.id == this.id &&
          other.actorUserId == this.actorUserId &&
          other.action == this.action &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLog> {
  final Value<int> id;
  final Value<int> actorUserId;
  final Value<String> action;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> metadataJson;
  final Value<DateTime> createdAt;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.action = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    this.id = const Value.absent(),
    required int actorUserId,
    required String action,
    required String entityType,
    required String entityId,
    required String metadataJson,
    this.createdAt = const Value.absent(),
  }) : actorUserId = Value(actorUserId),
       action = Value(action),
       entityType = Value(entityType),
       entityId = Value(entityId),
       metadataJson = Value(metadataJson);
  static Insertable<AuditLog> custom({
    Expression<int>? id,
    Expression<int>? actorUserId,
    Expression<String>? action,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (action != null) 'action': action,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AuditLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? actorUserId,
    Value<String>? action,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? metadataJson,
    Value<DateTime>? createdAt,
  }) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      actorUserId: actorUserId ?? this.actorUserId,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<int>(actorUserId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PrintJobsTable extends PrintJobs
    with TableInfo<$PrintJobsTable, PrintJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrintJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES "transactions" ("id")',
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionId,
    target,
    status,
    createdAt,
    updatedAt,
    attemptCount,
    lastAttemptAt,
    completedAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'print_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrintJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrintJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrintJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PrintJobsTable createAlias(String alias) {
    return $PrintJobsTable(attachedDatabase, alias);
  }
}

class PrintJob extends DataClass implements Insertable<PrintJob> {
  final int id;
  final int transactionId;
  final String target;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final String? lastError;
  const PrintJob({
    required this.id,
    required this.transactionId,
    required this.target,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.attemptCount,
    this.lastAttemptAt,
    this.completedAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_id'] = Variable<int>(transactionId);
    map['target'] = Variable<String>(target);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PrintJobsCompanion toCompanion(bool nullToAbsent) {
    return PrintJobsCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      target: Value(target),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      attemptCount: Value(attemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PrintJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrintJob(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      target: serializer.fromJson<String>(json['target']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<int>(transactionId),
      'target': serializer.toJson<String>(target),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PrintJob copyWith({
    int? id,
    int? transactionId,
    String? target,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? attemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => PrintJob(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    target: target ?? this.target,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    attemptCount: attemptCount ?? this.attemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PrintJob copyWithCompanion(PrintJobsCompanion data) {
    return PrintJob(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      target: data.target.present ? data.target.value : this.target,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrintJob(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('target: $target, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    target,
    status,
    createdAt,
    updatedAt,
    attemptCount,
    lastAttemptAt,
    completedAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrintJob &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.target == this.target &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.attemptCount == this.attemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.completedAt == this.completedAt &&
          other.lastError == this.lastError);
}

class PrintJobsCompanion extends UpdateCompanion<PrintJob> {
  final Value<int> id;
  final Value<int> transactionId;
  final Value<String> target;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> attemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> completedAt;
  final Value<String?> lastError;
  const PrintJobsCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.target = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PrintJobsCompanion.insert({
    this.id = const Value.absent(),
    required int transactionId,
    required String target,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : transactionId = Value(transactionId),
       target = Value(target);
  static Insertable<PrintJob> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<String>? target,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? attemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? completedAt,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (target != null) 'target': target,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PrintJobsCompanion copyWith({
    Value<int>? id,
    Value<int>? transactionId,
    Value<String>? target,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? attemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? completedAt,
    Value<String?>? lastError,
  }) {
    return PrintJobsCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      target: target ?? this.target,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      completedAt: completedAt ?? this.completedAt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrintJobsCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('target: $target, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $ReportSettingsTable extends ReportSettings
    with TableInfo<$ReportSettingsTable, ReportSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cashierReportModeMeta = const VerificationMeta(
    'cashierReportMode',
  );
  @override
  late final GeneratedColumn<String> cashierReportMode =
      GeneratedColumn<String>(
        'cashier_report_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('percentage'),
      );
  static const VerificationMeta _visibilityRatioMeta = const VerificationMeta(
    'visibilityRatio',
  );
  @override
  late final GeneratedColumn<double> visibilityRatio = GeneratedColumn<double>(
    'visibility_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _maxVisibleTotalMinorMeta =
      const VerificationMeta('maxVisibleTotalMinor');
  @override
  late final GeneratedColumn<int> maxVisibleTotalMinor = GeneratedColumn<int>(
    'max_visible_total_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _businessNameMeta = const VerificationMeta(
    'businessName',
  );
  @override
  late final GeneratedColumn<String> businessName = GeneratedColumn<String>(
    'business_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _businessAddressMeta = const VerificationMeta(
    'businessAddress',
  );
  @override
  late final GeneratedColumn<String> businessAddress = GeneratedColumn<String>(
    'business_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'REFERENCES "users" ("id")',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cashierReportMode,
    visibilityRatio,
    maxVisibleTotalMinor,
    businessName,
    businessAddress,
    updatedBy,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'report_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReportSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cashier_report_mode')) {
      context.handle(
        _cashierReportModeMeta,
        cashierReportMode.isAcceptableOrUnknown(
          data['cashier_report_mode']!,
          _cashierReportModeMeta,
        ),
      );
    }
    if (data.containsKey('visibility_ratio')) {
      context.handle(
        _visibilityRatioMeta,
        visibilityRatio.isAcceptableOrUnknown(
          data['visibility_ratio']!,
          _visibilityRatioMeta,
        ),
      );
    }
    if (data.containsKey('max_visible_total_minor')) {
      context.handle(
        _maxVisibleTotalMinorMeta,
        maxVisibleTotalMinor.isAcceptableOrUnknown(
          data['max_visible_total_minor']!,
          _maxVisibleTotalMinorMeta,
        ),
      );
    }
    if (data.containsKey('business_name')) {
      context.handle(
        _businessNameMeta,
        businessName.isAcceptableOrUnknown(
          data['business_name']!,
          _businessNameMeta,
        ),
      );
    }
    if (data.containsKey('business_address')) {
      context.handle(
        _businessAddressMeta,
        businessAddress.isAcceptableOrUnknown(
          data['business_address']!,
          _businessAddressMeta,
        ),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReportSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReportSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cashierReportMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cashier_report_mode'],
      )!,
      visibilityRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}visibility_ratio'],
      )!,
      maxVisibleTotalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_visible_total_minor'],
      ),
      businessName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_name'],
      ),
      businessAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_address'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReportSettingsTable createAlias(String alias) {
    return $ReportSettingsTable(attachedDatabase, alias);
  }
}

class ReportSetting extends DataClass implements Insertable<ReportSetting> {
  final int id;
  final String cashierReportMode;
  final double visibilityRatio;
  final int? maxVisibleTotalMinor;
  final String? businessName;
  final String? businessAddress;
  final int? updatedBy;
  final DateTime updatedAt;
  const ReportSetting({
    required this.id,
    required this.cashierReportMode,
    required this.visibilityRatio,
    this.maxVisibleTotalMinor,
    this.businessName,
    this.businessAddress,
    this.updatedBy,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cashier_report_mode'] = Variable<String>(cashierReportMode);
    map['visibility_ratio'] = Variable<double>(visibilityRatio);
    if (!nullToAbsent || maxVisibleTotalMinor != null) {
      map['max_visible_total_minor'] = Variable<int>(maxVisibleTotalMinor);
    }
    if (!nullToAbsent || businessName != null) {
      map['business_name'] = Variable<String>(businessName);
    }
    if (!nullToAbsent || businessAddress != null) {
      map['business_address'] = Variable<String>(businessAddress);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReportSettingsCompanion toCompanion(bool nullToAbsent) {
    return ReportSettingsCompanion(
      id: Value(id),
      cashierReportMode: Value(cashierReportMode),
      visibilityRatio: Value(visibilityRatio),
      maxVisibleTotalMinor: maxVisibleTotalMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(maxVisibleTotalMinor),
      businessName: businessName == null && nullToAbsent
          ? const Value.absent()
          : Value(businessName),
      businessAddress: businessAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(businessAddress),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReportSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReportSetting(
      id: serializer.fromJson<int>(json['id']),
      cashierReportMode: serializer.fromJson<String>(json['cashierReportMode']),
      visibilityRatio: serializer.fromJson<double>(json['visibilityRatio']),
      maxVisibleTotalMinor: serializer.fromJson<int?>(
        json['maxVisibleTotalMinor'],
      ),
      businessName: serializer.fromJson<String?>(json['businessName']),
      businessAddress: serializer.fromJson<String?>(json['businessAddress']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cashierReportMode': serializer.toJson<String>(cashierReportMode),
      'visibilityRatio': serializer.toJson<double>(visibilityRatio),
      'maxVisibleTotalMinor': serializer.toJson<int?>(maxVisibleTotalMinor),
      'businessName': serializer.toJson<String?>(businessName),
      'businessAddress': serializer.toJson<String?>(businessAddress),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReportSetting copyWith({
    int? id,
    String? cashierReportMode,
    double? visibilityRatio,
    Value<int?> maxVisibleTotalMinor = const Value.absent(),
    Value<String?> businessName = const Value.absent(),
    Value<String?> businessAddress = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    DateTime? updatedAt,
  }) => ReportSetting(
    id: id ?? this.id,
    cashierReportMode: cashierReportMode ?? this.cashierReportMode,
    visibilityRatio: visibilityRatio ?? this.visibilityRatio,
    maxVisibleTotalMinor: maxVisibleTotalMinor.present
        ? maxVisibleTotalMinor.value
        : this.maxVisibleTotalMinor,
    businessName: businessName.present ? businessName.value : this.businessName,
    businessAddress: businessAddress.present
        ? businessAddress.value
        : this.businessAddress,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReportSetting copyWithCompanion(ReportSettingsCompanion data) {
    return ReportSetting(
      id: data.id.present ? data.id.value : this.id,
      cashierReportMode: data.cashierReportMode.present
          ? data.cashierReportMode.value
          : this.cashierReportMode,
      visibilityRatio: data.visibilityRatio.present
          ? data.visibilityRatio.value
          : this.visibilityRatio,
      maxVisibleTotalMinor: data.maxVisibleTotalMinor.present
          ? data.maxVisibleTotalMinor.value
          : this.maxVisibleTotalMinor,
      businessName: data.businessName.present
          ? data.businessName.value
          : this.businessName,
      businessAddress: data.businessAddress.present
          ? data.businessAddress.value
          : this.businessAddress,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReportSetting(')
          ..write('id: $id, ')
          ..write('cashierReportMode: $cashierReportMode, ')
          ..write('visibilityRatio: $visibilityRatio, ')
          ..write('maxVisibleTotalMinor: $maxVisibleTotalMinor, ')
          ..write('businessName: $businessName, ')
          ..write('businessAddress: $businessAddress, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cashierReportMode,
    visibilityRatio,
    maxVisibleTotalMinor,
    businessName,
    businessAddress,
    updatedBy,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportSetting &&
          other.id == this.id &&
          other.cashierReportMode == this.cashierReportMode &&
          other.visibilityRatio == this.visibilityRatio &&
          other.maxVisibleTotalMinor == this.maxVisibleTotalMinor &&
          other.businessName == this.businessName &&
          other.businessAddress == this.businessAddress &&
          other.updatedBy == this.updatedBy &&
          other.updatedAt == this.updatedAt);
}

class ReportSettingsCompanion extends UpdateCompanion<ReportSetting> {
  final Value<int> id;
  final Value<String> cashierReportMode;
  final Value<double> visibilityRatio;
  final Value<int?> maxVisibleTotalMinor;
  final Value<String?> businessName;
  final Value<String?> businessAddress;
  final Value<int?> updatedBy;
  final Value<DateTime> updatedAt;
  const ReportSettingsCompanion({
    this.id = const Value.absent(),
    this.cashierReportMode = const Value.absent(),
    this.visibilityRatio = const Value.absent(),
    this.maxVisibleTotalMinor = const Value.absent(),
    this.businessName = const Value.absent(),
    this.businessAddress = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReportSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.cashierReportMode = const Value.absent(),
    this.visibilityRatio = const Value.absent(),
    this.maxVisibleTotalMinor = const Value.absent(),
    this.businessName = const Value.absent(),
    this.businessAddress = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<ReportSetting> custom({
    Expression<int>? id,
    Expression<String>? cashierReportMode,
    Expression<double>? visibilityRatio,
    Expression<int>? maxVisibleTotalMinor,
    Expression<String>? businessName,
    Expression<String>? businessAddress,
    Expression<int>? updatedBy,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cashierReportMode != null) 'cashier_report_mode': cashierReportMode,
      if (visibilityRatio != null) 'visibility_ratio': visibilityRatio,
      if (maxVisibleTotalMinor != null)
        'max_visible_total_minor': maxVisibleTotalMinor,
      if (businessName != null) 'business_name': businessName,
      if (businessAddress != null) 'business_address': businessAddress,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReportSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? cashierReportMode,
    Value<double>? visibilityRatio,
    Value<int?>? maxVisibleTotalMinor,
    Value<String?>? businessName,
    Value<String?>? businessAddress,
    Value<int?>? updatedBy,
    Value<DateTime>? updatedAt,
  }) {
    return ReportSettingsCompanion(
      id: id ?? this.id,
      cashierReportMode: cashierReportMode ?? this.cashierReportMode,
      visibilityRatio: visibilityRatio ?? this.visibilityRatio,
      maxVisibleTotalMinor: maxVisibleTotalMinor ?? this.maxVisibleTotalMinor,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cashierReportMode.present) {
      map['cashier_report_mode'] = Variable<String>(cashierReportMode.value);
    }
    if (visibilityRatio.present) {
      map['visibility_ratio'] = Variable<double>(visibilityRatio.value);
    }
    if (maxVisibleTotalMinor.present) {
      map['max_visible_total_minor'] = Variable<int>(
        maxVisibleTotalMinor.value,
      );
    }
    if (businessName.present) {
      map['business_name'] = Variable<String>(businessName.value);
    }
    if (businessAddress.present) {
      map['business_address'] = Variable<String>(businessAddress.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportSettingsCompanion(')
          ..write('id: $id, ')
          ..write('cashierReportMode: $cashierReportMode, ')
          ..write('visibilityRatio: $visibilityRatio, ')
          ..write('maxVisibleTotalMinor: $maxVisibleTotalMinor, ')
          ..write('businessName: $businessName, ')
          ..write('businessAddress: $businessAddress, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PrinterSettingsTable extends PrinterSettings
    with TableInfo<$PrinterSettingsTable, PrinterSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrinterSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceAddressMeta = const VerificationMeta(
    'deviceAddress',
  );
  @override
  late final GeneratedColumn<String> deviceAddress = GeneratedColumn<String>(
    'device_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paperWidthMeta = const VerificationMeta(
    'paperWidth',
  );
  @override
  late final GeneratedColumn<int> paperWidth = GeneratedColumn<int>(
    'paper_width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(80),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceName,
    deviceAddress,
    paperWidth,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'printer_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrinterSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceNameMeta);
    }
    if (data.containsKey('device_address')) {
      context.handle(
        _deviceAddressMeta,
        deviceAddress.isAcceptableOrUnknown(
          data['device_address']!,
          _deviceAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceAddressMeta);
    }
    if (data.containsKey('paper_width')) {
      context.handle(
        _paperWidthMeta,
        paperWidth.isAcceptableOrUnknown(data['paper_width']!, _paperWidthMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrinterSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrinterSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      )!,
      deviceAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_address'],
      )!,
      paperWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paper_width'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $PrinterSettingsTable createAlias(String alias) {
    return $PrinterSettingsTable(attachedDatabase, alias);
  }
}

class PrinterSetting extends DataClass implements Insertable<PrinterSetting> {
  final int id;
  final String deviceName;
  final String deviceAddress;
  final int paperWidth;
  final bool isActive;
  const PrinterSetting({
    required this.id,
    required this.deviceName,
    required this.deviceAddress,
    required this.paperWidth,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_name'] = Variable<String>(deviceName);
    map['device_address'] = Variable<String>(deviceAddress);
    map['paper_width'] = Variable<int>(paperWidth);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  PrinterSettingsCompanion toCompanion(bool nullToAbsent) {
    return PrinterSettingsCompanion(
      id: Value(id),
      deviceName: Value(deviceName),
      deviceAddress: Value(deviceAddress),
      paperWidth: Value(paperWidth),
      isActive: Value(isActive),
    );
  }

  factory PrinterSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrinterSetting(
      id: serializer.fromJson<int>(json['id']),
      deviceName: serializer.fromJson<String>(json['deviceName']),
      deviceAddress: serializer.fromJson<String>(json['deviceAddress']),
      paperWidth: serializer.fromJson<int>(json['paperWidth']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceName': serializer.toJson<String>(deviceName),
      'deviceAddress': serializer.toJson<String>(deviceAddress),
      'paperWidth': serializer.toJson<int>(paperWidth),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  PrinterSetting copyWith({
    int? id,
    String? deviceName,
    String? deviceAddress,
    int? paperWidth,
    bool? isActive,
  }) => PrinterSetting(
    id: id ?? this.id,
    deviceName: deviceName ?? this.deviceName,
    deviceAddress: deviceAddress ?? this.deviceAddress,
    paperWidth: paperWidth ?? this.paperWidth,
    isActive: isActive ?? this.isActive,
  );
  PrinterSetting copyWithCompanion(PrinterSettingsCompanion data) {
    return PrinterSetting(
      id: data.id.present ? data.id.value : this.id,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
      deviceAddress: data.deviceAddress.present
          ? data.deviceAddress.value
          : this.deviceAddress,
      paperWidth: data.paperWidth.present
          ? data.paperWidth.value
          : this.paperWidth,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrinterSetting(')
          ..write('id: $id, ')
          ..write('deviceName: $deviceName, ')
          ..write('deviceAddress: $deviceAddress, ')
          ..write('paperWidth: $paperWidth, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, deviceName, deviceAddress, paperWidth, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrinterSetting &&
          other.id == this.id &&
          other.deviceName == this.deviceName &&
          other.deviceAddress == this.deviceAddress &&
          other.paperWidth == this.paperWidth &&
          other.isActive == this.isActive);
}

class PrinterSettingsCompanion extends UpdateCompanion<PrinterSetting> {
  final Value<int> id;
  final Value<String> deviceName;
  final Value<String> deviceAddress;
  final Value<int> paperWidth;
  final Value<bool> isActive;
  const PrinterSettingsCompanion({
    this.id = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.deviceAddress = const Value.absent(),
    this.paperWidth = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  PrinterSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String deviceName,
    required String deviceAddress,
    this.paperWidth = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : deviceName = Value(deviceName),
       deviceAddress = Value(deviceAddress);
  static Insertable<PrinterSetting> custom({
    Expression<int>? id,
    Expression<String>? deviceName,
    Expression<String>? deviceAddress,
    Expression<int>? paperWidth,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceName != null) 'device_name': deviceName,
      if (deviceAddress != null) 'device_address': deviceAddress,
      if (paperWidth != null) 'paper_width': paperWidth,
      if (isActive != null) 'is_active': isActive,
    });
  }

  PrinterSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceName,
    Value<String>? deviceAddress,
    Value<int>? paperWidth,
    Value<bool>? isActive,
  }) {
    return PrinterSettingsCompanion(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      paperWidth: paperWidth ?? this.paperWidth,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (deviceAddress.present) {
      map['device_address'] = Variable<String>(deviceAddress.value);
    }
    if (paperWidth.present) {
      map['paper_width'] = Variable<int>(paperWidth.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrinterSettingsCompanion(')
          ..write('id: $id, ')
          ..write('deviceName: $deviceName, ')
          ..write('deviceAddress: $deviceAddress, ')
          ..write('paperWidth: $paperWidth, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _queueTableNameMeta = const VerificationMeta(
    'queueTableName',
  );
  @override
  late final GeneratedColumn<String> queueTableName = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordUuidMeta = const VerificationMeta(
    'recordUuid',
  );
  @override
  late final GeneratedColumn<String> recordUuid = GeneratedColumn<String>(
    'record_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('upsert'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    queueTableName,
    recordUuid,
    operation,
    createdAt,
    status,
    attemptCount,
    lastAttemptAt,
    syncedAt,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _queueTableNameMeta,
        queueTableName.isAcceptableOrUnknown(
          data['table_name']!,
          _queueTableNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_queueTableNameMeta);
    }
    if (data.containsKey('record_uuid')) {
      context.handle(
        _recordUuidMeta,
        recordUuid.isAcceptableOrUnknown(data['record_uuid']!, _recordUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_recordUuidMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      queueTableName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      recordUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_uuid'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String queueTableName;
  final String recordUuid;
  final String operation;
  final DateTime createdAt;
  final String status;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime? syncedAt;
  final String? errorMessage;
  const SyncQueueData({
    required this.id,
    required this.queueTableName,
    required this.recordUuid,
    required this.operation,
    required this.createdAt,
    required this.status,
    required this.attemptCount,
    this.lastAttemptAt,
    this.syncedAt,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['table_name'] = Variable<String>(queueTableName);
    map['record_uuid'] = Variable<String>(recordUuid);
    map['operation'] = Variable<String>(operation);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      queueTableName: Value(queueTableName),
      recordUuid: Value(recordUuid),
      operation: Value(operation),
      createdAt: Value(createdAt),
      status: Value(status),
      attemptCount: Value(attemptCount),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      queueTableName: serializer.fromJson<String>(json['queueTableName']),
      recordUuid: serializer.fromJson<String>(json['recordUuid']),
      operation: serializer.fromJson<String>(json['operation']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'queueTableName': serializer.toJson<String>(queueTableName),
      'recordUuid': serializer.toJson<String>(recordUuid),
      'operation': serializer.toJson<String>(operation),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? queueTableName,
    String? recordUuid,
    String? operation,
    DateTime? createdAt,
    String? status,
    int? attemptCount,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
  }) => SyncQueueData(
    id: id ?? this.id,
    queueTableName: queueTableName ?? this.queueTableName,
    recordUuid: recordUuid ?? this.recordUuid,
    operation: operation ?? this.operation,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      queueTableName: data.queueTableName.present
          ? data.queueTableName.value
          : this.queueTableName,
      recordUuid: data.recordUuid.present
          ? data.recordUuid.value
          : this.recordUuid,
      operation: data.operation.present ? data.operation.value : this.operation,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('queueTableName: $queueTableName, ')
          ..write('recordUuid: $recordUuid, ')
          ..write('operation: $operation, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    queueTableName,
    recordUuid,
    operation,
    createdAt,
    status,
    attemptCount,
    lastAttemptAt,
    syncedAt,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.queueTableName == this.queueTableName &&
          other.recordUuid == this.recordUuid &&
          other.operation == this.operation &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.errorMessage == this.errorMessage);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> queueTableName;
  final Value<String> recordUuid;
  final Value<String> operation;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<String?> errorMessage;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.queueTableName = const Value.absent(),
    this.recordUuid = const Value.absent(),
    this.operation = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String queueTableName,
    required String recordUuid,
    this.operation = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
  }) : queueTableName = Value(queueTableName),
       recordUuid = Value(recordUuid);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? queueTableName,
    Expression<String>? recordUuid,
    Expression<String>? operation,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<String>? errorMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (queueTableName != null) 'table_name': queueTableName,
      if (recordUuid != null) 'record_uuid': recordUuid,
      if (operation != null) 'operation': operation,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? queueTableName,
    Value<String>? recordUuid,
    Value<String>? operation,
    Value<DateTime>? createdAt,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<String?>? errorMessage,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      queueTableName: queueTableName ?? this.queueTableName,
      recordUuid: recordUuid ?? this.recordUuid,
      operation: operation ?? this.operation,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (queueTableName.present) {
      map['table_name'] = Variable<String>(queueTableName.value);
    }
    if (recordUuid.present) {
      map['record_uuid'] = Variable<String>(recordUuid.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('queueTableName: $queueTableName, ')
          ..write('recordUuid: $recordUuid, ')
          ..write('operation: $operation, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $ProductModifiersTable productModifiers = $ProductModifiersTable(
    this,
  );
  late final $ShiftsTable shifts = $ShiftsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $TransactionLinesTable transactionLines = $TransactionLinesTable(
    this,
  );
  late final $OrderModifiersTable orderModifiers = $OrderModifiersTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  late final $PaymentAdjustmentsTable paymentAdjustments =
      $PaymentAdjustmentsTable(this);
  late final $ShiftReconciliationsTable shiftReconciliations =
      $ShiftReconciliationsTable(this);
  late final $CashMovementsTable cashMovements = $CashMovementsTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $PrintJobsTable printJobs = $PrintJobsTable(this);
  late final $ReportSettingsTable reportSettings = $ReportSettingsTable(this);
  late final $PrinterSettingsTable printerSettings = $PrinterSettingsTable(
    this,
  );
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    categories,
    products,
    productModifiers,
    shifts,
    transactions,
    transactionLines,
    orderModifiers,
    payments,
    paymentAdjustments,
    shiftReconciliations,
    cashMovements,
    auditLogs,
    printJobs,
    reportSettings,
    printerSettings,
    syncQueue,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> pin,
      Value<String?> password,
      required String role,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> pin,
      Value<String?> password,
      Value<String> role,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ShiftsTable, List<Shift>> _openedShiftsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.shifts,
    aliasName: $_aliasNameGenerator(db.users.id, db.shifts.openedBy),
  );

  $$ShiftsTableProcessedTableManager get openedShifts {
    final manager = $$ShiftsTableTableManager(
      $_db,
      $_db.shifts,
    ).filter((f) => f.openedBy.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_openedShiftsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShiftsTable, List<Shift>> _closedShiftsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.shifts,
    aliasName: $_aliasNameGenerator(db.users.id, db.shifts.closedBy),
  );

  $$ShiftsTableProcessedTableManager get closedShifts {
    final manager = $$ShiftsTableTableManager(
      $_db,
      $_db.shifts,
    ).filter((f) => f.closedBy.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_closedShiftsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShiftsTable, List<Shift>>
  _cashierPreviewedShiftsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.shifts,
        aliasName: $_aliasNameGenerator(
          db.users.id,
          db.shifts.cashierPreviewedBy,
        ),
      );

  $$ShiftsTableProcessedTableManager get cashierPreviewedShifts {
    final manager = $$ShiftsTableTableManager($_db, $_db.shifts).filter(
      (f) => f.cashierPreviewedBy.id.sqlEquals($_itemColumn<int>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(
      _cashierPreviewedShiftsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _createdTransactionsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: $_aliasNameGenerator(db.users.id, db.transactions.userId),
  );

  $$TransactionsTableProcessedTableManager get createdTransactions {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _createdTransactionsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _cancelledTransactionsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactions,
        aliasName: $_aliasNameGenerator(
          db.users.id,
          db.transactions.cancelledBy,
        ),
      );

  $$TransactionsTableProcessedTableManager get cancelledTransactions {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.cancelledBy.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cancelledTransactionsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentAdjustmentsTable, List<PaymentAdjustment>>
  _paymentAdjustmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.paymentAdjustments,
        aliasName: $_aliasNameGenerator(
          db.users.id,
          db.paymentAdjustments.createdBy,
        ),
      );

  $$PaymentAdjustmentsTableProcessedTableManager get paymentAdjustmentsRefs {
    final manager = $$PaymentAdjustmentsTableTableManager(
      $_db,
      $_db.paymentAdjustments,
    ).filter((f) => f.createdBy.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _paymentAdjustmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ShiftReconciliationsTable,
    List<ShiftReconciliation>
  >
  _shiftReconciliationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.shiftReconciliations,
        aliasName: $_aliasNameGenerator(
          db.users.id,
          db.shiftReconciliations.countedBy,
        ),
      );

  $$ShiftReconciliationsTableProcessedTableManager
  get shiftReconciliationsRefs {
    final manager = $$ShiftReconciliationsTableTableManager(
      $_db,
      $_db.shiftReconciliations,
    ).filter((f) => f.countedBy.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _shiftReconciliationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CashMovementsTable, List<CashMovement>>
  _cashMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cashMovements,
    aliasName: $_aliasNameGenerator(
      db.users.id,
      db.cashMovements.createdByUserId,
    ),
  );

  $$CashMovementsTableProcessedTableManager get cashMovementsRefs {
    final manager = $$CashMovementsTableTableManager(
      $_db,
      $_db.cashMovements,
    ).filter((f) => f.createdByUserId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cashMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AuditLogsTable, List<AuditLog>>
  _auditLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.auditLogs,
    aliasName: $_aliasNameGenerator(db.users.id, db.auditLogs.actorUserId),
  );

  $$AuditLogsTableProcessedTableManager get auditLogsRefs {
    final manager = $$AuditLogsTableTableManager(
      $_db,
      $_db.auditLogs,
    ).filter((f) => f.actorUserId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_auditLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReportSettingsTable, List<ReportSetting>>
  _reportSettingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reportSettings,
    aliasName: $_aliasNameGenerator(db.users.id, db.reportSettings.updatedBy),
  );

  $$ReportSettingsTableProcessedTableManager get reportSettingsRefs {
    final manager = $$ReportSettingsTableTableManager(
      $_db,
      $_db.reportSettings,
    ).filter((f) => f.updatedBy.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_reportSettingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pin => $composableBuilder(
    column: $table.pin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get password => $composableBuilder(
    column: $table.password,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> openedShifts(
    Expression<bool> Function($$ShiftsTableFilterComposer f) f,
  ) {
    final $$ShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.openedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableFilterComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> closedShifts(
    Expression<bool> Function($$ShiftsTableFilterComposer f) f,
  ) {
    final $$ShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.closedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableFilterComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cashierPreviewedShifts(
    Expression<bool> Function($$ShiftsTableFilterComposer f) f,
  ) {
    final $$ShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.cashierPreviewedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableFilterComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> createdTransactions(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cancelledTransactions(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.cancelledBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentAdjustmentsRefs(
    Expression<bool> Function($$PaymentAdjustmentsTableFilterComposer f) f,
  ) {
    final $$PaymentAdjustmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paymentAdjustments,
      getReferencedColumn: (t) => t.createdBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentAdjustmentsTableFilterComposer(
            $db: $db,
            $table: $db.paymentAdjustments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shiftReconciliationsRefs(
    Expression<bool> Function($$ShiftReconciliationsTableFilterComposer f) f,
  ) {
    final $$ShiftReconciliationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftReconciliations,
      getReferencedColumn: (t) => t.countedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftReconciliationsTableFilterComposer(
            $db: $db,
            $table: $db.shiftReconciliations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cashMovementsRefs(
    Expression<bool> Function($$CashMovementsTableFilterComposer f) f,
  ) {
    final $$CashMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cashMovements,
      getReferencedColumn: (t) => t.createdByUserId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CashMovementsTableFilterComposer(
            $db: $db,
            $table: $db.cashMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> auditLogsRefs(
    Expression<bool> Function($$AuditLogsTableFilterComposer f) f,
  ) {
    final $$AuditLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditLogs,
      getReferencedColumn: (t) => t.actorUserId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditLogsTableFilterComposer(
            $db: $db,
            $table: $db.auditLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reportSettingsRefs(
    Expression<bool> Function($$ReportSettingsTableFilterComposer f) f,
  ) {
    final $$ReportSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reportSettings,
      getReferencedColumn: (t) => t.updatedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportSettingsTableFilterComposer(
            $db: $db,
            $table: $db.reportSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pin => $composableBuilder(
    column: $table.pin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get password => $composableBuilder(
    column: $table.password,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get pin =>
      $composableBuilder(column: $table.pin, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> openedShifts<T extends Object>(
    Expression<T> Function($$ShiftsTableAnnotationComposer a) f,
  ) {
    final $$ShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.openedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> closedShifts<T extends Object>(
    Expression<T> Function($$ShiftsTableAnnotationComposer a) f,
  ) {
    final $$ShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.closedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cashierPreviewedShifts<T extends Object>(
    Expression<T> Function($$ShiftsTableAnnotationComposer a) f,
  ) {
    final $$ShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.cashierPreviewedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> createdTransactions<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cancelledTransactions<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.cancelledBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentAdjustmentsRefs<T extends Object>(
    Expression<T> Function($$PaymentAdjustmentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentAdjustmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.paymentAdjustments,
          getReferencedColumn: (t) => t.createdBy,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PaymentAdjustmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.paymentAdjustments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> shiftReconciliationsRefs<T extends Object>(
    Expression<T> Function($$ShiftReconciliationsTableAnnotationComposer a) f,
  ) {
    final $$ShiftReconciliationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.shiftReconciliations,
          getReferencedColumn: (t) => t.countedBy,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ShiftReconciliationsTableAnnotationComposer(
                $db: $db,
                $table: $db.shiftReconciliations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cashMovementsRefs<T extends Object>(
    Expression<T> Function($$CashMovementsTableAnnotationComposer a) f,
  ) {
    final $$CashMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cashMovements,
      getReferencedColumn: (t) => t.createdByUserId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CashMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.cashMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> auditLogsRefs<T extends Object>(
    Expression<T> Function($$AuditLogsTableAnnotationComposer a) f,
  ) {
    final $$AuditLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditLogs,
      getReferencedColumn: (t) => t.actorUserId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> reportSettingsRefs<T extends Object>(
    Expression<T> Function($$ReportSettingsTableAnnotationComposer a) f,
  ) {
    final $$ReportSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reportSettings,
      getReferencedColumn: (t) => t.updatedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReportSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.reportSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, $$UsersTableReferences),
          User,
          PrefetchHooks Function({
            bool openedShifts,
            bool closedShifts,
            bool cashierPreviewedShifts,
            bool createdTransactions,
            bool cancelledTransactions,
            bool paymentAdjustmentsRefs,
            bool shiftReconciliationsRefs,
            bool cashMovementsRefs,
            bool auditLogsRefs,
            bool reportSettingsRefs,
          })
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> pin = const Value.absent(),
                Value<String?> password = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                name: name,
                pin: pin,
                password: password,
                role: role,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> pin = const Value.absent(),
                Value<String?> password = const Value.absent(),
                required String role,
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                name: name,
                pin: pin,
                password: password,
                role: role,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$UsersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                openedShifts = false,
                closedShifts = false,
                cashierPreviewedShifts = false,
                createdTransactions = false,
                cancelledTransactions = false,
                paymentAdjustmentsRefs = false,
                shiftReconciliationsRefs = false,
                cashMovementsRefs = false,
                auditLogsRefs = false,
                reportSettingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (openedShifts) db.shifts,
                    if (closedShifts) db.shifts,
                    if (cashierPreviewedShifts) db.shifts,
                    if (createdTransactions) db.transactions,
                    if (cancelledTransactions) db.transactions,
                    if (paymentAdjustmentsRefs) db.paymentAdjustments,
                    if (shiftReconciliationsRefs) db.shiftReconciliations,
                    if (cashMovementsRefs) db.cashMovements,
                    if (auditLogsRefs) db.auditLogs,
                    if (reportSettingsRefs) db.reportSettings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (openedShifts)
                        await $_getPrefetchedData<User, $UsersTable, Shift>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._openedShiftsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).openedShifts,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.openedBy == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (closedShifts)
                        await $_getPrefetchedData<User, $UsersTable, Shift>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._closedShiftsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).closedShifts,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.closedBy == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cashierPreviewedShifts)
                        await $_getPrefetchedData<User, $UsersTable, Shift>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._cashierPreviewedShiftsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).cashierPreviewedShifts,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cashierPreviewedBy == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (createdTransactions)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._createdTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).createdTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cancelledTransactions)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._cancelledTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).cancelledTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cancelledBy == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (paymentAdjustmentsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          PaymentAdjustment
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._paymentAdjustmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentAdjustmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.createdBy == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shiftReconciliationsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          ShiftReconciliation
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._shiftReconciliationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).shiftReconciliationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.countedBy == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cashMovementsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          CashMovement
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._cashMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).cashMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.createdByUserId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (auditLogsRefs)
                        await $_getPrefetchedData<User, $UsersTable, AuditLog>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._auditLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).auditLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.actorUserId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (reportSettingsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          ReportSetting
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._reportSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).reportSettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.updatedBy == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, $$UsersTableReferences),
      User,
      PrefetchHooks Function({
        bool openedShifts,
        bool closedShifts,
        bool cashierPreviewedShifts,
        bool createdTransactions,
        bool cancelledTransactions,
        bool paymentAdjustmentsRefs,
        bool shiftReconciliationsRefs,
        bool cashMovementsRefs,
        bool auditLogsRefs,
        bool reportSettingsRefs,
      })
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> imageUrl,
      Value<int> sortOrder,
      Value<bool> isActive,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> imageUrl,
      Value<int> sortOrder,
      Value<bool> isActive,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProductsTable, List<Product>> _productsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.products,
    aliasName: $_aliasNameGenerator(db.categories.id, db.products.categoryId),
  );

  $$ProductsTableProcessedTableManager get productsRefs {
    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_productsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> productsRefs(
    Expression<bool> Function($$ProductsTableFilterComposer f) f,
  ) {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> productsRefs<T extends Object>(
    Expression<T> Function($$ProductsTableAnnotationComposer a) f,
  ) {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool productsRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                imageUrl: imageUrl,
                sortOrder: sortOrder,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> imageUrl = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                imageUrl: imageUrl,
                sortOrder: sortOrder,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (productsRefs) db.products],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (productsRefs)
                    await $_getPrefetchedData<
                      Category,
                      $CategoriesTable,
                      Product
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._productsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).productsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool productsRefs})
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      required int categoryId,
      required String name,
      required int priceMinor,
      Value<String?> imageUrl,
      Value<bool> hasModifiers,
      Value<bool> isActive,
      Value<bool> isVisibleOnPos,
      Value<int> sortOrder,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      Value<int> categoryId,
      Value<String> name,
      Value<int> priceMinor,
      Value<String?> imageUrl,
      Value<bool> hasModifiers,
      Value<bool> isActive,
      Value<bool> isVisibleOnPos,
      Value<int> sortOrder,
    });

final class $$ProductsTableReferences
    extends BaseReferences<_$AppDatabase, $ProductsTable, Product> {
  $$ProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.products.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ProductModifiersTable, List<ProductModifier>>
  _productModifiersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productModifiers,
    aliasName: $_aliasNameGenerator(
      db.products.id,
      db.productModifiers.productId,
    ),
  );

  $$ProductModifiersTableProcessedTableManager get productModifiersRefs {
    final manager = $$ProductModifiersTableTableManager(
      $_db,
      $_db.productModifiers,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _productModifiersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionLinesTable, List<TransactionLine>>
  _transactionLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactionLines,
    aliasName: $_aliasNameGenerator(
      db.products.id,
      db.transactionLines.productId,
    ),
  );

  $$TransactionLinesTableProcessedTableManager get transactionLinesRefs {
    final manager = $$TransactionLinesTableTableManager(
      $_db,
      $_db.transactionLines,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceMinor => $composableBuilder(
    column: $table.priceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasModifiers => $composableBuilder(
    column: $table.hasModifiers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVisibleOnPos => $composableBuilder(
    column: $table.isVisibleOnPos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> productModifiersRefs(
    Expression<bool> Function($$ProductModifiersTableFilterComposer f) f,
  ) {
    final $$ProductModifiersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productModifiers,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductModifiersTableFilterComposer(
            $db: $db,
            $table: $db.productModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionLinesRefs(
    Expression<bool> Function($$TransactionLinesTableFilterComposer f) f,
  ) {
    final $$TransactionLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionLines,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionLinesTableFilterComposer(
            $db: $db,
            $table: $db.transactionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceMinor => $composableBuilder(
    column: $table.priceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasModifiers => $composableBuilder(
    column: $table.hasModifiers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVisibleOnPos => $composableBuilder(
    column: $table.isVisibleOnPos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get priceMinor => $composableBuilder(
    column: $table.priceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<bool> get hasModifiers => $composableBuilder(
    column: $table.hasModifiers,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get isVisibleOnPos => $composableBuilder(
    column: $table.isVisibleOnPos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> productModifiersRefs<T extends Object>(
    Expression<T> Function($$ProductModifiersTableAnnotationComposer a) f,
  ) {
    final $$ProductModifiersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productModifiers,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductModifiersTableAnnotationComposer(
            $db: $db,
            $table: $db.productModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionLinesRefs<T extends Object>(
    Expression<T> Function($$TransactionLinesTableAnnotationComposer a) f,
  ) {
    final $$TransactionLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionLines,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.transactionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, $$ProductsTableReferences),
          Product,
          PrefetchHooks Function({
            bool categoryId,
            bool productModifiersRefs,
            bool transactionLinesRefs,
          })
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> priceMinor = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<bool> hasModifiers = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isVisibleOnPos = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                categoryId: categoryId,
                name: name,
                priceMinor: priceMinor,
                imageUrl: imageUrl,
                hasModifiers: hasModifiers,
                isActive: isActive,
                isVisibleOnPos: isVisibleOnPos,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int categoryId,
                required String name,
                required int priceMinor,
                Value<String?> imageUrl = const Value.absent(),
                Value<bool> hasModifiers = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isVisibleOnPos = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                categoryId: categoryId,
                name: name,
                priceMinor: priceMinor,
                imageUrl: imageUrl,
                hasModifiers: hasModifiers,
                isActive: isActive,
                isVisibleOnPos: isVisibleOnPos,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                productModifiersRefs = false,
                transactionLinesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (productModifiersRefs) db.productModifiers,
                    if (transactionLinesRefs) db.transactionLines,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable: $$ProductsTableReferences
                                        ._categoryIdTable(db),
                                    referencedColumn: $$ProductsTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (productModifiersRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          ProductModifier
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._productModifiersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).productModifiersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionLinesRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          TransactionLine
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._transactionLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, $$ProductsTableReferences),
      Product,
      PrefetchHooks Function({
        bool categoryId,
        bool productModifiersRefs,
        bool transactionLinesRefs,
      })
    >;
typedef $$ProductModifiersTableCreateCompanionBuilder =
    ProductModifiersCompanion Function({
      Value<int> id,
      required int productId,
      required String name,
      required String type,
      Value<int> extraPriceMinor,
      Value<bool> isActive,
    });
typedef $$ProductModifiersTableUpdateCompanionBuilder =
    ProductModifiersCompanion Function({
      Value<int> id,
      Value<int> productId,
      Value<String> name,
      Value<String> type,
      Value<int> extraPriceMinor,
      Value<bool> isActive,
    });

final class $$ProductModifiersTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProductModifiersTable, ProductModifier> {
  $$ProductModifiersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias(
        $_aliasNameGenerator(db.productModifiers.productId, db.products.id),
      );

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProductModifiersTableFilterComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get extraPriceMinor => $composableBuilder(
    column: $table.extraPriceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get extraPriceMinor => $composableBuilder(
    column: $table.extraPriceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get extraPriceMinor => $composableBuilder(
    column: $table.extraPriceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductModifiersTable,
          ProductModifier,
          $$ProductModifiersTableFilterComposer,
          $$ProductModifiersTableOrderingComposer,
          $$ProductModifiersTableAnnotationComposer,
          $$ProductModifiersTableCreateCompanionBuilder,
          $$ProductModifiersTableUpdateCompanionBuilder,
          (ProductModifier, $$ProductModifiersTableReferences),
          ProductModifier,
          PrefetchHooks Function({bool productId})
        > {
  $$ProductModifiersTableTableManager(
    _$AppDatabase db,
    $ProductModifiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductModifiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductModifiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductModifiersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> extraPriceMinor = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => ProductModifiersCompanion(
                id: id,
                productId: productId,
                name: name,
                type: type,
                extraPriceMinor: extraPriceMinor,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int productId,
                required String name,
                required String type,
                Value<int> extraPriceMinor = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => ProductModifiersCompanion.insert(
                id: id,
                productId: productId,
                name: name,
                type: type,
                extraPriceMinor: extraPriceMinor,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductModifiersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable:
                                    $$ProductModifiersTableReferences
                                        ._productIdTable(db),
                                referencedColumn:
                                    $$ProductModifiersTableReferences
                                        ._productIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProductModifiersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductModifiersTable,
      ProductModifier,
      $$ProductModifiersTableFilterComposer,
      $$ProductModifiersTableOrderingComposer,
      $$ProductModifiersTableAnnotationComposer,
      $$ProductModifiersTableCreateCompanionBuilder,
      $$ProductModifiersTableUpdateCompanionBuilder,
      (ProductModifier, $$ProductModifiersTableReferences),
      ProductModifier,
      PrefetchHooks Function({bool productId})
    >;
typedef $$ShiftsTableCreateCompanionBuilder =
    ShiftsCompanion Function({
      Value<int> id,
      required int openedBy,
      Value<DateTime> openedAt,
      Value<int?> closedBy,
      Value<DateTime?> closedAt,
      Value<int?> cashierPreviewedBy,
      Value<DateTime?> cashierPreviewedAt,
      Value<String> status,
    });
typedef $$ShiftsTableUpdateCompanionBuilder =
    ShiftsCompanion Function({
      Value<int> id,
      Value<int> openedBy,
      Value<DateTime> openedAt,
      Value<int?> closedBy,
      Value<DateTime?> closedAt,
      Value<int?> cashierPreviewedBy,
      Value<DateTime?> cashierPreviewedAt,
      Value<String> status,
    });

final class $$ShiftsTableReferences
    extends BaseReferences<_$AppDatabase, $ShiftsTable, Shift> {
  $$ShiftsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _openedByTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.shifts.openedBy, db.users.id),
  );

  $$UsersTableProcessedTableManager get openedBy {
    final $_column = $_itemColumn<int>('opened_by')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_openedByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _closedByTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.shifts.closedBy, db.users.id),
  );

  $$UsersTableProcessedTableManager? get closedBy {
    final $_column = $_itemColumn<int>('closed_by');
    if ($_column == null) return null;
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_closedByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _cashierPreviewedByTable(_$AppDatabase db) =>
      db.users.createAlias(
        $_aliasNameGenerator(db.shifts.cashierPreviewedBy, db.users.id),
      );

  $$UsersTableProcessedTableManager? get cashierPreviewedBy {
    final $_column = $_itemColumn<int>('cashier_previewed_by');
    if ($_column == null) return null;
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cashierPreviewedByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: $_aliasNameGenerator(db.shifts.id, db.transactions.shiftId),
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.shiftId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ShiftReconciliationsTable,
    List<ShiftReconciliation>
  >
  _shiftReconciliationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.shiftReconciliations,
        aliasName: $_aliasNameGenerator(
          db.shifts.id,
          db.shiftReconciliations.shiftId,
        ),
      );

  $$ShiftReconciliationsTableProcessedTableManager
  get shiftReconciliationsRefs {
    final manager = $$ShiftReconciliationsTableTableManager(
      $_db,
      $_db.shiftReconciliations,
    ).filter((f) => f.shiftId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _shiftReconciliationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CashMovementsTable, List<CashMovement>>
  _cashMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cashMovements,
    aliasName: $_aliasNameGenerator(db.shifts.id, db.cashMovements.shiftId),
  );

  $$CashMovementsTableProcessedTableManager get cashMovementsRefs {
    final manager = $$CashMovementsTableTableManager(
      $_db,
      $_db.cashMovements,
    ).filter((f) => f.shiftId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cashMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cashierPreviewedAt => $composableBuilder(
    column: $table.cashierPreviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get openedBy {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.openedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get closedBy {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.closedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get cashierPreviewedBy {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cashierPreviewedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shiftReconciliationsRefs(
    Expression<bool> Function($$ShiftReconciliationsTableFilterComposer f) f,
  ) {
    final $$ShiftReconciliationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftReconciliations,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftReconciliationsTableFilterComposer(
            $db: $db,
            $table: $db.shiftReconciliations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cashMovementsRefs(
    Expression<bool> Function($$CashMovementsTableFilterComposer f) f,
  ) {
    final $$CashMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cashMovements,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CashMovementsTableFilterComposer(
            $db: $db,
            $table: $db.cashMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cashierPreviewedAt => $composableBuilder(
    column: $table.cashierPreviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get openedBy {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.openedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get closedBy {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.closedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get cashierPreviewedBy {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cashierPreviewedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cashierPreviewedAt => $composableBuilder(
    column: $table.cashierPreviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$UsersTableAnnotationComposer get openedBy {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.openedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get closedBy {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.closedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get cashierPreviewedBy {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cashierPreviewedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shiftReconciliationsRefs<T extends Object>(
    Expression<T> Function($$ShiftReconciliationsTableAnnotationComposer a) f,
  ) {
    final $$ShiftReconciliationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.shiftReconciliations,
          getReferencedColumn: (t) => t.shiftId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ShiftReconciliationsTableAnnotationComposer(
                $db: $db,
                $table: $db.shiftReconciliations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cashMovementsRefs<T extends Object>(
    Expression<T> Function($$CashMovementsTableAnnotationComposer a) f,
  ) {
    final $$CashMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cashMovements,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CashMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.cashMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShiftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftsTable,
          Shift,
          $$ShiftsTableFilterComposer,
          $$ShiftsTableOrderingComposer,
          $$ShiftsTableAnnotationComposer,
          $$ShiftsTableCreateCompanionBuilder,
          $$ShiftsTableUpdateCompanionBuilder,
          (Shift, $$ShiftsTableReferences),
          Shift,
          PrefetchHooks Function({
            bool openedBy,
            bool closedBy,
            bool cashierPreviewedBy,
            bool transactionsRefs,
            bool shiftReconciliationsRefs,
            bool cashMovementsRefs,
          })
        > {
  $$ShiftsTableTableManager(_$AppDatabase db, $ShiftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> openedBy = const Value.absent(),
                Value<DateTime> openedAt = const Value.absent(),
                Value<int?> closedBy = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int?> cashierPreviewedBy = const Value.absent(),
                Value<DateTime?> cashierPreviewedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => ShiftsCompanion(
                id: id,
                openedBy: openedBy,
                openedAt: openedAt,
                closedBy: closedBy,
                closedAt: closedAt,
                cashierPreviewedBy: cashierPreviewedBy,
                cashierPreviewedAt: cashierPreviewedAt,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int openedBy,
                Value<DateTime> openedAt = const Value.absent(),
                Value<int?> closedBy = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int?> cashierPreviewedBy = const Value.absent(),
                Value<DateTime?> cashierPreviewedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => ShiftsCompanion.insert(
                id: id,
                openedBy: openedBy,
                openedAt: openedAt,
                closedBy: closedBy,
                closedAt: closedAt,
                cashierPreviewedBy: cashierPreviewedBy,
                cashierPreviewedAt: cashierPreviewedAt,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ShiftsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                openedBy = false,
                closedBy = false,
                cashierPreviewedBy = false,
                transactionsRefs = false,
                shiftReconciliationsRefs = false,
                cashMovementsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (shiftReconciliationsRefs) db.shiftReconciliations,
                    if (cashMovementsRefs) db.cashMovements,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (openedBy) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.openedBy,
                                    referencedTable: $$ShiftsTableReferences
                                        ._openedByTable(db),
                                    referencedColumn: $$ShiftsTableReferences
                                        ._openedByTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (closedBy) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.closedBy,
                                    referencedTable: $$ShiftsTableReferences
                                        ._closedByTable(db),
                                    referencedColumn: $$ShiftsTableReferences
                                        ._closedByTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (cashierPreviewedBy) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.cashierPreviewedBy,
                                    referencedTable: $$ShiftsTableReferences
                                        ._cashierPreviewedByTable(db),
                                    referencedColumn: $$ShiftsTableReferences
                                        ._cashierPreviewedByTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Shift,
                          $ShiftsTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$ShiftsTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShiftsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shiftId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shiftReconciliationsRefs)
                        await $_getPrefetchedData<
                          Shift,
                          $ShiftsTable,
                          ShiftReconciliation
                        >(
                          currentTable: table,
                          referencedTable: $$ShiftsTableReferences
                              ._shiftReconciliationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShiftsTableReferences(
                                db,
                                table,
                                p0,
                              ).shiftReconciliationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shiftId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cashMovementsRefs)
                        await $_getPrefetchedData<
                          Shift,
                          $ShiftsTable,
                          CashMovement
                        >(
                          currentTable: table,
                          referencedTable: $$ShiftsTableReferences
                              ._cashMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShiftsTableReferences(
                                db,
                                table,
                                p0,
                              ).cashMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shiftId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ShiftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftsTable,
      Shift,
      $$ShiftsTableFilterComposer,
      $$ShiftsTableOrderingComposer,
      $$ShiftsTableAnnotationComposer,
      $$ShiftsTableCreateCompanionBuilder,
      $$ShiftsTableUpdateCompanionBuilder,
      (Shift, $$ShiftsTableReferences),
      Shift,
      PrefetchHooks Function({
        bool openedBy,
        bool closedBy,
        bool cashierPreviewedBy,
        bool transactionsRefs,
        bool shiftReconciliationsRefs,
        bool cashMovementsRefs,
      })
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      required String uuid,
      required int shiftId,
      required int userId,
      Value<int?> tableNumber,
      Value<String> status,
      Value<int> subtotalMinor,
      Value<int> modifierTotalMinor,
      Value<int> totalAmountMinor,
      Value<DateTime> createdAt,
      Value<DateTime?> paidAt,
      required DateTime updatedAt,
      Value<DateTime?> cancelledAt,
      Value<int?> cancelledBy,
      required String idempotencyKey,
      Value<bool> kitchenPrinted,
      Value<bool> receiptPrinted,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> shiftId,
      Value<int> userId,
      Value<int?> tableNumber,
      Value<String> status,
      Value<int> subtotalMinor,
      Value<int> modifierTotalMinor,
      Value<int> totalAmountMinor,
      Value<DateTime> createdAt,
      Value<DateTime?> paidAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> cancelledAt,
      Value<int?> cancelledBy,
      Value<String> idempotencyKey,
      Value<bool> kitchenPrinted,
      Value<bool> receiptPrinted,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ShiftsTable _shiftIdTable(_$AppDatabase db) => db.shifts.createAlias(
    $_aliasNameGenerator(db.transactions.shiftId, db.shifts.id),
  );

  $$ShiftsTableProcessedTableManager get shiftId {
    final $_column = $_itemColumn<int>('shift_id')!;

    final manager = $$ShiftsTableTableManager(
      $_db,
      $_db.shifts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shiftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.transactions.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<int>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _cancelledByTable(_$AppDatabase db) =>
      db.users.createAlias(
        $_aliasNameGenerator(db.transactions.cancelledBy, db.users.id),
      );

  $$UsersTableProcessedTableManager? get cancelledBy {
    final $_column = $_itemColumn<int>('cancelled_by');
    if ($_column == null) return null;
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cancelledByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionLinesTable, List<TransactionLine>>
  _transactionLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactionLines,
    aliasName: $_aliasNameGenerator(
      db.transactions.id,
      db.transactionLines.transactionId,
    ),
  );

  $$TransactionLinesTableProcessedTableManager get transactionLinesRefs {
    final manager = $$TransactionLinesTableTableManager(
      $_db,
      $_db.transactionLines,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionLinesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentsTable, List<Payment>> _paymentsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.payments,
    aliasName: $_aliasNameGenerator(
      db.transactions.id,
      db.payments.transactionId,
    ),
  );

  $$PaymentsTableProcessedTableManager get paymentsRefs {
    final manager = $$PaymentsTableTableManager(
      $_db,
      $_db.payments,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentAdjustmentsTable, List<PaymentAdjustment>>
  _paymentAdjustmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.paymentAdjustments,
        aliasName: $_aliasNameGenerator(
          db.transactions.id,
          db.paymentAdjustments.transactionId,
        ),
      );

  $$PaymentAdjustmentsTableProcessedTableManager get paymentAdjustmentsRefs {
    final manager = $$PaymentAdjustmentsTableTableManager(
      $_db,
      $_db.paymentAdjustments,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _paymentAdjustmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PrintJobsTable, List<PrintJob>>
  _printJobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.printJobs,
    aliasName: $_aliasNameGenerator(
      db.transactions.id,
      db.printJobs.transactionId,
    ),
  );

  $$PrintJobsTableProcessedTableManager get printJobsRefs {
    final manager = $$PrintJobsTableTableManager(
      $_db,
      $_db.printJobs,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_printJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tableNumber => $composableBuilder(
    column: $table.tableNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotalMinor => $composableBuilder(
    column: $table.subtotalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifierTotalMinor => $composableBuilder(
    column: $table.modifierTotalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalAmountMinor => $composableBuilder(
    column: $table.totalAmountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get kitchenPrinted => $composableBuilder(
    column: $table.kitchenPrinted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get receiptPrinted => $composableBuilder(
    column: $table.receiptPrinted,
    builder: (column) => ColumnFilters(column),
  );

  $$ShiftsTableFilterComposer get shiftId {
    final $$ShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableFilterComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get cancelledBy {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cancelledBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionLinesRefs(
    Expression<bool> Function($$TransactionLinesTableFilterComposer f) f,
  ) {
    final $$TransactionLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionLines,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionLinesTableFilterComposer(
            $db: $db,
            $table: $db.transactionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentsRefs(
    Expression<bool> Function($$PaymentsTableFilterComposer f) f,
  ) {
    final $$PaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableFilterComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentAdjustmentsRefs(
    Expression<bool> Function($$PaymentAdjustmentsTableFilterComposer f) f,
  ) {
    final $$PaymentAdjustmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paymentAdjustments,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentAdjustmentsTableFilterComposer(
            $db: $db,
            $table: $db.paymentAdjustments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> printJobsRefs(
    Expression<bool> Function($$PrintJobsTableFilterComposer f) f,
  ) {
    final $$PrintJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.printJobs,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrintJobsTableFilterComposer(
            $db: $db,
            $table: $db.printJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tableNumber => $composableBuilder(
    column: $table.tableNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotalMinor => $composableBuilder(
    column: $table.subtotalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifierTotalMinor => $composableBuilder(
    column: $table.modifierTotalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalAmountMinor => $composableBuilder(
    column: $table.totalAmountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get kitchenPrinted => $composableBuilder(
    column: $table.kitchenPrinted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get receiptPrinted => $composableBuilder(
    column: $table.receiptPrinted,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShiftsTableOrderingComposer get shiftId {
    final $$ShiftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableOrderingComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get cancelledBy {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cancelledBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get tableNumber => $composableBuilder(
    column: $table.tableNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get subtotalMinor => $composableBuilder(
    column: $table.subtotalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get modifierTotalMinor => $composableBuilder(
    column: $table.modifierTotalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalAmountMinor => $composableBuilder(
    column: $table.totalAmountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get kitchenPrinted => $composableBuilder(
    column: $table.kitchenPrinted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get receiptPrinted => $composableBuilder(
    column: $table.receiptPrinted,
    builder: (column) => column,
  );

  $$ShiftsTableAnnotationComposer get shiftId {
    final $$ShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get cancelledBy {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cancelledBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionLinesRefs<T extends Object>(
    Expression<T> Function($$TransactionLinesTableAnnotationComposer a) f,
  ) {
    final $$TransactionLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionLines,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.transactionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentsRefs<T extends Object>(
    Expression<T> Function($$PaymentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentAdjustmentsRefs<T extends Object>(
    Expression<T> Function($$PaymentAdjustmentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentAdjustmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.paymentAdjustments,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PaymentAdjustmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.paymentAdjustments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> printJobsRefs<T extends Object>(
    Expression<T> Function($$PrintJobsTableAnnotationComposer a) f,
  ) {
    final $$PrintJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.printJobs,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrintJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.printJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({
            bool shiftId,
            bool userId,
            bool cancelledBy,
            bool transactionLinesRefs,
            bool paymentsRefs,
            bool paymentAdjustmentsRefs,
            bool printJobsRefs,
          })
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> shiftId = const Value.absent(),
                Value<int> userId = const Value.absent(),
                Value<int?> tableNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> subtotalMinor = const Value.absent(),
                Value<int> modifierTotalMinor = const Value.absent(),
                Value<int> totalAmountMinor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> cancelledAt = const Value.absent(),
                Value<int?> cancelledBy = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<bool> kitchenPrinted = const Value.absent(),
                Value<bool> receiptPrinted = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                uuid: uuid,
                shiftId: shiftId,
                userId: userId,
                tableNumber: tableNumber,
                status: status,
                subtotalMinor: subtotalMinor,
                modifierTotalMinor: modifierTotalMinor,
                totalAmountMinor: totalAmountMinor,
                createdAt: createdAt,
                paidAt: paidAt,
                updatedAt: updatedAt,
                cancelledAt: cancelledAt,
                cancelledBy: cancelledBy,
                idempotencyKey: idempotencyKey,
                kitchenPrinted: kitchenPrinted,
                receiptPrinted: receiptPrinted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int shiftId,
                required int userId,
                Value<int?> tableNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> subtotalMinor = const Value.absent(),
                Value<int> modifierTotalMinor = const Value.absent(),
                Value<int> totalAmountMinor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> cancelledAt = const Value.absent(),
                Value<int?> cancelledBy = const Value.absent(),
                required String idempotencyKey,
                Value<bool> kitchenPrinted = const Value.absent(),
                Value<bool> receiptPrinted = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                uuid: uuid,
                shiftId: shiftId,
                userId: userId,
                tableNumber: tableNumber,
                status: status,
                subtotalMinor: subtotalMinor,
                modifierTotalMinor: modifierTotalMinor,
                totalAmountMinor: totalAmountMinor,
                createdAt: createdAt,
                paidAt: paidAt,
                updatedAt: updatedAt,
                cancelledAt: cancelledAt,
                cancelledBy: cancelledBy,
                idempotencyKey: idempotencyKey,
                kitchenPrinted: kitchenPrinted,
                receiptPrinted: receiptPrinted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                shiftId = false,
                userId = false,
                cancelledBy = false,
                transactionLinesRefs = false,
                paymentsRefs = false,
                paymentAdjustmentsRefs = false,
                printJobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionLinesRefs) db.transactionLines,
                    if (paymentsRefs) db.payments,
                    if (paymentAdjustmentsRefs) db.paymentAdjustments,
                    if (printJobsRefs) db.printJobs,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (shiftId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.shiftId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._shiftIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._shiftIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (userId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.userId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._userIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._userIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (cancelledBy) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.cancelledBy,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._cancelledByTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._cancelledByTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionLinesRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          TransactionLine
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._transactionLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (paymentsRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          Payment
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._paymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (paymentAdjustmentsRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          PaymentAdjustment
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._paymentAdjustmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentAdjustmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (printJobsRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          PrintJob
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._printJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).printJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({
        bool shiftId,
        bool userId,
        bool cancelledBy,
        bool transactionLinesRefs,
        bool paymentsRefs,
        bool paymentAdjustmentsRefs,
        bool printJobsRefs,
      })
    >;
typedef $$TransactionLinesTableCreateCompanionBuilder =
    TransactionLinesCompanion Function({
      Value<int> id,
      required String uuid,
      required int transactionId,
      required int productId,
      required String productName,
      required int unitPriceMinor,
      Value<int> quantity,
      required int lineTotalMinor,
    });
typedef $$TransactionLinesTableUpdateCompanionBuilder =
    TransactionLinesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> transactionId,
      Value<int> productId,
      Value<String> productName,
      Value<int> unitPriceMinor,
      Value<int> quantity,
      Value<int> lineTotalMinor,
    });

final class $$TransactionLinesTableReferences
    extends
        BaseReferences<_$AppDatabase, $TransactionLinesTable, TransactionLine> {
  $$TransactionLinesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.transactionLines.transactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias(
        $_aliasNameGenerator(db.transactionLines.productId, db.products.id),
      );

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$OrderModifiersTable, List<OrderModifier>>
  _orderModifiersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.orderModifiers,
    aliasName: $_aliasNameGenerator(
      db.transactionLines.id,
      db.orderModifiers.transactionLineId,
    ),
  );

  $$OrderModifiersTableProcessedTableManager get orderModifiersRefs {
    final manager = $$OrderModifiersTableTableManager(
      $_db,
      $_db.orderModifiers,
    ).filter((f) => f.transactionLineId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_orderModifiersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionLinesTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionLinesTable> {
  $$TransactionLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPriceMinor => $composableBuilder(
    column: $table.unitPriceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineTotalMinor => $composableBuilder(
    column: $table.lineTotalMinor,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> orderModifiersRefs(
    Expression<bool> Function($$OrderModifiersTableFilterComposer f) f,
  ) {
    final $$OrderModifiersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.orderModifiers,
      getReferencedColumn: (t) => t.transactionLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrderModifiersTableFilterComposer(
            $db: $db,
            $table: $db.orderModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionLinesTable> {
  $$TransactionLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPriceMinor => $composableBuilder(
    column: $table.unitPriceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineTotalMinor => $composableBuilder(
    column: $table.lineTotalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionLinesTable> {
  $$TransactionLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitPriceMinor => $composableBuilder(
    column: $table.unitPriceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get lineTotalMinor => $composableBuilder(
    column: $table.lineTotalMinor,
    builder: (column) => column,
  );

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> orderModifiersRefs<T extends Object>(
    Expression<T> Function($$OrderModifiersTableAnnotationComposer a) f,
  ) {
    final $$OrderModifiersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.orderModifiers,
      getReferencedColumn: (t) => t.transactionLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrderModifiersTableAnnotationComposer(
            $db: $db,
            $table: $db.orderModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionLinesTable,
          TransactionLine,
          $$TransactionLinesTableFilterComposer,
          $$TransactionLinesTableOrderingComposer,
          $$TransactionLinesTableAnnotationComposer,
          $$TransactionLinesTableCreateCompanionBuilder,
          $$TransactionLinesTableUpdateCompanionBuilder,
          (TransactionLine, $$TransactionLinesTableReferences),
          TransactionLine,
          PrefetchHooks Function({
            bool transactionId,
            bool productId,
            bool orderModifiersRefs,
          })
        > {
  $$TransactionLinesTableTableManager(
    _$AppDatabase db,
    $TransactionLinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> transactionId = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<int> unitPriceMinor = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> lineTotalMinor = const Value.absent(),
              }) => TransactionLinesCompanion(
                id: id,
                uuid: uuid,
                transactionId: transactionId,
                productId: productId,
                productName: productName,
                unitPriceMinor: unitPriceMinor,
                quantity: quantity,
                lineTotalMinor: lineTotalMinor,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int transactionId,
                required int productId,
                required String productName,
                required int unitPriceMinor,
                Value<int> quantity = const Value.absent(),
                required int lineTotalMinor,
              }) => TransactionLinesCompanion.insert(
                id: id,
                uuid: uuid,
                transactionId: transactionId,
                productId: productId,
                productName: productName,
                unitPriceMinor: unitPriceMinor,
                quantity: quantity,
                lineTotalMinor: lineTotalMinor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transactionId = false,
                productId = false,
                orderModifiersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (orderModifiersRefs) db.orderModifiers,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (transactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transactionId,
                                    referencedTable:
                                        $$TransactionLinesTableReferences
                                            ._transactionIdTable(db),
                                    referencedColumn:
                                        $$TransactionLinesTableReferences
                                            ._transactionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (productId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.productId,
                                    referencedTable:
                                        $$TransactionLinesTableReferences
                                            ._productIdTable(db),
                                    referencedColumn:
                                        $$TransactionLinesTableReferences
                                            ._productIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (orderModifiersRefs)
                        await $_getPrefetchedData<
                          TransactionLine,
                          $TransactionLinesTable,
                          OrderModifier
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionLinesTableReferences
                              ._orderModifiersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionLinesTableReferences(
                                db,
                                table,
                                p0,
                              ).orderModifiersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionLineId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionLinesTable,
      TransactionLine,
      $$TransactionLinesTableFilterComposer,
      $$TransactionLinesTableOrderingComposer,
      $$TransactionLinesTableAnnotationComposer,
      $$TransactionLinesTableCreateCompanionBuilder,
      $$TransactionLinesTableUpdateCompanionBuilder,
      (TransactionLine, $$TransactionLinesTableReferences),
      TransactionLine,
      PrefetchHooks Function({
        bool transactionId,
        bool productId,
        bool orderModifiersRefs,
      })
    >;
typedef $$OrderModifiersTableCreateCompanionBuilder =
    OrderModifiersCompanion Function({
      Value<int> id,
      required String uuid,
      required int transactionLineId,
      required String action,
      required String itemName,
      Value<int> extraPriceMinor,
    });
typedef $$OrderModifiersTableUpdateCompanionBuilder =
    OrderModifiersCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> transactionLineId,
      Value<String> action,
      Value<String> itemName,
      Value<int> extraPriceMinor,
    });

final class $$OrderModifiersTableReferences
    extends BaseReferences<_$AppDatabase, $OrderModifiersTable, OrderModifier> {
  $$OrderModifiersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionLinesTable _transactionLineIdTable(_$AppDatabase db) =>
      db.transactionLines.createAlias(
        $_aliasNameGenerator(
          db.orderModifiers.transactionLineId,
          db.transactionLines.id,
        ),
      );

  $$TransactionLinesTableProcessedTableManager get transactionLineId {
    final $_column = $_itemColumn<int>('transaction_line_id')!;

    final manager = $$TransactionLinesTableTableManager(
      $_db,
      $_db.transactionLines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionLineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OrderModifiersTableFilterComposer
    extends Composer<_$AppDatabase, $OrderModifiersTable> {
  $$OrderModifiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemName => $composableBuilder(
    column: $table.itemName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get extraPriceMinor => $composableBuilder(
    column: $table.extraPriceMinor,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionLinesTableFilterComposer get transactionLineId {
    final $$TransactionLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionLineId,
      referencedTable: $db.transactionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionLinesTableFilterComposer(
            $db: $db,
            $table: $db.transactionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrderModifiersTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderModifiersTable> {
  $$OrderModifiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemName => $composableBuilder(
    column: $table.itemName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get extraPriceMinor => $composableBuilder(
    column: $table.extraPriceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionLinesTableOrderingComposer get transactionLineId {
    final $$TransactionLinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionLineId,
      referencedTable: $db.transactionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionLinesTableOrderingComposer(
            $db: $db,
            $table: $db.transactionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrderModifiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderModifiersTable> {
  $$OrderModifiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get itemName =>
      $composableBuilder(column: $table.itemName, builder: (column) => column);

  GeneratedColumn<int> get extraPriceMinor => $composableBuilder(
    column: $table.extraPriceMinor,
    builder: (column) => column,
  );

  $$TransactionLinesTableAnnotationComposer get transactionLineId {
    final $$TransactionLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionLineId,
      referencedTable: $db.transactionLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.transactionLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrderModifiersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrderModifiersTable,
          OrderModifier,
          $$OrderModifiersTableFilterComposer,
          $$OrderModifiersTableOrderingComposer,
          $$OrderModifiersTableAnnotationComposer,
          $$OrderModifiersTableCreateCompanionBuilder,
          $$OrderModifiersTableUpdateCompanionBuilder,
          (OrderModifier, $$OrderModifiersTableReferences),
          OrderModifier,
          PrefetchHooks Function({bool transactionLineId})
        > {
  $$OrderModifiersTableTableManager(
    _$AppDatabase db,
    $OrderModifiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderModifiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderModifiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderModifiersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> transactionLineId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> itemName = const Value.absent(),
                Value<int> extraPriceMinor = const Value.absent(),
              }) => OrderModifiersCompanion(
                id: id,
                uuid: uuid,
                transactionLineId: transactionLineId,
                action: action,
                itemName: itemName,
                extraPriceMinor: extraPriceMinor,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int transactionLineId,
                required String action,
                required String itemName,
                Value<int> extraPriceMinor = const Value.absent(),
              }) => OrderModifiersCompanion.insert(
                id: id,
                uuid: uuid,
                transactionLineId: transactionLineId,
                action: action,
                itemName: itemName,
                extraPriceMinor: extraPriceMinor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OrderModifiersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionLineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transactionLineId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transactionLineId,
                                referencedTable: $$OrderModifiersTableReferences
                                    ._transactionLineIdTable(db),
                                referencedColumn:
                                    $$OrderModifiersTableReferences
                                        ._transactionLineIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OrderModifiersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrderModifiersTable,
      OrderModifier,
      $$OrderModifiersTableFilterComposer,
      $$OrderModifiersTableOrderingComposer,
      $$OrderModifiersTableAnnotationComposer,
      $$OrderModifiersTableCreateCompanionBuilder,
      $$OrderModifiersTableUpdateCompanionBuilder,
      (OrderModifier, $$OrderModifiersTableReferences),
      OrderModifier,
      PrefetchHooks Function({bool transactionLineId})
    >;
typedef $$PaymentsTableCreateCompanionBuilder =
    PaymentsCompanion Function({
      Value<int> id,
      required String uuid,
      required int transactionId,
      required String method,
      required int amountMinor,
      Value<DateTime> paidAt,
    });
typedef $$PaymentsTableUpdateCompanionBuilder =
    PaymentsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> transactionId,
      Value<String> method,
      Value<int> amountMinor,
      Value<DateTime> paidAt,
    });

final class $$PaymentsTableReferences
    extends BaseReferences<_$AppDatabase, $PaymentsTable, Payment> {
  $$PaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(db.payments.transactionId, db.transactions.id),
      );

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PaymentAdjustmentsTable, List<PaymentAdjustment>>
  _paymentAdjustmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.paymentAdjustments,
        aliasName: $_aliasNameGenerator(
          db.payments.id,
          db.paymentAdjustments.paymentId,
        ),
      );

  $$PaymentAdjustmentsTableProcessedTableManager get paymentAdjustmentsRefs {
    final manager = $$PaymentAdjustmentsTableTableManager(
      $_db,
      $_db.paymentAdjustments,
    ).filter((f) => f.paymentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _paymentAdjustmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> paymentAdjustmentsRefs(
    Expression<bool> Function($$PaymentAdjustmentsTableFilterComposer f) f,
  ) {
    final $$PaymentAdjustmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paymentAdjustments,
      getReferencedColumn: (t) => t.paymentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentAdjustmentsTableFilterComposer(
            $db: $db,
            $table: $db.paymentAdjustments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> paymentAdjustmentsRefs<T extends Object>(
    Expression<T> Function($$PaymentAdjustmentsTableAnnotationComposer a) f,
  ) {
    final $$PaymentAdjustmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.paymentAdjustments,
          getReferencedColumn: (t) => t.paymentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PaymentAdjustmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.paymentAdjustments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaymentsTable,
          Payment,
          $$PaymentsTableFilterComposer,
          $$PaymentsTableOrderingComposer,
          $$PaymentsTableAnnotationComposer,
          $$PaymentsTableCreateCompanionBuilder,
          $$PaymentsTableUpdateCompanionBuilder,
          (Payment, $$PaymentsTableReferences),
          Payment,
          PrefetchHooks Function({
            bool transactionId,
            bool paymentAdjustmentsRefs,
          })
        > {
  $$PaymentsTableTableManager(_$AppDatabase db, $PaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> transactionId = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<DateTime> paidAt = const Value.absent(),
              }) => PaymentsCompanion(
                id: id,
                uuid: uuid,
                transactionId: transactionId,
                method: method,
                amountMinor: amountMinor,
                paidAt: paidAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int transactionId,
                required String method,
                required int amountMinor,
                Value<DateTime> paidAt = const Value.absent(),
              }) => PaymentsCompanion.insert(
                id: id,
                uuid: uuid,
                transactionId: transactionId,
                method: method,
                amountMinor: amountMinor,
                paidAt: paidAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PaymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({transactionId = false, paymentAdjustmentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (paymentAdjustmentsRefs) db.paymentAdjustments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (transactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transactionId,
                                    referencedTable: $$PaymentsTableReferences
                                        ._transactionIdTable(db),
                                    referencedColumn: $$PaymentsTableReferences
                                        ._transactionIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (paymentAdjustmentsRefs)
                        await $_getPrefetchedData<
                          Payment,
                          $PaymentsTable,
                          PaymentAdjustment
                        >(
                          currentTable: table,
                          referencedTable: $$PaymentsTableReferences
                              ._paymentAdjustmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PaymentsTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentAdjustmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.paymentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaymentsTable,
      Payment,
      $$PaymentsTableFilterComposer,
      $$PaymentsTableOrderingComposer,
      $$PaymentsTableAnnotationComposer,
      $$PaymentsTableCreateCompanionBuilder,
      $$PaymentsTableUpdateCompanionBuilder,
      (Payment, $$PaymentsTableReferences),
      Payment,
      PrefetchHooks Function({bool transactionId, bool paymentAdjustmentsRefs})
    >;
typedef $$PaymentAdjustmentsTableCreateCompanionBuilder =
    PaymentAdjustmentsCompanion Function({
      Value<int> id,
      required String uuid,
      required int paymentId,
      required int transactionId,
      Value<String> type,
      Value<String> status,
      required int amountMinor,
      required String reason,
      required int createdBy,
      Value<DateTime> createdAt,
    });
typedef $$PaymentAdjustmentsTableUpdateCompanionBuilder =
    PaymentAdjustmentsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> paymentId,
      Value<int> transactionId,
      Value<String> type,
      Value<String> status,
      Value<int> amountMinor,
      Value<String> reason,
      Value<int> createdBy,
      Value<DateTime> createdAt,
    });

final class $$PaymentAdjustmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PaymentAdjustmentsTable,
          PaymentAdjustment
        > {
  $$PaymentAdjustmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PaymentsTable _paymentIdTable(_$AppDatabase db) =>
      db.payments.createAlias(
        $_aliasNameGenerator(db.paymentAdjustments.paymentId, db.payments.id),
      );

  $$PaymentsTableProcessedTableManager get paymentId {
    final $_column = $_itemColumn<int>('payment_id')!;

    final manager = $$PaymentsTableTableManager(
      $_db,
      $_db.payments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_paymentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.paymentAdjustments.transactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _createdByTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.paymentAdjustments.createdBy, db.users.id),
  );

  $$UsersTableProcessedTableManager get createdBy {
    final $_column = $_itemColumn<int>('created_by')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_createdByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PaymentAdjustmentsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentAdjustmentsTable> {
  $$PaymentAdjustmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PaymentsTableFilterComposer get paymentId {
    final $$PaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paymentId,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableFilterComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get createdBy {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentAdjustmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentAdjustmentsTable> {
  $$PaymentAdjustmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PaymentsTableOrderingComposer get paymentId {
    final $$PaymentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paymentId,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableOrderingComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get createdBy {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentAdjustmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentAdjustmentsTable> {
  $$PaymentAdjustmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PaymentsTableAnnotationComposer get paymentId {
    final $$PaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paymentId,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get createdBy {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentAdjustmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaymentAdjustmentsTable,
          PaymentAdjustment,
          $$PaymentAdjustmentsTableFilterComposer,
          $$PaymentAdjustmentsTableOrderingComposer,
          $$PaymentAdjustmentsTableAnnotationComposer,
          $$PaymentAdjustmentsTableCreateCompanionBuilder,
          $$PaymentAdjustmentsTableUpdateCompanionBuilder,
          (PaymentAdjustment, $$PaymentAdjustmentsTableReferences),
          PaymentAdjustment,
          PrefetchHooks Function({
            bool paymentId,
            bool transactionId,
            bool createdBy,
          })
        > {
  $$PaymentAdjustmentsTableTableManager(
    _$AppDatabase db,
    $PaymentAdjustmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentAdjustmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentAdjustmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentAdjustmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> paymentId = const Value.absent(),
                Value<int> transactionId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int> createdBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PaymentAdjustmentsCompanion(
                id: id,
                uuid: uuid,
                paymentId: paymentId,
                transactionId: transactionId,
                type: type,
                status: status,
                amountMinor: amountMinor,
                reason: reason,
                createdBy: createdBy,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int paymentId,
                required int transactionId,
                Value<String> type = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int amountMinor,
                required String reason,
                required int createdBy,
                Value<DateTime> createdAt = const Value.absent(),
              }) => PaymentAdjustmentsCompanion.insert(
                id: id,
                uuid: uuid,
                paymentId: paymentId,
                transactionId: transactionId,
                type: type,
                status: status,
                amountMinor: amountMinor,
                reason: reason,
                createdBy: createdBy,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PaymentAdjustmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({paymentId = false, transactionId = false, createdBy = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (paymentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.paymentId,
                                    referencedTable:
                                        $$PaymentAdjustmentsTableReferences
                                            ._paymentIdTable(db),
                                    referencedColumn:
                                        $$PaymentAdjustmentsTableReferences
                                            ._paymentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (transactionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.transactionId,
                                    referencedTable:
                                        $$PaymentAdjustmentsTableReferences
                                            ._transactionIdTable(db),
                                    referencedColumn:
                                        $$PaymentAdjustmentsTableReferences
                                            ._transactionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (createdBy) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.createdBy,
                                    referencedTable:
                                        $$PaymentAdjustmentsTableReferences
                                            ._createdByTable(db),
                                    referencedColumn:
                                        $$PaymentAdjustmentsTableReferences
                                            ._createdByTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PaymentAdjustmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaymentAdjustmentsTable,
      PaymentAdjustment,
      $$PaymentAdjustmentsTableFilterComposer,
      $$PaymentAdjustmentsTableOrderingComposer,
      $$PaymentAdjustmentsTableAnnotationComposer,
      $$PaymentAdjustmentsTableCreateCompanionBuilder,
      $$PaymentAdjustmentsTableUpdateCompanionBuilder,
      (PaymentAdjustment, $$PaymentAdjustmentsTableReferences),
      PaymentAdjustment,
      PrefetchHooks Function({
        bool paymentId,
        bool transactionId,
        bool createdBy,
      })
    >;
typedef $$ShiftReconciliationsTableCreateCompanionBuilder =
    ShiftReconciliationsCompanion Function({
      Value<int> id,
      required String uuid,
      required int shiftId,
      Value<String> kind,
      required int expectedCashMinor,
      required int countedCashMinor,
      required int varianceMinor,
      Value<String> countedCashSource,
      required int countedBy,
      Value<DateTime> countedAt,
    });
typedef $$ShiftReconciliationsTableUpdateCompanionBuilder =
    ShiftReconciliationsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> shiftId,
      Value<String> kind,
      Value<int> expectedCashMinor,
      Value<int> countedCashMinor,
      Value<int> varianceMinor,
      Value<String> countedCashSource,
      Value<int> countedBy,
      Value<DateTime> countedAt,
    });

final class $$ShiftReconciliationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ShiftReconciliationsTable,
          ShiftReconciliation
        > {
  $$ShiftReconciliationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShiftsTable _shiftIdTable(_$AppDatabase db) => db.shifts.createAlias(
    $_aliasNameGenerator(db.shiftReconciliations.shiftId, db.shifts.id),
  );

  $$ShiftsTableProcessedTableManager get shiftId {
    final $_column = $_itemColumn<int>('shift_id')!;

    final manager = $$ShiftsTableTableManager(
      $_db,
      $_db.shifts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shiftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _countedByTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.shiftReconciliations.countedBy, db.users.id),
  );

  $$UsersTableProcessedTableManager get countedBy {
    final $_column = $_itemColumn<int>('counted_by')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_countedByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShiftReconciliationsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftReconciliationsTable> {
  $$ShiftReconciliationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedCashMinor => $composableBuilder(
    column: $table.expectedCashMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countedCashMinor => $composableBuilder(
    column: $table.countedCashMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get varianceMinor => $composableBuilder(
    column: $table.varianceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countedCashSource => $composableBuilder(
    column: $table.countedCashSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get countedAt => $composableBuilder(
    column: $table.countedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ShiftsTableFilterComposer get shiftId {
    final $$ShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableFilterComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get countedBy {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.countedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftReconciliationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftReconciliationsTable> {
  $$ShiftReconciliationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedCashMinor => $composableBuilder(
    column: $table.expectedCashMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countedCashMinor => $composableBuilder(
    column: $table.countedCashMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get varianceMinor => $composableBuilder(
    column: $table.varianceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countedCashSource => $composableBuilder(
    column: $table.countedCashSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get countedAt => $composableBuilder(
    column: $table.countedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShiftsTableOrderingComposer get shiftId {
    final $$ShiftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableOrderingComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get countedBy {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.countedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftReconciliationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftReconciliationsTable> {
  $$ShiftReconciliationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get expectedCashMinor => $composableBuilder(
    column: $table.expectedCashMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get countedCashMinor => $composableBuilder(
    column: $table.countedCashMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get varianceMinor => $composableBuilder(
    column: $table.varianceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get countedCashSource => $composableBuilder(
    column: $table.countedCashSource,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get countedAt =>
      $composableBuilder(column: $table.countedAt, builder: (column) => column);

  $$ShiftsTableAnnotationComposer get shiftId {
    final $$ShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get countedBy {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.countedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftReconciliationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftReconciliationsTable,
          ShiftReconciliation,
          $$ShiftReconciliationsTableFilterComposer,
          $$ShiftReconciliationsTableOrderingComposer,
          $$ShiftReconciliationsTableAnnotationComposer,
          $$ShiftReconciliationsTableCreateCompanionBuilder,
          $$ShiftReconciliationsTableUpdateCompanionBuilder,
          (ShiftReconciliation, $$ShiftReconciliationsTableReferences),
          ShiftReconciliation,
          PrefetchHooks Function({bool shiftId, bool countedBy})
        > {
  $$ShiftReconciliationsTableTableManager(
    _$AppDatabase db,
    $ShiftReconciliationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftReconciliationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftReconciliationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ShiftReconciliationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> shiftId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> expectedCashMinor = const Value.absent(),
                Value<int> countedCashMinor = const Value.absent(),
                Value<int> varianceMinor = const Value.absent(),
                Value<String> countedCashSource = const Value.absent(),
                Value<int> countedBy = const Value.absent(),
                Value<DateTime> countedAt = const Value.absent(),
              }) => ShiftReconciliationsCompanion(
                id: id,
                uuid: uuid,
                shiftId: shiftId,
                kind: kind,
                expectedCashMinor: expectedCashMinor,
                countedCashMinor: countedCashMinor,
                varianceMinor: varianceMinor,
                countedCashSource: countedCashSource,
                countedBy: countedBy,
                countedAt: countedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int shiftId,
                Value<String> kind = const Value.absent(),
                required int expectedCashMinor,
                required int countedCashMinor,
                required int varianceMinor,
                Value<String> countedCashSource = const Value.absent(),
                required int countedBy,
                Value<DateTime> countedAt = const Value.absent(),
              }) => ShiftReconciliationsCompanion.insert(
                id: id,
                uuid: uuid,
                shiftId: shiftId,
                kind: kind,
                expectedCashMinor: expectedCashMinor,
                countedCashMinor: countedCashMinor,
                varianceMinor: varianceMinor,
                countedCashSource: countedCashSource,
                countedBy: countedBy,
                countedAt: countedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShiftReconciliationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shiftId = false, countedBy = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (shiftId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.shiftId,
                                referencedTable:
                                    $$ShiftReconciliationsTableReferences
                                        ._shiftIdTable(db),
                                referencedColumn:
                                    $$ShiftReconciliationsTableReferences
                                        ._shiftIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (countedBy) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.countedBy,
                                referencedTable:
                                    $$ShiftReconciliationsTableReferences
                                        ._countedByTable(db),
                                referencedColumn:
                                    $$ShiftReconciliationsTableReferences
                                        ._countedByTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShiftReconciliationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftReconciliationsTable,
      ShiftReconciliation,
      $$ShiftReconciliationsTableFilterComposer,
      $$ShiftReconciliationsTableOrderingComposer,
      $$ShiftReconciliationsTableAnnotationComposer,
      $$ShiftReconciliationsTableCreateCompanionBuilder,
      $$ShiftReconciliationsTableUpdateCompanionBuilder,
      (ShiftReconciliation, $$ShiftReconciliationsTableReferences),
      ShiftReconciliation,
      PrefetchHooks Function({bool shiftId, bool countedBy})
    >;
typedef $$CashMovementsTableCreateCompanionBuilder =
    CashMovementsCompanion Function({
      Value<int> id,
      required int shiftId,
      required String type,
      required String category,
      required int amountMinor,
      required String paymentMethod,
      Value<String?> note,
      required int createdByUserId,
      Value<DateTime> createdAt,
    });
typedef $$CashMovementsTableUpdateCompanionBuilder =
    CashMovementsCompanion Function({
      Value<int> id,
      Value<int> shiftId,
      Value<String> type,
      Value<String> category,
      Value<int> amountMinor,
      Value<String> paymentMethod,
      Value<String?> note,
      Value<int> createdByUserId,
      Value<DateTime> createdAt,
    });

final class $$CashMovementsTableReferences
    extends BaseReferences<_$AppDatabase, $CashMovementsTable, CashMovement> {
  $$CashMovementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShiftsTable _shiftIdTable(_$AppDatabase db) => db.shifts.createAlias(
    $_aliasNameGenerator(db.cashMovements.shiftId, db.shifts.id),
  );

  $$ShiftsTableProcessedTableManager get shiftId {
    final $_column = $_itemColumn<int>('shift_id')!;

    final manager = $$ShiftsTableTableManager(
      $_db,
      $_db.shifts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shiftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _createdByUserIdTable(_$AppDatabase db) =>
      db.users.createAlias(
        $_aliasNameGenerator(db.cashMovements.createdByUserId, db.users.id),
      );

  $$UsersTableProcessedTableManager get createdByUserId {
    final $_column = $_itemColumn<int>('created_by_user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_createdByUserIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CashMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $CashMovementsTable> {
  $$CashMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ShiftsTableFilterComposer get shiftId {
    final $$ShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableFilterComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get createdByUserId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $CashMovementsTable> {
  $$CashMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShiftsTableOrderingComposer get shiftId {
    final $$ShiftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableOrderingComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get createdByUserId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CashMovementsTable> {
  $$CashMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ShiftsTableAnnotationComposer get shiftId {
    final $$ShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get createdByUserId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CashMovementsTable,
          CashMovement,
          $$CashMovementsTableFilterComposer,
          $$CashMovementsTableOrderingComposer,
          $$CashMovementsTableAnnotationComposer,
          $$CashMovementsTableCreateCompanionBuilder,
          $$CashMovementsTableUpdateCompanionBuilder,
          (CashMovement, $$CashMovementsTableReferences),
          CashMovement,
          PrefetchHooks Function({bool shiftId, bool createdByUserId})
        > {
  $$CashMovementsTableTableManager(_$AppDatabase db, $CashMovementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CashMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CashMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CashMovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> shiftId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdByUserId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CashMovementsCompanion(
                id: id,
                shiftId: shiftId,
                type: type,
                category: category,
                amountMinor: amountMinor,
                paymentMethod: paymentMethod,
                note: note,
                createdByUserId: createdByUserId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int shiftId,
                required String type,
                required String category,
                required int amountMinor,
                required String paymentMethod,
                Value<String?> note = const Value.absent(),
                required int createdByUserId,
                Value<DateTime> createdAt = const Value.absent(),
              }) => CashMovementsCompanion.insert(
                id: id,
                shiftId: shiftId,
                type: type,
                category: category,
                amountMinor: amountMinor,
                paymentMethod: paymentMethod,
                note: note,
                createdByUserId: createdByUserId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CashMovementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shiftId = false, createdByUserId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (shiftId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.shiftId,
                                referencedTable: $$CashMovementsTableReferences
                                    ._shiftIdTable(db),
                                referencedColumn: $$CashMovementsTableReferences
                                    ._shiftIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (createdByUserId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.createdByUserId,
                                referencedTable: $$CashMovementsTableReferences
                                    ._createdByUserIdTable(db),
                                referencedColumn: $$CashMovementsTableReferences
                                    ._createdByUserIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CashMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CashMovementsTable,
      CashMovement,
      $$CashMovementsTableFilterComposer,
      $$CashMovementsTableOrderingComposer,
      $$CashMovementsTableAnnotationComposer,
      $$CashMovementsTableCreateCompanionBuilder,
      $$CashMovementsTableUpdateCompanionBuilder,
      (CashMovement, $$CashMovementsTableReferences),
      CashMovement,
      PrefetchHooks Function({bool shiftId, bool createdByUserId})
    >;
typedef $$AuditLogsTableCreateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<int> id,
      required int actorUserId,
      required String action,
      required String entityType,
      required String entityId,
      required String metadataJson,
      Value<DateTime> createdAt,
    });
typedef $$AuditLogsTableUpdateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<int> id,
      Value<int> actorUserId,
      Value<String> action,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> metadataJson,
      Value<DateTime> createdAt,
    });

final class $$AuditLogsTableReferences
    extends BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog> {
  $$AuditLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _actorUserIdTable(_$AppDatabase db) => db.users
      .createAlias($_aliasNameGenerator(db.auditLogs.actorUserId, db.users.id));

  $$UsersTableProcessedTableManager get actorUserId {
    final $_column = $_itemColumn<int>('actor_user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_actorUserIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get actorUserId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.actorUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get actorUserId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.actorUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$UsersTableAnnotationComposer get actorUserId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.actorUserId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogsTable,
          AuditLog,
          $$AuditLogsTableFilterComposer,
          $$AuditLogsTableOrderingComposer,
          $$AuditLogsTableAnnotationComposer,
          $$AuditLogsTableCreateCompanionBuilder,
          $$AuditLogsTableUpdateCompanionBuilder,
          (AuditLog, $$AuditLogsTableReferences),
          AuditLog,
          PrefetchHooks Function({bool actorUserId})
        > {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> actorUserId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AuditLogsCompanion(
                id: id,
                actorUserId: actorUserId,
                action: action,
                entityType: entityType,
                entityId: entityId,
                metadataJson: metadataJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int actorUserId,
                required String action,
                required String entityType,
                required String entityId,
                required String metadataJson,
                Value<DateTime> createdAt = const Value.absent(),
              }) => AuditLogsCompanion.insert(
                id: id,
                actorUserId: actorUserId,
                action: action,
                entityType: entityType,
                entityId: entityId,
                metadataJson: metadataJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuditLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({actorUserId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (actorUserId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.actorUserId,
                                referencedTable: $$AuditLogsTableReferences
                                    ._actorUserIdTable(db),
                                referencedColumn: $$AuditLogsTableReferences
                                    ._actorUserIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogsTable,
      AuditLog,
      $$AuditLogsTableFilterComposer,
      $$AuditLogsTableOrderingComposer,
      $$AuditLogsTableAnnotationComposer,
      $$AuditLogsTableCreateCompanionBuilder,
      $$AuditLogsTableUpdateCompanionBuilder,
      (AuditLog, $$AuditLogsTableReferences),
      AuditLog,
      PrefetchHooks Function({bool actorUserId})
    >;
typedef $$PrintJobsTableCreateCompanionBuilder =
    PrintJobsCompanion Function({
      Value<int> id,
      required int transactionId,
      required String target,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> attemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> completedAt,
      Value<String?> lastError,
    });
typedef $$PrintJobsTableUpdateCompanionBuilder =
    PrintJobsCompanion Function({
      Value<int> id,
      Value<int> transactionId,
      Value<String> target,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> attemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> completedAt,
      Value<String?> lastError,
    });

final class $$PrintJobsTableReferences
    extends BaseReferences<_$AppDatabase, $PrintJobsTable, PrintJob> {
  $$PrintJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(db.printJobs.transactionId, db.transactions.id),
      );

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PrintJobsTableFilterComposer
    extends Composer<_$AppDatabase, $PrintJobsTable> {
  $$PrintJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrintJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrintJobsTable> {
  $$PrintJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrintJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrintJobsTable> {
  $$PrintJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrintJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrintJobsTable,
          PrintJob,
          $$PrintJobsTableFilterComposer,
          $$PrintJobsTableOrderingComposer,
          $$PrintJobsTableAnnotationComposer,
          $$PrintJobsTableCreateCompanionBuilder,
          $$PrintJobsTableUpdateCompanionBuilder,
          (PrintJob, $$PrintJobsTableReferences),
          PrintJob,
          PrefetchHooks Function({bool transactionId})
        > {
  $$PrintJobsTableTableManager(_$AppDatabase db, $PrintJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrintJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrintJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrintJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> transactionId = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PrintJobsCompanion(
                id: id,
                transactionId: transactionId,
                target: target,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                attemptCount: attemptCount,
                lastAttemptAt: lastAttemptAt,
                completedAt: completedAt,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int transactionId,
                required String target,
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PrintJobsCompanion.insert(
                id: id,
                transactionId: transactionId,
                target: target,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                attemptCount: attemptCount,
                lastAttemptAt: lastAttemptAt,
                completedAt: completedAt,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PrintJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transactionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transactionId,
                                referencedTable: $$PrintJobsTableReferences
                                    ._transactionIdTable(db),
                                referencedColumn: $$PrintJobsTableReferences
                                    ._transactionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PrintJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrintJobsTable,
      PrintJob,
      $$PrintJobsTableFilterComposer,
      $$PrintJobsTableOrderingComposer,
      $$PrintJobsTableAnnotationComposer,
      $$PrintJobsTableCreateCompanionBuilder,
      $$PrintJobsTableUpdateCompanionBuilder,
      (PrintJob, $$PrintJobsTableReferences),
      PrintJob,
      PrefetchHooks Function({bool transactionId})
    >;
typedef $$ReportSettingsTableCreateCompanionBuilder =
    ReportSettingsCompanion Function({
      Value<int> id,
      Value<String> cashierReportMode,
      Value<double> visibilityRatio,
      Value<int?> maxVisibleTotalMinor,
      Value<String?> businessName,
      Value<String?> businessAddress,
      Value<int?> updatedBy,
      Value<DateTime> updatedAt,
    });
typedef $$ReportSettingsTableUpdateCompanionBuilder =
    ReportSettingsCompanion Function({
      Value<int> id,
      Value<String> cashierReportMode,
      Value<double> visibilityRatio,
      Value<int?> maxVisibleTotalMinor,
      Value<String?> businessName,
      Value<String?> businessAddress,
      Value<int?> updatedBy,
      Value<DateTime> updatedAt,
    });

final class $$ReportSettingsTableReferences
    extends BaseReferences<_$AppDatabase, $ReportSettingsTable, ReportSetting> {
  $$ReportSettingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $UsersTable _updatedByTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.reportSettings.updatedBy, db.users.id),
  );

  $$UsersTableProcessedTableManager? get updatedBy {
    final $_column = $_itemColumn<int>('updated_by');
    if ($_column == null) return null;
    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_updatedByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReportSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $ReportSettingsTable> {
  $$ReportSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cashierReportMode => $composableBuilder(
    column: $table.cashierReportMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get visibilityRatio => $composableBuilder(
    column: $table.visibilityRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxVisibleTotalMinor => $composableBuilder(
    column: $table.maxVisibleTotalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessAddress => $composableBuilder(
    column: $table.businessAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get updatedBy {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.updatedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReportSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReportSettingsTable> {
  $$ReportSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cashierReportMode => $composableBuilder(
    column: $table.cashierReportMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get visibilityRatio => $composableBuilder(
    column: $table.visibilityRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxVisibleTotalMinor => $composableBuilder(
    column: $table.maxVisibleTotalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessAddress => $composableBuilder(
    column: $table.businessAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get updatedBy {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.updatedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReportSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReportSettingsTable> {
  $$ReportSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cashierReportMode => $composableBuilder(
    column: $table.cashierReportMode,
    builder: (column) => column,
  );

  GeneratedColumn<double> get visibilityRatio => $composableBuilder(
    column: $table.visibilityRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxVisibleTotalMinor => $composableBuilder(
    column: $table.maxVisibleTotalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessAddress => $composableBuilder(
    column: $table.businessAddress,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$UsersTableAnnotationComposer get updatedBy {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.updatedBy,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReportSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReportSettingsTable,
          ReportSetting,
          $$ReportSettingsTableFilterComposer,
          $$ReportSettingsTableOrderingComposer,
          $$ReportSettingsTableAnnotationComposer,
          $$ReportSettingsTableCreateCompanionBuilder,
          $$ReportSettingsTableUpdateCompanionBuilder,
          (ReportSetting, $$ReportSettingsTableReferences),
          ReportSetting,
          PrefetchHooks Function({bool updatedBy})
        > {
  $$ReportSettingsTableTableManager(
    _$AppDatabase db,
    $ReportSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cashierReportMode = const Value.absent(),
                Value<double> visibilityRatio = const Value.absent(),
                Value<int?> maxVisibleTotalMinor = const Value.absent(),
                Value<String?> businessName = const Value.absent(),
                Value<String?> businessAddress = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReportSettingsCompanion(
                id: id,
                cashierReportMode: cashierReportMode,
                visibilityRatio: visibilityRatio,
                maxVisibleTotalMinor: maxVisibleTotalMinor,
                businessName: businessName,
                businessAddress: businessAddress,
                updatedBy: updatedBy,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cashierReportMode = const Value.absent(),
                Value<double> visibilityRatio = const Value.absent(),
                Value<int?> maxVisibleTotalMinor = const Value.absent(),
                Value<String?> businessName = const Value.absent(),
                Value<String?> businessAddress = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReportSettingsCompanion.insert(
                id: id,
                cashierReportMode: cashierReportMode,
                visibilityRatio: visibilityRatio,
                maxVisibleTotalMinor: maxVisibleTotalMinor,
                businessName: businessName,
                businessAddress: businessAddress,
                updatedBy: updatedBy,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReportSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({updatedBy = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (updatedBy) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.updatedBy,
                                referencedTable: $$ReportSettingsTableReferences
                                    ._updatedByTable(db),
                                referencedColumn:
                                    $$ReportSettingsTableReferences
                                        ._updatedByTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReportSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReportSettingsTable,
      ReportSetting,
      $$ReportSettingsTableFilterComposer,
      $$ReportSettingsTableOrderingComposer,
      $$ReportSettingsTableAnnotationComposer,
      $$ReportSettingsTableCreateCompanionBuilder,
      $$ReportSettingsTableUpdateCompanionBuilder,
      (ReportSetting, $$ReportSettingsTableReferences),
      ReportSetting,
      PrefetchHooks Function({bool updatedBy})
    >;
typedef $$PrinterSettingsTableCreateCompanionBuilder =
    PrinterSettingsCompanion Function({
      Value<int> id,
      required String deviceName,
      required String deviceAddress,
      Value<int> paperWidth,
      Value<bool> isActive,
    });
typedef $$PrinterSettingsTableUpdateCompanionBuilder =
    PrinterSettingsCompanion Function({
      Value<int> id,
      Value<String> deviceName,
      Value<String> deviceAddress,
      Value<int> paperWidth,
      Value<bool> isActive,
    });

class $$PrinterSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $PrinterSettingsTable> {
  $$PrinterSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceAddress => $composableBuilder(
    column: $table.deviceAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paperWidth => $composableBuilder(
    column: $table.paperWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrinterSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrinterSettingsTable> {
  $$PrinterSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceAddress => $composableBuilder(
    column: $table.deviceAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paperWidth => $composableBuilder(
    column: $table.paperWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrinterSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrinterSettingsTable> {
  $$PrinterSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceAddress => $composableBuilder(
    column: $table.deviceAddress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paperWidth => $composableBuilder(
    column: $table.paperWidth,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$PrinterSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrinterSettingsTable,
          PrinterSetting,
          $$PrinterSettingsTableFilterComposer,
          $$PrinterSettingsTableOrderingComposer,
          $$PrinterSettingsTableAnnotationComposer,
          $$PrinterSettingsTableCreateCompanionBuilder,
          $$PrinterSettingsTableUpdateCompanionBuilder,
          (
            PrinterSetting,
            BaseReferences<
              _$AppDatabase,
              $PrinterSettingsTable,
              PrinterSetting
            >,
          ),
          PrinterSetting,
          PrefetchHooks Function()
        > {
  $$PrinterSettingsTableTableManager(
    _$AppDatabase db,
    $PrinterSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrinterSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrinterSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrinterSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deviceName = const Value.absent(),
                Value<String> deviceAddress = const Value.absent(),
                Value<int> paperWidth = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => PrinterSettingsCompanion(
                id: id,
                deviceName: deviceName,
                deviceAddress: deviceAddress,
                paperWidth: paperWidth,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceName,
                required String deviceAddress,
                Value<int> paperWidth = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => PrinterSettingsCompanion.insert(
                id: id,
                deviceName: deviceName,
                deviceAddress: deviceAddress,
                paperWidth: paperWidth,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrinterSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrinterSettingsTable,
      PrinterSetting,
      $$PrinterSettingsTableFilterComposer,
      $$PrinterSettingsTableOrderingComposer,
      $$PrinterSettingsTableAnnotationComposer,
      $$PrinterSettingsTableCreateCompanionBuilder,
      $$PrinterSettingsTableUpdateCompanionBuilder,
      (
        PrinterSetting,
        BaseReferences<_$AppDatabase, $PrinterSettingsTable, PrinterSetting>,
      ),
      PrinterSetting,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String queueTableName,
      required String recordUuid,
      Value<String> operation,
      Value<DateTime> createdAt,
      Value<String> status,
      Value<int> attemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<String?> errorMessage,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> queueTableName,
      Value<String> recordUuid,
      Value<String> operation,
      Value<DateTime> createdAt,
      Value<String> status,
      Value<int> attemptCount,
      Value<DateTime?> lastAttemptAt,
      Value<DateTime?> syncedAt,
      Value<String?> errorMessage,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queueTableName => $composableBuilder(
    column: $table.queueTableName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordUuid => $composableBuilder(
    column: $table.recordUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queueTableName => $composableBuilder(
    column: $table.queueTableName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordUuid => $composableBuilder(
    column: $table.recordUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get queueTableName => $composableBuilder(
    column: $table.queueTableName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordUuid => $composableBuilder(
    column: $table.recordUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> queueTableName = const Value.absent(),
                Value<String> recordUuid = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                queueTableName: queueTableName,
                recordUuid: recordUuid,
                operation: operation,
                createdAt: createdAt,
                status: status,
                attemptCount: attemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                errorMessage: errorMessage,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String queueTableName,
                required String recordUuid,
                Value<String> operation = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                queueTableName: queueTableName,
                recordUuid: recordUuid,
                operation: operation,
                createdAt: createdAt,
                status: status,
                attemptCount: attemptCount,
                lastAttemptAt: lastAttemptAt,
                syncedAt: syncedAt,
                errorMessage: errorMessage,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$ProductModifiersTableTableManager get productModifiers =>
      $$ProductModifiersTableTableManager(_db, _db.productModifiers);
  $$ShiftsTableTableManager get shifts =>
      $$ShiftsTableTableManager(_db, _db.shifts);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$TransactionLinesTableTableManager get transactionLines =>
      $$TransactionLinesTableTableManager(_db, _db.transactionLines);
  $$OrderModifiersTableTableManager get orderModifiers =>
      $$OrderModifiersTableTableManager(_db, _db.orderModifiers);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
  $$PaymentAdjustmentsTableTableManager get paymentAdjustments =>
      $$PaymentAdjustmentsTableTableManager(_db, _db.paymentAdjustments);
  $$ShiftReconciliationsTableTableManager get shiftReconciliations =>
      $$ShiftReconciliationsTableTableManager(_db, _db.shiftReconciliations);
  $$CashMovementsTableTableManager get cashMovements =>
      $$CashMovementsTableTableManager(_db, _db.cashMovements);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$PrintJobsTableTableManager get printJobs =>
      $$PrintJobsTableTableManager(_db, _db.printJobs);
  $$ReportSettingsTableTableManager get reportSettings =>
      $$ReportSettingsTableTableManager(_db, _db.reportSettings);
  $$PrinterSettingsTableTableManager get printerSettings =>
      $$PrinterSettingsTableTableManager(_db, _db.printerSettings);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
}
