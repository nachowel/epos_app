import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/business_identity_settings.dart';
import '../../domain/models/cashier_z_report_settings.dart';
import '../../domain/models/printer_settings.dart';
import '../../domain/models/report_settings_policy.dart';
import '../database/app_database.dart' as db;

class SettingsRepository {
  const SettingsRepository(this._database);

  final db.AppDatabase _database;

  Future<ReportSettingsPolicy> getReportSettingsPolicy() async {
    return (await getCashierZReportSettings()).policy;
  }

  Future<BusinessIdentitySettings> getBusinessIdentitySettings() async {
    return (await getCashierZReportSettings()).businessIdentity;
  }

  Future<CashierZReportSettings> getCashierZReportSettings() async {
    final db.ReportSetting? row = await _getOrCreateReportSettingsRow();
    if (row == null) {
      return const CashierZReportSettings.defaults();
    }
    return CashierZReportSettings(
      policy: _mapReportSettings(row),
      businessIdentity: _mapBusinessIdentity(row),
    );
  }

  Future<double> getVisibilityRatio() async {
    return (await getReportSettingsPolicy()).visibilityRatio;
  }

  Future<void> updateVisibilityRatio(
    double ratio, {
    required int userId,
  }) async {
    if (ratio < 0.0 || ratio > 1.0) {
      throw ValidationException('visibility ratio must be between 0.0 and 1.0');
    }

    await _database.transaction(() async {
      final db.ReportSetting? row = await _getOrCreateReportSettingsRow();
      final DateTime now = DateTime.now();

      if (row == null) {
        await _database
            .into(_database.reportSettings)
            .insert(
              db.ReportSettingsCompanion.insert(
                cashierReportMode: Value<String>(
                  CashierReportMode.percentage.dbValue,
                ),
                visibilityRatio: Value<double>(ratio),
                maxVisibleTotalMinor: const Value<int?>.absent(),
                updatedBy: Value<int?>(userId),
                updatedAt: Value<DateTime>(now),
              ),
            );
        return;
      }

      await (_database.update(
        _database.reportSettings,
      )..where((db.$ReportSettingsTable t) => t.id.equals(row.id))).write(
        db.ReportSettingsCompanion(
          cashierReportMode: Value<String>(row.cashierReportMode),
          visibilityRatio: Value<double>(ratio),
          maxVisibleTotalMinor: Value<int?>(row.maxVisibleTotalMinor),
          updatedBy: Value<int?>(userId),
          updatedAt: Value<DateTime>(now),
        ),
      );
    });
  }

  Future<void> updateReportSettingsPolicy(
    ReportSettingsPolicy policy, {
    required int userId,
  }) async {
    final CashierZReportSettings existing = await getCashierZReportSettings();
    await updateCashierZReportSettings(
      existing.copyWith(policy: policy),
      userId: userId,
    );
  }

  Future<void> updateBusinessIdentitySettings(
    BusinessIdentitySettings identity, {
    required int userId,
  }) async {
    final CashierZReportSettings existing = await getCashierZReportSettings();
    await updateCashierZReportSettings(
      existing.copyWith(businessIdentity: identity),
      userId: userId,
    );
  }

  Future<void> updateCashierZReportSettings(
    CashierZReportSettings settings, {
    required int userId,
  }) async {
    _validatePolicy(settings.policy);
    final String? normalizedBusinessName = _normalizeNullableText(
      settings.businessIdentity.businessName,
    );
    final String? normalizedBusinessAddress = _normalizeNullableText(
      settings.businessIdentity.businessAddress,
    );

    await _database.transaction(() async {
      final db.ReportSetting? row = await _getOrCreateReportSettingsRow();
      final DateTime now = DateTime.now();

      if (row == null) {
        await _database
            .into(_database.reportSettings)
            .insert(
              db.ReportSettingsCompanion.insert(
                cashierReportMode: Value<String>(
                  settings.policy.cashierReportMode.dbValue,
                ),
                visibilityRatio: Value<double>(settings.policy.visibilityRatio),
                maxVisibleTotalMinor: Value<int?>(
                  settings.policy.maxVisibleTotalMinor,
                ),
                businessName: Value<String?>(normalizedBusinessName),
                businessAddress: Value<String?>(normalizedBusinessAddress),
                updatedBy: Value<int?>(userId),
                updatedAt: Value<DateTime>(now),
              ),
            );
        return;
      }

      await (_database.update(
        _database.reportSettings,
      )..where((db.$ReportSettingsTable t) => t.id.equals(row.id))).write(
        db.ReportSettingsCompanion(
          cashierReportMode: Value<String>(
            settings.policy.cashierReportMode.dbValue,
          ),
          visibilityRatio: Value<double>(settings.policy.visibilityRatio),
          maxVisibleTotalMinor: Value<int?>(
            settings.policy.maxVisibleTotalMinor,
          ),
          businessName: Value<String?>(normalizedBusinessName),
          businessAddress: Value<String?>(normalizedBusinessAddress),
          updatedBy: Value<int?>(userId),
          updatedAt: Value<DateTime>(now),
        ),
      );
    });
  }

