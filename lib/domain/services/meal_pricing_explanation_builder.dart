import '../../core/utils/currency_formatter.dart';
import '../models/meal_adjustment_profile.dart';
import '../models/meal_customization.dart';
import '../models/meal_pricing_explanation.dart';

const bool kShowPricingDebug = false;

class MealPricingExplanationBuilder {
  const MealPricingExplanationBuilder();

  List<PricingExplanationLine> buildCartSummary({
    required MealCustomizationResolvedSnapshot snapshot,
    required Map<int, String> productNamesById,
  }) {
    if (snapshot.sandwichSelection != null) {
      return _buildSandwichCartSummary(
        snapshot: snapshot,
        productNamesById: productNamesById,
      );
    }
    final _ExplanationParts parts = _buildExplanationParts(
      snapshot: snapshot,
      productNamesById: productNamesById,
    );
    return <PricingExplanationLine>[
      ...parts.removeLines,
      ...parts.swapLines,
      ...parts.extraLines.map((PricingExplanationLine line) {
        if (line.priceEffectMinor == 0) {
          final String label = line.label.replaceFirst(' +£0.00', '');
          return PricingExplanationLine(
            label: label,
            priceEffectMinor: line.priceEffectMinor,
            type: line.type,
          );
        }
        return line;
      }),
      ...parts.comboLines.where(
        (PricingExplanationLine line) => line.priceEffectMinor != 0,
      ),
    ];
  }

  List<PricingExplanationLine> build({
    required MealCustomizationResolvedSnapshot snapshot,
    required Map<int, String> productNamesById,
  }) {
    if (snapshot.sandwichSelection != null) {
      return _buildSandwichCartSummary(
        snapshot: snapshot,
        productNamesById: productNamesById,
      );
    }
    final _ExplanationParts parts = _buildExplanationParts(
      snapshot: snapshot,
      productNamesById: productNamesById,
    );
    final List<PricingExplanationLine> rawLines = <PricingExplanationLine>[
      ...parts.removeLines,
      ...parts.swapLines,
      ...parts.extraLines,
      ...parts.comboLines,
    ];

    final List<PricingExplanationLine> filtered = rawLines
        .where((PricingExplanationLine line) {
          return line.type == 'swap' || line.priceEffectMinor != 0;
        })
        .toList(growable: false);

    if (filtered.isNotEmpty) {
      return filtered;
    }

    final List<PricingExplanationLine> fallbackRemoves = rawLines
        .where((PricingExplanationLine line) {
          return line.type == 'remove';
        })
        .toList(growable: false);
    if (fallbackRemoves.isNotEmpty) {
      return fallbackRemoves;
    }

    return const <PricingExplanationLine>[];
  }

