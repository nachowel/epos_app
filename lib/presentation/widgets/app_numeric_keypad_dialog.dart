import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/utils/currency_formatter.dart';

/// Developer note
///
/// This migration is partial. Some numeric-entry screens still use legacy
/// text entry and should be audited deliberately before reuse work continues.
///
/// Use [AppNumericKeypadDialog.showNormalizedText] for non-money numeric entry
/// where the caller intentionally owns normalized text parsing. Admin-only
/// signed-money configuration should compose through this normalized-text path
/// at the call site instead of adding more shared money-specific helpers.
///
/// Use [AppNumericKeypadDialog.showCurrencyMinor] for money fields. Money entry
/// should avoid raw string contracts so behavior can round-trip through minor
/// units safely and deterministically.
///
/// PIN, password, and auth-style numeric inputs are a separate interaction
/// class. Do not automatically reuse this money-entry UX for credential flows.
///
/// Non-production or legacy screens should not be treated as integration
/// targets for this keypad without first confirming they are routed product UI.
///
/// Migration status:
/// - Verified migrated shared money-safe:
///   Custom Sale price, Payment received amount, Checkout custom discount
///   amount, Admin report settings money fields, Admin cash movement amount,
///   Counted cash, Admin modifier/product/breakfast-set/set-builder price
///   fields.
/// - Verified migrated shared generic:
///   Checkout custom discount percent entry.
/// - Legacy intentionally deferred:
///   Legacy compatibility settings screen, orders search/table-number flows,
///   and remaining admin numeric config editors that still rely on text entry.
/// - Intentionally separate flows:
///   PIN/auth/credential inputs such as login PIN and admin PIN management.
///
/// Manual QA checklist for future changes:
/// - Rapid reopen after cancel/apply
/// - Route change while the dialog is closing
/// - Windows touch + mouse interaction
/// - Enter / Escape / Backspace keyboard behavior
/// - Preset tap, then next digit replaces the preset
class AppNumericKeypadPreset {
  const AppNumericKeypadPreset({required this.label, required this.value});

  final String label;
  final String value;
}

/// Shared keypad configuration contract.
///
/// Semantics:
/// - [maxLength] counts numeric digits only. The decimal separator does not
///   count toward the limit.
/// - When [allowNegative] is enabled, the leading `-` sign does not count
///   toward [maxLength]. This is intended for local admin/config wrappers, not
///   normal POS money entry.
/// - In decimal mode, [maxLength] applies across whole and fractional digits.
/// - In currency mode, decimal input is always enabled and fractional
///   precision is fixed to 2 digits so values can round-trip through minor
///   units deterministically.
/// - [allowEmpty] only changes whether Apply may return an empty contract.
class AppNumericValueOptions {
  const AppNumericValueOptions({
    this.allowDecimal = true,
    this.allowEmpty = false,
    this.allowNegative = false,
    this.currencyMode = false,
    this.maxDecimalDigits = 2,
    this.maxLength,
  }) : assert(maxDecimalDigits >= 0),
       assert(maxLength == null || maxLength > 0);

  final bool allowDecimal;
  final bool allowEmpty;
  final bool allowNegative;
  final bool currencyMode;
  final int maxDecimalDigits;
  final int? maxLength;

  bool get effectiveAllowDecimal => currencyMode || allowDecimal;
  int get effectiveMaxDecimalDigits => currencyMode ? 2 : maxDecimalDigits;
}

class AppNumericEditResult {
  const AppNumericEditResult({
    required this.value,
    required this.replaceOnNextDigit,
  });

  final String value;
  final bool replaceOnNextDigit;
}

class AppNumericInputLogic {
  const AppNumericInputLogic._();

  /// Sanitizes external values into the keypad's editable text contract.
  static String sanitizeInitialValue(
    String value,
    AppNumericValueOptions options,
  ) {
    return _sanitize(value, options, preserveTrailingDecimal: false);
  }

