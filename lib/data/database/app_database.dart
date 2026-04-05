import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/migration_log_entry.dart';

part 'app_database.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get pin => text().nullable()();

  TextColumn get password => text().nullable()();

  TextColumn get role => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (role IN ('admin','cashier'))",
  ];
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get imageUrl => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get removalDiscount1Minor => integer()
      .named('removal_discount_1_minor')
      .withDefault(const Constant(0))();

  IntColumn get removalDiscount2Minor => integer()
      .named('removal_discount_2_minor')
      .withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (removal_discount_1_minor >= 0)',
    'CHECK (removal_discount_2_minor >= 0)',
  ];
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId =>
      integer().customConstraint('NOT NULL REFERENCES "categories" ("id")')();

  IntColumn get mealAdjustmentProfileId => integer()
      .nullable()
      .customConstraint('REFERENCES "meal_adjustment_profiles" ("id")')();

  TextColumn get name => text()();

  IntColumn get priceMinor => integer()();

  TextColumn get imageUrl => text().nullable()();

  BoolColumn get hasModifiers => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  BoolColumn get isVisibleOnPos =>
      boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>['CHECK (price_minor >= 0)'];
}

class MealAdjustmentProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  IntColumn get freeSwapLimit =>
      integer().named('free_swap_limit').withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
    'CHECK (free_swap_limit >= 0)',
  ];
}

class MealAdjustmentProfileComponents extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get profileId => integer().customConstraint(
    'NOT NULL REFERENCES "meal_adjustment_profiles" ("id")',
  )();

  TextColumn get componentKey => text().named('component_key')();

  TextColumn get displayName => text().named('display_name')();

  IntColumn get defaultItemProductId => integer()
      .named('default_item_product_id')
      .customConstraint('NOT NULL REFERENCES "products" ("id")')();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  BoolColumn get canRemove => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(component_key)) > 0)',
    'CHECK (length(trim(display_name)) > 0)',
    'CHECK (quantity > 0)',
    'CHECK (sort_order >= 0)',
    'UNIQUE(profile_id, component_key)',
  ];
}

class MealAdjustmentComponentOptions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get profileComponentId => integer()
      .named('profile_component_id')
      .customConstraint(
        'NOT NULL REFERENCES "meal_adjustment_profile_components" ("id")',
      )();

  IntColumn get optionItemProductId => integer()
      .named('option_item_product_id')
      .customConstraint('NOT NULL REFERENCES "products" ("id")')();

  TextColumn get optionType => text().named('option_type')();

  IntColumn get fixedPriceDeltaMinor =>
      integer().named('fixed_price_delta_minor').nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (option_type IN ('swap'))",
    'CHECK (fixed_price_delta_minor IS NULL OR fixed_price_delta_minor >= 0)',
    'CHECK (sort_order >= 0)',
    'UNIQUE(profile_component_id, option_item_product_id, option_type)',
  ];
}

class MealAdjustmentProfileExtras extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get profileId => integer().customConstraint(
    'NOT NULL REFERENCES "meal_adjustment_profiles" ("id")',
  )();

  IntColumn get itemProductId => integer()
      .named('item_product_id')
      .customConstraint('NOT NULL REFERENCES "products" ("id")')();

  IntColumn get fixedPriceDeltaMinor =>
      integer().named('fixed_price_delta_minor')();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (fixed_price_delta_minor >= 0)',
    'CHECK (sort_order >= 0)',
    'UNIQUE(profile_id, item_product_id)',
  ];
}

class MealAdjustmentPricingRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get profileId => integer().customConstraint(
    'NOT NULL REFERENCES "meal_adjustment_profiles" ("id")',
  )();

  TextColumn get name => text()();

  TextColumn get ruleType => text().named('rule_type')();

  IntColumn get priceDeltaMinor => integer().named('price_delta_minor')();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
    "CHECK (rule_type IN ('remove_only','combo','swap','extra'))",
    'CHECK (priority >= 0)',
  ];
}

class MealAdjustmentPricingRuleConditions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get ruleId => integer()
      .named('rule_id')
      .customConstraint(
        'NOT NULL REFERENCES "meal_adjustment_pricing_rules" ("id")',
      )();

  TextColumn get conditionType => text().named('condition_type')();

  TextColumn get componentKey => text().named('component_key').nullable()();

  IntColumn get itemProductId => integer()
      .named('item_product_id')
      .nullable()
      .customConstraint('REFERENCES "products" ("id")')();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (condition_type IN ('removed_component','swap_to_item','extra_item'))",
    'CHECK (quantity > 0)',
    '''CHECK (
      (condition_type = 'removed_component'
        AND component_key IS NOT NULL
        AND length(trim(component_key)) > 0
        AND item_product_id IS NULL)
      OR
      (condition_type = 'swap_to_item'
        AND component_key IS NOT NULL
        AND length(trim(component_key)) > 0
        AND item_product_id IS NOT NULL)
      OR
      (condition_type = 'extra_item'
        AND component_key IS NULL
        AND item_product_id IS NOT NULL)
    )''',
  ];
}

class ProductModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();

  @ReferenceName('modifierOwnerProducts')
  IntColumn get productId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  IntColumn get groupId => integer().nullable().customConstraint(
    'REFERENCES "modifier_groups" ("id")',
  )();

  @ReferenceName('modifierItemProducts')
  IntColumn get itemProductId =>
      integer().nullable().customConstraint('REFERENCES "products" ("id")')();

  TextColumn get name => text()();

  TextColumn get type => text()();

  IntColumn get extraPriceMinor => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (type IN ('included','extra','choice'))",
    'CHECK (extra_price_minor >= 0)',
    "CHECK ((type = 'choice' AND group_id IS NOT NULL AND item_product_id IS NOT NULL) OR (type IN ('included','extra') AND group_id IS NULL))",
  ];
}

class BreakfastExtraPresets extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
  ];
}

class BreakfastExtraPresetItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get presetId => integer().customConstraint(
    'NOT NULL REFERENCES "breakfast_extra_presets" ("id")',
  )();

  IntColumn get itemProductId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (sort_order >= 0)',
    'UNIQUE(preset_id, item_product_id)',
  ];
}

class MenuSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get freeSwapLimit => integer().withDefault(const Constant(2))();

  IntColumn get maxSwaps => integer().withDefault(const Constant(4))();

  IntColumn get updatedBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (free_swap_limit >= 0)',
    'CHECK (max_swaps >= 0)',
  ];
}

class SetItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  @ReferenceName('setProducts')
  IntColumn get productId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  @ReferenceName('setItemProducts')
  IntColumn get itemProductId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  BoolColumn get isRemovable => boolean().withDefault(const Constant(true))();

  IntColumn get defaultQuantity => integer().withDefault(const Constant(1))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (default_quantity > 0)',
    'UNIQUE(product_id, item_product_id)',
  ];
}

class ModifierGroups extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  TextColumn get name => text()();

  IntColumn get minSelect => integer().withDefault(const Constant(1))();

  IntColumn get maxSelect => integer().withDefault(const Constant(1))();

  IntColumn get includedQuantity => integer().withDefault(const Constant(1))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (min_select >= 0)',
    'CHECK (max_select > 0)',
    'CHECK (included_quantity > 0)',
    'CHECK (max_select >= min_select)',
    'UNIQUE(product_id, name)',
  ];
}

class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();

  @ReferenceName('openedShifts')
  IntColumn get openedBy =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();

  @ReferenceName('closedShifts')
  IntColumn get closedBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  DateTimeColumn get closedAt => dateTime().nullable()();

  @ReferenceName('cashierPreviewedShifts')
  IntColumn get cashierPreviewedBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  DateTimeColumn get cashierPreviewedAt => dateTime().nullable()();

  TextColumn get status => text().withDefault(const Constant('draft'))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (status IN ('open','closed'))",
  ];
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get shiftId =>
      integer().customConstraint('NOT NULL REFERENCES "shifts" ("id")')();

  @ReferenceName('createdTransactions')
  IntColumn get userId =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  IntColumn get tableNumber => integer().nullable()();

  TextColumn get status => text().withDefault(const Constant('open'))();

  IntColumn get subtotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get modifierTotalMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get paidAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get cancelledAt => dateTime().nullable()();

  @ReferenceName('cancelledTransactions')
  IntColumn get cancelledBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  TextColumn get idempotencyKey => text().unique()();

  BoolColumn get kitchenPrinted =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get receiptPrinted =>
      boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (status IN ('draft','sent','paid','cancelled'))",
    'CHECK (subtotal_minor >= 0)',
    'CHECK (total_amount_minor >= 0)',
  ];
}

