import '../../data/repositories/category_repository.dart';
import '../../data/repositories/modifier_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_modifier.dart';

class CatalogService {
  const CatalogService({
    required CategoryRepository categoryRepository,
    required ProductRepository productRepository,
    required ModifierRepository modifierRepository,
  }) : _categoryRepository = categoryRepository,
       _productRepository = productRepository,
       _modifierRepository = modifierRepository;

  final CategoryRepository _categoryRepository;
  final ProductRepository _productRepository;
  final ModifierRepository _modifierRepository;

  Future<List<Category>> getCategories() {
    return _categoryRepository.getActiveCatalogCategories();
  }

  Future<List<Product>> getProducts({int? categoryId}) {
    return _productRepository.getActiveCatalogProducts(categoryId: categoryId);
  }

  Future<List<ProductModifier>> getProductModifiers(int productId) {
    return _modifierRepository.getByProductId(productId, activeOnly: true);
  }
}
