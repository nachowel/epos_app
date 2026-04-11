import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/product.dart';
import 'pos_debug_metrics.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({required this.product, required this.onTap, super.key});

  final Product product;
  final VoidCallback? onTap;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isPressed = false;
  bool _isHovered = false;
  Stopwatch? _tapAcknowledgeStopwatch;
  Timer? _debugFeedbackTimer;
  PosMetricRating? _lastAckRating;
  int? _lastAckMs;

  @override
  void dispose() {
    _debugFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = widget.onTap != null;
    final bool isCustomizable =
        widget.product.hasModifiers ||
        widget.product.mealAdjustmentProfileId != null;
    final BorderRadius borderRadius = BorderRadius.circular(14);

    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: isInteractive ? (_) => _setHovered(true) : null,
      onExit: isInteractive ? (_) => _setHovered(false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 80),
        scale: _isPressed ? 0.982 : (_isHovered && isInteractive ? 1.008 : 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _isHovered && isInteractive
                ? AppColors.primaryLighter
                : AppColors.surface,
            borderRadius: borderRadius,
            border: Border.all(
              width: _isPressed || (_isHovered && isInteractive) ? 1.5 : 1,
              color: _isPressed
                  ? AppColors.primaryStrong
                  : (_isHovered && isInteractive
                        ? AppColors.primary
                        : AppColors.border),
            ),
            boxShadow: _resolveShadow(isInteractive: isInteractive),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: isInteractive
                  ? (_) {
                      _tapAcknowledgeStopwatch = Stopwatch()..start();
                    }
                  : null,
              onHighlightChanged: (bool value) {
                if (_isPressed == value) {
                  return;
                }
                setState(() {
                  _isPressed = value;
                });
                if (!value) {
                  return;
                }
                final Stopwatch? stopwatch = _tapAcknowledgeStopwatch;
                if (stopwatch == null || !stopwatch.isRunning) {
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  final PosMetricRating rating =
                      PosMetricsThresholds.rateProductTapAck(
                        stopwatch.elapsedMilliseconds,
                      );
                  logPosDebugMetric(
                    context,
                    eventType: 'pos_product_tap_ack_debug',
                    entityId: '${widget.product.id}',
                    metadata: <String, Object?>{
                      'ack_ms': stopwatch.elapsedMilliseconds,
                      'target_ms': PosMetricsThresholds.productTapAckTargetMs,
                      'borderline_ms':
                          PosMetricsThresholds.productTapAckBorderlineMs,
                      'rating': rating.name,
                      'interpretation': PosMetricsThresholds.interpret(rating),
                      'product_id': widget.product.id,
                      'product_name': widget.product.name,
                      'is_customizable':
                          widget.product.hasModifiers ||
                          widget.product.mealAdjustmentProfileId != null,
                    },
                  );
                  final bool debugFeedbackEnabled = ProviderScope.containerOf(
                    context,
                    listen: false,
                  ).read(appConfigProvider).featureFlags.debugLoggingEnabled;
                  if (debugFeedbackEnabled &&
                      rating != PosMetricRating.acceptable) {
                    _debugFeedbackTimer?.cancel();
                    setState(() {
                      _lastAckRating = rating;
                      _lastAckMs = stopwatch.elapsedMilliseconds;
                    });
                    _debugFeedbackTimer = Timer(const Duration(seconds: 3), () {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _lastAckRating = null;
                        _lastAckMs = null;
                      });
                    });
                  }
                  PosDebugSessionMetrics.recordProductTapAck(
                    stopwatch.elapsedMilliseconds,
                  );
                  logPosDebugSummary(context);
                  stopwatch.stop();
                  _tapAcknowledgeStopwatch = null;
                });
              },
              splashColor: AppColors.primaryLight,
              highlightColor: AppColors.primaryLighter,
              borderRadius: borderRadius,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: AspectRatio(
                        aspectRatio: 1.54,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            _ProductImage(imageUrl: widget.product.imageUrl),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Colors.black.withValues(alpha: 0.03),
                                      AppColors.primaryDarker.withValues(
                                        alpha: 0.09,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isCustomizable)
                              Positioned(
                                top: 7,
                                left: 7,
                                child: const _ProductBadge(),
                              ),
                            if (_lastAckRating != null && _lastAckMs != null)
                              Positioned(
                                right: 7,
                                bottom: 7,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 110,
                                  ),
                                  child: PosDebugThresholdBanner(
                                    label: 'Tap',
                                    elapsedMs: _lastAckMs!,
                                    rating: _lastAckRating!,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.fromMinor(
                              widget.product.priceMinor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
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
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _resolveShadow({required bool isInteractive}) {
    if (_isPressed && isInteractive) {
      return <BoxShadow>[
        BoxShadow(
          color: AppColors.primaryDarker.withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
    }

    if (_isHovered && isInteractive) {
      return <BoxShadow>[
        BoxShadow(
          color: AppColors.primaryDarker.withValues(alpha: 0.14),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
    }

    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  void _setHovered(bool value) {
    if (!mounted || _isHovered == value) {
      return;
    }
    setState(() {
      _isHovered = value;
    });
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppStrings.hasModifiersLabel,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.primaryStrong,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryDarker),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryDarker.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.tune_rounded,
          size: 11,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const _ProductImagePlaceholder(
        icon: Icons.fastfood_rounded,
        iconColor: AppColors.primary,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _ProductImagePlaceholder(
          icon: Icons.fastfood_rounded,
          iconColor: AppColors.primary,
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.surface.withValues(alpha: 0.04),
                  Colors.transparent,
                  AppColors.primaryDarker.withValues(alpha: 0.04),
                ],
                stops: const <double>[0, 0.58, 1],
              ),
            ),
          ),
        ),
        Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          loadingBuilder:
              (
                BuildContext context,
                Widget child,
                ImageChunkEvent? loadingProgress,
              ) {
                if (loadingProgress == null) {
                  return child;
                }
                return const _ProductImagePlaceholder(
                  icon: Icons.fastfood_rounded,
                  iconColor: AppColors.primary,
                );
              },
          errorBuilder: (_, __, ___) {
            return const _ProductImagePlaceholder(
              icon: Icons.broken_image_rounded,
              iconColor: AppColors.textSecondary,
            );
          },
        ),
      ],
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder({required this.icon, required this.iconColor});

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primaryLighter, AppColors.primaryLight],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -20,
            right: -12,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.42),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -14,
            left: -6,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.surface.withValues(alpha: 0.02),
                    AppColors.primaryDarker.withValues(alpha: 0.06),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderStrong),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primaryDarker.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 26, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}
