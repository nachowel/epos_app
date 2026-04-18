import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/product.dart';
import '../pos_product_presentation_policy.dart';
import 'product_card.dart';
import 'pos_product_image_cache.dart';

typedef ProductGridImagePrecache =
    Future<void> Function(
      BuildContext context,
      ImageProvider<Object> imageProvider,
    );

class ProductGrid extends StatefulWidget {
  const ProductGrid({
    required this.title,
    required this.productCount,
    required this.products,
    required this.isLoading,
    required this.onTapProduct,
    required this.viewportWidth,
    required this.presentationMode,
    required this.isSortMode,
    required this.isSavingSortOrder,
    required this.hasSortChanges,
    required this.sortDraft,
    required this.onEnterSortMode,
    required this.onCancelSortMode,
    required this.onSaveSortOrder,
    required this.onMoveProductUp,
    required this.onMoveProductDown,
    required this.onMoveProductToTop,
    required this.onMoveProductToBottom,
    this.searchController,
    this.onSearchChanged,
    this.isSearchActive = false,
    this.imageProviderResolver = resolveCachedPosProductImageProvider,
    this.imagePrecache = _defaultProductGridImagePrecache,
    this.enableVisibleImagePreload = true,
    super.key,
  });

  static const double _mainAxisSpacing = 10;
  static const double _crossAxisSpacing = 10;

  final String title;
  final int productCount;
  final List<Product> products;
  final bool isLoading;
  final ValueChanged<Product>? onTapProduct;
  final double viewportWidth;
  final ProductCardPresentationMode presentationMode;
  final bool isSortMode;
  final bool isSavingSortOrder;
  final bool hasSortChanges;
  final List<Product> sortDraft;
  final VoidCallback? onEnterSortMode;
  final VoidCallback onCancelSortMode;
  final Future<void> Function() onSaveSortOrder;
  final void Function(int index) onMoveProductUp;
  final void Function(int index) onMoveProductDown;
  final void Function(int index) onMoveProductToTop;
  final void Function(int index) onMoveProductToBottom;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final bool isSearchActive;
  final ProductCardImageProviderResolver imageProviderResolver;
  final ProductGridImagePrecache imagePrecache;
  final bool enableVisibleImagePreload;

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

Future<void> _defaultProductGridImagePrecache(
  BuildContext context,
  ImageProvider<Object> imageProvider,
) {
  return precacheImage(imageProvider, context);
}

class _ProductGridState extends State<ProductGrid> {
  static const int _preloadRowCount = 2;
  String? _lastVisiblePreloadSignature;

