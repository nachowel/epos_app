import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

String? normalizePosCategoryImageUrl(String? imageUrl) {
  final String? trimmed = imageUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String? normalizePosProductImageUrl(String? imageUrl) {
  final String? trimmed = imageUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

ImageProvider<Object> resolveCachedPosCategoryImageProvider(String imageUrl) {
  return CachedNetworkImageProvider(
    imageUrl,
    cacheManager: PosCategoryImageCacheManager.instance,
  );
}

ImageProvider<Object> resolveCachedPosProductImageProvider(String imageUrl) {
  // Keep disk caching on a plain CacheManager, but do not request cache-time
  // resizing here. `CachedNetworkImageProvider` only supports resize hints
  // with an `ImageCacheManager`, and mixing them caused runtime failures that
  // left POS cards in fallback mode.
  return CachedNetworkImageProvider(
    imageUrl,
    cacheManager: PosProductImageCacheManager.instance,
  );
}

Future<void> warmCatalogImageCache({
  required CacheManager cacheManager,
  required String imageUrl,
}) async {
  try {
    await cacheManager.getSingleFile(imageUrl);
  } catch (_) {
    // Image warmup is best-effort and must never affect POS/navigation flow.
  }
}

class PosCategoryImageCacheManager {
  PosCategoryImageCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'posCategoryImages',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 120,
    ),
  );
}

class PosProductImageCacheManager {
  PosProductImageCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'posProductImages',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 250,
    ),
  );
}