  static String previewValue(
    String value, {
    required AppNumericValueOptions options,
    required String emptyPreview,
  }) {
    if (value.trim().isEmpty) {
      return emptyPreview;
    }
    if (!options.currencyMode) {
      return value;
    }
    final String normalized = normalizeForApply(value, options) ?? emptyPreview;
    return normalized.isEmpty ? emptyPreview : normalized;
  }

  /// Normalizes keypad state into the dialog's apply contract.
  ///
  /// Returns:
  /// - `null` when the value is not valid/applicable for Apply
  /// - `''` when [AppNumericValueOptions.allowEmpty] is enabled and the user
  ///   explicitly applies an empty value
  /// - normalized numeric text otherwise
  ///
  /// In currency mode the returned value is always a major-unit string with
  /// exactly 2 decimals, for example `12.50`.
  /// This helper intentionally does not coerce empty to `0` or apply
  /// field-specific required/minimum rules; callers own those semantics.
  static String? normalizeForApply(
    String value,
    AppNumericValueOptions options,
  ) {
    final String sanitized = _sanitize(
      value,
      options,
      preserveTrailingDecimal: false,
    );
    if (sanitized.isEmpty) {
      return options.allowEmpty ? '' : null;
    }

    if (options.currencyMode) {
      final int? amountMinor = options.allowNegative
          ? CurrencyFormatter.tryParseSignedEditableMajorInput(sanitized)
          : CurrencyFormatter.tryParseEditableMajorInput(sanitized);
      if (amountMinor == null) {
        return null;
      }
      return CurrencyFormatter.toEditableMajorInput(amountMinor);
    }

    return sanitized;
  }

  static bool canApply(String value, AppNumericValueOptions options) {
    final String? normalized = normalizeForApply(value, options);
    if (normalized == null) {
      return false;
    }
    return options.allowEmpty || normalized.isNotEmpty;
  }

  /// Converts currency-mode text into minor units for money-safe behavior.
  static int? tryParseCurrencyMinor(String value) {
    final String normalized =
        normalizeForApply(
          value,
          const AppNumericValueOptions(currencyMode: true),
        ) ??
        '';
    if (normalized.isEmpty) {
      return 0;
    }
    return CurrencyFormatter.tryParseEditableMajorInput(normalized);
  }

  static AppNumericEditResult appendDigit({
    required String currentValue,
    required String digit,
    required bool replaceOnNextDigit,
    required AppNumericValueOptions options,
  }) {
    assert(RegExp(r'^\d$').hasMatch(digit));

    String base = replaceOnNextDigit ? '' : currentValue;
    final bool isNegative = base.startsWith('-');
    String unsignedBase = isNegative ? base.substring(1) : base;
    if (unsignedBase == '0') {
      unsignedBase = '';
    }
    if (_digitCount(base) >= (options.maxLength ?? 1 << 30)) {
      return AppNumericEditResult(
        value: base.isEmpty ? '0' : base,
        replaceOnNextDigit: false,
      );
    }
    if (unsignedBase.contains('.')) {
      final String decimals = unsignedBase.split('.').last;
      if (decimals.length >= options.effectiveMaxDecimalDigits) {
        return AppNumericEditResult(value: base, replaceOnNextDigit: false);
      }
    }

    final String nextUnsigned =
        '${unsignedBase.isEmpty ? '' : unsignedBase}$digit';
    final String nextValue = isNegative ? '-$nextUnsigned' : nextUnsigned;
    return AppNumericEditResult(value: nextValue, replaceOnNextDigit: false);
  }

  static AppNumericEditResult appendDecimal({
    required String currentValue,
    required bool replaceOnNextDigit,
    required AppNumericValueOptions options,
  }) {
    if (!options.effectiveAllowDecimal) {
      return AppNumericEditResult(
        value: currentValue,
        replaceOnNextDigit: replaceOnNextDigit,
      );
    }

    String base = replaceOnNextDigit ? '' : currentValue;
    final bool isNegative = base.startsWith('-');
    String unsignedBase = isNegative ? base.substring(1) : base;
    if (unsignedBase.contains('.')) {
      return AppNumericEditResult(value: base, replaceOnNextDigit: false);
    }
    if (unsignedBase.isEmpty) {
      unsignedBase = '0';
    }

    final String nextValue = '${isNegative ? '-' : ''}$unsignedBase.';
    return AppNumericEditResult(value: nextValue, replaceOnNextDigit: false);
  }

