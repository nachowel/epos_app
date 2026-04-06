import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/domain/models/cash_movement.dart';
import 'package:epos_app/domain/models/print_job.dart';

AppDatabase createTestDatabase() => _TestAppDatabase();

AppDatabase createPersistentTestDatabase(String path) =>
    _TestAppDatabase(NativeDatabase(File(path)));

class _TestAppDatabase extends AppDatabase {
  _TestAppDatabase([QueryExecutor? executor])
    : super(executor ?? NativeDatabase.memory());

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator _) async {
      await _createTables();
      await _createIndexes();
      await _createForeignKeyEmulation();
    },
    onUpgrade: (_, __, ___) async {
      throw UnsupportedError('Test migrations not implemented.');
    },
    beforeOpen: (OpeningDetails _) async {
      await customStatement('PRAGMA foreign_keys = OFF;');
    },
  );

  Future<void> _createTables() async {
    await customStatement('''
      CREATE TABLE users (
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
      CREATE TABLE categories (
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
      CREATE TABLE products (
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
      CREATE TABLE meal_adjustment_profiles (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NULL,
        profile_kind TEXT NOT NULL DEFAULT 'standard' CHECK (profile_kind IN ('standard','sandwich')),
        free_swap_limit INTEGER NOT NULL DEFAULT 0 CHECK (free_swap_limit >= 0),
        sandwich_surcharge_minor INTEGER NOT NULL DEFAULT 100 CHECK (sandwich_surcharge_minor >= 0),
        baguette_surcharge_minor INTEGER NOT NULL DEFAULT 180 CHECK (baguette_surcharge_minor >= 0),
        sandwich_sauce_options_json TEXT NOT NULL DEFAULT '["ketchup","mayo","brownSauce","chilliSauce"]',
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE meal_adjustment_profile_components (
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
      CREATE TABLE meal_adjustment_component_options (
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
      CREATE TABLE meal_adjustment_profile_extras (
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
      CREATE TABLE meal_adjustment_pricing_rules (
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
      CREATE TABLE meal_adjustment_pricing_rule_conditions (
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
      CREATE TABLE breakfast_extra_presets (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE breakfast_extra_preset_items (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        preset_id INTEGER NOT NULL,
        item_product_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
        UNIQUE(preset_id, item_product_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE menu_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        free_swap_limit INTEGER NOT NULL DEFAULT 2 CHECK (free_swap_limit >= 0),
        max_swaps INTEGER NOT NULL DEFAULT 4 CHECK (max_swaps >= 0),
        updated_by INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
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
    await customStatement('''
      CREATE TABLE set_items (
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
      CREATE TABLE modifier_groups (
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
      CREATE TABLE product_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        group_id INTEGER NULL,
        item_product_id INTEGER NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('included','extra','choice')),
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        CHECK ((type = 'choice' AND group_id IS NOT NULL) OR (type IN ('included','extra') AND group_id IS NULL))
      );
    ''');
    await customStatement('''
      CREATE TABLE shifts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        opened_by INTEGER NOT NULL,
        opened_at INTEGER NOT NULL DEFAULT (unixepoch()),
        closed_by INTEGER NULL,
        closed_at INTEGER NULL,
        cashier_previewed_by INTEGER NULL,
        cashier_previewed_at INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
      );
    ''');
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
      CREATE TABLE transaction_lines (
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
      CREATE TABLE meal_customization_line_snapshots (
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
      CREATE TABLE breakfast_cooking_instructions (
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
      CREATE TABLE payments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL UNIQUE,
        method TEXT NOT NULL CHECK (method IN ('cash','card')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        paid_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE payment_adjustments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        payment_id INTEGER NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'refund' CHECK (type IN ('refund','reversal')),
        status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        reason TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        UNIQUE(payment_id)
      );
    ''');
    await customStatement('''
      CREATE TABLE shift_reconciliations (
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
      CREATE TABLE cash_movements (
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
      CREATE TABLE audit_logs (
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
      CREATE TABLE print_jobs (
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
      CREATE TABLE report_settings (
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
      CREATE TABLE printer_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        device_name TEXT NOT NULL,
        device_address TEXT NOT NULL,
        paper_width INTEGER NOT NULL DEFAULT 80 CHECK (paper_width IN (58,80)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
    await customStatement('''
      CREATE TABLE sync_queue (
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
    await customStatement('''
      CREATE TABLE sync_queue_root_graph_snapshots (
        queue_id INTEGER NOT NULL PRIMARY KEY,
        transaction_uuid TEXT NOT NULL,
        graph_checksum TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
  }

  Future<void> _createIndexes() async {
    await customStatement(
      "CREATE UNIQUE INDEX ux_shifts_single_open ON shifts(status) WHERE status = 'open';",
    );
    await customStatement(
      'CREATE INDEX idx_breakfast_extra_presets_name ON breakfast_extra_presets(name, updated_at, id);',
    );
    await customStatement(
      'CREATE INDEX idx_breakfast_extra_preset_items_preset ON breakfast_extra_preset_items(preset_id, sort_order, id);',
    );
    await customStatement(
      'CREATE INDEX idx_menu_settings_updated_at ON menu_settings(updated_at, id);',
    );
    await customStatement(
      'CREATE INDEX idx_set_items_product ON set_items(product_id, sort_order, id);',
    );
    await customStatement(
      'CREATE INDEX idx_modifier_groups_product ON modifier_groups(product_id, sort_order, id);',
    );
    await customStatement(
      'CREATE INDEX idx_products_category ON products(category_id, is_active, is_visible_on_pos, sort_order);',
    );
    await customStatement(
      'CREATE INDEX idx_products_meal_adjustment_profile ON products(meal_adjustment_profile_id);',
    );
    await customStatement(
      'CREATE INDEX idx_meal_adjustment_profile_components_profile ON meal_adjustment_profile_components(profile_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX idx_meal_adjustment_component_options_component ON meal_adjustment_component_options(profile_component_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX idx_meal_adjustment_profile_extras_profile ON meal_adjustment_profile_extras(profile_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX idx_meal_adjustment_pricing_rules_profile ON meal_adjustment_pricing_rules(profile_id, is_active, priority);',
    );
    await customStatement(
      'CREATE INDEX idx_meal_adjustment_pricing_rule_conditions_rule ON meal_adjustment_pricing_rule_conditions(rule_id);',
    );
    await customStatement(
      'CREATE INDEX idx_product_modifiers_prod ON product_modifiers(product_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX idx_product_modifiers_group ON product_modifiers(group_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX idx_product_modifiers_item_product ON product_modifiers(item_product_id, type);',
    );
    await customStatement(
      'CREATE INDEX idx_transactions_shift ON transactions(shift_id, status, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_transactions_user ON transactions(user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_transaction_lines_tx ON transaction_lines(transaction_id);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX ux_meal_customization_line_snapshots_line ON meal_customization_line_snapshots(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX idx_meal_customization_line_snapshots_lookup ON meal_customization_line_snapshots(product_id, profile_id, customization_key, transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX idx_order_modifiers_line ON order_modifiers(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX idx_order_modifiers_item_product ON order_modifiers(item_product_id, charge_reason);',
    );
    await customStatement(
      'CREATE INDEX idx_order_modifiers_item_product_semantics ON order_modifiers(item_product_id, action, charge_reason, sort_key);',
    );
    await customStatement(
      'CREATE INDEX idx_order_modifiers_source_group ON order_modifiers(source_group_id, item_product_id, charge_reason);',
    );
    await customStatement(
      'CREATE INDEX idx_breakfast_cooking_instructions_line ON breakfast_cooking_instructions(transaction_line_id, sort_key, id);',
    );
    await customStatement(
      'CREATE INDEX idx_breakfast_cooking_instructions_item ON breakfast_cooking_instructions(item_product_id, instruction_code);',
    );
    await customStatement(
      'CREATE INDEX idx_payments_tx ON payments(transaction_id);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX ux_payment_adjustments_unique_payment ON payment_adjustments(payment_id);',
    );
    await customStatement(
      'CREATE INDEX idx_payment_adjustments_transaction ON payment_adjustments(transaction_id, created_at);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX ux_shift_reconciliations_shift_kind ON shift_reconciliations(shift_id, kind);',
    );
    await customStatement(
      'CREATE INDEX idx_shift_reconciliations_counted_at ON shift_reconciliations(counted_at);',
    );
    await customStatement(
      'CREATE INDEX idx_cash_movements_shift ON cash_movements(shift_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_cash_movements_actor ON cash_movements(created_by_user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_print_jobs_status ON print_jobs(status, updated_at);',
    );
    await customStatement(
      'CREATE INDEX idx_shifts_status ON shifts(status, opened_at);',
    );
    await customStatement(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(status, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_sync_queue_root_graph_snapshots_tx_uuid ON sync_queue_root_graph_snapshots(transaction_uuid, queue_id);',
    );
  }

  Future<void> _createForeignKeyEmulation() async {
    await _createFkTrigger(
      table: 'breakfast_extra_preset_items',
      column: 'preset_id',
      referencedTable: 'breakfast_extra_presets',
    );
    await _createFkTrigger(
      table: 'breakfast_extra_preset_items',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'products',
      column: 'category_id',
      referencedTable: 'categories',
    );
    await _createFkTrigger(
      table: 'products',
      column: 'meal_adjustment_profile_id',
      referencedTable: 'meal_adjustment_profiles',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'meal_adjustment_profile_components',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createFkTrigger(
      table: 'meal_adjustment_profile_components',
      column: 'default_item_product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'meal_adjustment_component_options',
      column: 'profile_component_id',
      referencedTable: 'meal_adjustment_profile_components',
    );
    await _createFkTrigger(
      table: 'meal_adjustment_component_options',
      column: 'option_item_product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'meal_adjustment_profile_extras',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createFkTrigger(
      table: 'meal_adjustment_profile_extras',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'meal_adjustment_pricing_rules',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createFkTrigger(
      table: 'meal_adjustment_pricing_rule_conditions',
      column: 'rule_id',
      referencedTable: 'meal_adjustment_pricing_rules',
    );
    await _createFkTrigger(
      table: 'meal_adjustment_pricing_rule_conditions',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'menu_settings',
      column: 'updated_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'set_items',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'set_items',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'modifier_groups',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'product_modifiers',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'product_modifiers',
      column: 'group_id',
      referencedTable: 'modifier_groups',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'product_modifiers',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'shifts',
      column: 'opened_by',
      referencedTable: 'users',
    );
    await _createFkTrigger(
      table: 'shifts',
      column: 'closed_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'shifts',
      column: 'cashier_previewed_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'transactions',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createFkTrigger(
      table: 'transactions',
      column: 'user_id',
      referencedTable: 'users',
    );
    await _createFkTrigger(
      table: 'transactions',
      column: 'cancelled_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'transaction_lines',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createFkTrigger(
      table: 'transaction_lines',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'meal_customization_line_snapshots',
      column: 'profile_id',
      referencedTable: 'meal_adjustment_profiles',
    );
    await _createFkTrigger(
      table: 'order_modifiers',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createFkTrigger(
      table: 'order_modifiers',
      column: 'item_product_id',
      referencedTable: 'products',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'order_modifiers',
      column: 'source_group_id',
      referencedTable: 'modifier_groups',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'breakfast_cooking_instructions',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createFkTrigger(
      table: 'breakfast_cooking_instructions',
      column: 'item_product_id',
      referencedTable: 'products',
    );
    await _createFkTrigger(
      table: 'payments',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createFkTrigger(
      table: 'payment_adjustments',
      column: 'payment_id',
      referencedTable: 'payments',
    );
    await _createFkTrigger(
      table: 'payment_adjustments',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createFkTrigger(
      table: 'payment_adjustments',
      column: 'created_by',
      referencedTable: 'users',
    );
    await _createFkTrigger(
      table: 'shift_reconciliations',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createFkTrigger(
      table: 'shift_reconciliations',
      column: 'counted_by',
      referencedTable: 'users',
    );
    await _createFkTrigger(
      table: 'cash_movements',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createFkTrigger(
      table: 'cash_movements',
      column: 'created_by_user_id',
      referencedTable: 'users',
    );
    await _createFkTrigger(
      table: 'print_jobs',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createFkTrigger(
      table: 'report_settings',
      column: 'updated_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createFkTrigger(
      table: 'audit_logs',
      column: 'actor_user_id',
      referencedTable: 'users',
    );
  }

  Future<void> _createFkTrigger({
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
      CREATE TRIGGER fk_${table}_${column}_insert
      BEFORE INSERT ON $table
      FOR EACH ROW
      WHEN $condition
      BEGIN
        SELECT RAISE(ABORT, '$message');
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER fk_${table}_${column}_update
      BEFORE UPDATE OF $column ON $table
      FOR EACH ROW
      WHEN $condition
      BEGIN
        SELECT RAISE(ABORT, '$message');
      END;
    ''');
  }
}