  _ExplanationParts _buildExplanationParts({
    required MealCustomizationResolvedSnapshot snapshot,
    required Map<int, String> productNamesById,
  }) {
    final List<MealCustomizationSemanticAction> removedActions =
        List<MealCustomizationSemanticAction>.from(
          snapshot.resolvedComponentActions.where(
            (MealCustomizationSemanticAction action) =>
                action.action == MealCustomizationAction.remove,
          ),
        )..sort(_compareRemovedActions);
    final List<MealCustomizationSemanticAction> swapActions =
        List<MealCustomizationSemanticAction>.from(
          snapshot.resolvedComponentActions.where(
            (MealCustomizationSemanticAction action) =>
                action.action == MealCustomizationAction.swap,
          ),
        )..sort(_compareSwapActions);
    final List<MealCustomizationSemanticAction> extraActions =
        List<MealCustomizationSemanticAction>.from(
          snapshot.resolvedExtraActions,
        )..sort(_compareExtraActions);
    final List<MealCustomizationAppliedRule> appliedRules =
        List<MealCustomizationAppliedRule>.from(snapshot.appliedRules)
          ..sort(_compareAppliedRules);

    final Map<String, String> removedNamesByComponentKey = <String, String>{
      for (final MealCustomizationSemanticAction action in removedActions)
        action.componentKey ?? '':
            _resolveProductName(action.itemProductId, productNamesById) +
            _quantitySuffix(action.quantity),
    };
    final Map<String, int> removeEffectsByComponentKey = <String, int>{};
    for (final MealCustomizationAppliedRule rule in appliedRules) {
      if (rule.priceDeltaMinor == 0) {
        continue;
      }
      switch (rule.ruleType) {
        case MealAdjustmentPricingRuleType.removeOnly:
        case MealAdjustmentPricingRuleType.combo:
          for (final _ParsedConditionKey condition in rule.conditionKeys.map(
            _parseConditionKey,
          )) {
            if (condition.type !=
                    MealAdjustmentPricingRuleConditionType.removedComponent ||
                condition.componentKey == null ||
                condition.componentKey!.isEmpty) {
              continue;
            }
            removeEffectsByComponentKey[condition.componentKey!] =
                (removeEffectsByComponentKey[condition.componentKey!] ?? 0) +
                rule.priceDeltaMinor;
          }
          break;
        case MealAdjustmentPricingRuleType.swap:
        case MealAdjustmentPricingRuleType.extra:
          break;
      }
    }

    final List<PricingExplanationLine> removeLines = removedActions
        .map((MealCustomizationSemanticAction action) {
          final String itemName = _resolveProductName(
            action.itemProductId,
            productNamesById,
          );
          return PricingExplanationLine(
            label: 'No $itemName${_quantitySuffix(action.quantity)}',
            priceEffectMinor:
                removeEffectsByComponentKey[action.componentKey ?? ''] ?? 0,
            type: 'remove',
          );
        })
        .toList(growable: false);

    final List<PricingExplanationLine> swapLines = swapActions
        .map((MealCustomizationSemanticAction action) {
          final String sourceName = _resolveProductName(
            action.sourceItemProductId,
            productNamesById,
          );
          final String targetName = _resolveProductName(
            action.itemProductId,
            productNamesById,
          );
          return PricingExplanationLine(
            label:
                '$sourceName${_quantitySuffix(action.quantity)} → $targetName${_quantitySuffix(action.quantity)}',
            priceEffectMinor: action.priceDeltaMinor,
            type: 'swap',
          );
        })
        .toList(growable: false);

    final List<PricingExplanationLine> extraLines = extraActions
        .map((MealCustomizationSemanticAction action) {
          final String itemName = _resolveProductName(
            action.itemProductId,
            productNamesById,
          );
          final String label = action.priceDeltaMinor == 0
              ? 'Extra $itemName${_quantitySuffix(action.quantity)}'
              : 'Extra $itemName${_quantitySuffix(action.quantity)} ${_signedMoney(action.priceDeltaMinor)}';
          return PricingExplanationLine(
            label: label,
            priceEffectMinor: action.priceDeltaMinor,
            type: 'extra',
          );
        })
        .toList(growable: false);

    final List<PricingExplanationLine> comboLines = appliedRules
        .where((MealCustomizationAppliedRule rule) {
          return rule.ruleType == MealAdjustmentPricingRuleType.combo &&
              rule.priceDeltaMinor != 0;
        })
        .map((MealCustomizationAppliedRule rule) {
          final List<String> removedNames = rule.conditionKeys
              .map(_parseConditionKey)
              .where(
                (_ParsedConditionKey condition) =>
                    condition.type ==
                        MealAdjustmentPricingRuleConditionType
                            .removedComponent &&
                    condition.componentKey != null &&
                    condition.componentKey!.isNotEmpty,
              )
              .map(
                (_ParsedConditionKey condition) =>
                    removedNamesByComponentKey[condition.componentKey!] ??
                    _humanizeComponentKey(condition.componentKey!),
              )
              .toList(growable: false);
          if (removedNames.isEmpty) {
            return null;
          }
          final String joinedNames = removedNames.join(' + ');
          return PricingExplanationLine(
            label:
                '$joinedNames removed (${_signedMoney(rule.priceDeltaMinor)})',
            priceEffectMinor: rule.priceDeltaMinor,
            type: 'combo',
          );
        })
        .whereType<PricingExplanationLine>()
        .toList(growable: false);

    return _ExplanationParts(
      removeLines: removeLines,
      swapLines: swapLines,
      extraLines: extraLines,
      comboLines: comboLines,
    );
  }

  List<String> buildDebugLines({
    required MealCustomizationResolvedSnapshot snapshot,
  }) {
    final List<MealCustomizationAppliedRule> rules =
        List<MealCustomizationAppliedRule>.from(snapshot.appliedRules)
          ..sort(_compareAppliedRules);
    return rules
        .map((MealCustomizationAppliedRule rule) {
          return '[DEBUG]\n'
              'Rule: #${rule.ruleId} (${rule.ruleType.name})\n'
              'Delta: ${rule.priceDeltaMinor}\n'
              'Matched: true';
        })
        .toList(growable: false);
  }