  static AppNumericEditResult backspace({
    required String currentValue,
    required bool replaceOnNextDigit,
    String emptyValue = '',
  }) {
    if (replaceOnNextDigit) {
      return AppNumericEditResult(value: emptyValue, replaceOnNextDigit: false);
    }
    if (currentValue.isEmpty) {
      return AppNumericEditResult(value: emptyValue, replaceOnNextDigit: false);
    }

    String nextValue = currentValue.substring(0, currentValue.length - 1);
    if (nextValue.endsWith('.')) {
      nextValue = nextValue.substring(0, nextValue.length - 1);
    }
    if (nextValue == '-') {
      nextValue = '';
    }

    return AppNumericEditResult(
      value: nextValue.isEmpty ? emptyValue : nextValue,
      replaceOnNextDigit: false,
    );
  }

  static AppNumericEditResult clear({String emptyValue = ''}) {
    return AppNumericEditResult(value: emptyValue, replaceOnNextDigit: false);
  }

  static AppNumericEditResult toggleNegative({
    required String currentValue,
    required bool replaceOnNextDigit,
    required AppNumericValueOptions options,
  }) {
    if (!options.allowNegative) {
      return AppNumericEditResult(
        value: currentValue,
        replaceOnNextDigit: replaceOnNextDigit,
      );
    }

    final String base = currentValue;
    if (base.isEmpty) {
      return const AppNumericEditResult(value: '-', replaceOnNextDigit: false);
    }
    if (base == '-') {
      return const AppNumericEditResult(value: '', replaceOnNextDigit: false);
    }
    if (base.startsWith('-')) {
      return AppNumericEditResult(
        value: base.substring(1),
        replaceOnNextDigit: false,
      );
    }
    return AppNumericEditResult(value: '-$base', replaceOnNextDigit: false);
  }

  static String _sanitize(
    String value,
    AppNumericValueOptions options, {
    required bool preserveTrailingDecimal,
  }) {
    final String trimmed = value.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) {
      return '';
    }

    final bool allowDecimal = options.effectiveAllowDecimal;
    final RegExp validPattern;
    if (allowDecimal) {
      validPattern = options.allowNegative
          ? RegExp(r'^-?\d*(\.\d*)?$')
          : RegExp(r'^\d*(\.\d*)?$');
    } else {
      validPattern = options.allowNegative
          ? RegExp(r'^-?\d*$')
          : RegExp(r'^\d*$');
    }
    if (!validPattern.hasMatch(trimmed)) {
      return '';
    }

    final bool isNegative = options.allowNegative && trimmed.startsWith('-');
    final String unsignedValue = isNegative ? trimmed.substring(1) : trimmed;
    final List<String> parts = unsignedValue.split('.');
    String whole = parts.first;
    String decimals = parts.length == 2 ? parts.last : '';
    final bool hadDecimal = allowDecimal && parts.length == 2;

    whole = _normalizeWholeDigits(whole);
    if (whole.isEmpty && hadDecimal) {
      whole = '0';
    }
    if (whole.isEmpty && decimals.isEmpty) {
      return '';
    }

    decimals = _applyMaxLengthToDecimals(
      whole: whole,
      decimals: decimals,
      options: options,
    );
    whole = _applyMaxLengthToWhole(whole: whole, options: options);

