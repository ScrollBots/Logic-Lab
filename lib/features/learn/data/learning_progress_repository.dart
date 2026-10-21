import 'package:flutter/foundation.dart';

@immutable
class LearningProgress {
  const LearningProgress({
    required this.itemId,
    required this.completed,
    required this.bestScore,
    required this.attempts,
    required this.updatedAt,
  });

  final String itemId;
  final bool completed;
  final int bestScore;
  final int attempts;
  final DateTime updatedAt;

  LearningProgress copyWith({
    bool? completed,
    int? bestScore,
    int? attempts,
    DateTime? updatedAt,
  }) {
    return LearningProgress(
      itemId: itemId,
      completed: completed ?? this.completed,
      bestScore: bestScore ?? this.bestScore,
      attempts: attempts ?? this.attempts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract class LearningProgressRepository {
  Future<List<LearningProgress>> loadAll();

  Future<void> upsert(LearningProgress progress);

  Future<void> deleteAll();

  Future<void> replaceAll(List<LearningProgress> items);
}

class MemoryLearningProgressRepository implements LearningProgressRepository {
  MemoryLearningProgressRepository([
    Iterable<LearningProgress> initial = const <LearningProgress>[],
  ]) : _items = <String, LearningProgress>{
         for (final LearningProgress item in initial) item.itemId: item,
       };

  final Map<String, LearningProgress> _items;

  @override
  Future<List<LearningProgress>> loadAll() async => _items.values.toList();

  @override
  Future<void> upsert(LearningProgress progress) async {
    _items[progress.itemId] = progress;
  }

  @override
  Future<void> deleteAll() async {
    _items.clear();
  }

  @override
  Future<void> replaceAll(List<LearningProgress> items) async {
    _items
      ..clear()
      ..addEntries(
        items.map(
          (LearningProgress item) =>
              MapEntry<String, LearningProgress>(item.itemId, item),
        ),
      );
  }
}
