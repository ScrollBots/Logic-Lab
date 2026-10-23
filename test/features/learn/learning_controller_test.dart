import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/learn/application/learning_controller.dart';
import 'package:logic_lab/features/learn/data/learning_progress_repository.dart';
import 'package:logic_lab/features/learn/data/learning_state_repository.dart';
import 'package:logic_lab/features/learn/domain/curriculum.dart';
import 'package:logic_lab/features/learn/domain/learning_state.dart';
import 'package:logic_lab/features/learn/domain/lesson_models.dart';

/// Builds a controller with an in-memory state snapshot and a fixed clock so
/// streaks and review dates are deterministic.
LearningController _controller({
  LearningProgressRepository? progress,
  LearningStateRepository? state,
  DateTime Function()? clock,
}) {
  return LearningController(
    progress ?? MemoryLearningProgressRepository(),
    stateRepository: state ?? MemoryLearningStateRepository(),
    clock: clock,
  );
}

LearningProgress _legacy(String itemId, DateTime at) {
  return LearningProgress(
    itemId: itemId,
    completed: true,
    bestScore: 100,
    attempts: 1,
    updatedAt: at,
  );
}

void main() {
  final DateTime now = DateTime(2026, 3, 10, 10);

  group('Loading and legacy migration', () {
    test('legacy completion rows are re-seeded into the snapshot', () async {
      final LearningController learning = _controller(
        progress: MemoryLearningProgressRepository(<LearningProgress>[
          _legacy('lesson_signals', now),
          _legacy('challenge_buffer', now),
          LearningProgress(
            itemId: 'lesson_and',
            completed: false,
            bestScore: 40,
            attempts: 2,
            updatedAt: now,
          ),
        ]),
        clock: () => now,
      );

      await learning.load();

      expect(learning.isLoading, isFalse);
      expect(learning.isLessonCompleted('lesson_signals'), isTrue);
      expect(
        learning.state.stepsDone('lesson_signals').length,
        kLessonById['lesson_signals']!.steps.length,
      );
      expect(learning.isCompleted('challenge_buffer'), isTrue);
      expect(learning.isLessonCompleted('lesson_and'), isFalse);
      expect(learning.completedCount, 2);
      expect(learning.nextLesson?.id, 'lesson_wiring');
    });

    test('an unknown legacy id is still reported as completed', () async {
      final LearningController learning = _controller(clock: () => now);
      await learning.load();

      await learning.markCompleted('legacy_item');

      expect(learning.isCompleted('legacy_item'), isTrue);
      expect(learning.items['legacy_item']?.completed, isTrue);
    });
  });

  group('Persistence', () {
    test('XP, lesson completion and mastery survive a restart', () async {
      final MemoryLearningStateRepository state =
          MemoryLearningStateRepository();
      final LearningController first = _controller(
        state: state,
        clock: () => now,
      );
      await first.load();

      expect(
        await first.recordAnswer(
          conceptIds: const <String>['and'],
          correct: true,
          usedHint: false,
        ),
        10,
      );
      await first.markStepDone('lesson_signals', 0);
      expect(await first.completeLesson('lesson_signals'), 20);
      expect(await first.completeLesson('lesson_signals'), 0);
      await first.saveOnboardingSeen();
      await first.flush();

      final LearningController second = _controller(
        state: state,
        clock: () => now,
      );
      await second.load();

      expect(second.xp, 30);
      expect(second.isLessonCompleted('lesson_signals'), isTrue);
      expect(
        second.state.stepsDone('lesson_signals').length,
        kLessonById['lesson_signals']!.steps.length,
      );
      expect(second.masteryFor('and').attempts, 1);
      expect(second.state.onboardingSeen, isTrue);
    });

    test('reset clears both the snapshot and the legacy rows', () async {
      final MemoryLearningProgressRepository progress =
          MemoryLearningProgressRepository(<LearningProgress>[
            _legacy('lesson_signals', now),
          ]);
      final MemoryLearningStateRepository state =
          MemoryLearningStateRepository();
      final LearningController learning = _controller(
        progress: progress,
        state: state,
        clock: () => now,
      );
      await learning.load();
      expect(learning.isLessonCompleted('lesson_signals'), isTrue);

      await learning.resetAll();

      expect(learning.xp, 0);
      expect(learning.isCompleted('lesson_signals'), isFalse);
      expect(learning.state.completedLessons, isEmpty);
      expect(await state.load(), isNull);
      expect(await progress.loadAll(), isEmpty);
    });
  });

  group('Path and unlocking', () {
    test('a lesson unlocks only after its predecessor is completed', () async {
      final LearningController learning = _controller(clock: () => now);
      await learning.load();

      expect(learning.canOpenLesson('lesson_signals'), isTrue);
      expect(learning.canOpenLesson('lesson_wiring'), isFalse);
      expect(learning.canOpenLesson('lesson_and'), isFalse);

      await learning.completeLesson('lesson_signals');

      expect(learning.canOpenLesson('lesson_wiring'), isTrue);
      expect(learning.canOpenLesson('lesson_and'), isFalse);
      expect(learning.nextLesson?.id, 'lesson_wiring');
      expect(learning.currentUnit?.id, 'unit_basics');
      expect(learning.lessonProgress(kLessonById['lesson_signals']!), 1);
    });

    test('resume starts at the first unfinished step', () async {
      final LearningController learning = _controller(clock: () => now);
      await learning.load();
      final LearningLesson lesson = kLessonById['lesson_signals']!;

      expect(learning.resumeStepIndex(lesson), 0);
      await learning.markStepDone(lesson.id, 0);
      await learning.markStepDone(lesson.id, 1);
      expect(learning.resumeStepIndex(lesson), 2);

      for (int index = 2; index < lesson.steps.length; index++) {
        await learning.markStepDone(lesson.id, index);
      }
      // Every step is done but the lesson was never closed: resume on the last
      // step so the summary and its bonus can still be earned.
      expect(learning.resumeStepIndex(lesson), lesson.steps.length - 1);

      await learning.completeLesson(lesson.id);
      expect(learning.resumeStepIndex(lesson), 0);
    });
  });

  group('Mastery and review', () {
    test('wrong answers make concepts due for review immediately', () async {
      final LearningController learning = _controller(clock: () => now);
      await learning.load();

      for (final String concept in <String>[
        'and',
        'or',
        'not',
        'xor',
        'buffer',
      ]) {
        await learning.recordAnswer(
          conceptIds: <String>[concept],
          correct: false,
          usedHint: false,
        );
      }

      expect(learning.reviewConceptIds.length, 4);
      expect(
        learning.reviewConceptIds.every(
          (String id) => learning.masteryFor(id).needsPractice(now),
        ),
        isTrue,
      );
      expect(learning.practicedConceptCount, 5);
      expect(learning.masteredConceptCount, 0);
    });

    test('solid mastery removes a concept from the review queue', () async {
      final LearningController learning = _controller(clock: () => now);
      await learning.load();

      await learning.recordAnswer(
        conceptIds: const <String>['and'],
        correct: false,
        usedHint: false,
      );
      await learning.recordAnswer(
        conceptIds: const <String>['and'],
        correct: true,
        usedHint: false,
      );
      await learning.recordAnswer(
        conceptIds: const <String>['and'],
        correct: true,
        usedHint: false,
      );

      final ConceptMastery mastery = learning.masteryFor('and');
      expect(mastery.attempts, 3);
      expect(mastery.correct, 2);
      expect(mastery.isDue(now), isFalse);
      expect(mastery.needsPractice(now), isFalse);
      expect(learning.reviewConceptIds, isNot(contains('and')));
      expect(learning.masteredConceptCount, 0);
    });

    test('challenge completion also records its concepts', () async {
      final LearningController learning = _controller(clock: () => now);
      await learning.load();

      await learning.markCompleted('challenge_and');

      expect(learning.isCompleted('challenge_and'), isTrue);
      expect(learning.xp, 15);
      expect(learning.masteryFor('and').attempts, 1);
      expect(learning.masteryFor('and').correct, 1);

      await learning.markCompleted('challenge_and');
      expect(learning.xp, 15);
      expect(learning.masteryFor('and').attempts, 1);
    });

    test(
      'a failed attempt is recorded without completing a challenge',
      () async {
        final LearningController learning = _controller(clock: () => now);
        await learning.load();

        await learning.recordAttempt('challenge_and', passed: false, score: 25);

        expect(learning.isCompleted('challenge_and'), isFalse);
        expect(learning.masteryFor('and').attempts, 1);
        expect(learning.masteryFor('and').correct, 0);
        expect(learning.items['challenge_and']?.attempts, 1);
        expect(learning.items['challenge_and']?.bestScore, 25);
      },
    );
  });

  group('Restore', () {
    test('a legacy backup is re-seeded and a full snapshot wins', () async {
      final LearningController learning = _controller(clock: () => now);
      await learning.load();

      await learning.restoreAll(<LearningProgress>[
        _legacy('lesson_signals', now),
        _legacy('challenge_and', now),
      ]);
      expect(learning.isLessonCompleted('lesson_signals'), isTrue);
      expect(learning.isCompleted('challenge_and'), isTrue);
      expect(learning.xp, 0);

      final LearningState snapshot = LearningState(
        xp: 240,
        streakDays: 4,
        bestStreak: 4,
        completedLessons: const <String>{'lesson_signals'},
        stepProgress: <String, List<int>>{
          'lesson_signals': <int>[0, 1, 2, 3],
        },
        concepts: <String, ConceptMastery>{
          'and': ConceptMastery(
            attempts: 3,
            correct: 3,
            intervalDays: 12,
            lastPracticed: now,
            dueAt: now.add(const Duration(days: 12)),
          ),
        },
        onboardingSeen: true,
      );
      await learning.restoreState(snapshot);

      expect(learning.xp, 240);
      expect(learning.level, 3);
      expect(learning.masteryFor('and').intervalDays, 12);
      expect(learning.state.onboardingSeen, isTrue);
      expect(learning.isCompleted('challenge_and'), isTrue);
    });
  });
}