  @override
  Widget build(BuildContext context) {
    final String displayTitle = widget.isSearchActive
        ? 'Arama Sonuçları'
        : widget.title;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.82)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.038),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppStrings.products,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.end,
                          children: <Widget>[
                            _ProductCountBadge(productCount: widget.productCount),
                            if (widget.isSortMode) ...<Widget>[
                              OutlinedButton(
                                key: const ValueKey<String>(
                                  'pos-product-sort-cancel',
                                ),
                                onPressed: widget.isSavingSortOrder
                                    ? null
                                    : widget.onCancelSortMode,
                                child: Text(AppStrings.cancel),
                              ),
                              ElevatedButton.icon(
                                key: const ValueKey<String>(
                                  'pos-product-sort-save',
                                ),
                                onPressed:
                                    widget.isSavingSortOrder ||
                                        !widget.hasSortChanges
                                    ? null
                                    : widget.onSaveSortOrder,
                                icon: widget.isSavingSortOrder
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(AppStrings.saveSettings),
                              ),
                            ] else
                              OutlinedButton.icon(
                                key: const ValueKey<String>(
                                  'pos-product-enter-sort-mode',
                                ),
                                onPressed: widget.onEnterSortMode,
                                icon: const Icon(Icons.swap_vert_rounded),
                                label: const Text('Ürünleri Sırala'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.searchController != null && !widget.isSortMode) ...<Widget>[
                  const SizedBox(height: 10),
                  _PosSearchBar(
                    controller: widget.searchController!,
                    onChanged: widget.onSearchChanged ?? (_) {},
                    isActive: widget.isSearchActive,
                  ),
                ],
              ],
            ),
          ),
          if (widget.isSortMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _SortModeBanner(hasChanges: widget.hasSortChanges),
            ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.84)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final List<Product> visibleProducts = widget.isSortMode
        ? widget.sortDraft
        : widget.products;
    if (widget.isLoading && visibleProducts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visibleProducts.isEmpty) {
      final String emptyMessage = widget.isSearchActive
          ? 'Sonuç bulunamadı'
          : AppStrings.noProductsInCategory;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                widget.isSearchActive
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                size: 40,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isSortMode) {
      return _ProductSortList(
        products: widget.sortDraft,
        isBusy: widget.isSavingSortOrder,
        onMoveUp: widget.onMoveProductUp,
        onMoveDown: widget.onMoveProductDown,
        onMoveToTop: widget.onMoveProductToTop,
        onMoveToBottom: widget.onMoveProductToBottom,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int crossAxisCount = _resolveCrossAxisCount(
          productAreaWidth: constraints.maxWidth,
          viewportWidth: widget.viewportWidth,
        );
        _scheduleVisibleImagePreload(
          context: context,
          products: visibleProducts,
          crossAxisCount: crossAxisCount,
        );

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: visibleProducts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: ProductGrid._mainAxisSpacing,
            crossAxisSpacing: ProductGrid._crossAxisSpacing,
            childAspectRatio: _resolveChildAspectRatio(),
          ),
          itemBuilder: (BuildContext context, int index) {
            final Product product = visibleProducts[index];
            return ProductCard(
              key: ValueKey<int>(product.id),
              product: product,
              presentationMode: widget.presentationMode,
              imageProviderResolver: widget.imageProviderResolver,
              onTap: widget.onTapProduct == null
                  ? null
                  : () => widget.onTapProduct!(product),
            );
          },
        );
      },
    );
  }

  int _resolveCrossAxisCount({
    required double productAreaWidth,
    required double viewportWidth,
  }) {
    if (productAreaWidth < 460 || viewportWidth < 900) {
      return 2;
    }
    if (productAreaWidth < 760) {
      return 3;
    }
    if (productAreaWidth < 1080) {
      return 4;
    }
    return 5;
  }

  double _resolveChildAspectRatio() {
    return switch (widget.presentationMode) {
      ProductCardPresentationMode.visual => 1.02,
      ProductCardPresentationMode.compact => 1.26,
    };
  }

  void _scheduleVisibleImagePreload({
    required BuildContext context,
    required List<Product> products,
    required int crossAxisCount,
  }) {
    if (!widget.enableVisibleImagePreload || products.isEmpty) {
      return;
    }

    final int preloadCount = (crossAxisCount * _preloadRowCount).clamp(
      0,
      products.length,
    );
    final List<String> imageUrls = products
        .take(preloadCount)
        .map((Product product) => normalizePosProductImageUrl(product.imageUrl))
        .whereType<String>()
        .toSet()
        .toList(growable: false);

    if (imageUrls.isEmpty) {
      return;
    }

    final String signature = imageUrls.join('|');
    if (_lastVisiblePreloadSignature == signature) {
      return;
    }
    _lastVisiblePreloadSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final String imageUrl in imageUrls) {
        unawaited(_precacheImageSafely(context, imageUrl));
      }
    });
  }

  Future<void> _precacheImageSafely(
    BuildContext context,
    String imageUrl,
  ) async {
    try {
      await widget.imagePrecache(
        context,
        widget.imageProviderResolver(imageUrl),
      );
    } catch (_) {
      // Preload is best-effort and should never break the grid.
    }
  }
}

class _ProductCountBadge extends StatelessWidget {
  const _ProductCountBadge({required this.productCount});

  final int productCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$productCount',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _SortModeBanner extends StatelessWidget {
  const _SortModeBanner({required this.hasChanges});

