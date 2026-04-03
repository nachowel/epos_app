import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/analytics/saved_analytics_view.dart';

class SavedAnalyticsViewStore {
  SavedAnalyticsViewStore(this._prefs);

  static const String _storageKey = 'admin_saved_analytics_views_v1';

  final SharedPreferences _prefs;

  Future<List<SavedAnalyticsView>> readAll() async {
    final List<SavedAnalyticsView> decoded = SavedAnalyticsView.decodeList(
      _prefs.getString(_storageKey),
    ).toList(growable: true);
    decoded.sort(
      (SavedAnalyticsView left, SavedAnalyticsView right) =>
          right.updatedAt.compareTo(left.updatedAt),
    );
    return decoded;
  }

  Future<List<SavedAnalyticsView>> save(SavedAnalyticsView view) async {
    final List<SavedAnalyticsView> existing = await readAll();
    final int index = existing.indexWhere(
      (SavedAnalyticsView item) => item.id == view.id,
    );
    if (index >= 0) {
      existing[index] = view;
    } else {
      existing.add(view);
    }
    await _persist(existing);
    return readAll();
  }

  Future<List<SavedAnalyticsView>> delete(String id) async {
    final List<SavedAnalyticsView> existing = await readAll();
    existing.removeWhere((SavedAnalyticsView item) => item.id == id);
    await _persist(existing);
    return readAll();
  }

  Future<void> _persist(List<SavedAnalyticsView> views) async {
    await _prefs.setString(_storageKey, SavedAnalyticsView.encodeList(views));
  }
}