Future<int> insertUser(
  AppDatabase db, {
  required String name,
  required String role,
  String? pin,
  String? password,
  bool isActive = true,
}) {
  return db
      .into(db.users)
      .insert(
        UsersCompanion.insert(
          name: name,
          role: role,
          pin: Value<String?>(pin),
          password: Value<String?>(password),
          isActive: Value<bool>(isActive),
        ),
      );
}

Future<int> insertShift(
  AppDatabase db, {
  required int openedBy,
  String status = 'open',
  int? closedBy,
  DateTime? closedAt,
  int? cashierPreviewedBy,
  DateTime? cashierPreviewedAt,
}) {
  return db
      .into(db.shifts)
      .insert(
        ShiftsCompanion.insert(
          openedBy: openedBy,
          status: Value<String>(status),
          closedBy: Value<int?>(closedBy),
          closedAt: Value<DateTime?>(closedAt),
          cashierPreviewedBy: Value<int?>(cashierPreviewedBy),
          cashierPreviewedAt: Value<DateTime?>(cashierPreviewedAt),
        ),
      );
}

Future<int> insertCategory(
  AppDatabase db, {
  required String name,
  int sortOrder = 0,
  bool isActive = true,
}) {
  return db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          name: name,
          sortOrder: Value<int>(sortOrder),
          isActive: Value<bool>(isActive),
        ),
      );
}

