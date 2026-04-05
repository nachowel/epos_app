import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/presentation/providers/admin_breakfast_set_editor_provider.dart';
import 'package:epos_app/presentation/providers/admin_breakfast_sets_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'saving a valid breakfast draft refreshes overview state without a manual reload',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int drinksCategoryId = await insertCategory(db, name: 'Drinks');

      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set Sync',
        priceMinor: 950,
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      await insertProduct(
        db,
        categoryId: drinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(adminBreakfastSetsNotifierProvider.notifier).load();

      AdminBreakfastSetsState overviewState = container.read(
        adminBreakfastSetsNotifierProvider,
      );
      expect(overviewState.errorMessage, isNull);
      expect(overviewState.items, hasLength(1));
      expect(
        overviewState.items.single.validationState,
        BreakfastSetValidationState.incomplete,
      );
      expect(
        overviewState.items.single.validationSummary,
        'Configuration not started.',
      );

      final AdminBreakfastSetEditorNotifier editorNotifier = container.read(
        adminBreakfastSetEditorNotifierProvider.notifier,
      );
      await editorNotifier.load(rootProductId);

      final AdminBreakfastSetEditorState initialEditorState = container.read(
        adminBreakfastSetEditorNotifierProvider,
      );
      final Product egg = initialEditorState
          .editorData!
          .availableSetItemProducts
          .firstWhere((Product product) => product.name == 'Egg');
      final Product tea = initialEditorState.editorData!.availableProducts
          .firstWhere((Product product) => product.name == 'Tea');

      await editorNotifier.addSetItem(egg);
      await editorNotifier.addChoiceGroup();
      await editorNotifier.updateChoiceGroupNameAt(0, 'Drink choice');
      await editorNotifier.updateChoiceGroupMinSelectAt(0, '1');
      await editorNotifier.addChoiceGroupMemberAt(0, tea);

      final AdminBreakfastSetEditorState readyEditorState = container.read(
        adminBreakfastSetEditorNotifierProvider,
      );
      expect(
        readyEditorState.draftStatus,
        AdminBreakfastSetEditorDraftStatus.valid,
      );
      expect(readyEditorState.isSaveEnabled, isTrue);

      final bool saved = await editorNotifier.save();
      expect(saved, isTrue);

      overviewState = container.read(adminBreakfastSetsNotifierProvider);
      expect(overviewState.errorMessage, isNull);
      expect(overviewState.items, hasLength(1));
      expect(
        overviewState.items.single.validationState,
        BreakfastSetValidationState.valid,
      );
      expect(
        overviewState.items.single.validationSummary,
        'Ready for editing.',
      );
    },
  );
}
