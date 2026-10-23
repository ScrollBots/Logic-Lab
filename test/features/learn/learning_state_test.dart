import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/learn/domain/learning_state.dart';

void main() {
  final DateTime day = DateTime(2026, 3, 10, 9);

  group('Concept mastery', () {
    test('correct answers double the review interval up to the cap', () {
      ConceptMastery mastery = const ConceptMastery();

      mastery = mastery.record(correctAnswer: true, now: day);
      expect(mastery.attempts, 1);
      expect(mastery.correct, 1);
      expect(mastery.mastery, 100);
      expect(mastery.intervalDays, 3);
      expect(mastery.lastPracticed, day);
      expect(mastery.dueAt, day.add(const Duration(days: 3)));

      mastery = mastery.record(correctAnswer: true, now: day);
      expect(mastery.intervalDays, 6);
      mastery = mastery.record(correctAnswer: true, now: day);
      expect(mastery.intervalDays, 12);
      mastery = mastery.record(correctAnswer: true, now: day);
      expect(mastery.intervalDays, 21);
      mastery = mastery.record(correctAnswer: true, now: day);
      expect(mastery.intervalDays, 21);
    });

    test('a wrong answer schedules an immediate review', () {
      final ConceptMastery mastery = ConceptMastery(
        attempts: 3,
        correct: 3,
        intervalDays: 6,
        lastPracticed: day,
        dueAt: day.add(const Duration(days: 6)),
      );

      final ConceptMastery next = mastery.record(
        correctAnswer: false,
        now: day,
      );
      expect(next.attempts, 4);
      expect(next.correct, 3);
      expect(next.mastery, 75);
      expect(next.intervalDays, 1);
      expect(next.dueAt, day);
      expect(next.needsPractice(day), isTrue);
    });

    test('a fresh concept is neither due nor practised', () {
      const ConceptMastery mastery = ConceptMastery();
      expect(mastery.mastery, 0);
      expect(mastery.isDue(day), isFalse);
      expect(mastery.needsPractice(day), isFalse);
    });

    test('a scheduled review is due on its due date', () {
      final ConceptMastery mastery = ConceptMastery(
        attempts: 1,
        correct: 1,
        intervalDays: 3,
        dueAt: day.add(const Duration(days: 3)),
      );
      expect(mastery.isDue(day.add(const Duration(days: 2))), isFalse);
      expect(mastery.isDue(day.add(const Duration(days: 3))), isTrue);
      expect(mastery.needsPractice(day), isFalse);
    });

    test('low mastery after repeated attempts needs practice', () {
      final ConceptMastery mastery = ConceptMastery(
        attempts: 3,
        correct: 1,
        intervalDays: 12,
        dueAt: day.add(const Duration(days: 30)),
      );
      expect(mastery.isDue(day), isFalse);
      expect(mastery.needsPractice(day), isTrue);
    });
  });

  group('XP, daily goal and streak', () {
    test('answers earn XP and build a streak across days', () {
      LearningState state = const LearningState();

      state = state.recordAnswer(
        conceptIds: const <String>['and'],
        correct: true,
        usedHint: false,
        now: day,
      );
      expect(state.xp, 10);
      expect(state.xpToday, 10);
      expect(state.streakDays, 1);
      expect(state.bestStreak, 1);
      expect(state.xpOn(day), 10);
      expect(state.concepts['and']!.attempts, 1);

      state = state.recordAnswer(
        conceptIds: const <String>['and'],
        correct: true,
        usedHint: true,
        now: day.add(const Duration(hours: 1)),
      );
      expect(state.xp, 14);
      expect(state.xpToday, 14);
      expect(state.streakDays, 1);

      state = state.recordAnswer(
        conceptIds: const <String>['and'],
        correct: false,
        usedHint: false,
        now: day.add(const Duration(hours: 2)),
      );
      expect(state.xp, 14);
      expect(state.concepts['and']!.attempts, 3);

      final LearningState nextDay = state.recordAnswer(
        conceptIds: const <String>['or'],
        correct: true,
        usedHint: false,
        now: day.add(const Duration(days: 1)),
      );
      expect(nextDay.xp, 24);
      expect(nextDay.xpToday, 10);
      expect(nextDay.streakDays, 2);
      expect(nextDay.bestStreak, 2);

      final LearningState afterGap = nextDay.recordAnswer(
        conceptIds: const <String>['or'],
        correct: true,
        usedHint: false,
        now: day.add(const Duration(days: 4)),
      );
      expect(afterGap.xp, 34);
      expect(afterGap.xpToday, 10);
      expect(afterGap.streakDays, 1);
      expect(afterGap.bestStreak, 2);
      expect(afterGap.streakOn(day.add(const Duration(days: 5))), 1);
      expect(afterGap.streakOn(day.add(const Duration(days: 6))), 0);
      expect(afterGap.xpOn(day.add(const Duration(days: 6))), 0);
    });

    test('an XP override replaces the default award', () {
      final LearningState state = const LearningState().recordAnswer(
        conceptIds: const <String>['and'],
        correct: true,
        usedHint: false,
        now: day,
        xpOverride: 0,
      );
      expect(state.xp, 0);
      expect(state.concepts['and']!.attempts, 1);
      expect(state.xpToday, 0);
    });

    test('level advances every 120 XP', () {
      expect(const LearningState().level, 1);
      expect(const LearningState(xp: 119).level, 1);
      expect(const LearningState(xp: 120).level, 2);
      expect(const LearningState(xp: 250).level, 3);
      expect(
        const LearningState(xp: 250).levelProgress,
        closeTo(10 / 120, 1e-9),
      );
    });
  });

  group('Lesson and challenge progress', () {
    test('completed lessons award their bonus once and fill every step', () {
      LearningState state = const LearningState();
      state = state.markStepDone('lesson_signals', 2, 4);
      state = state.markStepDone('lesson_signals', 0, 4);
      state = state.markStepDone('lesson_signals', 0, 4);
      expect(state.stepsDone('lesson_signals'), <int>{0, 2});

      state = state.markStepDone('lesson_signals', 1, 4);
      state = state.completeLesson('lesson_signals', 4, now: day);
      expect(state.isLessonCompleted('lesson_signals'), isTrue);
      expect(state.stepsDone('lesson_signals'), <int>{0, 1, 2, 3});
      expect(state.xp, 20);
      expect(state.lastLessonId, 'lesson_signals');

      final LearningState repeated = state.completeLesson(
        'lesson_signals',
        4,
        now: day,
      );
      expect(repeated.xp, 20);
      expect(identical(repeated, state), isTrue);
    });

    test('challenge completion awards its bonus once', () {
      final LearningState state = const LearningState().completeChallenge(
        'challenge_and',
        now: day,
      );
      expect(state.isChallengeCompleted('challenge_and'), isTrue);
      expect(state.xp, 15);
      expect(state.completeChallenge('challenge_and', now: day).xp, 15);
    });

    test('onboarding is remembered', () {
      final LearningState seen = const LearningState().markOnboardingSeen();
      expect(seen.onboardingSeen, isTrue);
      expect(identical(seen.markOnboardingSeen(), seen), isTrue);
    });
  });

  group('Serialization', () {
    test('state survives a JSON round trip', () {
      final LearningState state =
          const LearningState()
              .recordAnswer(
                conceptIds: const <String>['and'],
                correct: true,
                usedHint: false,
                now: day,
              )
              .completeLesson('lesson_and', 4, now: day)
              .completeChallenge('challenge_and', now: day)
              .markOnboardingSeen();

      final LearningState restored = LearningState.fromJson(
        jsonDecode(jsonEncode(state.toJson())),
      );

      expect(restored.xp, state.xp);
      expect(restored.dailyGoalXp, state.dailyGoalXp);
      expect(restored.xpToday, state.xpToday);
      expect(restored.streakDays, state.streakDays);
      expect(restored.bestStreak, state.bestStreak);
      expect(restored.lastActiveDay, state.lastActiveDay);
      expect(restored.completedLessons, state.completedLessons);
      expect(restored.completedChallenges, state.completedChallenges);
      expect(restored.stepProgress, state.stepProgress);
      expect(restored.lastLessonId, state.lastLessonId);
      expect(restored.onboardingSeen, isTrue);
      expect(restored.concepts['and']!.attempts, 1);
      expect(restored.concepts['and']!.correct, 1);
      expect(restored.concepts['and']!.intervalDays, 3);
      expect(restored.concepts['and']!.dueAt, isNotNull);
    });

    test('tolerant decoding keeps valid rows and ignores garbage', () {
      final LearningState state = LearningState.fromJson(<String, Object?>{
        'xp': -5,
        'dailyGoalXp': 'many',
        'xpToday': 3.7,
        'streakDays': 2,
        'lastActiveDay': 42,
        'concepts': <String, Object?>{
          'and': <String, Object?>{'attempts': 2, 'correct': 1},
          'broken': 'nope',
          '': <String, Object?>{'attempts': 9},
        },
        'completedLessons': <Object?>['lesson_and', 42, '', 'lesson_or'],
        'completedChallenges': 'challenge_and',
        'stepProgress': <String, Object?>{
          'lesson_and': <Object?>[2, -1, 'x', 0, 2],
          'bad': 'nope',
        },
        'lastLessonId': 3,
        'onboardingSeen': 'yes',
      });

      expect(state.xp, 0);
      expect(state.dailyGoalXp, 40);
      expect(state.xpToday, 3);
      expect(state.streakDays, 2);
      expect(state.lastActiveDay, isNull);
      expect(state.concepts.keys, containsAll(<String>['and', 'broken']));
      expect(state.concepts.containsKey(''), isFalse);
      expect(state.concepts['and']!.attempts, 2);
      expect(state.concepts['broken']!.attempts, 0);
      expect(state.completedLessons, <String>{'lesson_and', 'lesson_or'});
      expect(state.completedChallenges, isEmpty);
      expect(state.stepsDone('lesson_and'), <int>{0, 2});
      expect(state.stepProgress.containsKey('bad'), isFalse);
      expect(state.lastLessonId, isNull);
      expect(state.onboardingSeen, isFalse);

      expect(LearningState.fromJson('nope').xp, 0);
      expect(ConceptMastery.fromJson(42).attempts, 0);
    });

    test('day keys are stable local calendar strings', () {
      expect(dayKey(DateTime(2026, 3, 10)), '2026-03-10');
      expect(dayKey(DateTime(2026, 12, 1)), '2026-12-01');
    });
  });
}
