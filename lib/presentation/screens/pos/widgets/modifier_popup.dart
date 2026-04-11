import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/order_modifier.dart';
import '../../../../domain/models/product_modifier.dart';
import '../../../providers/cart_models.dart';
import '../../../providers/pos_interaction_provider.dart';
import 'pos_debug_metrics.dart';
import 'pos_operator_speed_helpers.dart';

class ModifierPopup extends ConsumerStatefulWidget {
  const ModifierPopup({
    required this.productId,
    required this.productName,
    super.key,
  });

  final int productId;
  final String productName;

  @override
  ConsumerState<ModifierPopup> createState() => _ModifierPopupState();
}

class _ModifierPopupState extends ConsumerState<ModifierPopup> {
  final Stopwatch _sessionStopwatch = Stopwatch();
  bool _isLoading = true;
  bool _isStructuredMode = false;
  String? _errorMessage;
  List<ProductModifier> _legacyIncluded = const <ProductModifier>[];
  List<ProductModifier> _legacyExtras = const <ProductModifier>[];
  List<ProductModifier> _freeToppings = const <ProductModifier>[];
  List<ProductModifier> _freeSauces = const <ProductModifier>[];
  List<ProductModifier> _paidAddIns = const <ProductModifier>[];
  final Map<int, bool> _legacyIncludedChecked = <int, bool>{};
  final Map<int, int> _legacyExtraCounts = <int, int>{};
  final Map<int, bool> _freeChecked = <int, bool>{};
  final Map<int, bool> _paidAddInSelected = <int, bool>{};
  int _modifierSelectionTapCount = 0;
  PosMetricRating? _lastSelectionRating;
  int? _lastSelectionElapsedMs;

  @override
  void initState() {
    super.initState();
    _sessionStopwatch.start();
    _loadModifiers();
  }

  Future<void> _loadModifiers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final List<ProductModifier> modifiers = await ref
          .read(catalogServiceProvider)
          .getProductModifiers(widget.productId);
      final bool isStructuredMode = modifiers.any(
        (ProductModifier modifier) => modifier.uiSection != null,
      );

      final List<ProductModifier> legacyIncluded = <ProductModifier>[];
      final List<ProductModifier> legacyExtras = <ProductModifier>[];
      final List<ProductModifier> freeToppings = <ProductModifier>[];
      final List<ProductModifier> freeSauces = <ProductModifier>[];
      final List<ProductModifier> paidAddIns = <ProductModifier>[];

      for (final ProductModifier modifier in modifiers) {
        if (isStructuredMode && modifier.uiSection == null) {
          continue;
        }
        if (modifier.isFreeOptionalAdd) {
          switch (modifier.uiSection!) {
            case ModifierUiSection.toppings:
              freeToppings.add(modifier);
              break;
            case ModifierUiSection.sauces:
              freeSauces.add(modifier);
              break;
            case ModifierUiSection.addIns:
              break;
          }
          continue;
        }
        if (modifier.isPaidOptionalAdd &&
            modifier.uiSection == ModifierUiSection.addIns) {
          paidAddIns.add(modifier);
          continue;
        }
        if (isStructuredMode) {
          continue;
        }
        if (modifier.isLegacyIncludedDefault) {
          legacyIncluded.add(modifier);
          continue;
        }
        if (modifier.isLegacyPaidExtra) {
          legacyExtras.add(modifier);
        }
      }

      _legacyIncludedChecked
        ..clear()
        ..addEntries(
          legacyIncluded.map(
            (ProductModifier modifier) =>
                MapEntry<int, bool>(modifier.id, true),
          ),
        );
      _legacyExtraCounts
        ..clear()
        ..addEntries(
          legacyExtras.map(
            (ProductModifier modifier) => MapEntry<int, int>(modifier.id, 0),
          ),
        );
      _freeChecked
        ..clear()
        ..addEntries(
          <ProductModifier>[...freeToppings, ...freeSauces].map(
            (ProductModifier modifier) =>
                MapEntry<int, bool>(modifier.id, false),
          ),
        );
      _paidAddInSelected
        ..clear()
        ..addEntries(
          paidAddIns.map(
            (ProductModifier modifier) =>
                MapEntry<int, bool>(modifier.id, false),
          ),
        );

