import '../models/meal_adjustment_profile.dart';

abstract class MealAdjustmentProfileRepository {
  Future<List<MealAdjustmentProfile>> listProfiles({bool activeOnly = true});

  Future<List<MealAdjustmentProfile>> listProfilesForAdmin();

  Future<MealAdjustmentProfile?> getProfileById(int id);

  Future<MealAdjustmentProfileDraft?> loadProfileDraft(int id);

  Future<int> saveProfileDraft(MealAdjustmentProfileDraft draft);

  Future<bool> deleteProfile(int profileId);

  Future<bool> assignProfileToProduct({required int productId, int? profileId});

  Future<List<MealAdjustmentProductSummary>> listProductsByProfile(
    int profileId, {
    bool activeOnly = false,
  });

  Future<Map<int, MealAdjustmentProductSummary>> loadProductSummariesByIds(
    Iterable<int> productIds,
  );

  Future<Set<int>> loadBreakfastSemanticProductIds(
    Iterable<int> productIds,
  );
}

class MealAdjustmentProductSummary {
  const MealAdjustmentProductSummary({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.isActive,
    this.mealAdjustmentProfileId,
  });

  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final bool isActive;
  final int? mealAdjustmentProfileId;

  bool get isBreakfastProduct =>
      categoryName.trim().toLowerCase() == 'set breakfast';
}
