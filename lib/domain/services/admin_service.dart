import '../../core/config/app_config.dart';
import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/modifier_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../data/repositories/system_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/admin_dashboard_snapshot.dart';
import '../models/cash_movement.dart';
import '../models/category.dart';
import '../models/database_export_result.dart';
import '../models/printer_device_option.dart';
import '../models/printer_settings.dart';
import '../models/product.dart';
import '../models/product_modifier.dart';
import '../models/shift.dart';
import '../models/shift_report.dart';
import '../models/sync_runtime_state.dart';
import '../models/sync_failure_guidance.dart';
import '../models/sync_monitor_snapshot.dart';
import '../models/sync_operations_summary.dart';
import '../models/sync_queue_item.dart';
import '../models/sync_reset_blocked_result.dart';
import '../models/sync_retry_all_result.dart';
import '../models/system_health_snapshot.dart';
import '../models/user.dart';
import '../models/z_report_action_result.dart';
import 'audit_log_service.dart';
import 'printer_service.dart';
import 'report_service.dart';
import 'cash_movement_service.dart';
import 'shift_session_service.dart';

enum ProductDeleteOutcome { deleted, deactivated }

class ProductDeletionAnalysis {
  const ProductDeletionAnalysis({
    required this.product,
    required this.hasHistoricalUsage,
    required this.isSetProduct,
    required this.setConfigReferenceCount,
    required this.requiredChoiceReferenceCount,
    required this.extrasPoolReferenceCount,
  });

  final Product product;
  final bool hasHistoricalUsage;
  final bool isSetProduct;
  final int setConfigReferenceCount;
  final int requiredChoiceReferenceCount;
  final int extrasPoolReferenceCount;

  bool get hasSemanticReferences =>
      setConfigReferenceCount > 0 ||
      requiredChoiceReferenceCount > 0 ||
      extrasPoolReferenceCount > 0;
}

class AdminService {
  static const String archivedCategoryName = 'Archived Products';
  static const int defaultSyncMaxRetryAttempts = 5;
  static const Duration defaultProcessingStuckThreshold = Duration(minutes: 2);

