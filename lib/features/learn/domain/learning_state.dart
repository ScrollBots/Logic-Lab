import 'package:flutter/foundation.dart';

/// Mastery of one concept, measured from real exercise answers.
///
/// The model is deliberately transparent: mastery is the ratio of correct
/// answers and the review interval doubles after every correct answer. No
/// hidden model decides what the learner sees.
@immutable
class ConceptMastery {
  const ConceptMastery({
    this.attempts = 0,
    this.correct = 0,
    this.intervalDays = 0,
    this.lastPracticed,
    this.dueAt,
  });

  final int attempts;
  final int correct;
  final int intervalDays;
  final DateTime? lastPracticed;
  final DateTime? dueAt;

  int get mastery => attempts == 0 ? 0 : ((correct * 100) / attempts).round();

  bool isDue(DateTime now) {
    if (attempts == 0) {
      return false;
    }
    final DateTime? due = dueAt;
    return due == null || !due.isAfter(now);
  }

  bool needsPractice(DateTime now) =>
      isDue(now) || (attempts >= 2 && mastery < 60);

  ConceptMastery record({required bool correctAnswer, required DateTime now}) {
    final int nextInterval;
    final DateTime nextDue;
    if (correctAnswer) {
      nextInterval = intervalDays <= 0 ? 3 : (intervalDays * 2).clamp(3, 21);
      nextDue = now.add(Duration(days: nextInterval));
    } else {
      nextInterval = 1;
      // A wrong answer is reviewable immediately, so the learner can practise
      // the concept again in the same day instead of waiting.
      nextDue = now;
    }
    return ConceptMastery(
      attempts: attempts + 1,
      correct: correct + (correctAnswer ? 1 : 0),
      intervalDays: nextInterval,
      lastPracticed: now,
      dueAt: nextDue,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'attempts': attempts,
    'correct': correct,
    'intervalDays': intervalDays,
    'lastPracticed': lastPracticed?.toUtc().toIso8601String(),
    'dueAt': dueAt?.toUtc().toIso8601String(),
  };

  factory ConceptMastery.fromJson(Object? raw) {
    if (raw is! Map) {
      return const ConceptMastery();
    }
    return ConceptMastery(
      attempts: _readCount(raw['attempts']),
      correct: _readCount(raw['correct']),
      intervalDays: _readCount(raw['intervalDays']),
      lastPracticed: _readDate(raw['lastPracticed']),
      dueAt: _readDate(raw['dueAt']),
    );
  }
}

/// Everything the learning experience needs to remember between sessions.
@immutable
class LearningState {
  const LearningState({
    this.xp = 0,
    this.dailyGoalXp = 40,
    this.xpToday = 0,
    this.streakDays = 0,
    this.bestStreak = 0,
    this.lastActiveDay,
    this.concepts = const <String, ConceptMastery>{},
    this.completedLessons = const <String>{},
    this.completedChallenges = const <String>{},
    this.stepProgress = const <String, List<int>>{},
    this.lastLessonId,
    this.onboardingSeen = false,
  });

  final int xp;
  final int dailyGoalXp;
  final int xpToday;
  final int streakDays;
  final int bestStreak;

  /// Local calendar day (`yyyy-mm-dd`) of the last XP-earning activity.
  final String? lastActiveDay;
  final Map<String, ConceptMastery> concepts;
  final Set<String> completedLessons;
  final Set<String> completedChallenges;
  final Map<String, List<int>> stepProgress;
  final String? lastLessonId;
  final bool onboardingSeen;

  bool get hasActivity => xp > 0;

  int get level => xp ~/ 120 + 1;

  double get levelProgress {
    final int remainder = xp % 120;
    return remainder / 120;
  }

  int xpOn(DateTime now) => lastActiveDay == dayKey(now) ? xpToday : 0;

  /// The streak is only current when the last activity happened today or
  /// yesterday. An older entry is kept in history but is not advertised as a
  /// live streak, and nothing is lost or punished.
  int streakOn(DateTime now) {
    final String? last = lastActiveDay;
    if (last == null) {
      return 0;
    }
    final String today = dayKey(now);
    if (last == today) {
      return streakDays;
    }
    if (last == dayKey(now.subtract(const Duration(days: 1)))) {
      return streakDays;
    }
    return 0;
  }

  bool isLessonCompleted(String lessonId) =>
      completedLessons.contains(lessonId);

  bool isChallengeCompleted(String challengeId) =>
      completedChallenges.contains(challengeId);

  Set<int> stepsDone(String lessonId) =>
      (stepProgress[lessonId] ?? const <int>[]).toSet();

  LearningState copyWith({
    int? xp,
    int? dailyGoalXp,
    int? xpToday,
    int? streakDays,
    int? bestStreak,
    String? lastActiveDay,
    Map<String, ConceptMastery>? concepts,
    Set<String>? completedLessons,
    Set<String>? completedChallenges,
    Map<String, List<int>>? stepProgress,
    String? lastLessonId,
    bool? onboardingSeen,
  }) {
    return LearningState(
      xp: xp ?? this.xp,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      xpToday: xpToday ?? this.xpToday,
      streakDays: streakDays ?? this.streakDays,
      bestStreak: bestStreak ?? this.bestStreak,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      concepts: concepts ?? this.concepts,
      completedLessons: completedLessons ?? this.completedLessons,
      completedChallenges: completedChallenges ?? this.completedChallenges,
      stepProgress: stepProgress ?? this.stepProgress,
      lastLessonId: lastLessonId ?? this.lastLessonId,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    );
  }