      setState(() {
        _isStructuredMode = isStructuredMode;
        _legacyIncluded = legacyIncluded;
        _legacyExtras = legacyExtras;
        _freeToppings = freeToppings;
        _freeSauces = freeSauces;
        _paidAddIns = paidAddIns;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = AppStrings.modifierLoadFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PosInteractionPolicy interactionPolicy = ref.watch(
      posInteractionProvider,
    );
    final bool isBlocked = !interactionPolicy.canOpenModifierDialog;
    final bool debugFeedbackEnabled = ref
        .watch(appConfigProvider)
        .featureFlags
        .debugLoggingEnabled;
    final PosMetricRating liveRating =
        PosMetricsThresholds.rateModifierSelectionElapsed(
          _sessionStopwatch.elapsedMilliseconds,
        );
    final PosMetricRating? visibleDebugRating =
        _lastSelectionRating != null &&
            _lastSelectionRating != PosMetricRating.acceptable
        ? _lastSelectionRating
        : (liveRating != PosMetricRating.acceptable ? liveRating : null);
    final int? visibleDebugElapsedMs =
        visibleDebugRating == _lastSelectionRating
        ? _lastSelectionElapsedMs
        : _sessionStopwatch.elapsedMilliseconds;

    return Dialog(
      backgroundColor: AppColors.surfaceAlt,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 800,
          maxWidth: 960,
          maxHeight: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _DialogHeader(
                title: widget.productName,
                subtitle: AppStrings.modifierDialogTitle,
                debugFeedbackEnabled: debugFeedbackEnabled,
                visibleDebugRating: visibleDebugRating,
                visibleDebugElapsedMs: visibleDebugElapsedMs,
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildContent(isBlocked)),
              if (!_isStructuredMode &&
                  !_isLoading &&
                  _errorMessage == null) ...<Widget>[
                const SizedBox(height: 16),
                _DialogFooter(
                  isSubmitEnabled: !_isLoading && !isBlocked,
                  onCancel: () => Navigator.of(context).pop(),
                  onSubmit: _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isBlocked) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            fontSize: AppSizes.fontSm,
            color: AppColors.error,
          ),
        ),
      );
    }