  List<PricingExplanationLine> _buildSandwichCartSummary({
    required MealCustomizationResolvedSnapshot snapshot,
    required Map<int, String> productNamesById,
  }) {
    final SandwichCustomizationSelection selection =
        snapshot.sandwichSelection!;
    final List<PricingExplanationLine> lines = <PricingExplanationLine>[];
    for (final int sauceProductId in selection.sauceProductIds) {
      lines.add(
        PricingExplanationLine(
          label: _resolveProductName(sauceProductId, productNamesById),
          priceEffectMinor: 0,
          type: 'choice',
        ),
      );
    }
    final SandwichToastOption? toastOption = selection.toastOption;
    if (toastOption != null) {
      lines.add(
        PricingExplanationLine(
          label: sandwichToastLabel(toastOption),
          priceEffectMinor: 0,
          type: 'choice',
        ),
      );
    }
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedExtraActions) {
      final String itemName = _resolveProductName(
        action.itemProductId,
        productNamesById,
      );
      final String label = action.priceDeltaMinor == 0
          ? 'Extra $itemName${_quantitySuffix(action.quantity)}'
          : 'Extra $itemName${_quantitySuffix(action.quantity)} ${_signedMoney(action.priceDeltaMinor)}';
      lines.add(
        PricingExplanationLine(
          label: label,
          priceEffectMinor: action.priceDeltaMinor,
          type: 'extra',
        ),
      );
    }
    return lines;
  }

  String _resolveProductName(
    int? productId,
    Map<int, String> productNamesById,
  ) {
    if (productId == null) {
      return 'Unknown';
    }
    return productNamesById[productId] ?? 'Product $productId';
  }

  String _signedMoney(int amountMinor) {
    final String absolute = CurrencyFormatter.fromMinor(amountMinor.abs());
    if (amountMinor > 0) {
      return '+$absolute';
    }
    if (amountMinor < 0) {
      return '-$absolute';
    }
    return absolute;
  }

  String _quantitySuffix(int quantity) {
    return quantity > 1 ? ' x$quantity' : '';
  }

  _ParsedConditionKey _parseConditionKey(String key) {
    final List<String> parts = key.split('|');
    final MealAdjustmentPricingRuleConditionType type =
        MealAdjustmentPricingRuleConditionType.values.byName(parts.first);
    return _ParsedConditionKey(
      type: type,
      componentKey: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      itemProductId: parts.length > 2 && parts[2].isNotEmpty
          ? int.tryParse(parts[2])
          : null,
      quantity: parts.length > 3 ? int.tryParse(parts[3]) ?? 1 : 1,
    );
  }

  String _humanizeComponentKey(String value) {
    final List<String> words = value
        .split(RegExp(r'[_\s]+'))
        .where((String part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return value;
    }
    return words
        .map((String word) {
          final String lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  int _compareRemovedActions(
    MealCustomizationSemanticAction left,
    MealCustomizationSemanticAction right,
  ) {
    final int componentCompare = (left.componentKey ?? '').compareTo(
      right.componentKey ?? '',
    );
    if (componentCompare != 0) {
      return componentCompare;
    }
    return (left.itemProductId ?? -1).compareTo(right.itemProductId ?? -1);
  }

  int _compareSwapActions(
    MealCustomizationSemanticAction left,
    MealCustomizationSemanticAction right,
  ) {
    final int componentCompare = (left.componentKey ?? '').compareTo(
      right.componentKey ?? '',
    );
    if (componentCompare != 0) {
      return componentCompare;
    }
    final int sourceCompare = (left.sourceItemProductId ?? -1).compareTo(
      right.sourceItemProductId ?? -1,
    );
    if (sourceCompare != 0) {
      return sourceCompare;
    }
    return (left.itemProductId ?? -1).compareTo(right.itemProductId ?? -1);
  }

  int _compareExtraActions(
    MealCustomizationSemanticAction left,
    MealCustomizationSemanticAction right,
  ) {
    return (left.itemProductId ?? -1).compareTo(right.itemProductId ?? -1);
  }

  int _compareAppliedRules(
    MealCustomizationAppliedRule left,
    MealCustomizationAppliedRule right,
  ) {
    final int specificityCompare = right.specificityScore.compareTo(
      left.specificityScore,
    );
    if (specificityCompare != 0) {
      return specificityCompare;
    }
    final int priorityCompare = right.priority.compareTo(left.priority);
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    return left.ruleId.compareTo(right.ruleId);
  }
}

class _ParsedConditionKey {
  const _ParsedConditionKey({
    required this.type,
    required this.componentKey,
    required this.itemProductId,
    required this.quantity,
  });

  final MealAdjustmentPricingRuleConditionType type;
  final String? componentKey;
  final int? itemProductId;
  final int quantity;
}

class _ExplanationParts {
  const _ExplanationParts({
    required this.removeLines,
    required this.swapLines,
    required this.extraLines,
    required this.comboLines,
  });

  final List<PricingExplanationLine> removeLines;
  final List<PricingExplanationLine> swapLines;
  final List<PricingExplanationLine> extraLines;
  final List<PricingExplanationLine> comboLines;
}
