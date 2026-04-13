import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

String? normalizePosProductImageUrl(String? imageUrl) {
  final String? trimmed = imageUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
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