    if (!allowDecimal) {
      return _applySignIfNeeded(whole, isNegative);
    }
    if (decimals.isEmpty) {
      final String normalized = hadDecimal && preserveTrailingDecimal
          ? '$whole.'
          : whole;
      return _applySignIfNeeded(normalized, isNegative);
    }
    return _applySignIfNeeded('$whole.$decimals', isNegative);
  }

  static String _applySignIfNeeded(String value, bool isNegative) {
    if (!isNegative) {
      return value;
    }
    if (value.isEmpty || RegExp(r'^0(\.0*)?$').hasMatch(value)) {
      return value;
    }
    return '-$value';
  }

  static String _normalizeWholeDigits(String whole) {
    if (whole.isEmpty) {
      return '';
    }
    final String normalized = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return normalized.isEmpty ? '0' : normalized;
  }

  static String _applyMaxLengthToWhole({
    required String whole,
    required AppNumericValueOptions options,
  }) {
    final int? maxLength = options.maxLength;
    if (maxLength == null || whole.length <= maxLength) {
      return whole;
    }
    return whole.substring(0, maxLength);
  }

  static String _applyMaxLengthToDecimals({
    required String whole,
    required String decimals,
    required AppNumericValueOptions options,
  }) {
    String limited = decimals;
    if (limited.length > options.effectiveMaxDecimalDigits) {
      limited = limited.substring(0, options.effectiveMaxDecimalDigits);
    }

    final int? maxLength = options.maxLength;
    if (maxLength == null) {
      return limited;
    }

    if (whole.length >= maxLength) {
      return '';
    }
    final int allowedDecimals = maxLength - whole.length;
    if (allowedDecimals <= 0) {
      return '';
    }
    if (limited.length <= allowedDecimals) {
      return limited;
    }
    return limited.substring(0, allowedDecimals);
  }

  static int _digitCount(String value) {
    return value.replaceAll('.', '').replaceAll('-', '').length;
  }
}

class AppNumericKeypadDialog extends StatefulWidget {
  const AppNumericKeypadDialog({
    this.title = 'Enter value',
    this.previewLabel,
    this.initialValue = '',
    this.prefixText = '',
    this.emptyPreview = '0',
    this.cancelLabel = 'Cancel',
    this.clearLabel = 'Clear',
    this.confirmButtonLabel = 'Apply',
    this.presets = const <AppNumericKeypadPreset>[],
    this.valueOptions = const AppNumericValueOptions(),
    super.key,
  });

  final String title;
  final String? previewLabel;
  final String initialValue;
  final String prefixText;
  final String emptyPreview;
  final String cancelLabel;
  final String clearLabel;
  final String confirmButtonLabel;
  final List<AppNumericKeypadPreset> presets;
  final AppNumericValueOptions valueOptions;

  /// Opens the shared keypad dialog and returns normalized non-money text.
  ///
  /// Return contract:
  /// - `null` when the user cancels
  /// - `''` only when `allowEmpty` is true and Apply is pressed on empty input
  /// - normalized numeric text otherwise
  ///
  /// This is the lowest-level shared dialog contract. Normal POS money entry
  /// should keep using [showCurrencyMinor] instead of reintroducing raw-string
  /// money handling at the call site.
  static Future<String?> showNormalizedText(
    BuildContext context, {
    String title = 'Enter value',
    String? previewLabel,
    String initialValue = '',
    String prefixText = '',
    String emptyPreview = '0',
    String cancelLabel = 'Cancel',
    String clearLabel = 'Clear',
    String confirmButtonLabel = 'Apply',
    List<AppNumericKeypadPreset> presets = const <AppNumericKeypadPreset>[],
    bool allowDecimal = true,
    bool allowEmpty = false,
    bool allowNegative = false,
    int maxDecimalDigits = 2,
    int? maxLength,
    FocusNode? restoreFocusNode,
  }) async {
    return _showWithOptions(
      context,
      title: title,
      previewLabel: previewLabel,
      initialValue: initialValue,
      prefixText: prefixText,
      emptyPreview: emptyPreview,
      cancelLabel: cancelLabel,
      clearLabel: clearLabel,
      confirmButtonLabel: confirmButtonLabel,
      presets: presets,
      valueOptions: AppNumericValueOptions(
        allowDecimal: allowDecimal,
        allowEmpty: allowEmpty,
        allowNegative: allowNegative,
        currencyMode: false,
        maxDecimalDigits: maxDecimalDigits,
        maxLength: maxLength,
      ),
      restoreFocusNode: restoreFocusNode,
    );
  }

