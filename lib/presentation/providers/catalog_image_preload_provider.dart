import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/services/catalog_service.dart';
import '../screens/pos/widgets/pos_product_image_cache.dart';

class CatalogImagePreloadService {
  CatalogImagePreloadService(this._catalogService);

  final CatalogService _catalogService;
  Future<void>? _inFlight;

  Future<void> preloadCatalogImages() {
    final Future<void>? inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final Future<void> task = _runPreload();
    _inFlight = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_inFlight, task)) {
          _inFlight = null;
        }
      }),
    );
    return task;
  }

  Future<void> _runPreload() async {
    final Future<List<Category>> categoriesFuture = _catalogService
        .getCategories();
    final Future<List<Product>> productsFuture = _catalogService.getProducts();
    final List<Category> categories = await categoriesFuture;
    final List<Product> products = await productsFuture;

    final Set<String> categoryImageUrls = categories
        .map((Category category) => normalizePosCategoryImageUrl(category.imageUrl))
        .whereType<String>()
        .toSet();
    final Set<String> productImageUrls = products
        .map((Product product) => normalizePosProductImageUrl(product.imageUrl))
        .whereType<String>()
        .toSet();

    await Future.wait(<Future<void>>[
      for (final String imageUrl in categoryImageUrls)
        warmCatalogImageCache(
          cacheManager: PosCategoryImageCacheManager.instance,
          imageUrl: imageUrl,
        ),
      for (final String imageUrl in productImageUrls)
        warmCatalogImageCache(
          cacheManager: PosProductImageCacheManager.instance,
          imageUrl: imageUrl,
        ),
    ]);
  }
}

final Provider<CatalogImagePreloadService>
catalogImagePreloadServiceProvider = Provider<CatalogImagePreloadService>(
  (Ref ref) => CatalogImagePreloadService(ref.watch(catalogServiceProvider)),
);
