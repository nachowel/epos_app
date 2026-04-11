import '../../../../domain/models/product_modifier.dart';

class PinnedModifierPresentation {
  const PinnedModifierPresentation({required this.pinned, required this.base});

  final List<ProductModifier> pinned;
  final List<ProductModifier> base;

  bool get hasPinnedSection => pinned.isNotEmpty;
}

class ModifierScanGroup {
  const ModifierScanGroup({required this.label, required this.modifiers});

  final String label;
  final List<ProductModifier> modifiers;
}

PinnedModifierPresentation buildPinnedModifierPresentation({
  required List<ProductModifier> modifiers,
  required Map<int, int> usageCounts,
  int maxPinned = 6,
}) {
  if (modifiers.length <= maxPinned) {
    return PinnedModifierPresentation(
      pinned: const <ProductModifier>[],
      base: modifiers,
    );
  }

  final List<({ProductModifier modifier, int score, int index})> ranked =
      <({ProductModifier modifier, int score, int index})>[];
  for (int index = 0; index < modifiers.length; index += 1) {
    final ProductModifier modifier = modifiers[index];
    final int score = usageCounts[modifier.id] ?? 0;
    if (score <= 0) {
      continue;
    }
    ranked.add((modifier: modifier, score: score, index: index));
  }
  if (ranked.isEmpty) {
    return PinnedModifierPresentation(
      pinned: const <ProductModifier>[],
      base: modifiers,
    );
  }

  ranked.sort((
    ({ProductModifier modifier, int score, int index}) left,
    ({ProductModifier modifier, int score, int index}) right,
  ) {
    final int scoreCompare = right.score.compareTo(left.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return left.index.compareTo(right.index);
  });

  final List<ProductModifier> pinned = ranked
      .take(maxPinned)
      .map((({ProductModifier modifier, int score, int index}) entry) {
        return entry.modifier;
      })
      .toList(growable: false);
  final Set<int> pinnedIds = pinned
      .map((ProductModifier modifier) => modifier.id)
      .toSet();
  final List<ProductModifier> base = modifiers
      .where((ProductModifier modifier) => !pinnedIds.contains(modifier.id))
      .toList(growable: false);
  return PinnedModifierPresentation(pinned: pinned, base: base);
}

List<ModifierScanGroup> buildModifierScanGroups(
  List<ProductModifier> modifiers,
) {
  if (modifiers.isEmpty) {
    return const <ModifierScanGroup>[];
  }

  final Map<String, List<ProductModifier>> grouped =
      <String, List<ProductModifier>>{};
  final List<String> order = <String>[];

  for (final ProductModifier modifier in modifiers) {
    final String label = _scanGroupLabel(modifier.name);
    final List<ProductModifier> bucket = grouped.putIfAbsent(label, () {
      order.add(label);
      return <ProductModifier>[];
    });
    bucket.add(modifier);
  }

  if (order.length <= 1) {
    return const <ModifierScanGroup>[];
  }

  return order
      .map(
        (String label) => ModifierScanGroup(
          label: label,
          modifiers: List<ProductModifier>.unmodifiable(grouped[label]!),
        ),
      )
      .toList(growable: false);
}

String _scanGroupLabel(String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '#';
  }

  final String first = trimmed.substring(0, 1).toUpperCase();
  final int codeUnit = first.codeUnitAt(0);
  final bool isAsciiLetter = codeUnit >= 65 && codeUnit <= 90;
  final bool isDigit = codeUnit >= 48 && codeUnit <= 57;
  if (isAsciiLetter || isDigit) {
    return first;
  }
  return '#';
}

class CartActiveEditContext {
  const CartActiveEditContext({
    this.selectedLocalId,
    this.activeCorrectionLocalId,
    this.activeCorrectionTapCount = 0,
  });

  final String? selectedLocalId;
  final String? activeCorrectionLocalId;
  final int activeCorrectionTapCount;

  CartActiveEditContext focusItem(
    String localId, {
    bool resetCorrectionSequence = true,
  }) {
    return CartActiveEditContext(
      selectedLocalId: localId,
      activeCorrectionLocalId: resetCorrectionSequence
          ? localId
          : activeCorrectionLocalId,
      activeCorrectionTapCount: resetCorrectionSequence
          ? 0
          : activeCorrectionTapCount,
    );
  }

  CartActiveEditContext beginQuantityCorrection(String localId) {
    if (activeCorrectionLocalId == localId) {
      return CartActiveEditContext(
        selectedLocalId: localId,
        activeCorrectionLocalId: localId,
        activeCorrectionTapCount: activeCorrectionTapCount + 1,
      );
    }
    return CartActiveEditContext(
      selectedLocalId: localId,
      activeCorrectionLocalId: localId,
      activeCorrectionTapCount: 1,
    );
  }

  CartActiveEditContext prune(Iterable<String> existingLocalIds) {
    final Set<String> ids = existingLocalIds.toSet();
    final bool hasSelected =
        selectedLocalId != null && ids.contains(selectedLocalId);
    final bool hasCorrectionTarget =
        activeCorrectionLocalId != null &&
        ids.contains(activeCorrectionLocalId);
    return CartActiveEditContext(
      selectedLocalId: hasSelected ? selectedLocalId : null,
      activeCorrectionLocalId: hasCorrectionTarget
          ? activeCorrectionLocalId
          : null,
      activeCorrectionTapCount: hasCorrectionTarget
          ? activeCorrectionTapCount
          : 0,
    );
  }

  String? adjacentSelection(Iterable<String> existingLocalIds, int offset) {
    final List<String> ids = existingLocalIds.toList(growable: false);
    if (ids.isEmpty) {
      return null;
    }
    final int currentIndex = selectedLocalId == null
        ? -1
        : ids.indexOf(selectedLocalId!);
    if (currentIndex == -1) {
      return ids.first;
    }

    final int targetIndex = currentIndex + offset;
    if (targetIndex < 0 || targetIndex >= ids.length) {
      return null;
    }
    return ids[targetIndex];
  }
}