    if (!_isStructuredMode &&
        _legacyIncluded.isEmpty &&
        _legacyExtras.isEmpty &&
        _freeToppings.isEmpty &&
        _freeSauces.isEmpty &&
        _paidAddIns.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          AppStrings.modifierNotFound,
          style: const TextStyle(
            fontSize: AppSizes.fontSm,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return IgnorePointer(
      ignoring: isBlocked,
      child: Opacity(
        opacity: isBlocked ? 0.5 : 1,
        child: _isStructuredMode
            ? _buildStructuredEditor(isBlocked)
            : _buildLegacyEditor(isBlocked),
      ),
    );
  }

  Widget _buildStructuredEditor(bool isBlocked) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (isBlocked)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSizes.spacingMd,
                      ),
                      child: Text(
                        ref.watch(posInteractionProvider).lockMessage ??
                            AppStrings.salesLockedAdminCloseRequired,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  _OptionSection(
                    title: 'FREE ADD-ONS',
                    child: _freeToppings.isEmpty
                        ? const _SectionPlaceholder(
                            'No free add-ons configured.',
                          )
                        : _buildStructuredButtonRow(
                            sectionKey: 'free_add_ons',
                            modifiers: _freeToppings,
                            isSelected: (ProductModifier modifier) =>
                                _freeChecked[modifier.id] ?? false,
                            onPressed: (ProductModifier modifier) {
                              _handleStructuredSelectionTap(
                                sectionKey: 'free_add_ons',
                                modifier: modifier,
                                onToggle: () {
                                  final bool isSelected =
                                      _freeChecked[modifier.id] ?? false;
                                  _freeChecked[modifier.id] = !isSelected;
                                },
                              );
                            },
                            keyPrefix: 'burger-free-add-on',
                          ),
                  ),
                  const SizedBox(height: 14),
                  _OptionSection(
                    title: 'SAUCES',
                    child: _freeSauces.isEmpty
                        ? const _SectionPlaceholder('No sauces configured.')
                        : _buildStructuredButtonRow(
                            sectionKey: 'sauces',
                            modifiers: _freeSauces,
                            isSelected: (ProductModifier modifier) =>
                                _freeChecked[modifier.id] ?? false,
                            onPressed: (ProductModifier modifier) {
                              _handleStructuredSelectionTap(
                                sectionKey: 'sauces',
                                modifier: modifier,
                                onToggle: () {
                                  final bool isSelected =
                                      _freeChecked[modifier.id] ?? false;
                                  _freeChecked[modifier.id] = !isSelected;
                                },
                              );
                            },
                            keyPrefix: 'burger-sauce',
                          ),
                  ),
                  const SizedBox(height: 14),
                  _OptionSection(
                    title: 'ADD-INS',
                    child: _paidAddIns.isEmpty
                        ? const _SectionPlaceholder(
                            'No paid add-ins configured.',
                          )
                        : _buildStructuredButtonRow(
                            sectionKey: 'add_ins',
                            modifiers: _paidAddIns,
                            isSelected: (ProductModifier modifier) =>
                                _paidAddInSelected[modifier.id] ?? false,
                            onPressed: (ProductModifier modifier) {
                              _handleStructuredSelectionTap(
                                sectionKey: 'add_ins',
                                modifier: modifier,
                                onToggle: () {
                                  final bool isSelected =
                                      _paidAddInSelected[modifier.id] ?? false;
                                  _paidAddInSelected[modifier.id] = !isSelected;
                                },
                              );
                            },
                            keyPrefix: 'burger-add-in-toggle',
                            showPrice: true,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 240,
          child: _SelectionSidebar(
            selections: _buildStructuredSummary(),
            addInTotalMinor: _paidAddIns.fold<int>(
              0,
              (int total, ProductModifier modifier) =>
                  total +
                  ((_paidAddInSelected[modifier.id] ?? false)
                      ? modifier.extraPriceMinor
                      : 0),
            ),
            isSubmitEnabled: !isBlocked,
            onCancel: () => Navigator.of(context).pop(),
            onSubmit: _submit,
          ),
        ),
      ],
    );
  }

  Widget _buildLegacyEditor(bool isBlocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isBlocked)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
            child: Text(
              ref.watch(posInteractionProvider).lockMessage ??
                  AppStrings.salesLockedAdminCloseRequired,
              style: const TextStyle(
                fontSize: AppSizes.fontSm,
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_legacyIncluded.isNotEmpty || _legacyExtras.isNotEmpty)
                  _buildLegacySections(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegacySections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_legacyIncluded.isNotEmpty) ...<Widget>[
          Text(
            AppStrings.includedModifiers,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          ..._legacyIncluded.map(
            (ProductModifier modifier) => CheckboxListTile(
              value: _legacyIncludedChecked[modifier.id] ?? true,
              title: Text(
                modifier.name,
                style: const TextStyle(fontSize: AppSizes.fontSm),
              ),
              onChanged: (bool? checked) {
                setState(() {
                  _legacyIncludedChecked[modifier.id] = checked ?? true;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        if (_legacyIncluded.isNotEmpty && _legacyExtras.isNotEmpty)
          const SizedBox(height: AppSizes.spacingMd),
        if (_legacyExtras.isNotEmpty) ...<Widget>[
          Text(
            AppStrings.extraModifiers,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          ..._legacyExtras.map((ProductModifier modifier) {
            final int count = _legacyExtraCounts[modifier.id] ?? 0;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                modifier.name,
                style: const TextStyle(fontSize: AppSizes.fontSm),
              ),
              subtitle: Text(
                CurrencyFormatter.fromMinor(modifier.extraPriceMinor),
                style: const TextStyle(fontSize: AppSizes.fontSm),
              ),
              trailing: _LegacyStepper(
                count: count,
                onDecrement: count <= 0
                    ? null
                    : () {
                        setState(() {
                          _legacyExtraCounts[modifier.id] = count - 1;
                        });
                      },
                onIncrement: () {
                  setState(() {
                    _legacyExtraCounts[modifier.id] = count + 1;
                  });
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildStructuredButtonRow({
    required String sectionKey,
    required List<ProductModifier> modifiers,
    required bool Function(ProductModifier modifier) isSelected,
    required void Function(ProductModifier modifier) onPressed,
    required String keyPrefix,
    bool showPrice = false,
  }) {
    final PinnedModifierPresentation presentation =
        buildPinnedModifierPresentation(
          modifiers: modifiers,
          usageCounts: _ModifierSessionUsageTracker.selectionCountsForProduct(
            widget.productId,
          ),
        );

    Widget buildGroup(List<ProductModifier> groupModifiers) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double spacing = 6;
          final double maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 640;
          final int columnCount = maxWidth >= 560
              ? 4
              : maxWidth >= 420
              ? 3
              : 2;
          final double rawTileWidth =
              (maxWidth - (spacing * (columnCount - 1))) / columnCount;
          final double tileWidth = rawTileWidth.clamp(124.0, 156.0);

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: groupModifiers
                .map(
                  (ProductModifier modifier) => SizedBox(
                    width: tileWidth,
                    child: _StructuredModifierButton(
                      key: ValueKey<String>('$keyPrefix-${modifier.id}'),
                      label: modifier.name,
                      priceLabel: showPrice
                          ? '+${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}'
                          : null,
                      isSelected: isSelected(modifier),
                      onPressed: () => onPressed(modifier),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (presentation.hasPinnedSection) ...<Widget>[
          const _StructuredSectionLabel('FREQUENTLY USED'),
          const SizedBox(height: 6),
          buildGroup(presentation.pinned),
          const SizedBox(height: 8),
        ],
        if (presentation.base.isNotEmpty) buildGroup(presentation.base),
      ],
    );
  }

  List<_SummaryLine> _buildStructuredSummary() {
    final List<_SummaryLine> lines = <_SummaryLine>[];
    for (final ProductModifier modifier in <ProductModifier>[
      ..._freeToppings,
      ..._freeSauces,
    ]) {
      if (_freeChecked[modifier.id] ?? false) {
        lines.add(_SummaryLine(label: modifier.name, priceMinor: 0));
      }
    }
    for (final ProductModifier modifier in _paidAddIns) {
      if (!(_paidAddInSelected[modifier.id] ?? false)) {
        continue;
      }
      lines.add(
        _SummaryLine(
          label:
              '${modifier.name} ${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}',
          priceMinor: modifier.extraPriceMinor,
        ),
      );
    }
    return lines;
  }

  void _handleStructuredSelectionTap({
    required String sectionKey,
    required ProductModifier modifier,
    required VoidCallback onToggle,
  }) {
    _modifierSelectionTapCount += 1;
    final Stopwatch acknowledgeStopwatch = Stopwatch()..start();
    setState(onToggle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final int elapsedMs = _sessionStopwatch.elapsedMilliseconds;
      final PosMetricRating selectionRating =
          PosMetricsThresholds.rateModifierSelectionElapsed(elapsedMs);
      setState(() {
        _lastSelectionElapsedMs = elapsedMs;
        _lastSelectionRating = selectionRating;
      });
      final bool isSelected =
          (_freeChecked[modifier.id] ?? false) ||
          (_paidAddInSelected[modifier.id] ?? false);
      logPosDebugMetric(
        context,
        eventType: 'pos_modifier_option_ack_debug',
        entityId: '${modifier.id}',
        metadata: <String, Object?>{
          'product_id': widget.productId,
          'modifier_id': modifier.id,
          'modifier_name': modifier.name,
          'section': sectionKey,
          'selection_tap_count': _modifierSelectionTapCount,
          'selected': isSelected,
          'ack_ms': acknowledgeStopwatch.elapsedMilliseconds,
        },
      );
      acknowledgeStopwatch.stop();
    });
  }

  void _submit() {
    final List<CartModifier> selected = <CartModifier>[];

    for (final ProductModifier modifier in _legacyIncluded) {
      final bool isChecked = _legacyIncludedChecked[modifier.id] ?? true;
      if (!isChecked) {
        selected.add(
          CartModifier(
            action: ModifierAction.remove,
            itemName: modifier.name,
            extraPriceMinor: 0,
          ),
        );
      }
    }

    for (final ProductModifier modifier in _legacyExtras) {
      final int count = _legacyExtraCounts[modifier.id] ?? 0;
      for (int index = 0; index < count; index += 1) {
        selected.add(
          CartModifier(
            action: ModifierAction.add,
            itemName: modifier.name,
            extraPriceMinor: modifier.extraPriceMinor,
          ),
        );
      }
    }

    for (final ProductModifier modifier in <ProductModifier>[
      ..._freeToppings,
      ..._freeSauces,
    ]) {
      if (!(_freeChecked[modifier.id] ?? false)) {
        continue;
      }
      selected.add(
        CartModifier(
          action: ModifierAction.add,
          itemName: modifier.name,
          extraPriceMinor: 0,
          priceBehavior: modifier.priceBehavior,
          uiSection: modifier.uiSection,
        ),
      );
    }

    for (final ProductModifier modifier in _paidAddIns) {
      if (_paidAddInSelected[modifier.id] ?? false) {
        selected.add(
          CartModifier(
            action: ModifierAction.add,
            itemName: modifier.name,
            extraPriceMinor: modifier.extraPriceMinor,
            priceBehavior: modifier.priceBehavior,
            uiSection: modifier.uiSection,
          ),
        );
      }
    }

    final List<int> selectedStructuredModifierIds = <int>[
      ..._freeToppings
          .where(
            (ProductModifier modifier) => _freeChecked[modifier.id] ?? false,
          )
          .map((ProductModifier modifier) => modifier.id),
      ..._freeSauces
          .where(
            (ProductModifier modifier) => _freeChecked[modifier.id] ?? false,
          )
          .map((ProductModifier modifier) => modifier.id),
      ..._paidAddIns
          .where(
            (ProductModifier modifier) =>
                _paidAddInSelected[modifier.id] ?? false,
          )
          .map((ProductModifier modifier) => modifier.id),
    ];
    final List<String> selectedStructuredModifierNames = <String>[
      ..._freeToppings
          .where(
            (ProductModifier modifier) => _freeChecked[modifier.id] ?? false,
          )
          .map((ProductModifier modifier) => modifier.name),
      ..._freeSauces
          .where(
            (ProductModifier modifier) => _freeChecked[modifier.id] ?? false,
          )
          .map((ProductModifier modifier) => modifier.name),
      ..._paidAddIns
          .where(
            (ProductModifier modifier) =>
                _paidAddInSelected[modifier.id] ?? false,
          )
          .map((ProductModifier modifier) => modifier.name),
    ];
    _ModifierSessionUsageTracker.recordSelections(
      productId: widget.productId,
      modifierIds: selectedStructuredModifierIds,
    );
    final int selectionElapsedMs = _sessionStopwatch.elapsedMilliseconds;
    final PosMetricRating selectionRating =
        PosMetricsThresholds.rateModifierSelectionElapsed(selectionElapsedMs);
    PosDebugSessionMetrics.recordModifierSelectionElapsed(selectionElapsedMs);
    PosDebugSessionMetrics.recordModifierUsage(selectedStructuredModifierNames);
    logPosDebugMetric(
      context,
      eventType: 'pos_modifier_selection_summary_debug',
      entityId: '${widget.productId}',
      metadata: <String, Object?>{
        'product_id': widget.productId,
        'product_name': widget.productName,
        'selection_tap_count': _modifierSelectionTapCount,
        'selected_modifier_count': selected.length,
        'structured_mode': _isStructuredMode,
        'elapsed_ms': selectionElapsedMs,
        'target_ms': PosMetricsThresholds.modifierSelectionTargetMs,
        'borderline_ms': PosMetricsThresholds.modifierSelectionBorderlineMs,
        'rating': selectionRating.name,
        'interpretation': PosMetricsThresholds.interpret(selectionRating),
      },
    );
    logPosDebugSummary(context);

    Navigator.of(context).pop(selected);
  }
}

class _OptionSection extends StatelessWidget {
  const _OptionSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SelectionSidebar extends StatelessWidget {
  const _SelectionSidebar({
    required this.selections,
    required this.addInTotalMinor,
    required this.isSubmitEnabled,
    required this.onCancel,
    required this.onSubmit,
  });

  final List<_SummaryLine> selections;
  final int addInTotalMinor;
  final bool isSubmitEnabled;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Selection',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Selected items',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(minHeight: 72),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: selections.isEmpty
                          ? const SizedBox.shrink()
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: selections
                                  .map(
                                    (_SummaryLine line) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: line.priceMinor > 0
                                            ? AppColors.primaryLight
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: line.priceMinor > 0
                                              ? AppColors.primary
                                              : AppColors.borderStrong,
                                        ),
                                      ),
                                      child: Text(
                                        line.label,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: line.priceMinor > 0
                                              ? AppColors.primaryDarker
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Price impact',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            addInTotalMinor > 0
                                ? '+${CurrencyFormatter.fromMinor(addInTotalMinor)}'
                                : CurrencyFormatter.fromMinor(0),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDarker,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isSubmitEnabled ? onSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  foregroundColor: AppColors.textOnPrimary,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textMuted,
                ),
                child: Text(
                  AppStrings.addToCart,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onCancel,
              child: Text(
                AppStrings.cancel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.subtitle,
    required this.debugFeedbackEnabled,
    required this.visibleDebugRating,
    required this.visibleDebugElapsedMs,
  });

  final String title;
  final String subtitle;
  final bool debugFeedbackEnabled;
  final PosMetricRating? visibleDebugRating;
  final int? visibleDebugElapsedMs;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (debugFeedbackEnabled &&
                  visibleDebugRating != null &&
                  visibleDebugElapsedMs != null) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PosDebugThresholdBanner(
                    label: 'Modifier flow',
                    elapsedMs: visibleDebugElapsedMs!,
                    rating: visibleDebugRating!,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          tooltip: AppStrings.cancel,
        ),
      ],
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.isSubmitEnabled,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isSubmitEnabled;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderStrong),
                backgroundColor: AppColors.surface,
              ),
              child: Text(
                AppStrings.cancel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isSubmitEnabled ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                foregroundColor: AppColors.textOnPrimary,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.textMuted,
              ),
              child: Text(
                AppStrings.addToCart,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _StructuredSectionLabel extends StatelessWidget {
  const _StructuredSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
        height: 1,
      ),
    );
  }
}

class _StructuredModifierButton extends StatelessWidget {
  const _StructuredModifierButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
    super.key,
    this.priceLabel,
  });

  final String label;
  final String? priceLabel;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints.tightFor(
            height: priceLabel == null ? 64 : 72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryStrong : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryStrong
                  : AppColors.borderStrong,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primaryDarker.withValues(alpha: 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.textOnPrimary
                            : AppColors.textPrimary,
                        height: 1.05,
                      ),
                    ),
                  ),
                  if (isSelected) ...<Widget>[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.textOnPrimary,
                    ),
                  ],
                ],
              ),
              if (priceLabel != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  priceLabel!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.textOnPrimary
                        : AppColors.primaryDarker,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegacyStepper extends StatelessWidget {
  const _LegacyStepper({
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int count;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          onPressed: onIncrement,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _SummaryLine {
  const _SummaryLine({required this.label, required this.priceMinor});

  final String label;
  final int priceMinor;
}

class _ModifierSessionUsageTracker {
  static final Map<int, Map<int, int>> _selectionCountsByProductId =
      <int, Map<int, int>>{};

  static Map<int, int> selectionCountsForProduct(int productId) {
    final Map<int, int>? counts = _selectionCountsByProductId[productId];
    if (counts == null) {
      return const <int, int>{};
    }
    return Map<int, int>.unmodifiable(counts);
  }

  static void recordSelections({
    required int productId,
    required Iterable<int> modifierIds,
  }) {
    final Map<int, int> counts = _selectionCountsByProductId.putIfAbsent(
      productId,
      () => <int, int>{},
    );
    for (final int modifierId in modifierIds) {
      counts[modifierId] = (counts[modifierId] ?? 0) + 1;
    }
  }
}