  LearningState recordAnswer({
    required List<String> conceptIds,
    required bool correct,
    required bool usedHint,
    required DateTime now,
    int xpOverride = -1,
  }) {
    final int gain =
        correct ? (xpOverride >= 0 ? xpOverride : (usedHint ? 4 : 10)) : 0;
    final Map<String, ConceptMastery> updatedConcepts = {...concepts};
    for (final String concept in conceptIds) {
      final ConceptMastery current =
          updatedConcepts[concept] ?? const ConceptMastery();
      updatedConcepts[concept] = current.record(
        correctAnswer: correct,
        now: now,
      );
    }
    final LearningState withConcepts = copyWith(concepts: updatedConcepts);
    return gain > 0 ? withConcepts._awardXp(gain, now) : withConcepts;
  }

  LearningState _awardXp(int gain, DateTime now) {
    final String today = dayKey(now);
    final String yesterday = dayKey(now.subtract(const Duration(days: 1)));
    final bool newDay = lastActiveDay != today;
    final int nextStreak;
    if (!newDay) {
      nextStreak = streakDays;
    } else if (lastActiveDay == yesterday) {
      nextStreak = streakDays + 1;
    } else {
      nextStreak = 1;
    }
    return copyWith(
      xp: xp + gain,
      xpToday: newDay ? gain : xpToday + gain,
      streakDays: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      lastActiveDay: today,
    );
  }

  LearningState markStepDone(String lessonId, int stepIndex, int stepCount) {
    final Set<int> done = stepsDone(lessonId)..add(stepIndex);
    return copyWith(
      stepProgress: <String, List<int>>{
        ...stepProgress,
        lessonId: done.toList()..sort(),
      },
    );
  }

  LearningState completeLesson(
    String lessonId,
    int stepCount, {
    required DateTime now,
    int bonusXp = 20,
  }) {
    if (completedLessons.contains(lessonId)) {
      return this;
    }
    final LearningState next = copyWith(
      completedLessons: <String>{...completedLessons, lessonId},
      stepProgress: <String, List<int>>{
        ...stepProgress,
        lessonId: List<int>.generate(stepCount, (int index) => index),
      },
      lastLessonId: lessonId,
    );
    return next._awardXp(bonusXp, now);
  }

  LearningState completeChallenge(
    String challengeId, {
    required DateTime now,
    int bonusXp = 15,
  }) {
    if (completedChallenges.contains(challengeId)) {
      return this;
    }
    final LearningState next = copyWith(
      completedChallenges: <String>{...completedChallenges, challengeId},
    );
    return next._awardXp(bonusXp, now);
  }

  LearningState markOnboardingSeen() =>
      onboardingSeen ? this : copyWith(onboardingSeen: true);

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'xp': xp,
    'dailyGoalXp': dailyGoalXp,
    'xpToday': xpToday,
    'streakDays': streakDays,
    'bestStreak': bestStreak,
    'lastActiveDay': lastActiveDay,
    'concepts': concepts.map(
      (String key, ConceptMastery value) =>
          MapEntry<String, Object?>(key, value.toJson()),
    ),
    'completedLessons': completedLessons.toList()..sort(),
    'completedChallenges': completedChallenges.toList()..sort(),
    'stepProgress': stepProgress.map(
      (String key, List<int> value) =>
          MapEntry<String, Object?>(key, value.toList()..sort()),
    ),
    'lastLessonId': lastLessonId,
    'onboardingSeen': onboardingSeen,
  };

  factory LearningState.fromJson(Object? raw) {
    if (raw is! Map) {
      return const LearningState();
    }
    final Map<String, ConceptMastery> concepts = <String, ConceptMastery>{};
    final Object? rawConcepts = raw['concepts'];
    if (rawConcepts is Map) {
      for (final MapEntry<Object?, Object?> entry in rawConcepts.entries) {
        final Object? key = entry.key;
        if (key is String && key.isNotEmpty) {
          concepts[key] = ConceptMastery.fromJson(entry.value);
        }
      }
    }
    final Map<String, List<int>> stepProgress = <String, List<int>>{};
    final Object? rawSteps = raw['stepProgress'];
    if (rawSteps is Map) {
      for (final MapEntry<Object?, Object?> entry in rawSteps.entries) {
        final Object? key = entry.key;
        final Object? value = entry.value;
        if (key is String && value is List) {
          final List<int> steps = <int>[
            for (final Object? step in value)
              if (step is num && step.isFinite && step >= 0) step.toInt(),
          ]..sort();
          if (steps.isNotEmpty) {
            stepProgress[key] = steps;
          }
        }
      }
    }
    return LearningState(
      xp: _readCount(raw['xp']),
      dailyGoalXp: _readCount(raw['dailyGoalXp'], fallback: 40),
      xpToday: _readCount(raw['xpToday']),
      streakDays: _readCount(raw['streakDays']),
      bestStreak: _readCount(raw['bestStreak']),
      lastActiveDay:
          raw['lastActiveDay'] is String
              ? raw['lastActiveDay']! as String
              : null,
      concepts: concepts,
      completedLessons: _readStringSet(raw['completedLessons']),
      completedChallenges: _readStringSet(raw['completedChallenges']),
      stepProgress: stepProgress,
      lastLessonId:
          raw['lastLessonId'] is String ? raw['lastLessonId']! as String : null,
      onboardingSeen: raw['onboardingSeen'] == true,
    );
  }
}

String dayKey(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Set<String> _readStringSet(Object? raw) {
  if (raw is! List) {
    return <String>{};
  }
  return <String>{
    for (final Object? item in raw)
      if (item is String && item.trim().isNotEmpty) item,
  };
}

int _readCount(Object? value, {int fallback = 0}) {
  if (value is! num || !value.isFinite || value < 0) {
    return fallback;
  }
  return value.toInt();
}

DateTime? _readDate(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}