Future<int> insertProduct(
  AppDatabase db, {
  required int categoryId,
  required String name,
  required int priceMinor,
  int? mealAdjustmentProfileId,
  bool hasModifiers = false,
  int sortOrder = 0,
  bool isActive = true,
  bool isVisibleOnPos = true,
}) {
  return db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          categoryId: categoryId,
          name: name,
          priceMinor: priceMinor,
          mealAdjustmentProfileId: Value<int?>(mealAdjustmentProfileId),
          hasModifiers: Value<bool>(hasModifiers),
          sortOrder: Value<int>(sortOrder),
          isActive: Value<bool>(isActive),
          isVisibleOnPos: Value<bool>(isVisibleOnPos),
        ),
      );
}

Future<int> insertPrinterSettings(
  AppDatabase db, {
  required String deviceName,
  required String deviceAddress,
  int paperWidth = 80,
  bool isActive = true,
}) {
  return db
      .into(db.printerSettings)
      .insert(
        PrinterSettingsCompanion.insert(
          deviceName: deviceName,
          deviceAddress: deviceAddress,
          paperWidth: Value<int>(paperWidth),
          isActive: Value<bool>(isActive),
        ),
      );
}

Future<int> insertTransaction(
  AppDatabase db, {
  required String uuid,
  required int shiftId,
  required int userId,
  required String status,
  required int totalAmountMinor,
  String? idempotencyKey,
  int? tableNumber,
  DateTime? updatedAt,
  DateTime? paidAt,
  DateTime? cancelledAt,
  int? cancelledBy,
}) {
  final DateTime now = updatedAt ?? DateTime.now();
  return db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          uuid: uuid,
          shiftId: shiftId,
          userId: userId,
          tableNumber: Value<int?>(tableNumber),
          idempotencyKey: idempotencyKey ?? 'idem-$uuid',
          updatedAt: now,
          status: Value<String>(status),
          subtotalMinor: Value<int>(totalAmountMinor),
          modifierTotalMinor: const Value<int>(0),
          totalAmountMinor: Value<int>(totalAmountMinor),
          paidAt: Value<DateTime?>(paidAt),
          cancelledAt: Value<DateTime?>(cancelledAt),
          cancelledBy: Value<int?>(cancelledBy),
        ),
      );
}

