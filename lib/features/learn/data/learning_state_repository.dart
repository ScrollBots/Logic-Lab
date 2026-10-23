import '../domain/learning_state.dart';

/// Persistence for the learning snapshot. The whole state is stored as one
/// document so XP, streaks, mastery and step progress can never drift apart.
abstract class LearningStateRepository {
  Future<LearningState?> load();

  Future<void> save(LearningState state);

  Future<void> clear();
}

class MemoryLearningStateRepository implements LearningStateRepository {
  MemoryLearningStateRepository([this._state]);

  LearningState? _state;

  @override
  Future<LearningState?> load() async => _state;

  @override
  Future<void> save(LearningState state) async {
    _state = state;
  }

  @override
  Future<void> clear() async {
    _state = null;
  }
}
