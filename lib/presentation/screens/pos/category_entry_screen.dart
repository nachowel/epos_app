import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/app_providers.dart';
import '../../../domain/models/category.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/section_app_bar.dart';

final FutureProvider<List<Category>> posEntryCategoriesProvider =
    FutureProvider<List<Category>>((Ref ref) {
      return ref.read(catalogServiceProvider).getCategories();
    });

class CategoryEntryScreen extends ConsumerStatefulWidget {
  const CategoryEntryScreen({super.key});

  @override
  ConsumerState<CategoryEntryScreen> createState() =>
      _CategoryEntryScreenState();
}

class _CategoryEntryScreenState extends ConsumerState<CategoryEntryScreen> {
  static const Key _emptyStateKey = Key('category-entry-empty-state');
  static const Key _featuredGridKey = Key('category-entry-featured-grid');
  static const Key _remainingGridKey = Key('category-entry-remaining-grid');
  static const double _featuredCardHeight = 156;
  static const double _remainingCardHeight = 116;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(shiftNotifierProvider.notifier).refreshOpenShift(),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(posEntryCategoriesProvider);
    await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
    await ref.read(posEntryCategoriesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final AsyncValue<List<Category>> categoriesAsync = ref.watch(
      posEntryCategoriesProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: 'Categories',
        currentRoute: '/pos/categories',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        compactVisual: true,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: categoriesAsync.when(
            loading: () => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: const <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
            error: (Object error, StackTrace stackTrace) => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.all(AppSizes.spacingLg),
                  sliver: SliverToBoxAdapter(
                    child: _EntryShell(
                      child: _EntryMessage(
                        title: 'Categories',
                        message: AppStrings.errorGeneric,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            data: (List<Category> categories) {
              if (categories.isEmpty) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSizes.spacingLg),
                      sliver: SliverToBoxAdapter(
                        child: _EntryShell(
                          child: _EntryMessage(
                            contentKey: _emptyStateKey,
                            title: 'Categories',
                            message: AppStrings.noCategories,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final List<Category> featuredCategories = categories
                  .take(3)
                  .toList(growable: false);
              final List<Category> remainingCategories = categories
                  .skip(3)
                  .toList(growable: false);

              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double horizontalPadding = constraints.maxWidth >= 1280
                      ? AppSizes.spacingXl
                      : AppSizes.spacingLg;
                  final int featuredColumns = _resolveFeaturedColumns(
                    width: constraints.maxWidth,
                    count: featuredCategories.length,
                  );
                  final int remainingColumns = _resolveRemainingColumns(
                    constraints.maxWidth,
                  );

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: <Widget>[
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          AppSizes.spacingMd,
                          horizontalPadding,
                          AppSizes.spacingLg,
                        ),
                        sliver: const SliverToBoxAdapter(
                          child: _EntryShell(
                            child: _EntryHeader(title: 'Categories'),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          remainingCategories.isNotEmpty
                              ? AppSizes.spacingMd
                              : AppSizes.spacingLg,
                        ),
                        sliver: _FeaturedCategoryGrid(
                          key: _featuredGridKey,
                          categories: featuredCategories,
                          columns: featuredColumns,
                          cardHeight: _featuredCardHeight,
                        ),
                      ),
                      if (remainingCategories.isNotEmpty)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            AppSizes.spacingLg,
                          ),
                          sliver: _RemainingCategoryGrid(
                            key: _remainingGridKey,
                            categories: remainingCategories,
                            columns: remainingColumns,
                            cardHeight: _remainingCardHeight,
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  int _resolveFeaturedColumns({required double width, required int count}) {
    if (count <= 1 || width < 720) {
      return 1;
    }
    if (count == 2 || width < 960) {
      return 2;
    }
    return 3;
  }

  int _resolveRemainingColumns(double width) {
    if (width < 700) {
      return 2;
    }
    if (width < 1024) {
      return 3;
    }
    return 4;
  }
}

class _EntryShell extends StatelessWidget {
  const _EntryShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EntryHeader extends StatelessWidget {
  const _EntryHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        14,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          height: 1,
        ),
      ),
    );
  }
}

class _EntryMessage extends StatelessWidget {
  const _EntryMessage({
    required this.title,
    required this.message,
    this.contentKey,
  });

  final String title;
  final String message;
  final Key? contentKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: contentKey,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _EntryHeader(title: title),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spacingLg,
              0,
              AppSizes.spacingLg,
              AppSizes.spacingLg,
            ),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: AppSizes.fontSm,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCategoryGrid extends StatelessWidget {
  const _FeaturedCategoryGrid({
    required this.categories,
    required this.columns,
    required this.cardHeight,
    super.key,
  });

  final List<Category> categories;
  final int columns;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        return _CategoryEntryCard(category: categories[index], isLarge: true);
      }, childCount: categories.length),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: cardHeight,
      ),
    );
  }
}

class _RemainingCategoryGrid extends StatelessWidget {
  const _RemainingCategoryGrid({
    required this.categories,
    required this.columns,
    required this.cardHeight,
    super.key,
  });

  final List<Category> categories;
  final int columns;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        return _CategoryEntryCard(category: categories[index], isLarge: false);
      }, childCount: categories.length),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: cardHeight,
      ),
    );
  }
}

class _CategoryEntryCard extends StatelessWidget {
  const _CategoryEntryCard({required this.category, required this.isLarge});

  final Category category;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(AppSizes.radiusLg);
    final double titleFontSize = isLarge ? 17 : 12.5;
    final FontWeight titleWeight = isLarge ? FontWeight.w800 : FontWeight.w700;
    final double titleInset = isLarge ? 12 : 9;

    return Material(
      key: ValueKey<String>('category-entry-card-${category.id}'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => context.go(_buildPosLocation(category.id)),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.borderStrong, width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryDarker.withValues(alpha: 0.08),
                blurRadius: isLarge ? 15 : 9,
                offset: Offset(0, isLarge ? 6 : 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _CategoryEntryImage(category: category),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const <double>[0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: titleInset,
                  right: titleInset,
                  bottom: titleInset,
                  child: Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: titleWeight,
                      color: AppColors.textOnPrimary,
                      height: isLarge ? 1.04 : 1.08,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryEntryImage extends StatelessWidget {
  const _CategoryEntryImage({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = category.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return _CategoryEntryPlaceholder(categoryId: category.id);
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _CategoryEntryPlaceholder(categoryId: category.id),
        Positioned.fill(
          child: Image.network(
            imageUrl,
            key: ValueKey<String>('category-entry-image-${category.id}'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, __, ___) =>
                _CategoryEntryPlaceholder(categoryId: category.id),
            loadingBuilder:
                (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return _CategoryEntryPlaceholder(categoryId: category.id);
                },
          ),
        ),
      ],
    );
  }
}

class _CategoryEntryPlaceholder extends StatelessWidget {
  const _CategoryEntryPlaceholder({this.categoryId});

  final int? categoryId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: categoryId == null
          ? null
          : ValueKey<String>('category-entry-placeholder-$categoryId'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primaryLight,
            AppColors.primaryLighter,
            AppColors.surfaceAlt,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.image_outlined,
                size: 42,
                color: AppColors.primaryDarker,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _buildPosLocation(int categoryId) {
  return Uri(
    path: '/pos',
    queryParameters: <String, String>{'categoryId': '$categoryId'},
  ).toString();
}