  @Deprecated(
    'Use showNormalizedText for generic entry or showCurrencyMinor for money entry.',
  )
  static Future<String?> show(
    BuildContext context, {
    String title = 'Enter value',
    String? previewLabel,
    String initialValue = '',
    String prefixText = '',
    String emptyPreview = '0',
    String cancelLabel = 'Cancel',
    String clearLabel = 'Clear',
    String confirmButtonLabel = 'Apply',
    List<AppNumericKeypadPreset> presets = const <AppNumericKeypadPreset>[],
    bool allowDecimal = true,
    bool allowEmpty = false,
    bool allowNegative = false,
    bool currencyMode = false,
    int maxDecimalDigits = 2,
    int? maxLength,
    FocusNode? restoreFocusNode,
  }) {
    if (currencyMode) {
      throw UnsupportedError(
        'Money fields must use AppNumericKeypadDialog.showCurrencyMinor.',
      );
    }
    return showNormalizedText(
      context,
      title: title,
      previewLabel: previewLabel,
      initialValue: initialValue,
      prefixText: prefixText,
      emptyPreview: emptyPreview,
      cancelLabel: cancelLabel,
      clearLabel: clearLabel,
      confirmButtonLabel: confirmButtonLabel,
      presets: presets,
      allowDecimal: allowDecimal,
      allowEmpty: allowEmpty,
      allowNegative: allowNegative,
      maxDecimalDigits: maxDecimalDigits,
      maxLength: maxLength,
      restoreFocusNode: restoreFocusNode,
    );
  }

  /// Opens the keypad for money entry and returns minor units.
  ///
  /// This is the preferred contract for business logic that should not rely on
  /// formatted strings for money behavior.
  static Future<int?> showCurrencyMinor(
    BuildContext context, {
    required String title,
    String? previewLabel,
    int? initialMinor,
    String prefixText = '',
    String emptyPreview = '0.00',
    String cancelLabel = 'Cancel',
    String clearLabel = 'Clear',
    String confirmButtonLabel = 'Apply',
    List<AppNumericKeypadPreset> presets = const <AppNumericKeypadPreset>[],
    FocusNode? restoreFocusNode,
  }) async {
    final String? normalized = await _showWithOptions(
      context,
      title: title,
      previewLabel: previewLabel,
      initialValue: initialMinor == null
          ? ''
          : CurrencyFormatter.toEditableMajorInput(initialMinor),
      prefixText: prefixText,
      emptyPreview: emptyPreview,
      cancelLabel: cancelLabel,
      clearLabel: clearLabel,
      confirmButtonLabel: confirmButtonLabel,
      presets: presets,
      valueOptions: const AppNumericValueOptions(currencyMode: true),
      restoreFocusNode: restoreFocusNode,
    );
    if (normalized == null) {
      return null;
    }
    return AppNumericInputLogic.tryParseCurrencyMinor(normalized);
  }

