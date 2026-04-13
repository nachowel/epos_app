import '../../data/repositories/analytics_repository.dart';
import '../models/analytics/analytics_date_range.dart';
import '../models/analytics/category_product_analytics_section.dart';
import '../models/analytics/product_analytics_item.dart';

class AnalyticsProductsService {
  const AnalyticsProductsService({
    required AnalyticsRepository repository,
    this.defaultPerCategoryLimit = 5,
  }) : _repository = repository,
       assert(defaultPerCategoryLimit > 0);

  final AnalyticsRepository _repository;
  final int defaultPerCategoryLimit;

  Future<List<CategoryProductAnalyticsSection>> getCategoryProductSections(
    AnalyticsDateRange range, {
    int? perCategoryLimit,
  }) async {
    final int resolvedLimit = perCategoryLimit ?? defaultPerCategoryLimit;
    final List<CategoryProductAnalyticsSection> sections = await _repository
        .getCategoryProductSections(range, perCategoryLimit: resolvedLimit);

    return sections
        .map(_normalizeSection)
        .where(
          (CategoryProductAnalyticsSection section) =>
              section.totalRevenueMinor > 0 || section.products.isNotEmpty,
        )
        .toList(growable: false);
  }

  CategoryProductAnalyticsSection _normalizeSection(
    CategoryProductAnalyticsSection section,
  ) {
    return section.copyWith(
      categoryName: section.categoryName.trim(),
      totalRevenueMinor: _normalizeRevenueMinor(section.totalRevenueMinor),
      products: section.products
          .map(_normalizeProduct)
          .where(
            (ProductAnalyticsItem item) =>
                item.revenueMinor > 0 || item.quantityCount > 0,
          )
          .toList(growable: false),
    );
  }

  ProductAnalyticsItem _normalizeProduct(ProductAnalyticsItem item) {
    return item.copyWith(
      productName: item.productName.trim(),
      revenueMinor: _normalizeRevenueMinor(item.revenueMinor),
      quantityCount: _normalizeCount(item.quantityCount),
    );
  }

  int _normalizeRevenueMinor(int value) => value < 0 ? 0 : value;

  int _normalizeCount(int value) => value < 0 ? 0 : value;
}
