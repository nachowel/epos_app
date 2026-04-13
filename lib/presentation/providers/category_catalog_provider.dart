import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/models/category.dart';

final FutureProvider<List<Category>> posEntryCategoriesProvider =
    FutureProvider<List<Category>>((Ref ref) {
      return ref.read(catalogServiceProvider).getCategories();
    });