  static Future<String?> _showWithOptions(
    BuildContext context, {
    required String title,
    required String? previewLabel,
    required String initialValue,
    required String prefixText,
    required String emptyPreview,
    required String cancelLabel,
    required String clearLabel,
    required String confirmButtonLabel,
    required List<AppNumericKeypadPreset> presets,
    required AppNumericValueOptions valueOptions,
    required FocusNode? restoreFocusNode,
  }) async {
    final FocusNode? focusToRestore =
        restoreFocusNode ?? FocusManager.instance.primaryFocus;
    focusToRestore?.unfocus();

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AppNumericKeypadDialog(
          title: title,
          previewLabel: previewLabel,
          initialValue: initialValue,
          prefixText: prefixText,
          emptyPreview: emptyPreview,
          cancelLabel: cancelLabel,
          clearLabel: clearLabel,
          confirmButtonLabel: confirmButtonLabel,
          presets: presets,
          valueOptions: valueOptions,
        );
      },
    );

    _restoreFocusSafely(focusToRestore);
    return result;
  }

  static void _restoreFocusSafely(FocusNode? focusNode) {
    if (focusNode == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final FocusNode? primaryFocus = FocusManager.instance.primaryFocus;
        final BuildContext? targetContext = focusNode.context;
        final BuildContext? primaryContext = primaryFocus?.context;
        final ModalRoute<dynamic>? targetRoute = targetContext == null
            ? null
            : ModalRoute.of(targetContext);
        final ModalRoute<dynamic>? primaryRoute = primaryContext == null
            ? null
            : ModalRoute.of(primaryContext);
        final bool differentActiveRouteOwnsFocus =
            primaryFocus != null &&
            primaryFocus != focusNode &&
            primaryFocus != FocusManager.instance.rootScope &&
            primaryContext != null &&
            primaryRoute != null &&
            targetRoute != null &&
            primaryRoute != targetRoute;
        if (differentActiveRouteOwnsFocus) {
          return;
        }
        if (focusNode.context == null || !focusNode.canRequestFocus) {
          return;
        }
        focusNode.requestFocus();
      } catch (_) {
        // Skip restoration if the owner disposed or detached the node while the
        // dialog was closing.
      }
    });
  }

  @override
  State<AppNumericKeypadDialog> createState() => _AppNumericKeypadDialogState();
}

class _AppNumericKeypadDialogState extends State<AppNumericKeypadDialog> {
  late String _value;
  late bool _replaceOnNextDigit;

  bool get _canApply =>
      AppNumericInputLogic.canApply(_value, widget.valueOptions);

  @override
  void initState() {
    super.initState();
    _value = AppNumericInputLogic.sanitizeInitialValue(
      widget.initialValue,
      widget.valueOptions,
    );
    _replaceOnNextDigit = _value.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size screenSize = MediaQuery.sizeOf(context);
    final double dialogWidth = math.min(screenSize.width * 0.42, 460);
    final String previewValue = AppNumericInputLogic.previewValue(
      _value,
      options: widget.valueOptions,
      emptyPreview: widget.emptyPreview,
    );

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(360, screenSize.height - 36),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (widget.previewLabel != null) ...<Widget>[
                            Text(
                              widget.previewLabel!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          FittedBox(
                            key: const ValueKey<String>(
                              'app-numeric-keypad-preview',
                            ),
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${widget.prefixText}$previewValue',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.presets.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.presets
                            .map(
                              (AppNumericKeypadPreset preset) => OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    // Presets replace the current value and
                                    // prime the next digit to replace the
                                    // preset, matching payment quick-action
                                    // behavior.
                                    _value =
                                        AppNumericInputLogic.sanitizeInitialValue(
                                          preset.value,
                                          widget.valueOptions,
                                        );
                                    _replaceOnNextDigit = true;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  minimumSize: const Size(96, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusMd,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  preset.label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (widget.valueOptions.allowNegative) ...<Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: const ValueKey<String>(
                            'app-numeric-keypad-toggle-sign',
                          ),
                          onPressed: _toggleNegative,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                          ),
                          child: Text(
                            _value.startsWith('-')
                                ? 'Make positive'
                                : 'Make negative',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppNumericKeypad(
                      allowDecimal: widget.valueOptions.effectiveAllowDecimal,
                      keyPrefix: 'app-numeric-keypad',
                      onDigit: _appendDigit,
                      onDecimal: _appendDecimal,
                      onBackspace: _backspace,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey<String>(
                              'app-numeric-keypad-cancel',
                            ),
                            onPressed: _cancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusLg,
                                ),
                              ),
                            ),
                            child: Text(
                              widget.cancelLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey<String>(
                              'app-numeric-keypad-clear',
                            ),
                            onPressed: _clear,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusLg,
                                ),
                              ),
                            ),
                            child: Text(
                              widget.clearLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        key: const ValueKey<String>('app-numeric-keypad-apply'),
                        onPressed: _canApply ? _apply : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.surface,
                          disabledBackgroundColor: AppColors.surfaceMuted,
                          disabledForegroundColor: AppColors.textMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLg,
                            ),
                          ),
                        ),
                        child: Text(
                          widget.confirmButtonLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _canApply
                                ? AppColors.surface
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_canApply) {
        _apply();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _toggleNegative();
      return KeyEventResult.handled;
    }