  Future<PrinterSettingsModel?> getActivePrinterSettings() async {
    final db.PrinterSetting? row =
        await (_database.select(_database.printerSettings)
              ..where((db.$PrinterSettingsTable t) => t.isActive.equals(true))
              ..orderBy(<OrderingTerm Function(db.$PrinterSettingsTable)>[
                (db.$PrinterSettingsTable t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();

    return row == null ? null : _mapPrinter(row);
  }

  Future<void> savePrinterSettings({
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
  }) async {
    if (paperWidth != 58 && paperWidth != 80) {
      throw ValidationException('paperWidth must be 58 or 80.');
    }

    await _database.transaction(() async {
      // Deterministic approach: keep only one active printer record.
      await (_database.update(
        _database.printerSettings,
      )..where((db.$PrinterSettingsTable t) => t.isActive.equals(true))).write(
        const db.PrinterSettingsCompanion(isActive: Value<bool>(false)),
      );

      await _database
          .into(_database.printerSettings)
          .insert(
            db.PrinterSettingsCompanion.insert(
              deviceName: deviceName,
              deviceAddress: deviceAddress,
              paperWidth: Value<int>(paperWidth),
              isActive: const Value<bool>(true),
            ),
          );
    });
  }

  PrinterSettingsModel _mapPrinter(db.PrinterSetting row) {
    return PrinterSettingsModel(
      id: row.id,
      deviceName: row.deviceName,
      deviceAddress: row.deviceAddress,
      paperWidth: row.paperWidth,
      isActive: row.isActive,
    );
  }

  Future<db.ReportSetting?> _getOrCreateReportSettingsRow() async {
    final db.ReportSetting? row =
        await (_database.select(_database.reportSettings)
              ..orderBy(<OrderingTerm Function(db.$ReportSettingsTable)>[
                (db.$ReportSettingsTable t) => OrderingTerm.asc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (row != null) {
      return row;
    }

    final int id = await _database
        .into(_database.reportSettings)
        .insert(db.ReportSettingsCompanion.insert());
    return (_database.select(
      _database.reportSettings,
    )..where((db.$ReportSettingsTable t) => t.id.equals(id))).getSingleOrNull();
  }

  ReportSettingsPolicy _mapReportSettings(db.ReportSetting row) {
    return ReportSettingsPolicy(
      cashierReportMode: CashierReportMode.fromDbValue(row.cashierReportMode),
      visibilityRatio: row.visibilityRatio,
      maxVisibleTotalMinor: row.maxVisibleTotalMinor,
    );
  }

  BusinessIdentitySettings _mapBusinessIdentity(db.ReportSetting row) {
    return BusinessIdentitySettings(
      businessName: _normalizeNullableText(row.businessName),
      businessAddress: _normalizeNullableText(row.businessAddress),
    );
  }

  String? _normalizeNullableText(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _validatePolicy(ReportSettingsPolicy policy) {
    if (policy.visibilityRatio < 0.0 || policy.visibilityRatio > 1.0) {
      throw ValidationException('visibility ratio must be between 0.0 and 1.0');
    }
    if (policy.maxVisibleTotalMinor != null &&
        policy.maxVisibleTotalMinor! < 0) {
      throw ValidationException('max visible total must be zero or greater.');
    }

    if (policy.isPercentageMode) {
      return;
    }

    if (policy.maxVisibleTotalMinor == null) {
      throw ValidationException(
        'max visible total is required for cap amount mode.',
      );
    }
  }
}
