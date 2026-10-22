import 'package:flutter/foundation.dart';

import '../data/learning_progress_repository.dart';

class LearningController extends ChangeNotifier {
  LearningController(this._repository);

  final LearningProgressRepository _repository;
  Map<String, LearningProgress> _items = <String, LearningProgress>{};
  bool _loading = true;

  Map<String, LearningProgress> get items =>
      Map<String, LearningProgress>.unmodifiable(_items);
  bool get isLoading => _loading;

  bool isCompleted(String itemId) => _items[itemId]?.completed ?? false;

  int get completedCount =>
      _items.values.where((LearningProgress p) => p.completed).length;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final List<LearningProgress> items = await _repository.loadAll();
      _items = <String, LearningProgress>{
        for (final LearningProgress item in items) item.itemId: item,
      };
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markCompleted(String itemId, {int score = 0}) async {
    final LearningProgress? existing = _items[itemId];
    final LearningProgress updated = LearningProgress(
      itemId: itemId,
      completed: true,
      bestScore:
          (existing?.bestScore ?? 0) > score ? existing!.bestScore : score,
      attempts: (existing?.attempts ?? 0) + 1,
      updatedAt: DateTime.now(),
    );
    _items = <String, LearningProgress>{..._items, itemId: updated};
    notifyListeners();
    await _repository.upsert(updated);
  }

  Future<void> recordAttempt(
    String itemId, {
    required bool passed,
    int score = 0,
  }) async {
    final LearningProgress? existing = _items[itemId];
    final LearningProgress updated = LearningProgress(
      itemId: itemId,
      completed: existing?.completed ?? passed,
      bestScore:
          (existing?.bestScore ?? 0) > score ? existing!.bestScore : score,
      attempts: (existing?.attempts ?? 0) + 1,
      updatedAt: DateTime.now(),
    );
    _items = <String, LearningProgress>{..._items, itemId: updated};
    notifyListeners();
    await _repository.upsert(updated);
  }

  Future<void> resetAll() async {
    _items = <String, LearningProgress>{};
    notifyListeners();
    await _repository.deleteAll();
  }

  /// Restores progress entries coming from a backup file.
  Future<void> restoreAll(List<LearningProgress> items) async {
    await _repository.replaceAll(items);
    await load();
  }
}