    final String? digit = _digitForKey(key);
    if (digit != null) {
      _appendDigit(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal ||
        key == LogicalKeyboardKey.comma) {
      _appendDecimal();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String? _digitForKey(LogicalKeyboardKey key) {
    final Map<LogicalKeyboardKey, String> keyMap = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    return keyMap[key];
  }

  void _appendDigit(String digit) {
    final AppNumericEditResult result = AppNumericInputLogic.appendDigit(
      currentValue: _value,
      digit: digit,
      replaceOnNextDigit: _replaceOnNextDigit,
      options: widget.valueOptions,
    );
    setState(() {
      _value = result.value;
      _replaceOnNextDigit = result.replaceOnNextDigit;
    });
  }

  void _appendDecimal() {
    final AppNumericEditResult result = AppNumericInputLogic.appendDecimal(
      currentValue: _value,
      replaceOnNextDigit: _replaceOnNextDigit,
      options: widget.valueOptions,
    );
    setState(() {
      _value = result.value;
      _replaceOnNextDigit = result.replaceOnNextDigit;
    });
  }

  void _backspace() {
    final AppNumericEditResult result = AppNumericInputLogic.backspace(
      currentValue: _value,
      replaceOnNextDigit: _replaceOnNextDigit,
    );
    setState(() {
      _value = result.value;
      _replaceOnNextDigit = result.replaceOnNextDigit;
    });
  }

  void _clear() {
    final AppNumericEditResult result = AppNumericInputLogic.clear();
    setState(() {
      _value = result.value;
      _replaceOnNextDigit = result.replaceOnNextDigit;
    });
  }

  void _toggleNegative() {
    final AppNumericEditResult result = AppNumericInputLogic.toggleNegative(
      currentValue: _value,
      replaceOnNextDigit: _replaceOnNextDigit,
      options: widget.valueOptions,
    );
    setState(() {
      _value = result.value;
      _replaceOnNextDigit = result.replaceOnNextDigit;
    });
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _apply() {
    final String? normalized = AppNumericInputLogic.normalizeForApply(
      _value,
      widget.valueOptions,
    );
    if (normalized == null) {
      return;
    }
    Navigator.of(context).pop(normalized);
  }
}

class AppNumericKeypad extends StatelessWidget {
  const AppNumericKeypad({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    this.allowDecimal = true,
    this.keyPrefix = 'app-numeric-keypad',
    this.buttonHeight = 64,
    this.rowSpacing = 8,
    this.columnSpacing = 8,
    this.digitTextStyle,
    this.iconSize = 22,
    this.buttonElevation = 0,
    this.pressedElevation = 0,
    this.buttonBackgroundColor = AppColors.surfaceMuted,
    this.buttonBorderColor,
    this.buttonShadowColor,
    this.buttonOverlayColor,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final bool allowDecimal;
  final String keyPrefix;
  final double buttonHeight;
  final double rowSpacing;
  final double columnSpacing;
  final TextStyle? digitTextStyle;
  final double iconSize;
  final double buttonElevation;
  final double pressedElevation;
  final Color buttonBackgroundColor;
  final Color? buttonBorderColor;
  final Color? buttonShadowColor;
  final Color? buttonOverlayColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _AppNumericKeypadRow(
          spacing: columnSpacing,
          children: <Widget>[
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-1'),
              label: '1',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('1'),
            ),
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-2'),
              label: '2',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('2'),
            ),
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-3'),
              label: '3',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('3'),
            ),
          ],
        ),
        SizedBox(height: rowSpacing),
        _AppNumericKeypadRow(
          spacing: columnSpacing,
          children: <Widget>[
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-4'),
              label: '4',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('4'),
            ),
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-5'),
              label: '5',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('5'),
            ),
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-6'),
              label: '6',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('6'),
            ),
          ],
        ),
        SizedBox(height: rowSpacing),
        _AppNumericKeypadRow(
          spacing: columnSpacing,
          children: <Widget>[
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-7'),
              label: '7',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('7'),
            ),
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-8'),
              label: '8',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('8'),
            ),
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-9'),
              label: '9',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('9'),
            ),
          ],
        ),
        SizedBox(height: rowSpacing),
        _AppNumericKeypadRow(
          spacing: columnSpacing,
          children: <Widget>[
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-decimal'),
              label: '.',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: allowDecimal ? onDecimal : null,
            ),
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-digit-0'),
              label: '0',
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: () => onDigit('0'),
            ),
            _AppNumericKeypadButton(
              key: ValueKey<String>('$keyPrefix-backspace'),
              icon: Icons.backspace_outlined,
              buttonHeight: buttonHeight,
              digitTextStyle: digitTextStyle,
              iconSize: iconSize,
              buttonElevation: buttonElevation,
              pressedElevation: pressedElevation,
              buttonBackgroundColor: buttonBackgroundColor,
              buttonBorderColor: buttonBorderColor,
              buttonShadowColor: buttonShadowColor,
              buttonOverlayColor: buttonOverlayColor,
              onPressed: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _AppNumericKeypadRow extends StatelessWidget {
  const _AppNumericKeypadRow({required this.children, required this.spacing});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand(
            (Widget child) => <Widget>[
              Expanded(child: child),
              if (child != children.last) SizedBox(width: spacing),
            ],
          )
          .toList(growable: false),
    );
  }
}

