import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/breakfast_extra_preset.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/models/semantic_product_configuration.dart';
import '../../domain/models/user.dart';
import 'admin_breakfast_sets_provider.dart';
import 'auth_provider.dart';

enum AdminBreakfastSetEditorDraftStatus { valid, incomplete, invalid }

enum AdminBreakfastSetEditorIssueSeverity { error, warning }

enum AdminBreakfastSetEditorIssueSection {
  setInfo,
  setItems,
  extras,
  choiceGroups,
  general,
}

class AdminBreakfastSetEditorValidationIssue {
  const AdminBreakfastSetEditorValidationIssue({
    required this.message,
    required this.severity,
    required this.section,
  });

  final String message;
  final AdminBreakfastSetEditorIssueSeverity severity;
  final AdminBreakfastSetEditorIssueSection section;
}

class AdminBreakfastSetItemSelection {
  const AdminBreakfastSetItemSelection({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;
}

class AdminBreakfastSetEditorState {
  const AdminBreakfastSetEditorState({
    required this.productId,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
    required this.editorData,
    required this.categoryName,
    required this.draftConfiguration,
    required this.validationResult,
    required this.draftStatus,
    required this.validationIssues,
    required this.setItemInlineIssues,
    required this.extraInlineIssues,
    required this.choiceGroupInlineIssues,
  });

  const AdminBreakfastSetEditorState.initial()
    : productId = null,
      isLoading = false,
      isSaving = false,
      errorMessage = null,
      editorData = null,
      categoryName = null,
      draftConfiguration = null,
      validationResult = null,
      draftStatus = AdminBreakfastSetEditorDraftStatus.invalid,
      validationIssues = const <AdminBreakfastSetEditorValidationIssue>[],
      setItemInlineIssues = const <int, List<String>>{},
      extraInlineIssues = const <int, List<String>>{},
      choiceGroupInlineIssues = const <int, List<String>>{};

  final int? productId;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final SemanticProductConfigurationEditorData? editorData;
  final String? categoryName;
  final SemanticProductConfigurationDraft? draftConfiguration;
  final SemanticMenuValidationResult? validationResult;
  final AdminBreakfastSetEditorDraftStatus draftStatus;
  final List<AdminBreakfastSetEditorValidationIssue> validationIssues;
  final Map<int, List<String>> setItemInlineIssues;
  final Map<int, List<String>> extraInlineIssues;
  final Map<int, List<String>> choiceGroupInlineIssues;

  bool get isSaveEnabled =>
      !isLoading &&
      !isSaving &&
      draftStatus == AdminBreakfastSetEditorDraftStatus.valid;

  bool get hasBlockingIssues => blockingIssues.isNotEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  List<AdminBreakfastSetEditorValidationIssue> get blockingIssues =>
      validationIssues
          .where(
            (AdminBreakfastSetEditorValidationIssue issue) =>
                issue.severity == AdminBreakfastSetEditorIssueSeverity.error,
          )
          .toList(growable: false);

  List<AdminBreakfastSetEditorValidationIssue> get warnings => validationIssues
      .where(
        (AdminBreakfastSetEditorValidationIssue issue) =>
            issue.severity == AdminBreakfastSetEditorIssueSeverity.warning,
      )
      .toList(growable: false);

  AdminBreakfastSetEditorState copyWith({
    Object? productId = _unset,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
    Object? editorData = _unset,
    Object? categoryName = _unset,
    Object? draftConfiguration = _unset,
    Object? validationResult = _unset,
    AdminBreakfastSetEditorDraftStatus? draftStatus,
    List<AdminBreakfastSetEditorValidationIssue>? validationIssues,
    Map<int, List<String>>? setItemInlineIssues,
    Map<int, List<String>>? extraInlineIssues,
    Map<int, List<String>>? choiceGroupInlineIssues,
  }) {
    return AdminBreakfastSetEditorState(
      productId: productId == _unset ? this.productId : productId as int?,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      editorData: editorData == _unset
          ? this.editorData
          : editorData as SemanticProductConfigurationEditorData?,
      categoryName: categoryName == _unset
          ? this.categoryName
          : categoryName as String?,
      draftConfiguration: draftConfiguration == _unset
          ? this.draftConfiguration
          : draftConfiguration as SemanticProductConfigurationDraft?,
      validationResult: validationResult == _unset
          ? this.validationResult
          : validationResult as SemanticMenuValidationResult?,
      draftStatus: draftStatus ?? this.draftStatus,
      validationIssues: validationIssues ?? this.validationIssues,
      setItemInlineIssues: setItemInlineIssues ?? this.setItemInlineIssues,
      extraInlineIssues: extraInlineIssues ?? this.extraInlineIssues,
      choiceGroupInlineIssues:
          choiceGroupInlineIssues ?? this.choiceGroupInlineIssues,
    );
  }
}

class AdminBreakfastSetEditorNotifier
    extends StateNotifier<AdminBreakfastSetEditorState> {
  AdminBreakfastSetEditorNotifier(this._ref)
    : super(const AdminBreakfastSetEditorState.initial());

  final Ref _ref;
  int _validationRequestId = 0;
  Set<int> _setRootProductIds = const <int>{};
  Set<int> _choiceMemberProductIds = const <int>{};

  Future<void> load(int productId) async {
    state = state.copyWith(
      productId: productId,
      isLoading: true,
      isSaving: false,
      errorMessage: null,
      editorData: null,
      categoryName: null,
      draftConfiguration: null,
      validationResult: null,
      draftStatus: AdminBreakfastSetEditorDraftStatus.invalid,
      validationIssues: const <AdminBreakfastSetEditorValidationIssue>[],
      setItemInlineIssues: const <int, List<String>>{},
      extraInlineIssues: const <int, List<String>>{},
      choiceGroupInlineIssues: const <int, List<String>>{},
    );
    try {
      final SemanticProductConfigurationEditorData editorData = await _ref
          .read(semanticMenuAdminServiceProvider)
          .loadEditorData(productId);
      _ref
          .read(appLoggerProvider)
          .info(
            eventType: 'admin_breakfast_set_editor_data_received',
            entityId: '$productId',
            metadata: <String, Object?>{
              'root_product_id': productId,
              'editor_available_set_item_products_length':
                  editorData.availableSetItemProducts.length,
              'editor_available_set_item_product_ids': editorData
                  .availableSetItemProducts
                  .map((Product product) => product.id)
                  .toList(growable: false),
              'draft_set_item_ids': editorData.configuration.setItems
                  .map((SemanticSetItemDraft item) => item.itemProductId)
                  .toList(growable: false),
            },
          );
      await _hydrateEditorData(
        editorData: editorData,
        productId: productId,
        isLoading: false,
        isSaving: false,
      );
      await _revalidateDraft(clearSaving: false);
    } catch (error, stackTrace) {
      state = state.copyWith(
        productId: productId,
        isLoading: false,
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_breakfast_set_editor_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> addSetItem(Product product) async {
    await addSetItemSelections(<AdminBreakfastSetItemSelection>[
      AdminBreakfastSetItemSelection(product: product, quantity: 1),
    ]);
  }

  Future<void> addSetItems(Iterable<Product> products) async {
    await addSetItemSelections(
      products.map(
        (Product product) =>
            AdminBreakfastSetItemSelection(product: product, quantity: 1),
      ),
    );
  }

  Future<void> addSetItemSelections(
    Iterable<AdminBreakfastSetItemSelection> selections,
  ) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    final List<AdminBreakfastSetItemSelection> selectedItems = selections
        .where(
          (AdminBreakfastSetItemSelection selection) => selection.quantity > 0,
        )
        .toList(growable: false);
    if (draftConfiguration == null || selectedItems.isEmpty) {
      return;
    }

    final List<SemanticSetItemDraft> items = List<SemanticSetItemDraft>.from(
      draftConfiguration.setItems,
    );
    final Set<int> existingItemProductIds = items
        .map((SemanticSetItemDraft item) => item.itemProductId)
        .toSet();
    for (final AdminBreakfastSetItemSelection selection in selectedItems) {
      final Product product = selection.product;
      if (existingItemProductIds.contains(product.id)) {
        continue;
      }
      existingItemProductIds.add(product.id);
      items.add(
        SemanticSetItemDraft(
          itemProductId: product.id,
          itemName: product.name,
          defaultQuantity: selection.quantity,
          isRemovable: true,
          sortOrder: items.length,
        ),
      );
    }
    await _applyDraft(
      _replaceSetItems(draftConfiguration: draftConfiguration, setItems: items),
    );
  }

  Future<void> removeSetItemAt(int index) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    if (draftConfiguration == null || index < 0) {
      return;
    }

    final List<SemanticSetItemDraft> items = List<SemanticSetItemDraft>.from(
      draftConfiguration.setItems,
    );
    if (index >= items.length) {
      return;
    }
    items.removeAt(index);
    await _applyDraft(
      _replaceSetItems(draftConfiguration: draftConfiguration, setItems: items),
    );
  }

  Future<void> addExtraItems(Iterable<Product> products) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    final List<Product> selectedProducts = products.toList(growable: false);
    if (draftConfiguration == null || selectedProducts.isEmpty) {
      return;
    }

    final List<SemanticExtraItemDraft> extras = List<SemanticExtraItemDraft>.of(
      draftConfiguration.extras,
    );
    final int baseSortOrder = extras.length;
    for (int index = 0; index < selectedProducts.length; index += 1) {
      final Product product = selectedProducts[index];
      extras.add(
        SemanticExtraItemDraft(
          itemProductId: product.id,
          itemName: product.name,
          sortOrder: baseSortOrder + index,
        ),
      );
    }
    await _applyDraft(
      _replaceExtras(draftConfiguration: draftConfiguration, extras: extras),
    );
  }

  Future<void> applyExtraPreset(BreakfastExtraPreset preset) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    if (draftConfiguration == null) {
      return;
    }

    final Set<int> existingIds = draftConfiguration.extras
        .map((SemanticExtraItemDraft extra) => extra.itemProductId)
        .toSet();
    final List<SemanticExtraItemDraft> extras = List<SemanticExtraItemDraft>.of(
      draftConfiguration.extras,
    );
    for (final BreakfastExtraPresetItem item in preset.items) {
      if (!existingIds.add(item.itemProductId)) {
        continue;
      }
      extras.add(
        SemanticExtraItemDraft(
          itemProductId: item.itemProductId,
          itemName: item.itemName,
          sortOrder: extras.length,
        ),
      );
    }
    await _applyDraft(
      _replaceExtras(draftConfiguration: draftConfiguration, extras: extras),
    );
  }

  Future<void> removeExtraItemAt(int index) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    if (draftConfiguration == null || index < 0) {
      return;
    }

    final List<SemanticExtraItemDraft> extras = List<SemanticExtraItemDraft>.of(
      draftConfiguration.extras,
    );
    if (index >= extras.length) {
      return;
    }
    extras.removeAt(index);
    await _applyDraft(
      _replaceExtras(draftConfiguration: draftConfiguration, extras: extras),
    );
  }

