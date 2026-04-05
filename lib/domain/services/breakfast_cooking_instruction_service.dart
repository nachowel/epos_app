import '../models/breakfast_cooking_instruction.dart';
import '../models/breakfast_rebuild.dart';

class BreakfastCookingInstructionService {
  const BreakfastCookingInstructionService();

  static const List<BreakfastCookingInstructionOption> _eggOptions =
      <BreakfastCookingInstructionOption>[
        BreakfastCookingInstructionOption(code: 'runny', label: 'Runny'),
        BreakfastCookingInstructionOption(code: 'medium', label: 'Medium'),
        BreakfastCookingInstructionOption(
          code: 'well_done',
          label: 'Well done',
        ),
      ];

  static const List<BreakfastCookingInstructionOption> _baconOptions =
      <BreakfastCookingInstructionOption>[
        BreakfastCookingInstructionOption(code: 'soft', label: 'Soft'),
        BreakfastCookingInstructionOption(code: 'crispy', label: 'Crispy'),
        BreakfastCookingInstructionOption(
          code: 'extra_crispy',
          label: 'Extra crispy',
        ),
      ];

  List<BreakfastCookingInstructionTarget> buildTargets({
    required BreakfastSetConfiguration configuration,
    required BreakfastRequestedState requestedState,
  }) {
    final Map<int, int> effectiveQuantities = _buildEffectiveQuantities(
      configuration: configuration,
      requestedState: requestedState,
    );
    final Map<int, BreakfastCookingInstructionRequest> selectedByProductId =
        <int, BreakfastCookingInstructionRequest>{
          for (final BreakfastCookingInstructionRequest request
              in requestedState.cookingInstructions)
            request.itemProductId: request,
        };
    final Map<int, String> namesByProductId = _buildNamesByProductId(
      configuration,
    );
    final Map<int, int> sortKeysByProductId = _buildSortKeysByProductId(
      configuration,
    );

    final List<BreakfastCookingInstructionTarget> targets =
        <BreakfastCookingInstructionTarget>[];
    for (final MapEntry<int, int> entry in effectiveQuantities.entries) {
      if (entry.value <= 0) {
        continue;
      }
      final String itemName =
          namesByProductId[entry.key] ??
          configuration.findCatalogProduct(entry.key)?.name ??
          'Item';
      final List<BreakfastCookingInstructionOption> options = optionsForItem(
        itemName,
      );
      if (options.isEmpty) {
        continue;
      }
      final BreakfastCookingInstructionRequest? selected =
          selectedByProductId[entry.key];
      targets.add(
        BreakfastCookingInstructionTarget(
          itemProductId: entry.key,
          itemName: itemName,
          quantity: entry.value,
          sortKey: sortKeysByProductId[entry.key] ?? 0,
          options: options,
          selectedInstructionCode: selected?.instructionCode,
          selectedInstructionLabel: selected?.instructionLabel,
        ),
      );
    }

    targets.sort((
      BreakfastCookingInstructionTarget a,
      BreakfastCookingInstructionTarget b,
    ) {
      final int sortCompare = a.sortKey.compareTo(b.sortKey);
      if (sortCompare != 0) {
        return sortCompare;
      }
      return a.itemName.compareTo(b.itemName);
    });
    return List<BreakfastCookingInstructionTarget>.unmodifiable(targets);
  }

  BreakfastRequestedState sanitizeRequestedState({
    required BreakfastSetConfiguration configuration,
    required BreakfastRequestedState requestedState,
  }) {
    final Set<int> activeTargetIds =
        buildTargets(
              configuration: configuration,
              requestedState: requestedState,
            )
            .map(
              (BreakfastCookingInstructionTarget target) =>
                  target.itemProductId,
            )
            .toSet();

    final List<BreakfastCookingInstructionRequest> sanitized =
        requestedState.cookingInstructions
            .where((BreakfastCookingInstructionRequest request) {
              if (!activeTargetIds.contains(request.itemProductId)) {
                return false;
              }
              final String? itemName = _buildNamesByProductId(
                configuration,
              )[request.itemProductId];
              if (itemName == null) {
                return false;
              }
              final List<BreakfastCookingInstructionOption> options =
                  optionsForItem(itemName);
              return options.any(
                (BreakfastCookingInstructionOption option) =>
                    option.code == request.instructionCode,
              );
            })
            .toList(growable: true)
          ..sort(
            (
              BreakfastCookingInstructionRequest a,
              BreakfastCookingInstructionRequest b,
            ) => a.itemProductId.compareTo(b.itemProductId),
          );

    if (_listEquals(sanitized, requestedState.cookingInstructions)) {
      return requestedState;
    }
    return requestedState.copyWith(cookingInstructions: sanitized);
  }