  const AdminService({
    required CategoryRepository categoryRepository,
    required ProductRepository productRepository,
    required ModifierRepository modifierRepository,
    required ShiftRepository shiftRepository,
    required TransactionRepository transactionRepository,
    required SyncQueueRepository syncQueueRepository,
    required SettingsRepository settingsRepository,
    required SystemRepository systemRepository,
    required ReportService reportService,
    required ShiftSessionService shiftSessionService,
    required CashMovementService cashMovementService,
    required PrinterService printerService,
    required AppConfig appConfig,
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _categoryRepository = categoryRepository,
       _productRepository = productRepository,
       _modifierRepository = modifierRepository,
       _shiftRepository = shiftRepository,
       _transactionRepository = transactionRepository,
       _syncQueueRepository = syncQueueRepository,
       _settingsRepository = settingsRepository,
       _systemRepository = systemRepository,
       _reportService = reportService,
       _shiftSessionService = shiftSessionService,
       _cashMovementService = cashMovementService,
       _printerService = printerService,
       _appConfig = appConfig,
       _auditLogService = auditLogService,
       _logger = logger;

  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;
  final ModifierRepository _modifierRepository;
  final ShiftRepository _shiftRepository;
  final TransactionRepository _transactionRepository;
  final SyncQueueRepository _syncQueueRepository;
  final SettingsRepository _settingsRepository;
  final SystemRepository _systemRepository;
  final ReportService _reportService;
  final ShiftSessionService _shiftSessionService;
  final CashMovementService _cashMovementService;
  final PrinterService _printerService;
  final AppConfig _appConfig;
  final AuditLogService _auditLogService;
  final AppLogger _logger;

  Future<AdminDashboardSnapshot> getDashboardSnapshot({
    required User user,
  }) async {
    _ensureAdmin(user);

    final Shift? activeShift = await _shiftSessionService.getBackendOpenShift();
    final int openOrderCount = activeShift == null
        ? 0
        : (await _transactionRepository.getActiveOrders(
            shiftId: activeShift.id,
          )).length;

    return AdminDashboardSnapshot(
      todaySalesTotalMinor: await _reportService.getTodaySalesTotalMinor(
        user: user,
      ),
      activeShift: activeShift,
      openOrderCount: openOrderCount,
      pendingSyncCount: await _syncQueueRepository.getPendingCount(),
      failedSyncCount: await _syncQueueRepository.getFailedCount(),
    );
  }

  Future<List<Category>> getCategories() {
    return _categoryRepository.getAll(activeOnly: false);
  }

  Future<int> createCategory({
    required User user,
    required String name,
    required int sortOrder,
    bool isActive = true,
  }) async {
    _ensureAdmin(user);
    _validateRequiredName(name, fieldName: 'Category name');
    _validateNonNegative(sortOrder, fieldName: 'sortOrder');
    await _ensureUniqueCategoryName(name);

    return _categoryRepository.insert(
      name: name.trim(),
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }

  Future<void> updateCategory({
    required User user,
    required int id,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) async {
    _ensureAdmin(user);
    _validateRequiredName(name, fieldName: 'Category name');
    _validateNonNegative(sortOrder, fieldName: 'sortOrder');
    await _ensureUniqueCategoryName(name, excludeCategoryId: id);

    final bool updated = await _categoryRepository.updateCategory(
      id: id,
      name: name.trim(),
      sortOrder: sortOrder,
      isActive: isActive,
    );
    if (!updated) {
      throw NotFoundException('Category not found: $id');
    }
  }

  Future<bool> categoryHasActiveProducts({
    required User user,
    required int id,
  }) async {
    _ensureAdmin(user);
    return _categoryRepository.hasActiveProducts(id);
  }

  Future<void> deleteCategory({required User user, required int id}) async {
    _ensureAdmin(user);
    if (await _categoryRepository.hasActiveProducts(id)) {
      throw ValidationException(
        'This category contains active products. Move, archive, or delete them first.',
      );
    }
    final List<Product> categoryProducts = await _productRepository
        .getByCategory(id, activeOnly: false);
    final List<Product> archivedProducts = categoryProducts
        .where((Product product) => !product.isActive)
        .toList(growable: false);
    if (archivedProducts.isNotEmpty) {
      final int archivedCategoryId = await _ensureArchivedFallbackCategory(
        excludeCategoryId: id,
      );
      for (final Product product in archivedProducts) {
        await _productRepository.updateProduct(
          id: product.id,
          categoryId: archivedCategoryId,
        );
      }
    }
    final bool deleted = await _categoryRepository.deleteCategory(id);
    if (!deleted) {
      throw NotFoundException('Category not found: $id');
    }
  }

  Future<void> toggleCategoryActive({
    required User user,
    required int id,
    required bool isActive,
  }) async {
    _ensureAdmin(user);
    final bool updated = await _categoryRepository.toggleActive(id, isActive);
    if (!updated) {
      throw NotFoundException('Category not found: $id');
    }
  }

  Future<List<Product>> getProducts({int? categoryId}) {
    if (categoryId == null) {
      return _productRepository.getAll(activeOnly: false);
    }
    return _productRepository.getByCategory(categoryId, activeOnly: false);
  }

  Future<int> createProduct({
    required User user,
    required int categoryId,
    required String name,
    required int priceMinor,
    required bool hasModifiers,
    required int sortOrder,
    bool isActive = true,
    bool isVisibleOnPos = true,
  }) async {
    _ensureAdmin(user);
    await _requireCategory(categoryId);
    _validateRequiredName(name, fieldName: 'Product name');
    _validateNonNegative(priceMinor, fieldName: 'price_minor');
    _validateNonNegative(sortOrder, fieldName: 'sortOrder');

    final int productId = await _productRepository.insert(
      categoryId: categoryId,
      name: name.trim(),
      priceMinor: priceMinor,
      hasModifiers: hasModifiers,
      sortOrder: sortOrder,
      isActive: isActive,
      isVisibleOnPos: isVisibleOnPos,
    );
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'product_created',
      entityType: 'product',
      entityId: '$productId',
      metadata: <String, Object?>{
        'category_id': categoryId,
        'name': name.trim(),
        'price_minor': priceMinor,
        'has_modifiers': hasModifiers,
        'is_active': isActive,
        'is_visible_on_pos': isVisibleOnPos,
      },
    );
    return productId;
  }

  Future<void> updateProduct({
    required User user,
    required int id,
    required int categoryId,
    required String name,
    required int priceMinor,
    required bool hasModifiers,
    required int sortOrder,
    required bool isActive,
    required bool isVisibleOnPos,
  }) async {
    _ensureAdmin(user);
    final Product before = await _requireExistingProduct(id);
    await _requireCategory(categoryId);
    _validateRequiredName(name, fieldName: 'Product name');
    _validateNonNegative(priceMinor, fieldName: 'price_minor');
    _validateNonNegative(sortOrder, fieldName: 'sortOrder');

    final bool updated = await _productRepository.updateProduct(
      id: id,
      categoryId: categoryId,
      name: name.trim(),
      priceMinor: priceMinor,
      hasModifiers: hasModifiers,
      sortOrder: sortOrder,
      isActive: isActive,
      isVisibleOnPos: isVisibleOnPos,
    );
    if (!updated) {
      throw NotFoundException('Product not found: $id');
    }
    final Product after = await _requireExistingProduct(id);
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'product_updated',
      entityType: 'product',
      entityId: '$id',
      metadata: <String, Object?>{
        'old_category_id': before.categoryId,
        'new_category_id': after.categoryId,
        'old_name': before.name,
        'new_name': after.name,
        'old_price_minor': before.priceMinor,
        'new_price_minor': after.priceMinor,
        'old_has_modifiers': before.hasModifiers,
        'new_has_modifiers': after.hasModifiers,
      },
    );
    await _logProductVisibilityChangeIfNeeded(
      actorUserId: user.id,
      before: before,
      after: after,
    );
  }

  Future<void> toggleProductActive({
    required User user,
    required int id,
    required bool isActive,
  }) async {
    _ensureAdmin(user);
    final Product before = await _requireExistingProduct(id);
    final bool updated = await _productRepository.toggleActive(id, isActive);
    if (!updated) {
      throw NotFoundException('Product not found: $id');
    }
    final Product after = await _requireExistingProduct(id);
    await _logProductVisibilityChangeIfNeeded(
      actorUserId: user.id,
      before: before,
      after: after,
    );
  }

  Future<void> toggleProductVisibilityOnPos({
    required User user,
    required int id,
    required bool isVisibleOnPos,
  }) async {
    _ensureAdmin(user);
    final Product before = await _requireExistingProduct(id);
    final bool updated = await _productRepository.toggleVisibilityOnPos(
      id,
      isVisibleOnPos,
    );
    if (!updated) {
      throw NotFoundException('Product not found: $id');
    }
    final Product after = await _requireExistingProduct(id);
    await _logProductVisibilityChangeIfNeeded(
      actorUserId: user.id,
      before: before,
      after: after,
    );
  }

  Future<ProductDeletionAnalysis> analyzeProductDeletion({
    required User user,
    required int id,
  }) async {
    _ensureAdmin(user);
    final Product product = await _requireExistingProduct(id);
    final ({int setConfigCount, int requiredChoiceCount, int extrasPoolCount})
    semanticReferences = await _productRepository.loadSemanticReferenceSummary(
      id,
    );
    return ProductDeletionAnalysis(
      product: product,
      hasHistoricalUsage: await _productRepository.hasHistoricalUsage(id),
      isSetProduct: await _productRepository.hasOwnedSemanticConfiguration(id),
      setConfigReferenceCount: semanticReferences.setConfigCount,
      requiredChoiceReferenceCount: semanticReferences.requiredChoiceCount,
      extrasPoolReferenceCount: semanticReferences.extrasPoolCount,
    );
  }

  Future<ProductDeleteOutcome> deleteProduct({
    required User user,
    required int id,
    bool confirmSemanticImpact = false,
  }) async {
    _ensureAdmin(user);
    final ProductDeletionAnalysis analysis = await analyzeProductDeletion(
      user: user,
      id: id,
    );
    final Product before = analysis.product;
    if (analysis.hasHistoricalUsage) {
      final bool updated = await _productRepository.updateProduct(
        id: id,
        isActive: false,
      );
      if (!updated) {
        throw NotFoundException('Product not found: $id');
      }
      await _logProductVisibilityChangeIfNeeded(
        actorUserId: user.id,
        before: before,
        after: before.copyWith(isActive: false),
      );
      return ProductDeleteOutcome.deactivated;
    }

    if (!analysis.isSetProduct &&
        analysis.hasSemanticReferences &&
        !confirmSemanticImpact) {
      throw ValidationException(
        'This product is used by other set configurations. Deleting it may affect those sets.',
      );
    }

    final bool deleted = analysis.isSetProduct
        ? await _productRepository.deleteSetProduct(id)
        : await _productRepository.deleteStandardProduct(id);
    if (!deleted) {
      throw NotFoundException('Product not found: $id');
    }
    await _auditLogService.logActionSafely(
      actorUserId: user.id,
      action: 'product_deleted',
      entityType: 'product',
      entityId: '$id',
      metadata: <String, Object?>{
        'category_id': before.categoryId,
        'name': before.name,
        'price_minor': before.priceMinor,
        'has_modifiers': before.hasModifiers,
        'is_active': before.isActive,
        'is_visible_on_pos': before.isVisibleOnPos,
      },
    );
    return ProductDeleteOutcome.deleted;
  }

  Future<List<ProductModifier>> getModifiersForProduct(int productId) async {
    await _requireProduct(productId);
    return _modifierRepository.getByProductId(productId, activeOnly: false);
  }

  Future<int> createModifier({
    required User user,
    required int productId,
    required String name,
    required ModifierType type,
    required int extraPriceMinor,
    bool isActive = true,
  }) async {
    _ensureAdmin(user);
    await _requireProduct(productId);
    _validateRequiredName(name, fieldName: 'Modifier name');
    _validateNonNegative(extraPriceMinor, fieldName: 'extra_price_minor');

    return _modifierRepository.insert(
      productId: productId,
      name: name.trim(),
      type: type,
      extraPriceMinor: type == ModifierType.extra ? extraPriceMinor : 0,
      isActive: isActive,
    );
  }

  Future<void> updateModifier({
    required User user,
    required int id,
    required int productId,
    required String name,
    required ModifierType type,
    required int extraPriceMinor,
    required bool isActive,
  }) async {
    _ensureAdmin(user);
    await _requireProduct(productId);
    _validateRequiredName(name, fieldName: 'Modifier name');
    _validateNonNegative(extraPriceMinor, fieldName: 'extra_price_minor');

    final bool updated = await _modifierRepository.updateModifier(
      id: id,
      productId: productId,
      name: name.trim(),
      type: type,
      extraPriceMinor: type == ModifierType.extra ? extraPriceMinor : 0,
      isActive: isActive,
    );
    if (!updated) {
      throw NotFoundException('Modifier not found: $id');
    }
  }

  Future<void> toggleModifierActive({
    required User user,
    required int id,
    required bool isActive,
  }) async {
    _ensureAdmin(user);
    final bool updated = await _modifierRepository.toggleActive(id, isActive);
    if (!updated) {
      throw NotFoundException('Modifier not found: $id');
    }
  }

  Future<Shift?> getActiveShift({required User user}) async {
    _ensureAdmin(user);
    return _shiftSessionService.getBackendOpenShift();
  }

  Future<List<Shift>> getRecentShifts({required User user, int limit = 20}) {
    _ensureAdmin(user);
    return _shiftRepository.getRecentShifts(limit: limit);
  }

  Future<ShiftReport> getRawShiftReport({
    required User user,
    required int shiftId,
  }) async {
    _ensureAdmin(user);
    return _reportService.getShiftReport(shiftId);
  }

  Future<List<CashMovement>> getCashMovementsForActiveShift({
    required User user,
  }) async {
    _ensureAdmin(user);
    return _cashMovementService.listCashMovementsForActiveShift();
  }

  Future<CashMovement> createManualCashMovement({
    required User user,
    required CashMovementType type,
    required String category,
    required int amountMinor,
    required CashMovementPaymentMethod paymentMethod,
    String? note,
  }) async {
    _ensureAdmin(user);
    return _cashMovementService.createManualCashMovement(
      type: type,
      category: category,
      amountMinor: amountMinor,
      paymentMethod: paymentMethod,
      note: note,
      actorUserId: user.id,
    );
  }

  Future<ZReportActionResult> runAdminFinalClose({
    required User user,
    required int countedCashMinor,
  }) {
    _ensureAdmin(user);
    return _reportService.runAdminFinalCloseWithCountedCash(
      user: user,
      countedCashMinor: countedCashMinor,
    );
  }

  Future<double> getVisibilityRatio({required User user}) {
    _ensureAdmin(user);
    return _reportService.getVisibilityRatio();
  }

  Future<void> updateVisibilityRatio({
    required User user,
    required double ratio,
  }) {
    _ensureAdmin(user);
    return _reportService.updateVisibilityRatio(user: user, ratio: ratio);
  }

  Future<PrinterSettingsModel?> getActivePrinterSettings({
    required User user,
  }) async {
    _ensureAdmin(user);
    return _settingsRepository.getActivePrinterSettings();
  }

  Future<List<PrinterDeviceOption>> getBondedPrinterDevices({
    required User user,
  }) async {
    _ensureAdmin(user);
    return _printerService.getBondedDevices();
  }

  Future<void> savePrinterSettings({
    required User user,
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
  }) async {
    _ensureAdmin(user);
    _validateRequiredName(deviceName, fieldName: 'Printer name');
    _validateRequiredName(deviceAddress, fieldName: 'Printer address');
    await _printerService.savePrinterSettings(
      deviceName: deviceName.trim(),
      deviceAddress: deviceAddress.trim(),
      paperWidth: paperWidth,
    );
  }

  Future<void> printTestPage({
    required User user,
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
  }) async {
    _ensureAdmin(user);
    _validateRequiredName(deviceName, fieldName: 'Printer name');
    _validateRequiredName(deviceAddress, fieldName: 'Printer address');
    await _printerService.printTestPage(
      deviceName: deviceName.trim(),
      deviceAddress: deviceAddress.trim(),
      paperWidth: paperWidth,
    );
  }

  Future<List<SyncQueueItem>> getSyncQueueItems({
    required User user,
    int limit = 100,
  }) async {
    _ensureAdmin(user);
    return _syncQueueRepository.getMonitorItems(limit: limit);
  }

  Future<({int pendingCount, int failedCount})> getSyncMonitorCounts({
    required User user,
  }) async {
    _ensureAdmin(user);
    return _syncQueueRepository.getMonitorCounts();
  }

  Future<SyncMonitorSnapshot> getSyncMonitorSnapshot({
    required User user,
    required SyncRuntimeState runtimeState,
    int limit = 100,
  }) async {
    _ensureAdmin(user);
    final ({int pendingCount, int failedCount}) counts =
        await _syncQueueRepository.getMonitorCounts();
    final SyncOperationsSummary operationsSummary =
        await _buildOperationsSummary();
    return SyncMonitorSnapshot(
      items: await _syncQueueRepository.getMonitorItems(limit: limit),
      pendingCount: counts.pendingCount,
      failedCount: counts.failedCount,
      syncedCount: await _syncQueueRepository.getSyncedCount(),
      stuckCount: operationsSummary.stuckCount,
      maxRetryAttempts: defaultSyncMaxRetryAttempts,
      retryableFailedCount: operationsSummary.retryableFailedCount,
      nonRetryableFailedCount: operationsSummary.nonRetryableFailedCount,
      driftBlockedCount: operationsSummary.driftBlockedCount,
      processingStuckCount: operationsSummary.processingStuckCount,
      exhaustedRetryCount: operationsSummary.exhaustedRetryCount,
      stuckDefinition: operationsSummary.stuckDefinition,
      lastFailedItem: await _syncQueueRepository.getLatestFailedItem(),
      syncEnabled: _appConfig.featureFlags.syncEnabled,
      isSupabaseConfigured: _appConfig.isSupabaseReadyForSync,
      supabaseConfigurationLabel: _appConfig.supabaseConfigurationLabel,
      supabaseConfigurationIssue: _appConfig.supabaseConfigurationIssue,
      lastSyncedAt: await _syncQueueRepository.getLastSyncedAt(),
      lastError: runtimeState.lastRuntimeError,
      isOnline: runtimeState.isOnline,
      isRunning: runtimeState.isRunning,
    );
  }

  Future<void> retrySyncItem({required User user, required int itemId}) async {
    _ensureAdmin(user);
    SyncQueueItem? item;
    for (final SyncQueueItem entry
        in await _syncQueueRepository.getFailedItems()) {
      if (entry.id == itemId) {
        item = entry;
        break;
      }
    }
    if (item == null) {
      throw NotFoundException(
        'Sync queue item not found or not failed: $itemId',
      );
    }
    final SyncFailureGuidance guidance = resolveSyncFailureGuidance(
      item,
      maxRetryAttempts: defaultSyncMaxRetryAttempts,
    );
    if (!guidance.canManualRetry) {
      throw ValidationException(guidance.nextStep);
    }
    await _syncQueueRepository.resetAttempts(itemId);
  }

  Future<SyncRetryAllResult> retryAllSyncItems({required User user}) async {
    _ensureAdmin(user);
    final List<SyncQueueItem> failedItems = await _syncQueueRepository
        .getFailedItems();
    final List<int> retryableIds = <int>[];
    int skippedNonRetryableCount = 0;
    int skippedManualReviewCount = 0;

    for (final SyncQueueItem item in failedItems) {
      final SyncFailureGuidance guidance = resolveSyncFailureGuidance(
        item,
        maxRetryAttempts: defaultSyncMaxRetryAttempts,
      );
      _logger.audit(
        eventType: 'admin_sync_retry_all_item_evaluated',
        entityId: item.recordUuid,
        message: guidance.includedInRetryAll
            ? 'Sync item reset for retry-all.'
            : 'Sync item skipped during retry-all evaluation.',
        metadata: <String, Object?>{
          'queue_row_id': item.id,
          'previous_status': item.status.name,
          'new_status': guidance.includedInRetryAll
              ? SyncQueueStatus.pending.name
              : item.status.name,
          'failure_type': item.failureDetails?.failureKind.name ?? 'unknown',
          'retryable': item.failureDetails?.retryable,
          'retry_all_action': guidance.includedInRetryAll ? 'reset' : 'skip',
          'skip_reason': guidance.kind.name,
        },
      );
      if (guidance.includedInRetryAll) {
        retryableIds.add(item.id);
        continue;
      }
      if (guidance.isNonRetryable) {
        skippedNonRetryableCount += 1;
      } else {
        skippedManualReviewCount += 1;
      }
    }

    await _syncQueueRepository.resetAttemptsForItems(retryableIds);
    return SyncRetryAllResult(
      retriedCount: retryableIds.length,
      skippedCount: failedItems.length - retryableIds.length,
      skippedNonRetryableCount: skippedNonRetryableCount,
      skippedManualReviewCount: skippedManualReviewCount,
    );
  }

  Future<SyncResetBlockedResult> resetBlockedTrustedSyncFailures({
    required User user,
  }) async {
    _ensureAdmin(user);
    final List<SyncQueueItem> failedItems = await _syncQueueRepository
        .getFailedItems();
    final List<int> resetIds = <int>[];

    for (final SyncQueueItem item in failedItems) {
      final SyncFailureGuidance guidance = resolveSyncFailureGuidance(
        item,
        maxRetryAttempts: defaultSyncMaxRetryAttempts,
      );
      if (_isBlockedTrustedSyncFailure(guidance.kind)) {
        resetIds.add(item.id);
      }
      _logger.audit(
        eventType: 'admin_sync_blocked_failure_evaluated',
        entityId: item.recordUuid,
        message: _isBlockedTrustedSyncFailure(guidance.kind)
            ? 'Blocked trusted-sync failure reset for retest.'
            : 'Sync failure left unchanged during blocked-failure reset.',
        metadata: <String, Object?>{
          'queue_row_id': item.id,
          'previous_status': item.status.name,
          'new_status': _isBlockedTrustedSyncFailure(guidance.kind)
              ? SyncQueueStatus.pending.name
              : item.status.name,
          'failure_type': item.failureDetails?.failureKind.name ?? 'unknown',
          'retryable': item.failureDetails?.retryable,
          'reset_for_retest': _isBlockedTrustedSyncFailure(guidance.kind),
        },
      );
    }

    await _syncQueueRepository.resetAttemptsForItems(resetIds);
    return SyncResetBlockedResult(
      resetCount: resetIds.length,
      skippedCount: failedItems.length - resetIds.length,
    );
  }

  Future<SystemHealthSnapshot> getSystemHealthSnapshot({
    required User user,
    required SyncRuntimeState runtimeState,
  }) async {
    _ensureAdmin(user);
    final ({int pendingCount, int failedCount}) counts =
        await _syncQueueRepository.getMonitorCounts();

    return SystemHealthSnapshot(
      syncEnabled: _appConfig.featureFlags.syncEnabled,
      isSupabaseConfigured: _appConfig.isSupabaseReadyForSync,
      supabaseConfigurationLabel: _appConfig.supabaseConfigurationLabel,
      supabaseConfigurationIssue: _appConfig.supabaseConfigurationIssue,
      debugLoggingEnabled: _appConfig.featureFlags.debugLoggingEnabled,
      environment: _appConfig.environment,
      appVersion: _appConfig.appVersion,
      schemaVersion: _systemRepository.schemaVersion,
      activeShift: await _shiftSessionService.getBackendOpenShift(),
      pendingCount: counts.pendingCount,
      failedCount: counts.failedCount,
      stuckCount: await _syncQueueRepository.getStuckCount(),
      lastSyncedAt: await _syncQueueRepository.getLastSyncedAt(),
      lastError:
          runtimeState.lastRuntimeError ??
          await _syncQueueRepository.getLastError(),
      isOnline: runtimeState.isOnline,
      isWorkerRunning: runtimeState.isRunning,
      migrationHistory: _systemRepository.getMigrationHistory(),
      lastMigrationFailure: _systemRepository.getLastMigrationFailure(),
      lastBackup: await _systemRepository.getLastBackup(),
    );
  }

  Future<DatabaseExportResult> exportLocalDatabase({required User user}) async {
    _ensureAdmin(user);
    if (!_appConfig.featureFlags.backupExportEnabled) {
      throw ValidationException('Backup export feature is disabled.');
    }
    return _systemRepository.exportLocalDatabase();
  }

  Future<void> _requireCategory(int categoryId) async {
    final Category? category = await _categoryRepository.getById(categoryId);
    if (category == null) {
      throw ValidationException('Category selection is required.');
    }
  }

  Future<void> _requireProduct(int productId) async {
    final Product? product = await _productRepository.getById(productId);
    if (product == null) {
      throw ValidationException('Product selection is required.');
    }
  }

  Future<Product> _requireExistingProduct(int productId) async {
    final Product? product = await _productRepository.getById(productId);
    if (product == null) {
      throw NotFoundException('Product not found: $productId');
    }
    return product;
  }

  Future<void> _logProductVisibilityChangeIfNeeded({
    required int actorUserId,
    required Product before,
    required Product after,
  }) async {
    if (before.isActive == after.isActive &&
        before.isVisibleOnPos == after.isVisibleOnPos) {
      return;
    }
    await _auditLogService.logActionSafely(
      actorUserId: actorUserId,
      action: 'product_visibility_changed',
      entityType: 'product',
      entityId: '${after.id}',
      metadata: <String, Object?>{
        'old_is_active': before.isActive,
        'old_is_visible_on_pos': before.isVisibleOnPos,
        'new_is_active': after.isActive,
        'new_is_visible_on_pos': after.isVisibleOnPos,
      },
    );
  }

  void _ensureAdmin(User user) {
    if (user.role != UserRole.admin) {
      throw UnauthorisedException('Only admins can access the admin panel.');
    }
  }

  void _validateRequiredName(String value, {required String fieldName}) {
    if (value.trim().isEmpty) {
      throw ValidationException('$fieldName is required.');
    }
  }

  void _validateNonNegative(int value, {required String fieldName}) {
    if (value < 0) {
      throw ValidationException('$fieldName cannot be negative.');
    }
  }

  Future<int> _ensureArchivedFallbackCategory({int? excludeCategoryId}) async {
    final Category? existing = await _categoryRepository.findByNameIgnoreCase(
      archivedCategoryName,
      excludeCategoryId: excludeCategoryId,
    );
    if (existing != null) {
      return existing.id;
    }
    return _categoryRepository.insert(
      name: archivedCategoryName,
      sortOrder: 9999,
      isActive: true,
    );
  }

  Future<void> _ensureUniqueCategoryName(
    String name, {
    int? excludeCategoryId,
  }) async {
    if (await _categoryRepository.nameExistsIgnoreCase(
      name,
      excludeCategoryId: excludeCategoryId,
    )) {
      throw ValidationException('Category with this name already exists');
    }
  }

  Future<SyncOperationsSummary> _buildOperationsSummary() async {
    final DateTime now = DateTime.now();
    final List<SyncQueueItem> failedItems = await _syncQueueRepository
        .getFailedItems();
    final List<SyncQueueItem> processingItems = await _syncQueueRepository
        .getProcessingItems();

    int retryableFailedCount = 0;
    int nonRetryableFailedCount = 0;
    int driftBlockedCount = 0;
    int exhaustedRetryCount = 0;

    for (final SyncQueueItem item in failedItems) {
      final SyncFailureGuidance guidance = resolveSyncFailureGuidance(
        item,
        maxRetryAttempts: defaultSyncMaxRetryAttempts,
      );
      switch (guidance.kind) {
        case SyncFailureGuidanceKind.retryable:
        case SyncFailureGuidanceKind.networkUnreachable:
        case SyncFailureGuidanceKind.remoteServerError:
          retryableFailedCount += 1;
          break;
        case SyncFailureGuidanceKind.localGraphDrift:
          nonRetryableFailedCount += 1;
          driftBlockedCount += 1;
          break;
        case SyncFailureGuidanceKind.maxRetryHit:
          exhaustedRetryCount += 1;
          break;
        case SyncFailureGuidanceKind.validationFailure:
        case SyncFailureGuidanceKind.authOrConfigFailure:
          nonRetryableFailedCount += 1;
          break;
        case SyncFailureGuidanceKind.unknown:
          exhaustedRetryCount += 1;
          break;
      }
    }

    int processingStuckCount = 0;
    for (final SyncQueueItem item in processingItems) {
      final DateTime? lastAttemptAt = item.lastAttemptAt;
      final bool isStuck =
          lastAttemptAt != null &&
          lastAttemptAt.add(defaultProcessingStuckThreshold).isBefore(now);
      if (isStuck) {
        processingStuckCount += 1;
      }
    }

    return SyncOperationsSummary(
      retryableFailedCount: retryableFailedCount,
      nonRetryableFailedCount: nonRetryableFailedCount,
      driftBlockedCount: driftBlockedCount,
      processingStuckCount: processingStuckCount,
      exhaustedRetryCount: exhaustedRetryCount,
    );
  }

  bool _isBlockedTrustedSyncFailure(SyncFailureGuidanceKind kind) {
    return kind == SyncFailureGuidanceKind.authOrConfigFailure ||
        kind == SyncFailureGuidanceKind.validationFailure;
  }
}