  Future<bool> saveExtraPreset({
    int? presetId,
    required String name,
    required List<Product> products,
  }) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    final SemanticProductConfigurationEditorData? editorData = state.editorData;
    if (currentUser == null || editorData == null) {
      return false;
    }

    try {
      await _ref
          .read(semanticMenuAdminServiceProvider)
          .saveExtraPreset(
            user: currentUser,
            presetId: presetId,
            name: name,
            itemProductIds: products.map((Product product) => product.id),
          );
      await _refreshExtraPresets();
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_breakfast_extra_preset_save_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<void> updateSetItemQuantityAt(int index, String rawValue) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    if (draftConfiguration == null || index < 0) {
      return;
    }

    final List<SemanticSetItemDraft> items = List<SemanticSetItemDraft>.from(
      draftConfiguration.setItems,
    );
    if (index >= items.length) {
      return;
    }
    final int parsedQuantity = int.tryParse(rawValue.trim()) ?? 0;
    items[index] = items[index].copyWith(defaultQuantity: parsedQuantity);
    await _applyDraft(
      _replaceSetItems(draftConfiguration: draftConfiguration, setItems: items),
    );
  }

  Future<void> addChoiceGroup() async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    if (draftConfiguration == null) {
      return;
    }

    final List<SemanticChoiceGroupDraft> groups =
        List<SemanticChoiceGroupDraft>.from(draftConfiguration.choiceGroups)
          ..add(
            SemanticChoiceGroupDraft(
              name: '',
              minSelect: 0,
              maxSelect: 1,
              includedQuantity: 1,
              sortOrder: draftConfiguration.choiceGroups.length,
              members: const <SemanticChoiceMemberDraft>[],
            ),
          );
    await _applyDraft(
      _replaceChoiceGroups(
        draftConfiguration: draftConfiguration,
        choiceGroups: groups,
      ),
    );
  }

  Future<void> removeChoiceGroupAt(int index) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    if (draftConfiguration == null || index < 0) {
      return;
    }

    final List<SemanticChoiceGroupDraft> groups =
        List<SemanticChoiceGroupDraft>.from(draftConfiguration.choiceGroups);
    if (index >= groups.length) {
      return;
    }
    groups.removeAt(index);
    await _applyDraft(
      _replaceChoiceGroups(
        draftConfiguration: draftConfiguration,
        choiceGroups: groups,
      ),
    );
  }

  Future<void> updateChoiceGroupNameAt(int index, String value) async {
    await _updateChoiceGroupAt(
      index,
      (SemanticChoiceGroupDraft group) => group.copyWith(name: value),
    );
  }

  Future<void> updateChoiceGroupMinSelectAt(int index, String rawValue) async {
    final int parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    await _updateChoiceGroupAt(
      index,
      (SemanticChoiceGroupDraft group) =>
          group.copyWith(minSelect: parsedValue),
    );
  }

  Future<void> updateChoiceGroupMaxSelectAt(int index, String rawValue) async {
    final int parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    await _updateChoiceGroupAt(
      index,
      (SemanticChoiceGroupDraft group) =>
          group.copyWith(maxSelect: parsedValue),
    );
  }

  Future<void> updateChoiceGroupIncludedQuantityAt(
    int index,
    String rawValue,
  ) async {
    final int parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    await _updateChoiceGroupAt(
      index,
      (SemanticChoiceGroupDraft group) =>
          group.copyWith(includedQuantity: parsedValue),
    );
  }

  Future<void> addChoiceGroupMemberAt(int groupIndex, Product product) async {
    await _updateChoiceGroupAt(groupIndex, (SemanticChoiceGroupDraft group) {
      final List<SemanticChoiceMemberDraft> members =
          List<SemanticChoiceMemberDraft>.from(group.members)..add(
            SemanticChoiceMemberDraft(
              itemProductId: product.id,
              itemName: product.name,
              position: group.members.length,
            ),
          );
      return group.copyWith(members: members);
    });
  }

  Future<void> removeChoiceGroupMemberAt(
    int groupIndex,
    int memberIndex,
  ) async {
    await _updateChoiceGroupAt(groupIndex, (SemanticChoiceGroupDraft group) {
      final List<SemanticChoiceMemberDraft> members =
          List<SemanticChoiceMemberDraft>.from(group.members);
      if (memberIndex < 0 || memberIndex >= members.length) {
        return group;
      }
      members.removeAt(memberIndex);
      return group.copyWith(members: members);
    });
  }

  Future<void> _updateChoiceGroupAt(
    int index,
    SemanticChoiceGroupDraft Function(SemanticChoiceGroupDraft group) transform,
  ) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    if (draftConfiguration == null || index < 0) {
      return;
    }

    final List<SemanticChoiceGroupDraft> groups =
        List<SemanticChoiceGroupDraft>.from(draftConfiguration.choiceGroups);
    if (index >= groups.length) {
      return;
    }
    groups[index] = transform(groups[index]);
    await _applyDraft(
      _replaceChoiceGroups(
        draftConfiguration: draftConfiguration,
        choiceGroups: groups,
      ),
    );
  }

  Future<void> _applyDraft(
    SemanticProductConfigurationDraft draftConfiguration,
  ) async {
    final SemanticProductConfigurationDraft normalizedDraft = _normalizeDraft(
      draftConfiguration,
    );
    final SemanticProductConfigurationEditorData? editorData = state.editorData;
    if (editorData == null) {
      return;
    }

    state = state.copyWith(
      draftConfiguration: normalizedDraft,
      setItemInlineIssues: _buildSetItemInlineIssues(
        editorData: editorData,
        draftConfiguration: normalizedDraft,
      ),
      choiceGroupInlineIssues: _buildChoiceGroupInlineIssues(
        editorData: editorData,
        draftConfiguration: normalizedDraft,
      ),
      errorMessage: null,
    );
    await _revalidateDraftAndClearSaving();
  }

  Future<void> _revalidateDraftAndClearSaving() async {
    await _revalidateDraft(clearSaving: true);
  }

  Future<bool> save() async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    final SemanticProductConfigurationEditorData? editorData = state.editorData;
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (draftConfiguration == null ||
        editorData == null ||
        currentUser == null ||
        !state.isSaveEnabled) {
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(semanticMenuAdminServiceProvider)
          .saveConfiguration(
            user: currentUser,
            configuration: draftConfiguration,
          );
      await _ref.read(adminBreakfastSetsNotifierProvider.notifier).load();
      final SemanticProductConfigurationEditorData refreshedEditorData =
          await _ref
              .read(semanticMenuAdminServiceProvider)
              .loadEditorData(draftConfiguration.productId);
      await _hydrateEditorData(
        editorData: refreshedEditorData,
        productId: draftConfiguration.productId,
        isLoading: false,
        isSaving: false,
      );
      await _revalidateDraft(clearSaving: false);
      return true;
    } on SemanticProductConfigurationValidationException catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_breakfast_set_editor_save_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<void> _revalidateDraft({required bool clearSaving}) async {
    final SemanticProductConfigurationDraft? draftConfiguration =
        state.draftConfiguration;
    final SemanticProductConfigurationEditorData? editorData = state.editorData;
    if (draftConfiguration == null || editorData == null) {
      return;
    }

    final int requestId = ++_validationRequestId;
    try {
      final SemanticMenuValidationResult validationResult = await _ref
          .read(semanticMenuAdminServiceProvider)
          .validateConfiguration(
            configuration: draftConfiguration,
            profile: editorData.profile,
          );
      if (requestId != _validationRequestId) {
        return;
      }
      state = state.copyWith(
        isSaving: clearSaving ? false : state.isSaving,
        validationResult: validationResult,
        draftStatus: _resolveDraftStatus(validationResult),
        validationIssues: _buildValidationIssues(validationResult),
        setItemInlineIssues: _buildSetItemInlineIssues(
          editorData: editorData,
          draftConfiguration: draftConfiguration,
        ),
        extraInlineIssues: _buildExtraInlineIssues(
          editorData: editorData,
          draftConfiguration: draftConfiguration,
        ),
        choiceGroupInlineIssues: _buildChoiceGroupInlineIssues(
          editorData: editorData,
          draftConfiguration: draftConfiguration,
        ),
      );
    } catch (error, stackTrace) {
      if (requestId != _validationRequestId) {
        return;
      }
      state = state.copyWith(
        isSaving: clearSaving ? false : state.isSaving,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_breakfast_set_editor_validate_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  AdminBreakfastSetEditorDraftStatus _resolveDraftStatus(
    SemanticMenuValidationResult validationResult,
  ) {
    if (validationResult.errors.isNotEmpty) {
      return AdminBreakfastSetEditorDraftStatus.invalid;
    }
    if (validationResult.warnings.isNotEmpty) {
      return AdminBreakfastSetEditorDraftStatus.incomplete;
    }
    return AdminBreakfastSetEditorDraftStatus.valid;
  }

  List<AdminBreakfastSetEditorValidationIssue> _buildValidationIssues(
    SemanticMenuValidationResult validationResult,
  ) {
    return List<AdminBreakfastSetEditorValidationIssue>.unmodifiable(
      <AdminBreakfastSetEditorValidationIssue>[
        ...validationResult.errors.map(
          (String message) => AdminBreakfastSetEditorValidationIssue(
            message: message,
            severity: AdminBreakfastSetEditorIssueSeverity.error,
            section: _resolveIssueSection(message),
          ),
        ),
        ...validationResult.warnings.map(
          (String message) => AdminBreakfastSetEditorValidationIssue(
            message: message,
            severity: AdminBreakfastSetEditorIssueSeverity.warning,
            section: _resolveIssueSection(message),
          ),
        ),
      ],
    );
  }

  AdminBreakfastSetEditorIssueSection _resolveIssueSection(String message) {
    final String normalized = message.toLowerCase();
    if (normalized.contains('legacy flat') ||
        normalized.contains('selected set product') ||
        normalized.contains('become a set root')) {
      return AdminBreakfastSetEditorIssueSection.setInfo;
    }
    if (normalized.contains('set item') ||
        normalized.contains('included item') ||
        normalized.contains('component')) {
      return AdminBreakfastSetEditorIssueSection.setItems;
    }
    if (normalized.contains('extra')) {
      return AdminBreakfastSetEditorIssueSection.extras;
    }
    if (normalized.contains('choice group') ||
        normalized.contains('choice member') ||
        normalized.contains('choice option') ||
        normalized.contains('required choice') ||
        normalized.contains('selection per group')) {
      return AdminBreakfastSetEditorIssueSection.choiceGroups;
    }
    return AdminBreakfastSetEditorIssueSection.general;
  }

  Map<int, List<String>> _buildSetItemInlineIssues({
    required SemanticProductConfigurationEditorData editorData,
    required SemanticProductConfigurationDraft draftConfiguration,
  }) {
    final Map<int, List<String>> issuesByIndex = <int, List<String>>{};
    final Map<int, int> seenCounts = <int, int>{};
    final Set<int> currentChoiceMemberIds = draftConfiguration.choiceGroups
        .expand((SemanticChoiceGroupDraft group) => group.members)
        .map((SemanticChoiceMemberDraft member) => member.itemProductId)
        .toSet();
    final Set<int> availableProductIds = editorData.availableProducts
        .map((Product product) => product.id)
        .toSet();

    for (
      int index = 0;
      index < draftConfiguration.setItems.length;
      index += 1
    ) {
      final SemanticSetItemDraft item = draftConfiguration.setItems[index];
      final List<String> issues = <String>[];

      final int duplicateCount = (seenCounts[item.itemProductId] ?? 0) + 1;
      seenCounts[item.itemProductId] = duplicateCount;
      if (duplicateCount > 1) {
        issues.add('Duplicate item selected.');
      }
      if (item.defaultQuantity <= 0) {
        issues.add('Quantity must be greater than zero.');
      }
      if (!availableProductIds.contains(item.itemProductId)) {
        issues.add('Selected item no longer exists in the catalog.');
      }
      if (item.itemProductId == editorData.rootProduct.id) {
        issues.add('The set root cannot be used as a set item.');
      }
      if (_setRootProductIds.contains(item.itemProductId)) {
        issues.add('A breakfast set root cannot be used as a set item.');
      }
      if (_choiceMemberProductIds.contains(item.itemProductId) ||
          currentChoiceMemberIds.contains(item.itemProductId)) {
        issues.add('A choice member product cannot be used as a set item.');
      }

      if (issues.isNotEmpty) {
        issuesByIndex[index] = List<String>.unmodifiable(issues);
      }
    }

    if (seenCounts.isNotEmpty) {
      final Map<int, int> totals = <int, int>{};
      for (final SemanticSetItemDraft item in draftConfiguration.setItems) {
        totals[item.itemProductId] = (totals[item.itemProductId] ?? 0) + 1;
      }
      for (
        int index = 0;
        index < draftConfiguration.setItems.length;
        index += 1
      ) {
        final SemanticSetItemDraft item = draftConfiguration.setItems[index];
        if ((totals[item.itemProductId] ?? 0) > 1) {
          issuesByIndex[index] = List<String>.unmodifiable(<String>[
            ...?issuesByIndex[index],
            if (!(issuesByIndex[index]?.contains('Duplicate item selected.') ??
                false))
              'Duplicate item selected.',
          ]);
        }
      }
    }

    return Map<int, List<String>>.unmodifiable(issuesByIndex);
  }

  Future<void> _hydrateEditorData({
    required SemanticProductConfigurationEditorData editorData,
    required int productId,
    required bool isLoading,
    required bool isSaving,
  }) async {
    final Category? category = await _ref
        .read(categoryRepositoryProvider)
        .getById(editorData.rootProduct.categoryId);
    _setRootProductIds = await _ref
        .read(breakfastConfigurationRepositoryProvider)
        .loadSetRootProductIds();
    _choiceMemberProductIds = await _ref
        .read(breakfastConfigurationRepositoryProvider)
        .loadChoiceMemberProductIds();
    final SemanticProductConfigurationDraft draftConfiguration =
        _normalizeDraft(editorData.configuration);
    final List<AdminBreakfastSetEditorValidationIssue> validationIssues =
        _buildValidationIssues(editorData.validationResult);

    state = state.copyWith(
      productId: productId,
      isLoading: isLoading,
      isSaving: isSaving,
      errorMessage: null,
      editorData: editorData,
      categoryName: category?.name ?? 'Unknown Category',
      draftConfiguration: draftConfiguration,
      validationResult: editorData.validationResult,
      draftStatus: _resolveDraftStatus(editorData.validationResult),
      validationIssues: validationIssues,
      setItemInlineIssues: _buildSetItemInlineIssues(
        editorData: editorData,
        draftConfiguration: draftConfiguration,
      ),
      extraInlineIssues: _buildExtraInlineIssues(
        editorData: editorData,
        draftConfiguration: draftConfiguration,
      ),
      choiceGroupInlineIssues: _buildChoiceGroupInlineIssues(
        editorData: editorData,
        draftConfiguration: draftConfiguration,
      ),
    );
  }

  Map<int, List<String>> _buildExtraInlineIssues({
    required SemanticProductConfigurationEditorData editorData,
    required SemanticProductConfigurationDraft draftConfiguration,
  }) {
    final Map<int, List<String>> issuesByIndex = <int, List<String>>{};
    final Set<int> currentSetItemIds = draftConfiguration.setItems
        .map((SemanticSetItemDraft item) => item.itemProductId)
        .toSet();
    final Set<int> currentChoiceMemberIds = draftConfiguration.choiceGroups
        .expand((SemanticChoiceGroupDraft group) => group.members)
        .map((SemanticChoiceMemberDraft member) => member.itemProductId)
        .toSet();
    final Set<int> availableProductIds = editorData.availableProducts
        .map((Product product) => product.id)
        .toSet();
    final Map<int, int> seenCounts = <int, int>{};

    for (int index = 0; index < draftConfiguration.extras.length; index += 1) {
      final SemanticExtraItemDraft extra = draftConfiguration.extras[index];
      final List<String> issues = <String>[];

      final int duplicateCount = (seenCounts[extra.itemProductId] ?? 0) + 1;
      seenCounts[extra.itemProductId] = duplicateCount;
      if (duplicateCount > 1) {
        issues.add('Duplicate extra selected.');
      }
      if (!availableProductIds.contains(extra.itemProductId)) {
        issues.add('Selected extra no longer exists in the catalog.');
      }
      if (extra.itemProductId == editorData.rootProduct.id) {
        issues.add('The set root cannot be used as an extra.');
      }
      if (_setRootProductIds.contains(extra.itemProductId)) {
        issues.add('A breakfast set root cannot be used as an extra.');
      }
      if (currentSetItemIds.contains(extra.itemProductId)) {
        issues.add('A set item product cannot also be used as an extra.');
      }
      if (currentChoiceMemberIds.contains(extra.itemProductId)) {
        issues.add('A choice member product cannot also be used as an extra.');
      }

      if (issues.isNotEmpty) {
        issuesByIndex[index] = List<String>.unmodifiable(
          issues.toSet().toList(growable: false),
        );
      }
    }

    return Map<int, List<String>>.unmodifiable(issuesByIndex);
  }

  Map<int, List<String>> _buildChoiceGroupInlineIssues({
    required SemanticProductConfigurationEditorData editorData,
    required SemanticProductConfigurationDraft draftConfiguration,
  }) {
    final Map<int, List<String>> issuesByIndex = <int, List<String>>{};
    final Set<int> currentSetItemIds = draftConfiguration.setItems
        .map((SemanticSetItemDraft item) => item.itemProductId)
        .toSet();
    final Set<int> availableProductIds = editorData.availableProducts
        .map((Product product) => product.id)
        .toSet();

    for (
      int groupIndex = 0;
      groupIndex < draftConfiguration.choiceGroups.length;
      groupIndex += 1
    ) {
      final SemanticChoiceGroupDraft group =
          draftConfiguration.choiceGroups[groupIndex];
      final List<String> issues = <String>[];

      if (group.minSelect > group.maxSelect) {
        issues.add(
          'Minimum selection cannot be greater than maximum selection.',
        );
      }
      if (group.includedQuantity > group.maxSelect) {
        issues.add(
          'Included quantity cannot be greater than maximum selection.',
        );
      }
      if (group.members.isEmpty) {
        issues.add('Choice groups must contain at least one member.');
      }

      final Set<int> memberIds = <int>{};
      for (final SemanticChoiceMemberDraft member in group.members) {
        if (!availableProductIds.contains(member.itemProductId)) {
          issues.add('A choice member no longer exists in the catalog.');
          continue;
        }
        if (!memberIds.add(member.itemProductId)) {
          issues.add('Duplicate members are not allowed in the same group.');
        }
        if (member.itemProductId == editorData.rootProduct.id) {
          issues.add('The set root cannot be selected as a choice member.');
        }
        if (_setRootProductIds.contains(member.itemProductId)) {
          issues.add('A breakfast set root cannot be a choice member.');
        }
        if (currentSetItemIds.contains(member.itemProductId)) {
          issues.add(
            'A product cannot be both a set item and a choice member.',
          );
        }
      }

      if (issues.isNotEmpty) {
        issuesByIndex[groupIndex] = List<String>.unmodifiable(
          issues.toSet().toList(growable: false),
        );
      }
    }

    return Map<int, List<String>>.unmodifiable(issuesByIndex);
  }

  SemanticProductConfigurationDraft _normalizeDraft(
    SemanticProductConfigurationDraft draftConfiguration,
  ) {
    final List<SemanticSetItemDraft> normalizedItems =
        List<SemanticSetItemDraft>.generate(
          draftConfiguration.setItems.length,
          (int index) {
            final SemanticSetItemDraft item =
                draftConfiguration.setItems[index];
            return item.copyWith(sortOrder: index);
          },
          growable: false,
        );
    final List<SemanticChoiceGroupDraft> normalizedGroups =
        List<SemanticChoiceGroupDraft>.generate(
          draftConfiguration.choiceGroups.length,
          (int groupIndex) {
            final SemanticChoiceGroupDraft group =
                draftConfiguration.choiceGroups[groupIndex];
            final List<SemanticChoiceMemberDraft> normalizedMembers =
                List<SemanticChoiceMemberDraft>.generate(group.members.length, (
                  int memberIndex,
                ) {
                  final SemanticChoiceMemberDraft member =
                      group.members[memberIndex];
                  return member.copyWith(position: memberIndex);
                }, growable: false);
            return group.copyWith(
              sortOrder: groupIndex,
              members: List<SemanticChoiceMemberDraft>.unmodifiable(
                normalizedMembers,
              ),
            );
          },
          growable: false,
        );
    final List<SemanticExtraItemDraft> normalizedExtras =
        List<SemanticExtraItemDraft>.generate(
          draftConfiguration.extras.length,
          (int index) {
            final SemanticExtraItemDraft extra =
                draftConfiguration.extras[index];
            return extra.copyWith(sortOrder: index);
          },
          growable: false,
        );
    return SemanticProductConfigurationDraft(
      productId: draftConfiguration.productId,
      setItems: List<SemanticSetItemDraft>.unmodifiable(normalizedItems),
      choiceGroups: List<SemanticChoiceGroupDraft>.unmodifiable(
        normalizedGroups,
      ),
      extras: List<SemanticExtraItemDraft>.unmodifiable(normalizedExtras),
    );
  }

  SemanticProductConfigurationDraft _replaceSetItems({
    required SemanticProductConfigurationDraft draftConfiguration,
    required List<SemanticSetItemDraft> setItems,
  }) {
    return SemanticProductConfigurationDraft(
      productId: draftConfiguration.productId,
      setItems: List<SemanticSetItemDraft>.unmodifiable(setItems),
      choiceGroups: draftConfiguration.choiceGroups,
      extras: draftConfiguration.extras,
    );
  }

  SemanticProductConfigurationDraft _replaceChoiceGroups({
    required SemanticProductConfigurationDraft draftConfiguration,
    required List<SemanticChoiceGroupDraft> choiceGroups,
  }) {
    return SemanticProductConfigurationDraft(
      productId: draftConfiguration.productId,
      setItems: draftConfiguration.setItems,
      choiceGroups: List<SemanticChoiceGroupDraft>.unmodifiable(choiceGroups),
      extras: draftConfiguration.extras,
    );
  }

  SemanticProductConfigurationDraft _replaceExtras({
    required SemanticProductConfigurationDraft draftConfiguration,
    required List<SemanticExtraItemDraft> extras,
  }) {
    return SemanticProductConfigurationDraft(
      productId: draftConfiguration.productId,
      setItems: draftConfiguration.setItems,
      choiceGroups: draftConfiguration.choiceGroups,
      extras: List<SemanticExtraItemDraft>.unmodifiable(extras),
    );
  }

  Future<void> _refreshExtraPresets() async {
    final SemanticProductConfigurationEditorData? editorData = state.editorData;
    if (editorData == null) {
      return;
    }
    final List<BreakfastExtraPreset> presets = await _ref
        .read(semanticMenuAdminServiceProvider)
        .loadExtraPresets();
    state = state.copyWith(
      editorData: editorData.copyWith(extraPresets: presets),
      errorMessage: null,
    );
  }
}

final StateNotifierProvider<
  AdminBreakfastSetEditorNotifier,
  AdminBreakfastSetEditorState
>
adminBreakfastSetEditorNotifierProvider =
    StateNotifierProvider<
      AdminBreakfastSetEditorNotifier,
      AdminBreakfastSetEditorState
    >((Ref ref) => AdminBreakfastSetEditorNotifier(ref));

const Object _unset = Object();

extension AdminBreakfastSetEditorDraftStatusPresentation
    on AdminBreakfastSetEditorDraftStatus {
  String get label {
    switch (this) {
      case AdminBreakfastSetEditorDraftStatus.valid:
        return 'Valid';
      case AdminBreakfastSetEditorDraftStatus.incomplete:
        return 'Incomplete';
      case AdminBreakfastSetEditorDraftStatus.invalid:
        return 'Invalid';
    }
  }
}

extension AdminBreakfastSetEditorIssueSectionPresentation
    on AdminBreakfastSetEditorIssueSection {
  String get label {
    switch (this) {
      case AdminBreakfastSetEditorIssueSection.setInfo:
        return 'Set Info';
      case AdminBreakfastSetEditorIssueSection.setItems:
        return 'Set Items';
      case AdminBreakfastSetEditorIssueSection.extras:
        return 'Extras';
      case AdminBreakfastSetEditorIssueSection.choiceGroups:
        return 'Choice Groups';
      case AdminBreakfastSetEditorIssueSection.general:
        return 'General';
    }
  }
}
