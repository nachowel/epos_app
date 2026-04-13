import 'dart:ui' as ui;

import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/presentation/screens/pos/pos_product_presentation_policy.dart';
import 'package:epos_app/presentation/screens/pos/widgets/product_card.dart';
import 'package:epos_app/presentation/screens/pos/widgets/product_grid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'preloads only the first visible image-backed products and does not repeat on rebuild',
    (WidgetTester tester) async {
      final List<String> preloadedUrls = <String>[];

      await tester.pumpWidget(
        _buildHarness(
          products: <Product>[
            _buildProduct(id: 1, imageUrl: 'https://cdn.example.com/1.jpg'),
            _buildProduct(id: 2, imageUrl: 'https://cdn.example.com/2.jpg'),
            _buildProduct(id: 3, imageUrl: null),
            _buildProduct(id: 4, imageUrl: ' https://cdn.example.com/4.jpg '),
            _buildProduct(id: 5, imageUrl: ''),
            _buildProduct(id: 6, imageUrl: 'https://cdn.example.com/6.jpg'),
            _buildProduct(id: 7, imageUrl: 'https://cdn.example.com/7.jpg'),
            _buildProduct(id: 8, imageUrl: 'https://cdn.example.com/8.jpg'),
          ],
          imageProviderResolver: (String imageUrl) =>
              _TrackingImageProvider(imageUrl),
          imagePrecache:
              (BuildContext _, ImageProvider<Object> imageProvider) async {
                preloadedUrls.add(
                  (imageProvider as _TrackingImageProvider).imageUrl,
                );
              },
        ),
      );
      await tester.pump();

      expect(preloadedUrls, <String>[
        'https://cdn.example.com/1.jpg',
        'https://cdn.example.com/2.jpg',
        'https://cdn.example.com/4.jpg',
        'https://cdn.example.com/6.jpg',
      ]);

      await tester.pumpWidget(
        _buildHarness(
          products: <Product>[
            _buildProduct(id: 1, imageUrl: 'https://cdn.example.com/1.jpg'),
            _buildProduct(id: 2, imageUrl: 'https://cdn.example.com/2.jpg'),
            _buildProduct(id: 3, imageUrl: null),
            _buildProduct(id: 4, imageUrl: ' https://cdn.example.com/4.jpg '),
            _buildProduct(id: 5, imageUrl: ''),
            _buildProduct(id: 6, imageUrl: 'https://cdn.example.com/6.jpg'),
            _buildProduct(id: 7, imageUrl: 'https://cdn.example.com/7.jpg'),
            _buildProduct(id: 8, imageUrl: 'https://cdn.example.com/8.jpg'),
          ],
          imageProviderResolver: (String imageUrl) =>
              _TrackingImageProvider(imageUrl),
          imagePrecache:
              (BuildContext _, ImageProvider<Object> imageProvider) async {
                preloadedUrls.add(
                  (imageProvider as _TrackingImageProvider).imageUrl,
                );
              },
        ),
      );
      await tester.pump();

      expect(preloadedUrls, <String>[
        'https://cdn.example.com/1.jpg',
        'https://cdn.example.com/2.jpg',
        'https://cdn.example.com/4.jpg',
        'https://cdn.example.com/6.jpg',
      ]);
      expect(preloadedUrls, isNot(contains('https://cdn.example.com/7.jpg')));
      expect(preloadedUrls, isNot(contains('https://cdn.example.com/8.jpg')));
    },
  );

  testWidgets('sort mode skips visible image preloading', (
    WidgetTester tester,
  ) async {
    final List<String> preloadedUrls = <String>[];

    await tester.pumpWidget(
      _buildHarness(
        products: <Product>[
          _buildProduct(id: 1, imageUrl: 'https://cdn.example.com/1.jpg'),
          _buildProduct(id: 2, imageUrl: 'https://cdn.example.com/2.jpg'),
        ],
        isSortMode: true,
        imageProviderResolver: (String imageUrl) =>
            _TrackingImageProvider(imageUrl),
        imagePrecache:
            (BuildContext _, ImageProvider<Object> imageProvider) async {
              preloadedUrls.add(
                (imageProvider as _TrackingImageProvider).imageUrl,
              );
            },
      ),
    );
    await tester.pump();

    expect(preloadedUrls, isEmpty);
    expect(
      find.byKey(const ValueKey<String>('pos-product-sort-list')),
      findsOneWidget,
    );
  });
}

Widget _buildHarness({
  required List<Product> products,
  required ProductCardImageProviderResolver imageProviderResolver,
  required ProductGridImagePrecache imagePrecache,
  bool isSortMode = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 720,
        height: 560,
        child: ProductGrid(
          title: 'Breakfast',
          productCount: products.length,
          products: products,
          isLoading: false,
          onTapProduct: (_) {},
          viewportWidth: 1200,
          presentationMode: ProductCardPresentationMode.visual,
          isSortMode: isSortMode,
          isSavingSortOrder: false,
          hasSortChanges: false,
          sortDraft: products,
          imageProviderResolver: imageProviderResolver,
          imagePrecache: imagePrecache,
          onEnterSortMode: () {},
          onCancelSortMode: () {},
          onSaveSortOrder: () async {},
          onMoveProductUp: (_) {},
          onMoveProductDown: (_) {},
          onMoveProductToTop: (_) {},
          onMoveProductToBottom: (_) {},
        ),
      ),
    ),
  );
}

Product _buildProduct({required int id, required String? imageUrl}) {
  return Product(
    id: id,
    categoryId: 10,
    mealAdjustmentProfileId: null,
    name: 'Product $id',
    priceMinor: 500 + id,
    imageUrl: imageUrl,
    hasModifiers: false,
    isActive: true,
    sortOrder: id,
  );
}

Future<ImageInfo> _buildImageInfo() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Paint paint = Paint()..color = const Color(0xFF2AA79B);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 4), paint);
  final ui.Image image = await recorder.endRecording().toImage(4, 4);
  return ImageInfo(image: image);
}

class _TrackingImageProvider extends ImageProvider<_TrackingImageProvider> {
  const _TrackingImageProvider(this.imageUrl);

  final String imageUrl;

  @override
  Future<_TrackingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_TrackingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _TrackingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_buildImageInfo());
  }
}
