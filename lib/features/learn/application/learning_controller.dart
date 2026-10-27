import 'package:flutter/foundation.dart';

import '../data/learning_progress_repository.dart';
import '../data/learning_state_repository.dart';
import '../domain/curriculum.dart';
import '../domain/learning_content.dart';
import '../domain/learning_state.dart';
import '../domain/lesson_models.dart';

/// The single source of truth for learning progress.
///
/// It keeps two storage shapes in sync:
///
/// * [LearningState] is the full snapshot (XP, streak, mastery, review
///   scheduling and step progress) stored by [LearningStateRepository].
/// * [LearningProgress] rows are the legacy per-item records, still written so
///   older backups and the settings data tools keep working.
class LearningController extends ChangeNotifier {
  LearningController(
    this._repository, {
    LearningStateRepository? stateRepository,
    DateTime Function()? clock,
  }) : _stateRepository = stateRepository ?? MemoryLearningStateRepository(),
       _clock = clock ?? DateTime.now;

  final LearningProgressRepository _repository;
  final LearningStateRepository _stateRepository;
  final DateTime Function() _clock;

  Map<String, LearningProgress> _items = <String, LearningProgress>{};
  LearningState _state = const LearningState();
  bool _loading = true;
  Future<void> _writeQueue = Future<void>.value();

  Map<String, LearningProgress> get items =>
      Map<String, LearningProgress>.unmodifiable(_items);
  bool get isLoading => _loading;
  LearningState get state => _state;
  DateTime get now => _clock();

  int get xp => _state.xp;
  int get level => _state.level;
  double get levelProgress => _state.levelProgress;
  int get streak => _state.streakOn(now);
  int get bestStreak => _state.bestStreak;
  int get xpToday => _state.xpOn(now);
  int get dailyGoalXp => _state.dailyGoalXp;
  double get dailyProgress =>
      dailyGoalXp <= 0 ? 0 : (xpToday / dailyGoalXp).clamp(0.0, 1.0);

  int get completedCount =>
      _state.completedLessons.length + _state.completedChallenges.length;

  int get totalLessons => kLessons.length;

  bool isCompleted(String itemId) =>
      _state.completedLessons.contains(itemId) ||
      _state.completedChallenges.contains(itemId) ||
      (_items[itemId]?.completed ?? false);

  bool isLessonCompleted(String lessonId) =>
      _state.completedLessons.contains(lessonId);

  bool canOpenLesson(String lessonId) =>
      isLessonUnlocked(lessonId, _state.completedLessons) ||
      isLessonCompleted(lessonId);

  LearningLesson? get nextLesson {
    for (final LearningLesson lesson in kLessons) {
      if (!isLessonCompleted(lesson.id)) {
        return lesson;
      }
    }
    return null;
  }

  LearningUnit? get currentUnit {
    final LearningLesson? lesson = nextLesson;
    return lesson == null ? kCurriculum.last : unitOfLesson(lesson.id);
  }

  bool get allLessonsCompleted =>
      kLessons.every((LearningLesson lesson) => isLessonCompleted(lesson.id));

  double lessonProgress(LearningLesson lesson) {
    if (isLessonCompleted(lesson.id)) {
      return 1;
    }
    if (lesson.steps.isEmpty) {
      return 0;
    }
    return _state.stepsDone(lesson.id).length / lesson.steps.length;
  }

  int resumeStepIndex(LearningLesson lesson) {
    final Set<int> done = _state.stepsDone(lesson.id);
    for (int index = 0; index < lesson.steps.length; index++) {
      if (!done.contains(index)) {
        return index;
      }
    }
    // Every step is finished but the lesson was never closed: resume on the
    // last step so the summary (and the completion bonus) can still be earned.
    if (!isLessonCompleted(lesson.id) && lesson.steps.isNotEmpty) {
      return lesson.steps.length - 1;
    }
    return 0;
  }

  ConceptMastery masteryFor(String conceptId) =>
      _state.concepts[conceptId] ?? const ConceptMastery();

  int get masteredConceptCount => _state.concepts.values
      .where(
        (ConceptMastery value) => value.attempts >= 2 && value.mastery >= 80,
      )
      .length;

  int get practicedConceptCount => _state.concepts.length;