  final bool hasChanges;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('pos-product-sort-mode-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.reorder_rounded,
            size: 18,
            color: AppColors.warningStrong,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasChanges
                  ? 'Sıralama modu açık. Değişiklikler yalnızca bu kategori için Kaydet ile uygulanır.'
                  : 'Sıralama modu açık. Ürünleri yukarı veya aşağı taşıyın, sonra Kaydet seçin.',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.warningStrong,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSortList extends StatelessWidget {
  const _ProductSortList({
    required this.products,
    required this.isBusy,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMoveToTop,
    required this.onMoveToBottom,
  });

  final List<Product> products;
  final bool isBusy;
  final void Function(int index) onMoveUp;
  final void Function(int index) onMoveDown;
  final void Function(int index) onMoveToTop;
  final void Function(int index) onMoveToBottom;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey<String>('pos-product-sort-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Product product = products[index];
        return _ProductSortRow(
          product: product,
          index: index,
          itemCount: products.length,
          isBusy: isBusy,
          onMoveUp: () => onMoveUp(index),
          onMoveDown: () => onMoveDown(index),
          onMoveToTop: () => onMoveToTop(index),
          onMoveToBottom: () => onMoveToBottom(index),
        );
      },
    );
  }
}

class _ProductSortRow extends StatelessWidget {
  const _ProductSortRow({
    required this.product,
    required this.index,
    required this.itemCount,
    required this.isBusy,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMoveToTop,
    required this.onMoveToBottom,
  });

  final Product product;
  final int index;
  final int itemCount;
  final bool isBusy;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveToTop;
  final VoidCallback onMoveToBottom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey<String>('pos-product-sort-row-${product.id}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool useStackedControls = constraints.maxWidth < 360;
            final Widget details = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDarker,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.fromMinor(product.priceMinor),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final Widget controls = _ProductSortMoveControls(
              itemId: '${product.id}',
              isBusy: isBusy,
              isFirst: index == 0,
              isLast: index == itemCount - 1,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
              onMoveToTop: onMoveToTop,
              onMoveToBottom: onMoveToBottom,
            );

            if (useStackedControls) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  details,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: controls),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: details),
                const SizedBox(width: 12),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductSortMoveControls extends StatelessWidget {
  const _ProductSortMoveControls({
    required this.itemId,
    required this.isBusy,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMoveToTop,
    required this.onMoveToBottom,
  });

  final String itemId;
  final bool isBusy;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveToTop;
  final VoidCallback onMoveToBottom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: <Widget>[
        _MoveControlButton(
          buttonKey: ValueKey<String>('sort-move-top-$itemId'),
          tooltip: 'Başa al',
          icon: Icons.vertical_align_top_rounded,
          onPressed: isBusy || isFirst ? null : onMoveToTop,
        ),
        _MoveControlButton(
          buttonKey: ValueKey<String>('sort-move-up-$itemId'),
          tooltip: 'Yukarı',
          icon: Icons.keyboard_arrow_up_rounded,
          onPressed: isBusy || isFirst ? null : onMoveUp,
        ),
        _MoveControlButton(
          buttonKey: ValueKey<String>('sort-move-down-$itemId'),
          tooltip: 'Aşağı',
          icon: Icons.keyboard_arrow_down_rounded,
          onPressed: isBusy || isLast ? null : onMoveDown,
        ),
        _MoveControlButton(
          buttonKey: ValueKey<String>('sort-move-bottom-$itemId'),
          tooltip: 'Sona al',
          icon: Icons.vertical_align_bottom_rounded,
          onPressed: isBusy || isLast ? null : onMoveToBottom,
        ),
      ],
    );
  }
}

class _MoveControlButton extends StatelessWidget {
  const _MoveControlButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 20,
        splashRadius: 20,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primaryDarker,
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          disabledBackgroundColor: AppColors.surfaceAlt,
          disabledForegroundColor: AppColors.textSecondary.withValues(
            alpha: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _PosSearchBar extends StatelessWidget {
  const _PosSearchBar({
    required this.controller,
    required this.onChanged,
    required this.isActive,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        key: const ValueKey<String>('pos-product-search'),
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Ürün ara...',
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 20,
          ),
          suffixIcon: isActive
              ? GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 20,
          ),
          filled: true,
          fillColor: isActive
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