class TransactionLines extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionId =>
      integer().customConstraint('NOT NULL REFERENCES "transactions" ("id")')();

  IntColumn get productId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  TextColumn get productName => text()();

  IntColumn get unitPriceMinor => integer()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  IntColumn get lineTotalMinor => integer()();

  TextColumn get pricingMode =>
      text().withDefault(const Constant('standard'))();

  IntColumn get removalDiscountTotalMinor =>
      integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (unit_price_minor >= 0)',
    'CHECK (quantity > 0)',
    'CHECK (line_total_minor >= 0)',
    "CHECK (pricing_mode IN ('standard','set'))",
    'CHECK (removal_discount_total_minor >= 0)',
  ];
}

class OrderModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionLineId => integer().customConstraint(
    'NOT NULL REFERENCES "transaction_lines" ("id")',
  )();

  TextColumn get action => text()();

  TextColumn get itemName => text()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  IntColumn get itemProductId =>
      integer().nullable().customConstraint('REFERENCES "products" ("id")')();

  IntColumn get sourceGroupId => integer().nullable().customConstraint(
    'REFERENCES "modifier_groups" ("id")',
  )();

  IntColumn get extraPriceMinor => integer().withDefault(const Constant(0))();

  TextColumn get chargeReason => text().nullable()();

  IntColumn get unitPriceMinor => integer().withDefault(const Constant(0))();

  IntColumn get priceEffectMinor => integer().withDefault(const Constant(0))();

  IntColumn get sortKey => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (\"action\" IN ('remove','add','choice'))",
    'CHECK (quantity > 0)',
    'CHECK (extra_price_minor >= 0)',
    'CHECK (unit_price_minor >= 0)',
    "CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount','combo_discount'))",
    "CHECK (\"action\" != 'choice' OR charge_reason = 'included_choice')",
  ];
}

class BreakfastCookingInstructions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionLineId => integer().customConstraint(
    'NOT NULL REFERENCES "transaction_lines" ("id")',
  )();

  IntColumn get itemProductId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  TextColumn get itemName => text()();

  TextColumn get instructionCode => text()();

  TextColumn get instructionLabel => text()();

  IntColumn get appliedQuantity =>
      integer().withDefault(const Constant(1)).named('applied_quantity')();

  IntColumn get sortKey => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(instruction_code)) > 0)',
    'CHECK (length(trim(instruction_label)) > 0)',
    'CHECK (applied_quantity > 0)',
    'UNIQUE(transaction_line_id, item_product_id)',
  ];
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionId => integer().customConstraint(
    'UNIQUE NOT NULL REFERENCES "transactions" ("id")',
  )();

  TextColumn get method => text()();

  IntColumn get amountMinor => integer()();

  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (method IN ('cash','card'))",
    'CHECK (amount_minor > 0)',
  ];
}

class PaymentAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get paymentId => integer().customConstraint(
    'UNIQUE NOT NULL REFERENCES "payments" ("id")',
  )();

  IntColumn get transactionId =>
      integer().customConstraint('NOT NULL REFERENCES "transactions" ("id")')();

  TextColumn get type => text().withDefault(const Constant('refund'))();

  TextColumn get status => text().withDefault(const Constant('completed'))();

  IntColumn get amountMinor => integer()();

  TextColumn get reason => text()();

  IntColumn get createdBy =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (type IN ('refund','reversal'))",
    "CHECK (status IN ('completed'))",
    'CHECK (amount_minor > 0)',
  ];
}

class ShiftReconciliations extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get shiftId =>
      integer().customConstraint('NOT NULL REFERENCES "shifts" ("id")')();

  TextColumn get kind => text().withDefault(const Constant('final_close'))();

  IntColumn get expectedCashMinor => integer()();

  IntColumn get countedCashMinor => integer()();

  IntColumn get varianceMinor => integer()();

  TextColumn get countedCashSource =>
      text().withDefault(const Constant('entered'))();

  IntColumn get countedBy =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  DateTimeColumn get countedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (kind IN ('final_close'))",
    "CHECK (counted_cash_source IN ('entered','compatibility_fallback'))",
    'CHECK (expected_cash_minor >= 0)',
    'CHECK (counted_cash_minor >= 0)',
    'UNIQUE(shift_id, kind)',
  ];
}

class CashMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get shiftId =>
      integer().customConstraint('NOT NULL REFERENCES "shifts" ("id")')();

  TextColumn get type => text()();

  TextColumn get category => text()();

  IntColumn get amountMinor => integer()();

  TextColumn get paymentMethod => text()();

  TextColumn get note => text().nullable()();

  IntColumn get createdByUserId =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (type IN ('income','expense'))",
    'CHECK (length(trim(category)) > 0)',
    'CHECK (amount_minor > 0)',
    "CHECK (payment_method IN ('cash','card','other'))",
  ];
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get actorUserId =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  TextColumn get action => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get metadataJson => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim("action")) > 0)',
    'CHECK (length(trim(entity_type)) > 0)',
    'CHECK (length(trim(entity_id)) > 0)',
  ];
}

class PrintJobs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get transactionId =>
      integer().customConstraint('NOT NULL REFERENCES "transactions" ("id")')();

  TextColumn get target => text()();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (target IN ('kitchen','receipt'))",
    "CHECK (status IN ('pending','printing','printed','failed'))",
    'UNIQUE(transaction_id, target)',
  ];
}

class ReportSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get cashierReportMode =>
      text().withDefault(const Constant('percentage'))();

  RealColumn get visibilityRatio => real().withDefault(const Constant(1.0))();

  IntColumn get maxVisibleTotalMinor => integer().nullable()();

  TextColumn get businessName => text().nullable()();

  TextColumn get businessAddress => text().nullable()();

  IntColumn get updatedBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (cashier_report_mode IN ('percentage','cap_amount'))",
    'CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0)',
    'CHECK (max_visible_total_minor IS NULL OR max_visible_total_minor >= 0)',
  ];
}

class PrinterSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get deviceName => text()();

  TextColumn get deviceAddress => text()();

  IntColumn get paperWidth => integer().withDefault(const Constant(80))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (paper_width IN (58,80))',
  ];
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get queueTableName => text().named('table_name')();

  TextColumn get recordUuid => text()();

  TextColumn get operation => text().withDefault(const Constant('upsert'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  DateTimeColumn get syncedAt => dateTime().nullable()();

  TextColumn get errorMessage => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments'))",
    "CHECK (operation IN ('upsert'))",
    "CHECK (status IN ('pending','processing','synced','failed'))",
  ];
}

