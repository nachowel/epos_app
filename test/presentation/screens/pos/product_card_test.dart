import 'dart:async';
import 'dart:ui' as ui;

import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/presentation/screens/pos/pos_product_presentation_policy.dart';
import 'package:epos_app/presentation/screens/pos/widgets/product_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long product name uses up to two lines in compact mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        product: const Product(
          id: 1,
          categoryId: 10,
          mealAdjustmentProfileId: null,
          name:
              'Extremely Long Breakfast Plate Name That Should Never Wrap Across Multiple Lines',
          priceMinor: 695,
          imageUrl: null,
          hasModifiers: false,
          isActive: true,
          sortOrder: 1,
        ),
        presentationMode: ProductCardPresentationMode.compact,
      ),
    );

    final Text nameText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('product-card-name')),
    );

    expect(nameText.maxLines, 2);
    expect(nameText.overflow, TextOverflow.ellipsis);
  });

  testWidgets(
    'compact mode shows image panel above the product name when image is available',
    (WidgetTester tester) async {
      final Completer<ImageInfo> completer = Completer<ImageInfo>();

      await tester.pumpWidget(
        _buildHarness(
          product: const Product(
            id: 11,
            categoryId: 10,
            mealAdjustmentProfileId: null,
            name: 'Chicken Club Sandwich',
            priceMinor: 895,
            imageUrl: 'https://cdn.example.com/chicken-club.jpg',
            hasModifiers: false,
            isActive: true,
            sortOrder: 11,
          ),
          presentationMode: ProductCardPresentationMode.compact,
          imageProviderResolver: (_) => _DeferredImageProvider(completer),
        ),
      );

      completer.complete(await _buildImageInfo());
      await tester.pump();

      final Rect imageRect = tester.getRect(
        find.byKey(const ValueKey<String>('product-card-image-panel')),
      );
      final Rect nameRect = tester.getRect(
        find.byKey(const ValueKey<String>('product-card-name')),
      );

      expect(
        find.byKey(const ValueKey<String>('product-card-image')),
        findsOneWidget,
      );
      expect(imageRect.bottom, lessThanOrEqualTo(nameRect.top));
    },
  );

  testWidgets(
    'compact mode without image keeps the current text-first layout',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildHarness(
          product: const Product(
            id: 13,
            categoryId: 10,
            mealAdjustmentProfileId: null,
            name: 'Veggie Panini',
            priceMinor: 775,
            imageUrl: null,
            hasModifiers: false,
            isActive: true,
            sortOrder: 13,
          ),
          presentationMode: ProductCardPresentationMode.compact,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('product-card-text-backdrop')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('product-card-image-panel')),
        findsNothing,
      );
    },
  );

  testWidgets('compact mode keeps price visually secondary to the name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        product: const Product(
          id: 12,
          categoryId: 10,
          mealAdjustmentProfileId: null,
          name: 'Chicken Club Sandwich',
          priceMinor: 895,
          imageUrl: null,
          hasModifiers: false,
          isActive: true,
          sortOrder: 12,
        ),
        presentationMode: ProductCardPresentationMode.compact,
      ),
    );

    final Text nameText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('product-card-name')),
    );
    final Text priceText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('product-card-price-text')),
    );

    expect(nameText.style!.fontSize, greaterThan(priceText.style!.fontSize!));
    expect(
      nameText.style!.fontWeight!.index,
      greaterThanOrEqualTo(priceText.style!.fontWeight!.index),
    );
  });

  testWidgets(
    'image load failure falls back to the current no-image compact layout',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildHarness(
          product: const Product(
            id: 2,
            categoryId: 10,
            mealAdjustmentProfileId: null,
            name: 'Farmer Breakfast',
            priceMinor: 600,
            imageUrl: 'https://cdn.example.com/failure.jpg',
            hasModifiers: false,
            isActive: true,
            sortOrder: 2,
          ),
          presentationMode: ProductCardPresentationMode.compact,
          imageProviderResolver: (_) => const _FailingImageProvider(),
        ),
      );
      await tester.pump();

      final Text nameText = tester.widget<Text>(
        find.byKey(const ValueKey<String>('product-card-name')),
      );

      expect(nameText.maxLines, 2);
      expect(find.text('£6.00'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('product-card-text-backdrop')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('product-card-image-panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('product-card-loading')),
        findsNothing,
      );
    },
  );

  testWidgets('loading state keeps a stable card size before image resolves', (
    WidgetTester tester,
  ) async {
    final Completer<ImageInfo> completer = Completer<ImageInfo>();
    final _DeferredImageProvider imageProvider = _DeferredImageProvider(
      completer,
    );

    await tester.pumpWidget(
      _buildHarness(
        product: const Product(
          id: 3,
          categoryId: 10,
          mealAdjustmentProfileId: null,
          name: 'Breakfast Set',
          priceMinor: 725,
          imageUrl: 'https://cdn.example.com/loading.jpg',
          hasModifiers: false,
          isActive: true,
          sortOrder: 3,
        ),
        presentationMode: ProductCardPresentationMode.visual,
        imageProviderResolver: (_) => imageProvider,
      ),
    );

    final Finder cardFinder = find.byType(ProductCard);
    final Size beforeResolve = tester.getSize(cardFinder);

    expect(
      find.byKey(const ValueKey<String>('product-card-loading')),
      findsOneWidget,
    );

    completer.complete(await _buildImageInfo());
    await tester.pump();

    final Size afterResolve = tester.getSize(cardFinder);

    expect(afterResolve, beforeResolve);
    expect(
      find.byKey(const ValueKey<String>('product-card-image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('product-card-loading')),
      findsNothing,
    );
  });

  testWidgets('tap callback fires exactly once', (WidgetTester tester) async {
    int tapCount = 0;

    await tester.pumpWidget(
      _buildHarness(
        product: const Product(
          id: 4,
          categoryId: 10,
          mealAdjustmentProfileId: null,
          name: 'Tea',
          priceMinor: 199,
          imageUrl: null,
          hasModifiers: false,
          isActive: true,
          sortOrder: 4,
        ),
        presentationMode: ProductCardPresentationMode.compact,
        onTap: () {
          tapCount++;
        },
      ),
    );

    await tester.tap(find.byType(ProductCard));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('price remains visible in constrained width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        width: 128,
        height: 104,
        product: const Product(
          id: 5,
          categoryId: 10,
          mealAdjustmentProfileId: null,
          name: 'Very Long Toasted Breakfast Sandwich Name',
          priceMinor: 199,
          imageUrl: null,
          hasModifiers: false,
          isActive: true,
          sortOrder: 5,
        ),
        presentationMode: ProductCardPresentationMode.compact,
      ),
    );

    final Rect cardRect = tester.getRect(find.byType(ProductCard));
    final Rect priceRect = tester.getRect(
      find.byKey(const ValueKey<String>('product-card-price')),
    );

    expect(find.text('£1.99'), findsOneWidget);
    expect(priceRect.right, lessThanOrEqualTo(cardRect.right));
    expect(priceRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    expect(priceRect.center.dx, greaterThanOrEqualTo(cardRect.center.dx));
  });
}

Widget _buildHarness({
  required Product product,
  required ProductCardPresentationMode presentationMode,
  ProductCardImageProviderResolver? imageProviderResolver,
  VoidCallback? onTap,
  double width = 180,
  double height = 180,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: ProductCard(
            product: product,
            onTap: onTap,
            presentationMode: presentationMode,
            imageProviderResolver:
                imageProviderResolver ?? _defaultImageProviderResolver,
          ),
        ),
      ),
    ),
  );
}

ImageProvider<Object> _defaultImageProviderResolver(String imageUrl) {
  return NetworkImage(imageUrl);
}

Future<ImageInfo> _buildImageInfo() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Paint paint = Paint()..color = const Color(0xFF2AA79B);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 4), paint);
  final ui.Image image = await recorder.endRecording().toImage(4, 4);
  return ImageInfo(image: image);
}

class _DeferredImageProvider extends ImageProvider<_DeferredImageProvider> {
  const _DeferredImageProvider(this.completer);

  final Completer<ImageInfo> completer;

  @override
  Future<_DeferredImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_DeferredImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DeferredImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(completer.future);
  }
}

class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
  const _FailingImageProvider();

  @override
  Future<_FailingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FailingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError('Image load failed')),
    );
  }
}