Future<int> insertSyncQueueItem(
  AppDatabase db, {
  required String tableName,
  required String recordUuid,
  String status = 'pending',
  int attemptCount = 0,
  String? errorMessage,
}) {
  return db
      .into(db.syncQueue)
      .insert(
        SyncQueueCompanion.insert(
          queueTableName: tableName,
          recordUuid: recordUuid,
          status: Value<String>(status),
          attemptCount: Value<int>(attemptCount),
          errorMessage: Value<String?>(errorMessage),
        ),
      );
}

Future<int> insertPayment(
  AppDatabase db, {
  required String uuid,
  required int transactionId,
  required String method,
  required int amountMinor,
  DateTime? paidAt,
}) {
  return db
      .into(db.payments)
      .insert(
        PaymentsCompanion.insert(
          uuid: uuid,
          transactionId: transactionId,
          method: method,
          amountMinor: amountMinor,
          paidAt: Value<DateTime>(paidAt ?? DateTime.now()),
        ),
      );
}

Future<int> insertPaymentAdjustment(
  AppDatabase db, {
  required String uuid,
  required int paymentId,
  required int transactionId,
  String type = 'refund',
  String status = 'completed',
  required int amountMinor,
  required String reason,
  required int createdBy,
  DateTime? createdAt,
}) {
  return db
      .into(db.paymentAdjustments)
      .insert(
        PaymentAdjustmentsCompanion.insert(
          uuid: uuid,
          paymentId: paymentId,
          transactionId: transactionId,
          type: Value<String>(type),
          status: Value<String>(status),
          amountMinor: amountMinor,
          reason: reason,
          createdBy: createdBy,
          createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
        ),
      );
}

