import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/product.dart';
import '../pos_product_presentation_policy.dart';
import 'pos_debug_metrics.dart';
import 'pos_product_image_cache.dart';

typedef ProductCardImageProviderResolver =
    ImageProvider<Object> Function(String imageUrl);

ImageProvider<Object> _defaultProductCardImageProviderResolver(
  String imageUrl,
) {
  return resolveCachedPosProductImageProvider(imageUrl);
}

class ProductCard extends StatefulWidget {
  const ProductCard({
    required this.product,
    required this.onTap,
    this.presentationMode = ProductCardPresentationMode.visual,
    this.imageProviderResolver = _defaultProductCardImageProviderResolver,
    super.key,
  });

  final Product product;
  final VoidCallback? onTap;
  final ProductCardPresentationMode presentationMode;
  final ProductCardImageProviderResolver imageProviderResolver;

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
    final String productName = widget.product.name.trim();
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
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _ImageAwareProductFace(
                        productName: productName,
                        priceMinor: widget.product.priceMinor,
                        imageUrl: widget.product.imageUrl,
                        imageProviderResolver: widget.imageProviderResolver,
                        presentationMode: widget.presentationMode,
                      ),
                      if (isCustomizable)
                        Positioned(
                          top: 9,
                          left: 9,
                          child: const _ProductBadge(),
                        ),
                      if (_lastAckRating != null && _lastAckMs != null)
                        Positioned(
                          top: 9,
                          right: 9,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
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

class _CompactTextOnlyFace extends StatelessWidget {
  const _CompactTextOnlyFace({
    required this.productName,
    required this.priceMinor,
  });

  final String productName;
  final int priceMinor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _CompactProductBackdrop(
          backdropKey: ValueKey<String>('product-card-text-backdrop'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    productName,
                    key: const ValueKey<String>('product-card-name'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.08,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 22,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      right: 52,
                      top: 10,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              AppColors.primary.withValues(alpha: 0.18),
                              AppColors.primary.withValues(alpha: 0.03),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _PriceTag(
                        priceMinor: priceMinor,
                        isOnImage: false,
                        compact: true,
                        containerKey: const ValueKey<String>(
                          'product-card-price',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactProductBackdrop extends StatelessWidget {
  const _CompactProductBackdrop({this.backdropKey});

  final Key? backdropKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: backdropKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.surface,
            AppColors.surfaceAlt,
            AppColors.primaryLighter.withValues(alpha: 0.45),
          ],
          stops: const <double>[0, 0.6, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.white.withValues(alpha: 0.06),
              AppColors.primaryDarker.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageAwareProductFace extends StatefulWidget {
  const _ImageAwareProductFace({
    required this.productName,
    required this.priceMinor,
    required this.imageUrl,
    required this.imageProviderResolver,
    required this.presentationMode,
  });

  final String productName;
  final int priceMinor;
  final String? imageUrl;
  final ProductCardImageProviderResolver imageProviderResolver;
  final ProductCardPresentationMode presentationMode;

  @override
  State<_ImageAwareProductFace> createState() => _ImageAwareProductFaceState();
}

enum _ImageAwareProductFaceStatus { fallback, loading, loaded, error }

class _ImageAwareProductFaceState extends State<_ImageAwareProductFace> {
  _ImageAwareProductFaceStatus _status = _ImageAwareProductFaceStatus.fallback;
  ImageProvider<Object>? _imageProvider;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageState(shouldNotify: false);
  }

  @override
  void didUpdateWidget(covariant _ImageAwareProductFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageProviderResolver != widget.imageProviderResolver) {
      _resolveImageState(shouldNotify: true);
    }
  }

  @override
  void dispose() {
    _clearImageStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _ImageAwareProductFaceStatus.loaded => _ImagePresentFace(
        productName: widget.productName,
        priceMinor: widget.priceMinor,
        imageProvider: _imageProvider!,
        presentationMode: widget.presentationMode,
      ),
      _ImageAwareProductFaceStatus.loading => _ImagePresentFace(
        productName: widget.productName,
        priceMinor: widget.priceMinor,
        imageProvider: _imageProvider,
        presentationMode: widget.presentationMode,
        isLoading: true,
      ),
      _ImageAwareProductFaceStatus.fallback ||
      _ImageAwareProductFaceStatus.error => _buildFallbackFace(),
    };
  }

  void _resolveImageState({required bool shouldNotify}) {
    final String? normalizedImageUrl = normalizePosProductImageUrl(
      widget.imageUrl,
    );
    if (normalizedImageUrl == null) {
      _clearImageStream();
      _imageProvider = null;
      _setStatus(
        _ImageAwareProductFaceStatus.fallback,
        shouldNotify: shouldNotify,
      );
      return;
    }

    _clearImageStream();
    _imageProvider = widget.imageProviderResolver(normalizedImageUrl);
    _status = _ImageAwareProductFaceStatus.loading;
    _imageStream = _imageProvider!.resolve(
      createLocalImageConfiguration(context),
    );
    _imageStreamListener = ImageStreamListener(
      (ImageInfo _, bool __) {
        _clearImageStream();
        _setStatus(_ImageAwareProductFaceStatus.loaded, shouldNotify: true);
      },
      onError: (Object _, StackTrace? __) {
        _clearImageStream();
        _setStatus(_ImageAwareProductFaceStatus.error, shouldNotify: true);
      },
    );
    _imageStream!.addListener(_imageStreamListener!);

    if (shouldNotify && mounted) {
      setState(() {});
    }
  }

  void _setStatus(
    _ImageAwareProductFaceStatus nextStatus, {
    required bool shouldNotify,
  }) {
    if (_status == nextStatus) {
      return;
    }
    _status = nextStatus;
    if (shouldNotify && mounted) {
      setState(() {});
    }
  }

  void _clearImageStream() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  Widget _buildFallbackFace() {
    return switch (widget.presentationMode) {
      ProductCardPresentationMode.visual => _VisualFallbackFace(
        productName: widget.productName,
        priceMinor: widget.priceMinor,
        isLoading: false,
      ),
      ProductCardPresentationMode.compact => _CompactTextOnlyFace(
        productName: widget.productName,
        priceMinor: widget.priceMinor,
      ),
    };
  }
}

class _ImagePresentFace extends StatelessWidget {
  const _ImagePresentFace({
    required this.productName,
    required this.priceMinor,
    required this.imageProvider,
    required this.presentationMode,
    this.isLoading = false,
  });

  final String productName;
  final int priceMinor;
  final ImageProvider<Object>? imageProvider;
  final ProductCardPresentationMode presentationMode;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool isCompact =
        presentationMode == ProductCardPresentationMode.compact;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.surface, AppColors.surfaceAlt],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: isCompact ? 10 : 12,
            child: _ImagePanel(
              imageProvider: imageProvider,
              isLoading: isLoading,
            ),
          ),
          Container(height: 1, color: AppColors.border.withValues(alpha: 0.8)),
          Expanded(
            flex: isCompact ? 9 : 8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        productName,
                        key: const ValueKey<String>('product-card-name'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 15 : 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.08,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _PriceTag(
                      priceMinor: priceMinor,
                      isOnImage: false,
                      compact: true,
                      containerKey: const ValueKey<String>(
                        'product-card-price',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({required this.imageProvider, required this.isLoading});

  final ImageProvider<Object>? imageProvider;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('product-card-image-panel'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primaryLighter.withValues(alpha: 0.78),
            AppColors.surfaceAlt,
            AppColors.primaryLight.withValues(alpha: 0.64),
          ],
          stops: const <double>[0, 0.55, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (!isLoading && imageProvider != null)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                opacity: 1,
                child: Image(
                  key: const ValueKey<String>('product-card-image'),
                  image: imageProvider!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          if (isLoading || imageProvider == null)
            const Positioned.fill(child: _ImageLoadingPlaceholder()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(
                      alpha: imageProvider == null ? 0.1 : 0,
                    ),
                    Colors.black.withValues(
                      alpha: imageProvider == null ? 0.04 : 0.08,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useCompactPlaceholder = constraints.maxHeight < 84;
        final double iconBoxSize = useCompactPlaceholder ? 28 : 42;
        final double iconSize = useCompactPlaceholder ? 16 : 20;
        final double chipWidth = useCompactPlaceholder ? 18 : 26;
        final double chipHeight = useCompactPlaceholder ? 4 : 6;
        final double primaryBarWidth = useCompactPlaceholder ? 34 : 58;
        final double secondaryBarWidth = useCompactPlaceholder ? 20 : 34;
        final double barHeight = useCompactPlaceholder ? 4 : 6;

        return DecoratedBox(
          key: const ValueKey<String>('product-card-loading'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.06),
                AppColors.primaryLight.withValues(alpha: 0.12),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: useCompactPlaceholder ? 8 : 12,
                right: useCompactPlaceholder ? 8 : 12,
                child: Container(
                  width: chipWidth,
                  height: chipHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(
                      useCompactPlaceholder ? 10 : 14,
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    size: iconSize,
                    color: AppColors.primaryDarker.withValues(alpha: 0.52),
                  ),
                ),
              ),
              Positioned(
                left: useCompactPlaceholder ? 8 : 14,
                bottom: useCompactPlaceholder ? 10 : 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: primaryBarWidth,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    SizedBox(height: useCompactPlaceholder ? 4 : 6),
                    Container(
                      width: secondaryBarWidth,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VisualFallbackFace extends StatelessWidget {
  const _VisualFallbackFace({
    required this.productName,
    required this.priceMinor,
    required this.isLoading,
  });

  final String productName;
  final int priceMinor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _ProductBackdrop(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 52),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  productName,
                  key: const ValueKey<String>('product-card-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                if (isLoading) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      key: const ValueKey<String>('product-card-loading'),
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryStrong,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: _PriceTag(
            priceMinor: priceMinor,
            isOnImage: false,
            containerKey: const ValueKey<String>('product-card-price'),
          ),
        ),
      ],
    );
  }
}

class _ProductBackdrop extends StatelessWidget {
  const _ProductBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primaryLighter,
            AppColors.surfaceAlt,
            AppColors.primaryLight,
          ],
          stops: const <double>[0, 0.56, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -18,
            right: -8,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -10,
            child: Container(
              width: 64,
              height: 64,
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
                    AppColors.primaryDarker.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({
    required this.priceMinor,
    required this.isOnImage,
    this.compact = false,
    this.containerKey,
  });

  final int priceMinor;
  final bool isOnImage;
  final bool compact;
  final Key? containerKey;

  @override
  Widget build(BuildContext context) {
    final bool useCompactStyle = compact && !isOnImage;

    return Container(
      key: containerKey,
      constraints: BoxConstraints(minWidth: useCompactStyle ? 0 : 60),
      padding: EdgeInsets.symmetric(
        horizontal: useCompactStyle ? 8 : 10,
        vertical: useCompactStyle ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isOnImage
            ? Colors.black.withValues(alpha: 0.32)
            : AppColors.surface.withValues(
                alpha: useCompactStyle ? 0.72 : 0.94,
              ),
        borderRadius: BorderRadius.circular(useCompactStyle ? 12 : 999),
        border: isOnImage
            ? null
            : Border.all(
                color:
                    (useCompactStyle
                            ? AppColors.border
                            : AppColors.borderStrong)
                        .withValues(alpha: useCompactStyle ? 0.84 : 0.9),
              ),
      ),
      alignment: Alignment.center,
      child: Text(
        CurrencyFormatter.fromMinor(priceMinor),
        key: useCompactStyle
            ? const ValueKey<String>('product-card-price-text')
            : null,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: useCompactStyle ? 12 : 15,
          fontWeight: useCompactStyle ? FontWeight.w700 : FontWeight.w800,
          color: isOnImage
              ? Colors.white
              : (useCompactStyle
                    ? AppColors.textSecondary
                    : AppColors.primaryDarker),
          height: 1,
        ),
      ),
    );
  }
}