class _AppNumericKeypadButton extends StatelessWidget {
  const _AppNumericKeypadButton({
    required this.onPressed,
    required this.buttonHeight,
    required this.iconSize,
    required this.buttonElevation,
    required this.pressedElevation,
    required this.buttonBackgroundColor,
    this.label,
    this.icon,
    this.digitTextStyle,
    this.buttonBorderColor,
    this.buttonShadowColor,
    this.buttonOverlayColor,
    super.key,
  }) : assert(label != null || icon != null);

  final VoidCallback? onPressed;
  final double buttonHeight;
  final double iconSize;
  final double buttonElevation;
  final double pressedElevation;
  final Color buttonBackgroundColor;
  final String? label;
  final IconData? icon;
  final TextStyle? digitTextStyle;
  final Color? buttonBorderColor;
  final Color? buttonShadowColor;
  final Color? buttonOverlayColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle defaultTextStyle =
        Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: onPressed == null
              ? AppColors.textMuted
              : AppColors.textPrimary,
        ) ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.w800);

    return SizedBox(
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style:
            ElevatedButton.styleFrom(
              elevation: buttonElevation,
              shadowColor: buttonShadowColor,
              backgroundColor: buttonBackgroundColor,
              disabledBackgroundColor: buttonBackgroundColor,
              foregroundColor: AppColors.textPrimary,
              disabledForegroundColor: AppColors.textMuted,
              overlayColor: buttonOverlayColor,
              side: buttonBorderColor == null
                  ? null
                  : BorderSide(color: buttonBorderColor!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
            ).copyWith(
              elevation: WidgetStateProperty.resolveWith<double?>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.disabled)) {
                  return 0;
                }
                if (states.contains(WidgetState.pressed)) {
                  return pressedElevation;
                }
                return buttonElevation;
              }),
            ),
        child: icon == null
            ? Text(
                label!,
                style:
                    digitTextStyle?.copyWith(
                      color: onPressed == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ) ??
                    defaultTextStyle,
              )
            : Icon(icon, size: iconSize),
      ),
    );
  }
}