Future<int> insertShiftReconciliation(
  AppDatabase db, {
  required String uuid,
  required int shiftId,
  String kind = 'final_close',
  required int expectedCashMinor,
  required int countedCashMinor,
  required int varianceMinor,
  String countedCashSource = 'entered',
  required int countedBy,
  DateTime? countedAt,
}) {
  return db
      .into(db.shiftReconciliations)
      .insert(
        ShiftReconciliationsCompanion.insert(
          uuid: uuid,
          shiftId: shiftId,
          kind: Value<String>(kind),
          expectedCashMinor: expectedCashMinor,
          countedCashMinor: countedCashMinor,
          varianceMinor: varianceMinor,
          countedCashSource: Value<String>(countedCashSource),
          countedBy: countedBy,
          countedAt: Value<DateTime>(countedAt ?? DateTime.now()),
        ),
      );
}

Future<int> insertCashMovement(
  AppDatabase db, {
  required int shiftId,
  required CashMovementType type,
  required String category,
  required int amountMinor,
  required CashMovementPaymentMethod paymentMethod,
  String? note,
  required int createdByUserId,
  DateTime? createdAt,
}) {
  return db
      .into(db.cashMovements)
      .insert(
        CashMovementsCompanion.insert(
          shiftId: shiftId,
          type: _cashMovementTypeToDb(type),
          category: category,
          amountMinor: amountMinor,
          paymentMethod: _cashMovementPaymentMethodToDb(paymentMethod),
          note: Value<String?>(note),
          createdByUserId: createdByUserId,
          createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
        ),
      );
}

Future<int> insertPrintJob(
  AppDatabase db, {
  required int transactionId,
  required PrintJobTarget target,
  String status = 'pending',
  int attemptCount = 0,
  DateTime? lastAttemptAt,
  DateTime? completedAt,
  String? lastError,
}) {
  return db
      .into(db.printJobs)
      .insert(
        PrintJobsCompanion.insert(
          transactionId: transactionId,
          target: target == PrintJobTarget.kitchen ? 'kitchen' : 'receipt',
          status: Value<String>(status),
          attemptCount: Value<int>(attemptCount),
          lastAttemptAt: Value<DateTime?>(lastAttemptAt),
          completedAt: Value<DateTime?>(completedAt),
          lastError: Value<String?>(lastError),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
}

String _cashMovementTypeToDb(CashMovementType value) {
  switch (value) {
    case CashMovementType.income:
      return 'income';
    case CashMovementType.expense:
      return 'expense';
  }
}

String _cashMovementPaymentMethodToDb(CashMovementPaymentMethod value) {
  switch (value) {
    case CashMovementPaymentMethod.cash:
      return 'cash';
    case CashMovementPaymentMethod.card:
      return 'card';
    case CashMovementPaymentMethod.other:
      return 'other';
  }
}