@DriftDatabase(
  tables: <Type>[
    Users,
    Categories,
    Products,
    MealAdjustmentProfiles,
    MealAdjustmentProfileComponents,
    MealAdjustmentComponentOptions,
    MealAdjustmentProfileExtras,
    MealAdjustmentPricingRules,
    MealAdjustmentPricingRuleConditions,
    BreakfastExtraPresets,
    BreakfastExtraPresetItems,
    MenuSettings,
    SetItems,
    ModifierGroups,
    ProductModifiers,
    Shifts,
    Transactions,
    TransactionLines,
    OrderModifiers,
    BreakfastCookingInstructions,
    Payments,
    PaymentAdjustments,
    ShiftReconciliations,
    CashMovements,
    AuditLogs,
    PrintJobs,
    ReportSettings,
    PrinterSettings,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Opens a database from an existing file (e.g. for backup verification).
  factory AppDatabase.forFile(File file) {
    return AppDatabase(NativeDatabase(file));
  }

  static const int currentSchemaVersion = 25;
  final List<MigrationLogEntry> _migrationHistory = <MigrationLogEntry>[];
  MigrationLogEntry? _lastMigrationFailure;

  List<MigrationLogEntry> get migrationHistory =>
      List<MigrationLogEntry>.unmodifiable(_migrationHistory);

  MigrationLogEntry? get lastMigrationFailure => _lastMigrationFailure;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await _runMigrationStep(
        step: 'create_schema',
        fromVersion: 0,
        toVersion: schemaVersion,
        action: () async {
          try {
            await m.createAll();
          } on Object {
            // Drift's generated CREATE TABLE statements with inline REFERENCES
            // are not reliable on every SQLite runtime we support. Fall back to
            // the explicit bootstrap SQL and trigger-backed FK enforcement so
            // fresh databases remain usable and consistent with upgraded ones.
            await _createBaseTables();
            await _createFreshPathFkEmulation();
          }
          await _seedDefaultMenuSettings();
          await _createMealCustomizationSnapshotSchema();
          await _createIndexes();
          await _createMealCustomizationSnapshotIndexes();
          await _createMealCustomizationSnapshotFkEmulation();
        },
      );
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await _runMigrationStep(
          step: 'migrate_v2',
          fromVersion: from,
          toVersion: 2,
          action: _migrateToV2,
        );
      }
      if (from < 3) {
        await _runMigrationStep(
          step: 'migrate_v3',
          fromVersion: from < 2 ? 2 : from,
          toVersion: 3,
          action: _migrateToV3,
        );
      }
      if (from < 4) {
        await _runMigrationStep(
          step: 'migrate_v4',
          fromVersion: from < 3 ? 3 : from,
          toVersion: 4,
          action: _migrateToV4,
        );
      }
      if (from < 5) {
        await _runMigrationStep(
          step: 'migrate_v5',
          fromVersion: from < 4 ? 4 : from,
          toVersion: 5,
          action: _migrateToV5,
        );
      }
      if (from < 6) {
        await _runMigrationStep(
          step: 'migrate_v6',
          fromVersion: from < 5 ? 5 : from,
          toVersion: 6,
          action: () => _migrateToV6(m),
        );
      }
      if (from < 7) {
        await _runMigrationStep(
          step: 'migrate_v7',
          fromVersion: from < 6 ? 6 : from,
          toVersion: 7,
          action: _migrateToV7,
        );
      }
      if (from < 8) {
        await _runMigrationStep(
          step: 'migrate_v8',
          fromVersion: from < 7 ? 7 : from,
          toVersion: 8,
          action: _migrateToV8,
        );
      }
      if (from < 9) {
        await _runMigrationStep(
          step: 'migrate_v9',
          fromVersion: from < 8 ? 8 : from,
          toVersion: 9,
          action: _migrateToV9,
        );
      }
      if (from < 10) {
        await _runMigrationStep(
          step: 'migrate_v10',
          fromVersion: from < 9 ? 9 : from,
          toVersion: 10,
          action: _migrateToV10,
        );
      }
      if (from < 11) {
        await _runMigrationStep(
          step: 'migrate_v11',
          fromVersion: from < 10 ? 10 : from,
          toVersion: 11,
          action: _migrateToV11,
        );
      }
      if (from < 12) {
        await _runMigrationStep(
          step: 'migrate_v12',
          fromVersion: from < 11 ? 11 : from,
          toVersion: 12,
          action: _migrateToV12,
        );
      }
      if (from < 13) {
        await _runMigrationStep(
          step: 'migrate_v13',
          fromVersion: from < 12 ? 12 : from,
          toVersion: 13,
          action: _migrateToV13,
        );
      }
      if (from < 14) {
        await _runMigrationStep(
          step: 'migrate_v14',
          fromVersion: from < 13 ? 13 : from,
          toVersion: 14,
          action: _migrateToV14,
        );
      }
      if (from < 15) {
        await _runMigrationStep(
          step: 'migrate_v15',
          fromVersion: from < 14 ? 14 : from,
          toVersion: 15,
          action: _migrateToV15,
        );
      }
      if (from < 16) {
        await _runMigrationStep(
          step: 'migrate_v16',
          fromVersion: from < 15 ? 15 : from,
          toVersion: 16,
          action: _migrateToV16,
        );
      }
      if (from < 17) {
        await _runMigrationStep(
          step: 'migrate_v17',
          fromVersion: from < 16 ? 16 : from,
          toVersion: 17,
          action: _migrateToV17,
        );
      }
      if (from < 18) {
        await _runMigrationStep(
          step: 'migrate_v18',
          fromVersion: from < 17 ? 17 : from,
          toVersion: 18,
          action: _migrateToV18,
        );
      }
      if (from < 19) {
        await _runMigrationStep(
          step: 'migrate_v19',
          fromVersion: from < 18 ? 18 : from,
          toVersion: 19,
          action: _migrateToV19,
        );
      }
      if (from < 20) {
        await _runMigrationStep(
          step: 'migrate_v20',
          fromVersion: from < 19 ? 19 : from,
          toVersion: 20,
          action: _migrateToV20,
        );
      }
      if (from < 21) {
        await _runMigrationStep(
          step: 'migrate_v21',
          fromVersion: from < 20 ? 20 : from,
          toVersion: 21,
          action: _migrateToV21,
        );
      }
      if (from < 22) {
        await _runMigrationStep(
          step: 'migrate_v22',
          fromVersion: from < 21 ? 21 : from,
          toVersion: 22,
          action: _migrateToV22,
        );
      }
      if (from < 23) {
        await _runMigrationStep(
          step: 'migrate_v23',
          fromVersion: from < 22 ? 22 : from,
          toVersion: 23,
          action: _migrateToV23,
        );
      }
      if (from < 24) {
        await _runMigrationStep(
          step: 'migrate_v24',
          fromVersion: from < 23 ? 23 : from,
          toVersion: 24,
          action: _migrateToV24,
        );
      }
      if (from < 25) {
        await _runMigrationStep(
          step: 'migrate_v25',
          fromVersion: from < 24 ? 24 : from,
          toVersion: 25,
          action: _migrateToV25,
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      _migrationHistory.add(
        MigrationLogEntry(
          timestamp: DateTime.now().toUtc(),
          step: 'database_open',
          fromVersion: details.wasCreated
              ? 0
              : details.versionBefore ?? details.versionNow,
          toVersion: details.versionNow,
          status: MigrationLogStatus.succeeded,
          message: details.hadUpgrade
              ? 'Database opened after upgrade.'
              : 'Database opened.',
        ),
      );
    },
  );

  Future<void> _createBaseTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NULL,
        password TEXT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        image_url TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        removal_discount_1_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_1_minor >= 0),
        removal_discount_2_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_2_minor >= 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        meal_adjustment_profile_id INTEGER NULL,
        name TEXT NOT NULL,
        price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
        image_url TEXT NULL,
        has_modifiers INTEGER NOT NULL DEFAULT 0 CHECK (has_modifiers IN (0, 1)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        is_visible_on_pos INTEGER NOT NULL DEFAULT 1 CHECK (is_visible_on_pos IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_profiles (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NULL,
        free_swap_limit INTEGER NOT NULL DEFAULT 0 CHECK (free_swap_limit >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_profile_components (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        component_key TEXT NOT NULL,
        display_name TEXT NOT NULL,
        default_item_product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        can_remove INTEGER NOT NULL DEFAULT 1 CHECK (can_remove IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        CHECK (length(trim(component_key)) > 0),
        CHECK (length(trim(display_name)) > 0),
        UNIQUE(profile_id, component_key)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_component_options (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        profile_component_id INTEGER NOT NULL,
        option_item_product_id INTEGER NOT NULL,
        option_type TEXT NOT NULL CHECK (option_type IN ('swap')),
        fixed_price_delta_minor INTEGER NULL CHECK (fixed_price_delta_minor IS NULL OR fixed_price_delta_minor >= 0),
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        UNIQUE(profile_component_id, option_item_product_id, option_type)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_profile_extras (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        fixed_price_delta_minor INTEGER NOT NULL CHECK (fixed_price_delta_minor >= 0),
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        UNIQUE(profile_id, item_product_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_pricing_rules (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        rule_type TEXT NOT NULL CHECK (rule_type IN ('remove_only','combo','swap','extra')),
        price_delta_minor INTEGER NOT NULL,
        priority INTEGER NOT NULL DEFAULT 0 CHECK (priority >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_pricing_rule_conditions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        rule_id INTEGER NOT NULL,
        condition_type TEXT NOT NULL CHECK (condition_type IN ('removed_component','swap_to_item','extra_item')),
        component_key TEXT NULL,
        item_product_id INTEGER NULL,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        CHECK (
          (condition_type = 'removed_component'
            AND component_key IS NOT NULL
            AND length(trim(component_key)) > 0
            AND item_product_id IS NULL)
          OR
          (condition_type = 'swap_to_item'
            AND component_key IS NOT NULL
            AND length(trim(component_key)) > 0
            AND item_product_id IS NOT NULL)
          OR
          (condition_type = 'extra_item'
            AND component_key IS NULL
            AND item_product_id IS NOT NULL)
        )
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS breakfast_extra_presets (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS breakfast_extra_preset_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        preset_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        UNIQUE(preset_id, item_product_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS menu_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        free_swap_limit INTEGER NOT NULL DEFAULT 2 CHECK (free_swap_limit >= 0),
        max_swaps INTEGER NOT NULL DEFAULT 4 CHECK (max_swaps >= 0),
        updated_by INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS set_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        is_removable INTEGER NOT NULL DEFAULT 1 CHECK (is_removable IN (0, 1)),
        default_quantity INTEGER NOT NULL DEFAULT 1 CHECK (default_quantity > 0),
        sort_order INTEGER NOT NULL DEFAULT 0,
        UNIQUE(product_id, item_product_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS modifier_groups (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        min_select INTEGER NOT NULL DEFAULT 1 CHECK (min_select >= 0),
        max_select INTEGER NOT NULL DEFAULT 1 CHECK (max_select > 0),
        included_quantity INTEGER NOT NULL DEFAULT 1 CHECK (included_quantity > 0),
        sort_order INTEGER NOT NULL DEFAULT 0,
        CHECK (max_select >= min_select),
        UNIQUE(product_id, name)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS product_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        group_id INTEGER NULL,
        item_product_id INTEGER NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('included','extra','choice')),
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        CHECK ((type = 'choice' AND group_id IS NOT NULL AND item_product_id IS NOT NULL) OR (type IN ('included','extra') AND group_id IS NULL))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        opened_by INTEGER NOT NULL,
        opened_at INTEGER NOT NULL DEFAULT (unixepoch()),
        closed_by INTEGER NULL,
        closed_at INTEGER NULL,
        cashier_previewed_at INTEGER NULL,
        cashier_previewed_by INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        table_number INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
        subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
        modifier_total_minor INTEGER NOT NULL DEFAULT 0,
        total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        paid_at INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        cancelled_at INTEGER NULL,
        cancelled_by INTEGER NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
        receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transaction_lines (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
        pricing_mode TEXT NOT NULL DEFAULT 'standard' CHECK (pricing_mode IN ('standard','set')),
        removal_discount_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_total_minor >= 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS order_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_line_id INTEGER NOT NULL,
        action TEXT NOT NULL CHECK (action IN ('remove','add','choice')),
        item_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        item_product_id INTEGER NULL,
        source_group_id INTEGER NULL,
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
        charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount','combo_discount')),
        unit_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0),
        price_effect_minor INTEGER NOT NULL DEFAULT 0,
        sort_key INTEGER NOT NULL DEFAULT 0,
        CHECK (action != 'choice' OR charge_reason = 'included_choice')
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS breakfast_cooking_instructions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_line_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        instruction_code TEXT NOT NULL CHECK (length(trim(instruction_code)) > 0),
        instruction_label TEXT NOT NULL CHECK (length(trim(instruction_label)) > 0),
        applied_quantity INTEGER NOT NULL DEFAULT 1 CHECK (applied_quantity > 0),
        sort_key INTEGER NOT NULL DEFAULT 0,
        UNIQUE(transaction_line_id, item_product_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL UNIQUE,
        method TEXT NOT NULL CHECK (method IN ('cash','card')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        paid_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS payment_adjustments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        payment_id INTEGER NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'refund' CHECK (type IN ('refund','reversal')),
        status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        reason TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS shift_reconciliations (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        kind TEXT NOT NULL DEFAULT 'final_close' CHECK (kind IN ('final_close')),
        expected_cash_minor INTEGER NOT NULL CHECK (expected_cash_minor >= 0),
        counted_cash_minor INTEGER NOT NULL CHECK (counted_cash_minor >= 0),
        variance_minor INTEGER NOT NULL,
        counted_cash_source TEXT NOT NULL DEFAULT 'entered' CHECK (counted_cash_source IN ('entered','compatibility_fallback')),
        counted_by INTEGER NOT NULL,
        counted_at INTEGER NOT NULL DEFAULT (unixepoch()),
        UNIQUE(shift_id, kind)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cash_movements (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income','expense')),
        category TEXT NOT NULL CHECK (length(trim(category)) > 0),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        payment_method TEXT NOT NULL CHECK (payment_method IN ('cash','card','other')),
        note TEXT NULL,
        created_by_user_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        actor_user_id INTEGER NOT NULL,
        action TEXT NOT NULL CHECK (length(trim(action)) > 0),
        entity_type TEXT NOT NULL CHECK (length(trim(entity_type)) > 0),
        entity_id TEXT NOT NULL CHECK (length(trim(entity_id)) > 0),
        metadata_json TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS print_jobs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        target TEXT NOT NULL CHECK (target IN ('kitchen','receipt')),
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','printing','printed','failed')),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at INTEGER NULL,
        completed_at INTEGER NULL,
        last_error TEXT NULL,
        UNIQUE(transaction_id, target)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS report_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        cashier_report_mode TEXT NOT NULL DEFAULT 'percentage' CHECK (cashier_report_mode IN ('percentage','cap_amount')),
        visibility_ratio REAL NOT NULL DEFAULT 1.0 CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
        max_visible_total_minor INTEGER NULL CHECK (max_visible_total_minor IS NULL OR max_visible_total_minor >= 0),
        business_name TEXT NULL,
        business_address TEXT NULL,
        updated_by INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS printer_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        device_name TEXT NOT NULL,
        device_address TEXT NOT NULL,
        paper_width INTEGER NOT NULL DEFAULT 80 CHECK (paper_width IN (58,80)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments')),
        record_uuid TEXT NOT NULL,
        operation TEXT NOT NULL DEFAULT 'upsert' CHECK (operation IN ('upsert')),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','synced','failed')),
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at INTEGER NULL,
        synced_at INTEGER NULL,
        error_message TEXT NULL
      );
    ''');
    await _createSyncRootSnapshotTable();
  }

  Future<void> _createMealCustomizationSnapshotSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_customization_line_snapshots (
        transaction_line_id INTEGER NOT NULL PRIMARY KEY,
        product_id INTEGER NOT NULL,
        profile_id INTEGER NOT NULL,
        customization_key TEXT NOT NULL,
        snapshot_json TEXT NOT NULL,
        total_adjustment_minor INTEGER NOT NULL,
        free_swap_count_used INTEGER NOT NULL DEFAULT 0 CHECK (free_swap_count_used >= 0),
        paid_swap_count_used INTEGER NOT NULL DEFAULT 0 CHECK (paid_swap_count_used >= 0)
      );
    ''');
  }

  Future<void> _createFreshPathFkEmulation() async {
    await _createMigrationFkTrigger(
      table: 'breakfast_extra_preset_items',
      column: 'preset_id',
      referencedTable: 'breakfast_extra_presets',
    );
    await _createMigrationFkTrigger(
      table: 'breakfast_extra_preset_items',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'products',
      column: 'category_id',
      referencedTable: 'categories',
    );
    await _createMigrationFkTrigger(
      table: 'products',
      column: 'meal_adjustment_profile_id',
      referencedTable: 'meal_adjustment_profiles',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_profile_components',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_profile_components',
      column: 'default_item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_component_options',
      column: 'profile_component_id',
      referencedTable: 'meal_adjustment_profile_components',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_component_options',
      column: 'option_item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_profile_extras',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_profile_extras',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_pricing_rules',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_pricing_rule_conditions',
      column: 'rule_id',
      referencedTable: 'meal_adjustment_pricing_rules',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_pricing_rule_conditions',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'menu_settings',
      column: 'updated_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'set_items',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'set_items',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'modifier_groups',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'group_id',
      referencedTable: 'modifier_groups',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'shifts',
      column: 'opened_by',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'shifts',
      column: 'closed_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'shifts',
      column: 'cashier_previewed_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'user_id',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'cancelled_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'transaction_lines',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createMigrationFkTrigger(
      table: 'transaction_lines',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'breakfast_cooking_instructions',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'breakfast_cooking_instructions',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'payments',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createMigrationFkTrigger(
      table: 'payment_adjustments',
      column: 'payment_id',
      referencedTable: 'payments',
    );
    await _createMigrationFkTrigger(
      table: 'payment_adjustments',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createMigrationFkTrigger(
      table: 'payment_adjustments',
      column: 'created_by',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'shift_reconciliations',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'shift_reconciliations',
      column: 'counted_by',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'cash_movements',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'cash_movements',
      column: 'created_by_user_id',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'audit_logs',
      column: 'actor_user_id',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'print_jobs',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createMigrationFkTrigger(
      table: 'report_settings',
      column: 'updated_by',
      referencedTable: 'users',
      nullable: true,
    );
  }

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_breakfast_extra_presets_name ON breakfast_extra_presets(name, updated_at, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_breakfast_extra_preset_items_preset ON breakfast_extra_preset_items(preset_id, sort_order, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_menu_settings_updated_at ON menu_settings(updated_at, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_set_items_product ON set_items(product_id, sort_order, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_modifier_groups_product ON modifier_groups(product_id, sort_order, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id, is_active, is_visible_on_pos, sort_order);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_products_meal_adjustment_profile ON products(meal_adjustment_profile_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_profile_components_profile ON meal_adjustment_profile_components(profile_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_component_options_component ON meal_adjustment_component_options(profile_component_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_profile_extras_profile ON meal_adjustment_profile_extras(profile_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_pricing_rules_profile ON meal_adjustment_pricing_rules(profile_id, is_active, priority);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_pricing_rule_conditions_rule ON meal_adjustment_pricing_rule_conditions(rule_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_prod ON product_modifiers(product_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_group ON product_modifiers(group_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_item_product ON product_modifiers(item_product_id, type);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_shift ON transactions(shift_id, status, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transaction_lines_tx ON transaction_lines(transaction_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_line ON order_modifiers(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product ON order_modifiers(item_product_id, charge_reason);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product_semantics ON order_modifiers(item_product_id, action, charge_reason, sort_key);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_source_group ON order_modifiers(source_group_id, item_product_id, charge_reason);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_breakfast_cooking_instructions_line ON breakfast_cooking_instructions(transaction_line_id, sort_key, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_breakfast_cooking_instructions_item ON breakfast_cooking_instructions(item_product_id, instruction_code);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_tx ON payments(transaction_id);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_payment_adjustments_unique_payment ON payment_adjustments(payment_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payment_adjustments_transaction ON payment_adjustments(transaction_id, created_at);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_shift_reconciliations_shift_kind ON shift_reconciliations(shift_id, kind);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shift_reconciliations_counted_at ON shift_reconciliations(counted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_shift ON cash_movements(shift_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_actor ON cash_movements(created_by_user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_print_jobs_status ON print_jobs(status, updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status, opened_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_root_graph_snapshots_tx_uuid ON sync_queue_root_graph_snapshots(transaction_uuid, queue_id);',
    );
    // SQLite partial unique index destegi oldugu icin tek-acik-shift kurali DB seviyesinde enforce edilir.
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_shifts_single_open ON shifts(status) WHERE status = 'open';",
    );
  }

  Future<void> _migrateToV2() async {
    await customStatement('PRAGMA foreign_keys = OFF;');

    try {
      await customStatement(
        'ALTER TABLE shifts ADD COLUMN cashier_previewed_by INTEGER NULL;',
      );
      await customStatement(
        'ALTER TABLE shifts ADD COLUMN cashier_previewed_at INTEGER NULL;',
      );

      await customStatement('''
        CREATE TABLE users_v2 (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NULL,
          password TEXT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');

      await customStatement('''
        INSERT INTO users_v2 (id, name, pin, password, role, is_active, created_at)
        SELECT
          id,
          name,
          pin,
          password,
          CASE
            WHEN role = 'staff' THEN 'cashier'
            ELSE role
          END,
          is_active,
          created_at
        FROM users;
      ''');

      await customStatement('DROP TABLE users;');
      await customStatement('ALTER TABLE users_v2 RENAME TO users;');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV3() async {
    // Reserved migration slot from an abandoned role-naming revision.
    // Intentionally left as a no-op so upgrades do not reintroduce `staff`.
  }

  Future<void> _migrateToV4() async {
    await customStatement('PRAGMA foreign_keys = OFF;');

    try {
      await customStatement('''
        CREATE TABLE users_v4 (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NULL,
          password TEXT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');

      await customStatement('''
        INSERT INTO users_v4 (id, name, pin, password, role, is_active, created_at)
        SELECT
          id,
          name,
          pin,
          password,
          CASE
            WHEN role = 'staff' THEN 'cashier'
            ELSE role
          END,
          is_active,
          created_at
        FROM users;
      ''');

      await customStatement('DROP TABLE users;');
      await customStatement('ALTER TABLE users_v4 RENAME TO users;');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV5() async {
    await customStatement('PRAGMA foreign_keys = OFF;');

    try {
      await customStatement('DROP INDEX IF EXISTS idx_transactions_shift;');
      await customStatement('DROP INDEX IF EXISTS idx_transactions_user;');

      await customStatement('''
        CREATE TABLE transactions_v5 (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          shift_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          table_number INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
          subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
          modifier_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (modifier_total_minor >= 0),
          total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
          created_at INTEGER NOT NULL DEFAULT (unixepoch()),
          paid_at INTEGER NULL,
          updated_at INTEGER NOT NULL,
          cancelled_at INTEGER NULL,
          cancelled_by INTEGER NULL,
          idempotency_key TEXT NOT NULL UNIQUE,
          kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
          receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
        );
      ''');

      await customStatement('''
        INSERT INTO transactions_v5 (
          id,
          uuid,
          shift_id,
          user_id,
          table_number,
          status,
          subtotal_minor,
          modifier_total_minor,
          total_amount_minor,
          created_at,
          paid_at,
          updated_at,
          cancelled_at,
          cancelled_by,
          idempotency_key,
          kitchen_printed,
          receipt_printed
        )
        SELECT
          id,
          uuid,
          shift_id,
          user_id,
          table_number,
          CASE
            WHEN status = 'open' THEN 'sent'
            ELSE status
          END,
          subtotal_minor,
          modifier_total_minor,
          total_amount_minor,
          created_at,
          paid_at,
          updated_at,
          cancelled_at,
          cancelled_by,
          idempotency_key,
          kitchen_printed,
          receipt_printed
        FROM transactions;
      ''');

      await customStatement('DROP TABLE transactions;');
      await customStatement(
        'ALTER TABLE transactions_v5 RENAME TO transactions;',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_shift ON transactions(shift_id, status, created_at);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id, created_at);',
      );
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV6(Migrator _) async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS print_jobs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        target TEXT NOT NULL CHECK (target IN ('kitchen','receipt')),
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','printing','printed','failed')),
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at INTEGER NULL,
        completed_at INTEGER NULL,
        last_error TEXT NULL,
        UNIQUE(transaction_id, target)
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_print_jobs_status ON print_jobs(status, updated_at);',
    );

    await customStatement('''
      INSERT OR IGNORE INTO print_jobs (
        transaction_id,
        target,
        status,
        created_at,
        updated_at,
        completed_at
      )
      SELECT
        id,
        'kitchen',
        CASE
          WHEN kitchen_printed = 1 THEN 'printed'
          ELSE 'pending'
        END,
        updated_at,
        updated_at,
        CASE
          WHEN kitchen_printed = 1 THEN updated_at
          ELSE NULL
        END
      FROM transactions
      WHERE status IN ('sent', 'paid') OR kitchen_printed = 1;
    ''');

    await customStatement('''
      INSERT OR IGNORE INTO print_jobs (
        transaction_id,
        target,
        status,
        created_at,
        updated_at,
        completed_at
      )
      SELECT
        id,
        'receipt',
        CASE
          WHEN receipt_printed = 1 THEN 'printed'
          ELSE 'pending'
        END,
        COALESCE(paid_at, updated_at),
        COALESCE(paid_at, updated_at),
        CASE
          WHEN receipt_printed = 1 THEN COALESCE(paid_at, updated_at)
          ELSE NULL
        END
      FROM transactions
      WHERE status = 'paid';
    ''');
  }

  Future<void> _migrateToV7() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS payment_adjustments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        payment_id INTEGER NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'refund' CHECK (type IN ('refund','reversal')),
        status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        reason TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS shift_reconciliations (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        kind TEXT NOT NULL DEFAULT 'final_close' CHECK (kind IN ('final_close')),
        expected_cash_minor INTEGER NOT NULL CHECK (expected_cash_minor >= 0),
        counted_cash_minor INTEGER NOT NULL CHECK (counted_cash_minor >= 0),
        variance_minor INTEGER NOT NULL,
        counted_by INTEGER NOT NULL,
        counted_at INTEGER NOT NULL DEFAULT (unixepoch()),
        UNIQUE(shift_id, kind)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        actor_id INTEGER NOT NULL,
        action_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_payment_adjustments_unique_payment ON payment_adjustments(payment_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payment_adjustments_transaction ON payment_adjustments(transaction_id, created_at);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_shift_reconciliations_shift_kind ON shift_reconciliations(shift_id, kind);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shift_reconciliations_counted_at ON shift_reconciliations(counted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);',
    );
  }

  Future<void> _migrateToV8() async {
    await customStatement('''
      ALTER TABLE shift_reconciliations
      ADD COLUMN counted_cash_source TEXT NOT NULL DEFAULT 'compatibility_fallback'
      CHECK (counted_cash_source IN ('entered','compatibility_fallback'));
    ''');
  }

  Future<void> _migrateToV9() async {
    await customStatement('''
      ALTER TABLE products
      ADD COLUMN is_visible_on_pos INTEGER NOT NULL DEFAULT 1
      CHECK (is_visible_on_pos IN (0, 1));
    ''');
    await customStatement('DROP INDEX IF EXISTS idx_products_category;');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id, is_active, is_visible_on_pos, sort_order);',
    );
  }

  Future<void> _migrateToV10() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cash_movements (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income','expense')),
        category TEXT NOT NULL CHECK (length(trim(category)) > 0),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        payment_method TEXT NOT NULL CHECK (payment_method IN ('cash','card','other')),
        note TEXT NULL,
        created_by_user_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_shift ON cash_movements(shift_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_actor ON cash_movements(created_by_user_id, created_at);',
    );
  }

  Future<void> _migrateToV11() async {
    final QueryRow legacyAuditRow = await customSelect(
      'SELECT COUNT(*) AS row_count FROM audit_logs WHERE actor_id IS NULL;',
    ).getSingle();
    final int legacyRowsWithoutActor = legacyAuditRow.read<int>('row_count');
    if (legacyRowsWithoutActor > 0) {
      throw DatabaseException(
        'Legacy audit_logs rows without actor_id cannot be migrated to schema v11.',
      );
    }

    await customStatement('PRAGMA foreign_keys = OFF;');
    try {
      await customStatement('DROP INDEX IF EXISTS idx_audit_logs_created_at;');
      await customStatement('DROP INDEX IF EXISTS idx_audit_logs_entity;');
      await customStatement('DROP INDEX IF EXISTS idx_audit_logs_actor;');

      await customStatement(
        'ALTER TABLE audit_logs RENAME TO audit_logs_legacy_v11;',
      );
      // Drift table creation with a real FK on actor_user_id was not reliable
      // on this legacy upgrade path. v12 adds DB-level trigger enforcement for
      // migrated databases so the upgraded table has explicit FK-equivalent
      // protection even when SQLite rebuild syntax differs from fresh creation.
      await customStatement('''
        CREATE TABLE audit_logs (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          actor_user_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (length(trim("action")) > 0),
          entity_type TEXT NOT NULL CHECK (length(trim(entity_type)) > 0),
          entity_id TEXT NOT NULL CHECK (length(trim(entity_id)) > 0),
          metadata_json TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');

      await customStatement('''
        INSERT INTO audit_logs (
          id,
          "actor_user_id",
          "action",
          "entity_type",
          "entity_id",
          "metadata_json",
          "created_at"
        )
        SELECT
          id,
          actor_id,
          action_type,
          entity_type,
          entity_id,
          COALESCE(NULLIF(TRIM(metadata_json), ''), '{}'),
          created_at
        FROM audit_logs_legacy_v11;
      ''');

      await customStatement('DROP TABLE audit_logs_legacy_v11;');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id, created_at);',
      );
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV12() async {
    // Fresh databases already get canonical FK constraints from Drift table
    // definitions. On legacy upgrade paths, rebuilding these tables with inline
    // REFERENCES clauses was not reliable on the SQLite migration path used by
    // this project. v12 therefore makes the mismatch explicit and installs
    // trigger-based FK enforcement for upgraded databases.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_shift ON cash_movements(shift_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_actor ON cash_movements(created_by_user_id, created_at);',
    );
    await _createMigrationFkTrigger(
      table: 'cash_movements',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'cash_movements',
      column: 'created_by_user_id',
      referencedTable: 'users',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id, created_at);',
    );
    await _createMigrationFkTrigger(
      table: 'audit_logs',
      column: 'actor_user_id',
      referencedTable: 'users',
    );
  }

  Future<void> _migrateToV13() async {
    await customStatement('PRAGMA foreign_keys = OFF;');
    try {
      await customStatement(
        'DROP TRIGGER IF EXISTS fk_report_settings_updated_by_insert;',
      );
      await customStatement(
        'DROP TRIGGER IF EXISTS fk_report_settings_updated_by_update;',
      );
      await customStatement(
        'ALTER TABLE report_settings RENAME TO report_settings_legacy_v13;',
      );
      await customStatement('''
        CREATE TABLE report_settings (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          cashier_report_mode TEXT NOT NULL DEFAULT 'percentage'
            CHECK (cashier_report_mode IN ('percentage','cap_amount')),
          visibility_ratio REAL NOT NULL DEFAULT 1.0
            CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
          max_visible_total_minor INTEGER NULL
            CHECK (max_visible_total_minor IS NULL OR max_visible_total_minor >= 0),
          updated_by INTEGER NULL,
          updated_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');

      await customStatement('''
        INSERT INTO report_settings (
          id,
          cashier_report_mode,
          visibility_ratio,
          max_visible_total_minor,
          updated_by,
          updated_at
        )
        SELECT
          id,
          'percentage',
          visibility_ratio,
          NULL,
          updated_by,
          updated_at
        FROM report_settings_legacy_v13;
      ''');

      await customStatement('DROP TABLE report_settings_legacy_v13;');
      await _createMigrationFkTrigger(
        table: 'report_settings',
        column: 'updated_by',
        referencedTable: 'users',
        nullable: true,
      );
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV14() async {
    await customStatement(
      'ALTER TABLE report_settings ADD COLUMN business_name TEXT NULL;',
    );
    await customStatement(
      'ALTER TABLE report_settings ADD COLUMN business_address TEXT NULL;',
    );
  }

  Future<void> _migrateToV15() async {
    await _createSyncRootSnapshotTable();
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_root_graph_snapshots_tx_uuid ON sync_queue_root_graph_snapshots(transaction_uuid, queue_id);',
    );
  }

  Future<void> _createMealCustomizationSnapshotIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_meal_customization_line_snapshots_line ON meal_customization_line_snapshots(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_customization_line_snapshots_lookup ON meal_customization_line_snapshots(product_id, profile_id, customization_key, transaction_line_id);',
    );
  }

  Future<void> _createMealCustomizationSnapshotFkEmulation() async {
    await _createMigrationFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
  }

  Future<void> _migrateToV16() async {
    await customStatement('''
      ALTER TABLE categories
      ADD COLUMN removal_discount_1_minor INTEGER NOT NULL DEFAULT 0
      CHECK (removal_discount_1_minor >= 0);
    ''');
    await customStatement('''
      ALTER TABLE categories
      ADD COLUMN removal_discount_2_minor INTEGER NOT NULL DEFAULT 0
      CHECK (removal_discount_2_minor >= 0);
    ''');

    await customStatement('''
      ALTER TABLE transaction_lines
      ADD COLUMN pricing_mode TEXT NOT NULL DEFAULT 'standard'
      CHECK (pricing_mode IN ('standard','set'));
    ''');
    await customStatement('''
      ALTER TABLE transaction_lines
      ADD COLUMN removal_discount_total_minor INTEGER NOT NULL DEFAULT 0
      CHECK (removal_discount_total_minor >= 0);
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS menu_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        free_swap_limit INTEGER NOT NULL DEFAULT 2 CHECK (free_swap_limit >= 0),
        max_swaps INTEGER NOT NULL DEFAULT 4 CHECK (max_swaps >= 0),
        updated_by INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await _seedDefaultMenuSettings();
    await customStatement('''
      CREATE TABLE IF NOT EXISTS set_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        is_removable INTEGER NOT NULL DEFAULT 1 CHECK (is_removable IN (0, 1)),
        default_quantity INTEGER NOT NULL DEFAULT 1 CHECK (default_quantity > 0),
        sort_order INTEGER NOT NULL DEFAULT 0,
        UNIQUE(product_id, item_product_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS modifier_groups (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        min_select INTEGER NOT NULL DEFAULT 1 CHECK (min_select >= 0),
        max_select INTEGER NOT NULL DEFAULT 1 CHECK (max_select > 0),
        included_quantity INTEGER NOT NULL DEFAULT 1 CHECK (included_quantity > 0),
        sort_order INTEGER NOT NULL DEFAULT 0,
        CHECK (max_select >= min_select),
        UNIQUE(product_id, name)
      );
    ''');

    await customStatement('PRAGMA foreign_keys = OFF;');
    try {
      await customStatement('DROP INDEX IF EXISTS idx_product_modifiers_prod;');
      await customStatement(
        'DROP INDEX IF EXISTS idx_product_modifiers_group;',
      );
      await customStatement(
        'ALTER TABLE product_modifiers RENAME TO product_modifiers_legacy_v16;',
      );
      await customStatement('''
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          group_id INTEGER NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra','choice')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          CHECK ((group_id IS NOT NULL AND type = 'choice') OR (group_id IS NULL AND type IN ('included','extra')))
        );
      ''');
      await customStatement('''
        INSERT INTO product_modifiers (
          id,
          product_id,
          group_id,
          name,
          type,
          extra_price_minor,
          is_active
        )
        SELECT
          id,
          product_id,
          NULL,
          name,
          type,
          extra_price_minor,
          is_active
        FROM product_modifiers_legacy_v16;
      ''');
      await customStatement('DROP TABLE product_modifiers_legacy_v16;');

      await customStatement('DROP INDEX IF EXISTS idx_order_modifiers_line;');
      await customStatement(
        'DROP INDEX IF EXISTS idx_order_modifiers_item_product;',
      );
      await customStatement(
        'ALTER TABLE order_modifiers RENAME TO order_modifiers_legacy_v16;',
      );
      await customStatement('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add','choice')),
          item_name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
          item_product_id INTEGER NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount')),
          CHECK (action != 'choice' OR charge_reason = 'included_choice')
        );
      ''');
      await customStatement('''
        INSERT INTO order_modifiers (
          id,
          uuid,
          transaction_line_id,
          action,
          item_name,
          quantity,
          item_product_id,
          extra_price_minor,
          charge_reason
        )
        SELECT
          id,
          uuid,
          transaction_line_id,
          action,
          item_name,
          1,
          NULL,
          extra_price_minor,
          NULL
        FROM order_modifiers_legacy_v16;
      ''');
      await customStatement('DROP TABLE order_modifiers_legacy_v16;');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_menu_settings_updated_at ON menu_settings(updated_at, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_set_items_product ON set_items(product_id, sort_order, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_modifier_groups_product ON modifier_groups(product_id, sort_order, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_prod ON product_modifiers(product_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_group ON product_modifiers(group_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_line ON order_modifiers(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product ON order_modifiers(item_product_id, charge_reason);',
    );

    await _createMigrationFkTrigger(
      table: 'menu_settings',
      column: 'updated_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'set_items',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'set_items',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'modifier_groups',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'group_id',
      referencedTable: 'modifier_groups',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
  }

  Future<void> _migrateToV17() async {
    final bool hasMaxSwaps = await _tableHasColumn(
      tableName: 'menu_settings',
      columnName: 'max_swaps',
    );
    if (!hasMaxSwaps) {
      await customStatement('''
        ALTER TABLE menu_settings
        ADD COLUMN max_swaps INTEGER NOT NULL DEFAULT 4
        CHECK (max_swaps >= 0);
      ''');
    }

    await _seedDefaultMenuSettings();
  }

  Future<void> _migrateToV18() async {
    await customStatement('PRAGMA foreign_keys = OFF;');
    try {
      await customStatement('DROP INDEX IF EXISTS idx_product_modifiers_prod;');
      await customStatement(
        'DROP INDEX IF EXISTS idx_product_modifiers_group;',
      );
      await customStatement(
        'DROP INDEX IF EXISTS idx_product_modifiers_item_product;',
      );
      await customStatement(
        'ALTER TABLE product_modifiers RENAME TO product_modifiers_legacy_v18;',
      );
      await customStatement('''
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          group_id INTEGER NULL,
          item_product_id INTEGER NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra','choice')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          CHECK ((type = 'choice' AND group_id IS NOT NULL AND item_product_id IS NOT NULL) OR (type IN ('included','extra') AND group_id IS NULL))
        );
      ''');
      await customStatement('''
        INSERT INTO product_modifiers (
          id,
          product_id,
          group_id,
          item_product_id,
          name,
          type,
          extra_price_minor,
          is_active
        )
        SELECT
          id,
          product_id,
          group_id,
          NULL,
          name,
          type,
          extra_price_minor,
          is_active
        FROM product_modifiers_legacy_v18;
      ''');
      await customStatement('DROP TABLE product_modifiers_legacy_v18;');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_prod ON product_modifiers(product_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_group ON product_modifiers(group_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_item_product ON product_modifiers(item_product_id, type);',
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'group_id',
      referencedTable: 'modifier_groups',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
  }

  Future<void> _migrateToV19() async {
    final bool hasOrderModifiersTable = await _tableExists('order_modifiers');
    if (!hasOrderModifiersTable) {
      return;
    }

    await customStatement('PRAGMA foreign_keys = OFF;');
    try {
      await customStatement('DROP INDEX IF EXISTS idx_order_modifiers_line;');
      await customStatement(
        'DROP INDEX IF EXISTS idx_order_modifiers_item_product;',
      );
      await customStatement(
        'DROP INDEX IF EXISTS idx_order_modifiers_item_product_semantics;',
      );
      await customStatement(
        'ALTER TABLE order_modifiers RENAME TO order_modifiers_legacy_v19;',
      );
      await customStatement('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add','choice')),
          item_name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
          item_product_id INTEGER NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount')),
          unit_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0),
          price_effect_minor INTEGER NOT NULL DEFAULT 0 CHECK (price_effect_minor >= 0),
          sort_key INTEGER NOT NULL DEFAULT 0,
          CHECK (action != 'choice' OR charge_reason = 'included_choice')
        );
      ''');
      await customStatement('''
        INSERT INTO order_modifiers (
          id,
          uuid,
          transaction_line_id,
          action,
          item_name,
          quantity,
          item_product_id,
          extra_price_minor,
          charge_reason,
          unit_price_minor,
          price_effect_minor,
          sort_key
        )
        SELECT
          id,
          uuid,
          transaction_line_id,
          action,
          item_name,
          quantity,
          item_product_id,
          extra_price_minor,
          charge_reason,
          extra_price_minor,
          extra_price_minor,
          0
        FROM order_modifiers_legacy_v19;
      ''');
      await customStatement('DROP TABLE order_modifiers_legacy_v19;');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_line ON order_modifiers(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product ON order_modifiers(item_product_id, charge_reason);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product_semantics ON order_modifiers(item_product_id, action, charge_reason, sort_key);',
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'source_group_id',
      referencedTable: 'modifier_groups',
      nullable: true,
    );
  }

  Future<void> _migrateToV20() async {
    final bool hasOrderModifiersTable = await _tableExists('order_modifiers');
    if (!hasOrderModifiersTable) {
      return;
    }

    final bool hasSourceGroupId = await _tableHasColumn(
      tableName: 'order_modifiers',
      columnName: 'source_group_id',
    );
    if (!hasSourceGroupId) {
      await customStatement(
        'ALTER TABLE order_modifiers ADD COLUMN source_group_id INTEGER NULL;',
      );
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_source_group ON order_modifiers(source_group_id, item_product_id, charge_reason);',
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'source_group_id',
      referencedTable: 'modifier_groups',
      nullable: true,
    );
  }

  Future<void> _migrateToV21() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS breakfast_extra_presets (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS breakfast_extra_preset_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        preset_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        UNIQUE(preset_id, item_product_id)
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_breakfast_extra_presets_name ON breakfast_extra_presets(name, updated_at, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_breakfast_extra_preset_items_preset ON breakfast_extra_preset_items(preset_id, sort_order, id);',
    );
    await _createMigrationFkTrigger(
      table: 'breakfast_extra_preset_items',
      column: 'preset_id',
      referencedTable: 'breakfast_extra_presets',
    );
    await _createMigrationFkTrigger(
      table: 'breakfast_extra_preset_items',
      column: 'item_product_id',
      referencedTable: 'products',
    );
  }

  Future<void> _migrateToV22() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS breakfast_cooking_instructions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_line_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        instruction_code TEXT NOT NULL CHECK (length(trim(instruction_code)) > 0),
        instruction_label TEXT NOT NULL CHECK (length(trim(instruction_label)) > 0),
        applied_quantity INTEGER NOT NULL DEFAULT 1 CHECK (applied_quantity > 0),
        sort_key INTEGER NOT NULL DEFAULT 0,
        UNIQUE(transaction_line_id, item_product_id)
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_breakfast_cooking_instructions_line ON breakfast_cooking_instructions(transaction_line_id, sort_key, id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_breakfast_cooking_instructions_item ON breakfast_cooking_instructions(item_product_id, instruction_code);',
    );
    await _createMigrationFkTrigger(
      table: 'breakfast_cooking_instructions',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'breakfast_cooking_instructions',
      column: 'item_product_id',
      referencedTable: 'products',
    );
  }

  Future<void> _migrateToV23() async {
    // Phase 1 meal-adjustment foundation:
    // - add optional product -> profile binding
    // - create profile/components/swaps/extras/pricing tables
    // - keep existing breakfast and flat-modifier flows unchanged
    final bool hasMealAdjustmentProfileId = await _tableHasColumn(
      tableName: 'products',
      columnName: 'meal_adjustment_profile_id',
    );
    if (!hasMealAdjustmentProfileId) {
      await customStatement(
        'ALTER TABLE products ADD COLUMN meal_adjustment_profile_id INTEGER NULL;',
      );
    }

    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_profiles (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NULL,
        free_swap_limit INTEGER NOT NULL DEFAULT 0 CHECK (free_swap_limit >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_profile_components (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        component_key TEXT NOT NULL,
        display_name TEXT NOT NULL,
        default_item_product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        can_remove INTEGER NOT NULL DEFAULT 1 CHECK (can_remove IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        CHECK (length(trim(component_key)) > 0),
        CHECK (length(trim(display_name)) > 0),
        UNIQUE(profile_id, component_key)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_component_options (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        profile_component_id INTEGER NOT NULL,
        option_item_product_id INTEGER NOT NULL,
        option_type TEXT NOT NULL CHECK (option_type IN ('swap')),
        fixed_price_delta_minor INTEGER NULL CHECK (fixed_price_delta_minor IS NULL OR fixed_price_delta_minor >= 0),
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        UNIQUE(profile_component_id, option_item_product_id, option_type)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_profile_extras (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        fixed_price_delta_minor INTEGER NOT NULL CHECK (fixed_price_delta_minor >= 0),
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        UNIQUE(profile_id, item_product_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_pricing_rules (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        rule_type TEXT NOT NULL CHECK (rule_type IN ('remove_only','combo','swap','extra')),
        price_delta_minor INTEGER NOT NULL,
        priority INTEGER NOT NULL DEFAULT 0 CHECK (priority >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS meal_adjustment_pricing_rule_conditions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        rule_id INTEGER NOT NULL,
        condition_type TEXT NOT NULL CHECK (condition_type IN ('removed_component','swap_to_item','extra_item')),
        component_key TEXT NULL,
        item_product_id INTEGER NULL,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        CHECK (
          (condition_type = 'removed_component'
            AND component_key IS NOT NULL
            AND length(trim(component_key)) > 0
            AND item_product_id IS NULL)
          OR
          (condition_type = 'swap_to_item'
            AND component_key IS NOT NULL
            AND length(trim(component_key)) > 0
            AND item_product_id IS NOT NULL)
          OR
          (condition_type = 'extra_item'
            AND component_key IS NULL
            AND item_product_id IS NOT NULL)
        )
      );
    ''');

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_products_meal_adjustment_profile ON products(meal_adjustment_profile_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_profile_components_profile ON meal_adjustment_profile_components(profile_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_component_options_component ON meal_adjustment_component_options(profile_component_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_profile_extras_profile ON meal_adjustment_profile_extras(profile_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_pricing_rules_profile ON meal_adjustment_pricing_rules(profile_id, is_active, priority);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_adjustment_pricing_rule_conditions_rule ON meal_adjustment_pricing_rule_conditions(rule_id);',
    );

    await _createMigrationFkTrigger(
      table: 'products',
      column: 'meal_adjustment_profile_id',
      referencedTable: 'meal_adjustment_profiles',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_profile_components',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_profile_components',
      column: 'default_item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_component_options',
      column: 'profile_component_id',
      referencedTable: 'meal_adjustment_profile_components',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_component_options',
      column: 'option_item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_profile_extras',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_profile_extras',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_pricing_rules',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_pricing_rule_conditions',
      column: 'rule_id',
      referencedTable: 'meal_adjustment_pricing_rules',
    );
    await _createMigrationFkTrigger(
      table: 'meal_adjustment_pricing_rule_conditions',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
  }

  Future<void> _migrateToV24() async {
    // Phase 3 meal-adjustment order integration:
    // - allow signed transaction modifier totals so discount rows can persist
    // - allow signed order_modifiers.price_effect_minor for semantic discounts
    // - add combo_discount as a first-class semantic charge reason
    await customStatement('PRAGMA foreign_keys = OFF;');

    try {
      await customStatement('DROP INDEX IF EXISTS idx_transactions_shift;');
      await customStatement('DROP INDEX IF EXISTS idx_transactions_user;');
      await customStatement('ALTER TABLE transactions RENAME TO transactions_legacy_v24;');
      await customStatement('''
        CREATE TABLE transactions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          shift_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          table_number INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
          subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
          modifier_total_minor INTEGER NOT NULL DEFAULT 0,
          total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
          created_at INTEGER NOT NULL DEFAULT (unixepoch()),
          paid_at INTEGER NULL,
          updated_at INTEGER NOT NULL,
          cancelled_at INTEGER NULL,
          cancelled_by INTEGER NULL,
          idempotency_key TEXT NOT NULL UNIQUE,
          kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
          receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
        );
      ''');
      await customStatement('''
        INSERT INTO transactions (
          id,
          uuid,
          shift_id,
          user_id,
          table_number,
          status,
          subtotal_minor,
          modifier_total_minor,
          total_amount_minor,
          created_at,
          paid_at,
          updated_at,
          cancelled_at,
          cancelled_by,
          idempotency_key,
          kitchen_printed,
          receipt_printed
        )
        SELECT
          id,
          uuid,
          shift_id,
          user_id,
          table_number,
          status,
          subtotal_minor,
          modifier_total_minor,
          total_amount_minor,
          created_at,
          paid_at,
          updated_at,
          cancelled_at,
          cancelled_by,
          idempotency_key,
          kitchen_printed,
          receipt_printed
        FROM transactions_legacy_v24;
      ''');
      await customStatement('DROP TABLE transactions_legacy_v24;');

      await customStatement('DROP INDEX IF EXISTS idx_order_modifiers_line;');
      await customStatement('DROP INDEX IF EXISTS idx_order_modifiers_item_product;');
      await customStatement('DROP INDEX IF EXISTS idx_order_modifiers_item_product_semantics;');
      await customStatement('DROP INDEX IF EXISTS idx_order_modifiers_source_group;');
      await customStatement('ALTER TABLE order_modifiers RENAME TO order_modifiers_legacy_v24;');
      await customStatement('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add','choice')),
          item_name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
          item_product_id INTEGER NULL,
          source_group_id INTEGER NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount','combo_discount')),
          unit_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0),
          price_effect_minor INTEGER NOT NULL DEFAULT 0,
          sort_key INTEGER NOT NULL DEFAULT 0,
          CHECK (action != 'choice' OR charge_reason = 'included_choice')
        );
      ''');
      await customStatement('''
        INSERT INTO order_modifiers (
          id,
          uuid,
          transaction_line_id,
          action,
          item_name,
          quantity,
          item_product_id,
          source_group_id,
          extra_price_minor,
          charge_reason,
          unit_price_minor,
          price_effect_minor,
          sort_key
        )
        SELECT
          id,
          uuid,
          transaction_line_id,
          action,
          item_name,
          quantity,
          item_product_id,
          source_group_id,
          extra_price_minor,
          charge_reason,
          unit_price_minor,
          price_effect_minor,
          sort_key
        FROM order_modifiers_legacy_v24;
      ''');
      await customStatement('DROP TABLE order_modifiers_legacy_v24;');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_shift ON transactions(shift_id, status, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_line ON order_modifiers(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product ON order_modifiers(item_product_id, charge_reason);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product_semantics ON order_modifiers(item_product_id, action, charge_reason, sort_key);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_source_group ON order_modifiers(source_group_id, item_product_id, charge_reason);',
    );

    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'user_id',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'cancelled_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'source_group_id',
      referencedTable: 'modifier_groups',
      nullable: true,
    );
  }

  Future<void> _migrateToV25() async {
    await _createMealCustomizationSnapshotSchema();
    await _createMealCustomizationSnapshotIndexes();
    await _createMealCustomizationSnapshotFkEmulation();
  }

  Future<void> _createSyncRootSnapshotTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_queue_root_graph_snapshots (
        queue_id INTEGER NOT NULL PRIMARY KEY,
        transaction_uuid TEXT NOT NULL,
        graph_checksum TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
  }

  Future<void> _createMigrationFkTrigger({
    required String table,
    required String column,
    required String referencedTable,
    bool nullable = false,
  }) async {
    final String condition =
        '${nullable ? 'NEW.$column IS NOT NULL AND ' : ''}'
        '(SELECT id FROM $referencedTable WHERE id = NEW.$column) IS NULL';
    final String message = 'fk_$table.$column->$referencedTable.id';

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS fk_${table}_${column}_insert
      BEFORE INSERT ON $table
      FOR EACH ROW
      WHEN $condition
      BEGIN
        SELECT RAISE(ABORT, '$message');
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS fk_${table}_${column}_update
      BEFORE UPDATE OF $column ON $table
      FOR EACH ROW
      WHEN $condition
      BEGIN
        SELECT RAISE(ABORT, '$message');
      END;
    ''');
  }

  Future<void> _seedDefaultMenuSettings() async {
    await customStatement('''
      INSERT INTO menu_settings (
        free_swap_limit,
        max_swaps,
        updated_by,
        updated_at
      )
      SELECT 2, 4, NULL, unixepoch()
      WHERE NOT EXISTS (SELECT 1 FROM menu_settings);
    ''');
  }

  Future<bool> _tableHasColumn({
    required String tableName,
    required String columnName,
  }) async {
    final List<QueryRow> rows = await customSelect(
      'PRAGMA table_info($tableName)',
    ).get();
    return rows.any((QueryRow row) => row.read<String>('name') == columnName);
  }

  Future<bool> _tableExists(String tableName) async {
    final QueryRow? row = await customSelect(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name = ?
      ''',
      variables: <Variable<Object>>[Variable<String>(tableName)],
    ).getSingleOrNull();
    return row != null;
  }

  Future<void> _runMigrationStep({
    required String step,
    required int fromVersion,
    required int toVersion,
    required Future<void> Function() action,
  }) async {
    _migrationHistory.add(
      MigrationLogEntry(
        timestamp: DateTime.now().toUtc(),
        step: step,
        fromVersion: fromVersion,
        toVersion: toVersion,
        status: MigrationLogStatus.started,
        message: null,
      ),
    );

    try {
      await action();
      _migrationHistory.add(
        MigrationLogEntry(
          timestamp: DateTime.now().toUtc(),
          step: step,
          fromVersion: fromVersion,
          toVersion: toVersion,
          status: MigrationLogStatus.succeeded,
          message: null,
        ),
      );
    } catch (error) {
      final MigrationLogEntry failure = MigrationLogEntry(
        timestamp: DateTime.now().toUtc(),
        step: step,
        fromVersion: fromVersion,
        toVersion: toVersion,
        status: MigrationLogStatus.failed,
        message: error.toString(),
      );
      _migrationHistory.add(failure);
      _lastMigrationFailure = failure;
      rethrow;
    }
  }

  static Future<File> resolveDefaultDatabaseFile() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final File databaseFile = File(
      p.join(documentsDirectory.path, 'epos.sqlite'),
    );
    debugPrint('[AppDatabase] Resolved SQLite path: ${databaseFile.path}');
    return databaseFile;
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final File databaseFile = await AppDatabase.resolveDefaultDatabaseFile();

    return NativeDatabase.createInBackground(databaseFile);
  });
}