  List<BreakfastCookingInstructionRecord> buildPersistedRecords({
    required int transactionLineId,
    required BreakfastSetConfiguration configuration,
    required BreakfastRequestedState requestedState,
    required String Function() createUuid,
  }) {
    return buildTargets(
          configuration: configuration,
          requestedState: requestedState,
        )
        .where(
          (BreakfastCookingInstructionTarget target) => target.hasSelection,
        )
        .map((BreakfastCookingInstructionTarget target) {
          final BreakfastCookingInstructionOption option = target.options
              .firstWhere(
                (BreakfastCookingInstructionOption candidate) =>
                    candidate.code == target.selectedInstructionCode,
              );
          return BreakfastCookingInstructionRecord(
            id: 0,
            uuid: createUuid(),
            transactionLineId: transactionLineId,
            itemProductId: target.itemProductId,
            itemName: target.itemName,
            instructionCode: option.code,
            instructionLabel: option.label,
            appliedQuantity: target.quantity,
            sortKey: target.sortKey,
          );
        })
        .toList(growable: false);
  }

  List<BreakfastCookingInstructionOption> optionsForItem(String itemName) {
    final String normalized = _normalizeName(itemName);
    if (normalized.contains('egg')) {
      return _eggOptions;
    }
    if (normalized.contains('bacon')) {
      return _baconOptions;
    }
    return const <BreakfastCookingInstructionOption>[];
  }

  Map<int, int> _buildEffectiveQuantities({
    required BreakfastSetConfiguration configuration,
    required BreakfastRequestedState requestedState,
  }) {
    final Map<int, int> quantities = <int, int>{};
    final Map<int, int> removedByProductId = <int, int>{
      for (final BreakfastRemovedSetItemRequest removal
          in requestedState.removedSetItems)
        removal.itemProductId: removal.quantity,
    };

    for (final BreakfastSetItemConfig item in configuration.setItems) {
      final int keptQuantity =
          item.defaultQuantity - (removedByProductId[item.itemProductId] ?? 0);
      if (keptQuantity > 0) {
        quantities.update(
          item.itemProductId,
          (int quantity) => quantity + keptQuantity,
          ifAbsent: () => keptQuantity,
        );
      }
    }

    for (final BreakfastChosenGroupRequest choice
        in requestedState.chosenGroups) {
      final int? selectedItemProductId = choice.selectedItemProductId;
      if (selectedItemProductId == null || choice.requestedQuantity <= 0) {
        continue;
      }
      quantities.update(
        selectedItemProductId,
        (int quantity) => quantity + choice.requestedQuantity,
        ifAbsent: () => choice.requestedQuantity,
      );
    }

    for (final BreakfastAddedProductRequest add
        in requestedState.addedProducts) {
      if (add.quantity <= 0) {
        continue;
      }
      quantities.update(
        add.itemProductId,
        (int quantity) => quantity + add.quantity,
        ifAbsent: () => add.quantity,
      );
    }

    return quantities;
  }

  Map<int, String> _buildNamesByProductId(
    BreakfastSetConfiguration configuration,
  ) {
    final Map<int, String> namesByProductId = <int, String>{};
    for (final BreakfastSetItemConfig item in configuration.setItems) {
      namesByProductId.putIfAbsent(item.itemProductId, () => item.itemName);
    }
    for (final BreakfastExtraItemConfig extra in configuration.extras) {
      namesByProductId.putIfAbsent(extra.itemProductId, () => extra.itemName);
    }
    for (final BreakfastChoiceGroupConfig group in configuration.choiceGroups) {
      for (final BreakfastChoiceGroupMemberConfig member in group.members) {
        namesByProductId.putIfAbsent(
          member.itemProductId,
          () => member.displayName,
        );
      }
    }
    for (final MapEntry<int, BreakfastCatalogProduct> entry
        in configuration.catalogProductsById.entries) {
      namesByProductId.putIfAbsent(entry.key, () => entry.value.name);
    }
    return namesByProductId;
  }

  Map<int, int> _buildSortKeysByProductId(
    BreakfastSetConfiguration configuration,
  ) {
    final Map<int, int> sortKeysByProductId = <int, int>{};
    for (final BreakfastSetItemConfig item in configuration.setItems) {
      sortKeysByProductId.update(
        item.itemProductId,
        (int current) => item.sortOrder < current ? item.sortOrder : current,
        ifAbsent: () => item.sortOrder,
      );
    }
    for (final BreakfastExtraItemConfig extra in configuration.extras) {
      sortKeysByProductId.update(
        extra.itemProductId,
        (int current) => extra.sortOrder < current ? extra.sortOrder : current,
        ifAbsent: () => extra.sortOrder,
      );
    }
    for (final BreakfastChoiceGroupConfig group in configuration.choiceGroups) {
      for (final BreakfastChoiceGroupMemberConfig member in group.members) {
        sortKeysByProductId.update(
          member.itemProductId,
          (int current) =>
              group.sortOrder < current ? group.sortOrder : current,
          ifAbsent: () => group.sortOrder,
        );
      }
    }
    return sortKeysByProductId;
  }

  String _normalizeName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}
