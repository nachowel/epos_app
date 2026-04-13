import 'package:cached_network_image/cached_network_image.dart';
import 'package:epos_app/presentation/screens/pos/widgets/pos_product_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizePosProductImageUrl trims valid URLs and drops empties', () {
    expect(
      normalizePosProductImageUrl(' https://cdn.example.com/products/tea.jpg '),
      'https://cdn.example.com/products/tea.jpg',
    );
    expect(normalizePosProductImageUrl('   '), isNull);
    expect(normalizePosProductImageUrl(null), isNull);
  });

  test(
    'resolveCachedPosProductImageProvider uses cached_network_image without resize wrapping',
    () {
      final ImageProvider<Object> provider =
          resolveCachedPosProductImageProvider(
            'https://cdn.example.com/products/coffee.jpg',
          );

      expect(provider, isA<CachedNetworkImageProvider>());
      expect(
        (provider as CachedNetworkImageProvider).url,
        'https://cdn.example.com/products/coffee.jpg',
      );
    },
  );
}