  /// Concepts that should be reviewed now: scheduled reviews that are due and
  /// concepts whose measured mastery is still low.
  List<String> get reviewConceptIds {
    final DateTime moment = now;
    final List<MapEntry<String, ConceptMastery>> entries =
        _state.concepts.entries
            .where(
              (MapEntry<String, ConceptMastery> entry) =>
                  entry.value.needsPractice(moment),
            )
            .toList()
          ..sort((
            MapEntry<String, ConceptMastery> a,
            MapEntry<String, ConceptMastery> b,
          ) {
            final DateTime aDue = a.value.dueAt ?? moment;
            final DateTime bDue = b.value.dueAt ?? moment;
            final int byDue = aDue.compareTo(bDue);
            return byDue != 0
                ? byDue
                : a.value.mastery.compareTo(b.value.mastery);
          });
    return entries
        .take(4)
        .map((MapEntry<String, ConceptMastery> entry) => entry.key)
        .toList(growable: false);
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final List<LearningProgress> items = await _repository.loadAll();
      _items = <String, LearningProgress>{
        for (final LearningProgress item in items) item.itemId: item,
      };
      _state = await _stateRepository.load() ?? _seedFrom(items);
      _mergeStateIntoItems();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  LearningState _seedFrom(List<LearningProgress> items) {
    final Set<String> lessons = <String>{};
    final Set<String> challenges = <String>{};
    for (final LearningProgress item in items) {
      if (!item.completed) {
        continue;
      }
      if (item.itemId.startsWith('lesson_')) {
        lessons.add(item.itemId);
      } else if (item.itemId.startsWith('challenge_')) {
        challenges.add(item.itemId);
      }
    }
    final Map<String, List<int>> steps = <String, List<int>>{};
    for (final String lessonId in lessons) {
      final LearningLesson? lesson = lessonById(lessonId);
      if (lesson != null) {
        steps[lessonId] = List<int>.generate(
          lesson.steps.length,
          (int index) => index,
        );
      }
    }
    return LearningState(
      completedLessons: lessons,
      completedChallenges: challenges,
      stepProgress: steps,
    );
  }

  void _mergeStateIntoItems() {
    final DateTime moment = now;
    final Map<String, LearningProgress> merged = <String, LearningProgress>{
      ..._items,
    };
    for (final String lessonId in _state.completedLessons) {
      merged.putIfAbsent(
        lessonId,
        () => LearningProgress(
          itemId: lessonId,
          completed: true,
          bestScore: 100,
          attempts: 1,
          updatedAt: moment,
        ),
      );
    }
    for (final String challengeId in _state.completedChallenges) {
      merged.putIfAbsent(
        challengeId,
        () => LearningProgress(
          itemId: challengeId,
          completed: true,
          bestScore: 100,
          attempts: 1,
          updatedAt: moment,
        ),
      );
    }
    _items = merged;
  }

  /// Records one exercise answer and returns how much XP it earned.
  Future<int> recordAnswer({
    required List<String> conceptIds,
    required bool correct,
    required bool usedHint,
    int xpOverride = -1,
  }) async {
    final int before = _state.xp;
    _state = _state.recordAnswer(
      conceptIds: conceptIds,
      correct: correct,
      usedHint: usedHint,
      now: now,
      xpOverride: xpOverride,
    );
    notifyListeners();
    await _saveState();
    return _state.xp - before;
  }

  Future<void> markStepDone(String lessonId, int stepIndex) async {
    final LearningLesson? lesson = lessonById(lessonId);
    if (lesson == null) {
      return;
    }
    _state = _state.markStepDone(lessonId, stepIndex, lesson.steps.length);
    notifyListeners();
    await _saveState();
  }

  Future<int> completeLesson(String lessonId) async {
    final LearningLesson? lesson = lessonById(lessonId);
    if (lesson == null || isLessonCompleted(lessonId)) {
      return 0;
    }
    final int before = _state.xp;
    _state = _state.completeLesson(lessonId, lesson.steps.length, now: now);
    await _mirrorLegacy(lessonId, score: 100, incrementAttempts: true);
    notifyListeners();
    await _saveState();
    return _state.xp - before;
  }

  Future<void> saveOnboardingSeen() async {
    if (_state.onboardingSeen) {
      return;
    }
    _state = _state.markOnboardingSeen();
    notifyListeners();
    await _saveState();
  }

  /// Legacy entry point used by the challenge editor.
  Future<void> markCompleted(String itemId, {int score = 0}) async {
    final LearningChallenge? challenge = challengeById(itemId);
    if (challenge != null) {
      final bool isNew = !_state.isChallengeCompleted(itemId);
      if (isNew) {
        _state = _state.completeChallenge(itemId, now: now);
        if (challenge.concepts.isNotEmpty) {
          _state = _state.recordAnswer(
            conceptIds: challenge.concepts,
            correct: true,
            usedHint: false,
            now: now,
            xpOverride: 0,
          );
        }
      }
      await _mirrorLegacy(
        itemId,
        score: score > 0 ? score : 100,
        incrementAttempts: true,
      );
      notifyListeners();
      await _saveState();
      return;
    }
    final LearningLesson? lesson = lessonById(itemId);
    if (lesson != null) {
      await completeLesson(itemId);
      return;
    }
    // Unknown legacy ids are still shown as completed in the old data views.
    _items = <String, LearningProgress>{
      ..._items,
      itemId: LearningProgress(
        itemId: itemId,
        completed: true,
        bestScore: score,
        attempts: (_items[itemId]?.attempts ?? 0) + 1,
        updatedAt: now,
      ),
    };
    await _repository.upsert(_items[itemId]!);
    notifyListeners();
  }

  Future<void> recordAttempt(
    String itemId, {
    required bool passed,
    int score = 0,
  }) async {
    if (passed) {
      await markCompleted(itemId, score: score);
      return;
    }
    final LearningChallenge? challenge = challengeById(itemId);
    if (challenge != null && challenge.concepts.isNotEmpty) {
      _state = _state.recordAnswer(
        conceptIds: challenge.concepts,
        correct: false,
        usedHint: false,
        now: now,
      );
      await _saveState();
    }
    final LearningProgress? existing = _items[itemId];
    final LearningProgress updated = LearningProgress(
      itemId: itemId,
      completed: existing?.completed ?? false,
      bestScore: (existing?.bestScore ?? 0) > score
          ? existing!.bestScore
          : score,
      attempts: (existing?.attempts ?? 0) + 1,
      updatedAt: now,
    );
    _items = <String, LearningProgress>{..._items, itemId: updated};
    notifyListeners();
    await _repository.upsert(updated);
  }

  Future<void> _mirrorLegacy(
    String itemId, {
    required int score,
    bool incrementAttempts = false,
  }) async {
    final LearningProgress? existing = _items[itemId];
    final LearningProgress updated = LearningProgress(
      itemId: itemId,
      completed: true,
      bestScore: (existing?.bestScore ?? 0) > score
          ? existing!.bestScore
          : score,
      attempts: (existing?.attempts ?? 0) + (incrementAttempts ? 1 : 0),
      updatedAt: now,
    );
    _items = <String, LearningProgress>{..._items, itemId: updated};
    await _repository.upsert(updated);
  }

  LearningState exportState() => _state;

  Future<void> restoreState(LearningState state) async {
    _state = state;
    _mergeStateIntoItems();
    notifyListeners();
    await _saveState();
  }

  Future<void> resetAll() async {
    _items = <String, LearningProgress>{};
    _state = const LearningState();
    notifyListeners();
    await _repository.deleteAll();
    await _stateRepository.clear();
  }

  /// Restores legacy completion rows, then rebuilds the learning snapshot from
  /// them. A backup that also carries a full snapshot calls [restoreState]
  /// afterwards, so XP and review scheduling are preserved too.
  Future<void> restoreAll(List<LearningProgress> items) async {
    await _repository.replaceAll(items);
    _items = <String, LearningProgress>{
      for (final LearningProgress item in items) item.itemId: item,
    };
    _state = _seedFrom(items);
    _mergeStateIntoItems();
    notifyListeners();
    await _saveState();
  }

  Future<void> flush() => _writeQueue;

  Future<void> _saveState() {
    final LearningState snapshot = _state;
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _stateRepository.save(snapshot);
      } catch (error) {
        debugPrint('Could not persist learning state: $error');
      }
    });
    return _writeQueue;
  }
}
