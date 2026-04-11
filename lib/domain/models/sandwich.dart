enum SandwichBreadType { roll, sandwich, baguette }

enum SandwichToastOption { normal, toasted }

const int kDefaultSandwichSurchargeMinor = 100;
const int kDefaultBaguetteSurchargeMinor = 180;
const String kSaucesCategoryName = 'Sauces';
const String _legacySandwichSauceKetchup = 'ketchup';
const String _legacySandwichSauceMayo = 'mayo';
const String _legacySandwichSauceBrownSauce = 'brownSauce';
const String _legacySandwichSauceChilliSauce = 'chilliSauce';
const List<String> kLegacyDefaultSandwichSauceLookupKeys = <String>[
  _legacySandwichSauceKetchup,
  _legacySandwichSauceMayo,
  _legacySandwichSauceBrownSauce,
  _legacySandwichSauceChilliSauce,
];

const Map<String, List<String>> _legacySandwichSauceAliases =
    <String, List<String>>{
      _legacySandwichSauceKetchup: <String>[
        'ketchup',
        'tomatoketchup',
        'tomatosauce',
      ],
      _legacySandwichSauceMayo: <String>['mayo', 'mayonnaise'],
      _legacySandwichSauceBrownSauce: <String>['brownsauce', 'brown'],
      _legacySandwichSauceChilliSauce: <String>[
        'chillisauce',
        'chilli',
        'chilisauce',
      ],
    };

List<int> normalizeSandwichSauceProductIds(Iterable<int> sauceProductIds) {
  final Set<int> seen = <int>{};
  final List<int> normalized = <int>[];
  for (final int productId in sauceProductIds) {
    if (productId <= 0 || !seen.add(productId)) {
      continue;
    }
    normalized.add(productId);
  }
  return List<int>.unmodifiable(normalized);
}

List<String> normalizeLegacySandwichSauceLookupKeys(Iterable<String> keys) {
  final Set<String> seen = <String>{};
  final List<String> normalized = <String>[];
  for (final String rawKey in keys) {
    final String? canonical = canonicalLegacySandwichSauceLookupKey(rawKey);
    if (canonical == null || !seen.add(canonical)) {
      continue;
    }
    normalized.add(canonical);
  }
  return List<String>.unmodifiable(normalized);
}

String normalizeSandwichSauceLookupValue(String value) {
  final String trimmed = value.trim().toLowerCase();
  return trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String? canonicalLegacySandwichSauceLookupKey(String rawValue) {
  final String normalized = normalizeSandwichSauceLookupValue(rawValue);
  if (normalized.isEmpty) {
    return null;
  }
  for (final MapEntry<String, List<String>> entry
      in _legacySandwichSauceAliases.entries) {
    for (final String alias in entry.value) {
      if (normalizeSandwichSauceLookupValue(alias) == normalized) {
        return entry.key;
      }
    }
  }
  return null;
}

List<String> sandwichSauceLookupTokensForName(String productName) {
  final String normalized = normalizeSandwichSauceLookupValue(productName);
  if (normalized.isEmpty) {
    return const <String>[];
  }
  final String? canonical = canonicalLegacySandwichSauceLookupKey(normalized);
  if (canonical == null) {
    return <String>[normalized];
  }
  final List<String> aliases = _legacySandwichSauceAliases[canonical]!;
  return <String>{
    normalized,
    canonical,
    ...aliases.map(normalizeSandwichSauceLookupValue),
  }.toList(growable: false);
}

int sandwichBreadLabelSortRank(SandwichBreadType breadType) {
  switch (breadType) {
    case SandwichBreadType.roll:
      return 0;
    case SandwichBreadType.sandwich:
      return 1;
    case SandwichBreadType.baguette:
      return 2;
  }
}

String sandwichBreadLabel(SandwichBreadType breadType) {
  switch (breadType) {
    case SandwichBreadType.roll:
      return 'Roll';
    case SandwichBreadType.sandwich:
      return 'Sandwich';
    case SandwichBreadType.baguette:
      return 'Baguette';
  }
}

String legacySandwichSauceLabel(String lookupKey) {
  switch (lookupKey) {
    case _legacySandwichSauceKetchup:
      return 'Ketchup';
    case _legacySandwichSauceMayo:
      return 'Mayo';
    case _legacySandwichSauceBrownSauce:
      return 'Brown Sauce';
    case _legacySandwichSauceChilliSauce:
      return 'Chilli Sauce';
    default:
      return lookupKey;
  }
}

String sandwichToastLabel(SandwichToastOption toastOption) {
  switch (toastOption) {
    case SandwichToastOption.normal:
      return 'Normal';
    case SandwichToastOption.toasted:
      return 'Toasted';
  }
}
