import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/learn/domain/curriculum.dart';
import 'package:logic_lab/features/learn/domain/learning_content.dart';
import 'package:logic_lab/features/learn/domain/lesson_models.dart';
import 'package:logic_lab/features/learn/domain/review_bank.dart';
import 'package:logic_lab/features/truth_table/domain/truth_table.dart';

/// The rows an exercise must produce, in the canonical 00, 01, 10, 11 order.
const Map<ComponentType, List<bool>> _gateTruthTables = {
  ComponentType.andGate: <bool>[false, false, false, true],
  ComponentType.orGate: <bool>[false, true, true, true],
  ComponentType.nandGate: <bool>[true, true, true, false],
  ComponentType.norGate: <bool>[true, false, false, false],
  ComponentType.xorGate: <bool>[false, true, true, false],
  ComponentType.xnorGate: <bool>[true, false, false, true],
  ComponentType.bufferGate: <bool>[false, true],
  ComponentType.notGate: <bool>[true, false],
};

void main() {
  group('Exercise evaluation', () {
    for (final MapEntry<ComponentType, List<bool>> entry
        in _gateTruthTables.entries) {
      test('${entry.key.technicalName} exercise matches the real simulator', () {
        final ExerciseCircuit circuit = gateExercise(entry.key);
        final List<bool?> rows = circuit.truthRows();

        expect(rows, isNot(contains(null)));
        expect(rows.whereType<bool>().toList(), entry.value);

        // The same circuit, evaluated by the truth table generator, must agree
        // with the exercise row for row.
        final TruthTableResult table = const TruthTableGenerator().generate(
          circuit.build(const <String, bool>{}),
        );
        final String outputKey = table.outputs.single.nodeId;
        expect(
          table.rows
              .map((TruthTableRow row) => row.outputs[outputKey])
              .toList(),
          rows,
          reason:
              '${entry.key.technicalName} exercises must not duplicate '
              'logic that the simulator already defines',
        );
      });
    }

    test('compound exercises simplify to their documented behaviour', () {
      final Map<ExerciseCircuit, List<bool?>> expected =
          <ExerciseCircuit, List<bool?>>{
            combiningExercise(): <bool?>[false, false, true, true],
            implicationExercise(): <bool?>[true, true, false, true],
            xnorFromGatesExercise(): <bool?>[true, false, false, true],
          };
      for (final MapEntry<ExerciseCircuit, List<bool?>> entry
          in expected.entries) {
        expect(entry.key.truthRows(), entry.value);
        final TruthTableResult table = const TruthTableGenerator().generate(
          entry.key.build(const <String, bool>{}),
        );
        expect(
          table.rows.map((TruthTableRow row) {
            return row.outputs[table.outputs.single.nodeId];
          }).toList(),
          entry.value,
        );
      }
    });

    test('row helpers follow the canonical A, B order', () {
      expect(ExerciseCircuit.rowLabel(0), 'A=0, B=0');
      expect(ExerciseCircuit.rowLabel(1), 'A=0, B=1');
      expect(ExerciseCircuit.rowLabel(2), 'A=1, B=0');
      expect(ExerciseCircuit.rowLabel(3), 'A=1, B=1');
      expect(ExerciseCircuit.rowLabel(1, labels: const <String>['X']), 'X=1');

      final ExerciseCircuit buffer = gateExercise(ComponentType.bufferGate);
      expect(buffer.valuesForRow(0), <String, bool>{'A': false});
      expect(buffer.valuesForRow(1), <String, bool>{'A': true});
    });

    test('gate expressions match the gate definitions', () {
      expect(expressionForGate(ComponentType.andGate), 'Y = A · B');
      expect(expressionForGate(ComponentType.orGate), 'Y = A + B');
      expect(expressionForGate(ComponentType.notGate), 'Y = ¬A');
      expect(expressionForGate(ComponentType.xorGate), 'Y = A ⊕ B');
      expect(expressionForGate(ComponentType.xnorGate), 'Y = A ⊙ B');
      expect(expressionForGate(ComponentType.bufferGate), 'Y = A');
    });
  });

  group('Step evaluation', () {
    test('a wrong prediction does not reveal the answer immediately', () {
      final PredictionStep step =
          kLessonById['lesson_signals']!.steps
              .whereType<PredictionStep>()
              .first;

      final StepEvaluation wrong = step.check(false);
      expect(wrong.correct, isFalse);
      expect(wrong.feedback, isNot(contains('درست است')));
      expect(wrong.correctLabel, '۱');
      expect(wrong.solution, step.explanation);

      expect(step.check(true).correct, isTrue);
    });

    test('a truth table reports the mismatched rows', () {
      final TruthTableStep step =
          kLessonById['lesson_and']!.steps.whereType<TruthTableStep>().first;

      expect(step.expectedRows(), <bool?>[false, false, false, true]);

      final StepEvaluation wrong = step.check(<bool?>[true, false, true, true]);
      expect(wrong.correct, isFalse);
      expect(wrong.mismatchRows, <int>[0, 2]);
      expect(wrong.solution, contains('جدول درست'));

      final StepEvaluation incomplete = step.check(<bool?>[false, false]);
      expect(incomplete.correct, isFalse);
      expect(incomplete.mismatchRows, <int>[2, 3]);

      expect(step.check(<bool?>[false, false, false, true]).correct, isTrue);
    });

    test('a wrong gate choice hides the correct gate name', () {
      final GateChoiceStep step =
          kLessonById['lesson_signals']!.steps
              .whereType<GateChoiceStep>()
              .first;

      final StepEvaluation wrong = step.check(ComponentType.andGate);
      expect(wrong.correct, isFalse);
      expect(wrong.feedback, isNot(contains(step.correct.persianName)));
      expect(wrong.correctLabel, step.correct.persianName);

      expect(step.check(ComponentType.bufferGate).correct, isTrue);
    });

    test('a wrong text choice hides the correct expression', () {
      final TextChoiceStep step =
          kLessonById['lesson_wiring']!.steps.whereType<TextChoiceStep>().first;
      final LessonOption wrongOption = step.options.firstWhere(
        (LessonOption option) => !option.correct,
      );

      final StepEvaluation wrong = step.check(wrongOption);
      expect(wrong.correct, isFalse);
      expect(wrong.feedback, isNot(contains(step.correctOption.text)));
      expect(wrong.correctLabel, step.correctOption.text);

      expect(step.check(step.correctOption).correct, isTrue);
    });
  });

  group('Curriculum integrity', () {
    test('every lesson is coherent and every exercise is simulatable', () {
      final Set<String> stepIds = <String>{};
      for (final LearningLesson lesson in kLessons) {
        expect(lesson.steps, isNotEmpty, reason: lesson.id);
        expect(lesson.minutes, greaterThan(0), reason: lesson.id);
        expect(
          lesson.steps.any((LessonStep step) => step is! ConceptStep),
          isTrue,
          reason: '${lesson.id} has no interactive step',
        );

        for (final LessonStep step in lesson.steps) {
          expect(
            stepIds.add(step.id),
            isTrue,
            reason: 'duplicate step id ${step.id}',
          );
          for (final String concept in step.concepts) {
            expect(
              kConceptLabels.containsKey(concept),
              isTrue,
              reason: 'unknown concept "$concept" in ${step.id}',
            );
          }
          for (final String hint in step.hints) {
            expect(hint.trim(), isNotEmpty, reason: step.id);
          }
          _expectExercisesEvaluate(step);
        }
      }
    });

    test('every build step points at a challenge the simulator can verify', () {
      for (final LearningLesson lesson in kLessons) {
        for (final BuildCircuitStep step
            in lesson.steps.whereType<BuildCircuitStep>()) {
          final LearningChallenge? maybeChallenge = challengeById(
            step.challengeId,
          );
          expect(
            maybeChallenge,
            isNotNull,
            reason: '${step.id} references ${step.challengeId}',
          );
          final LearningChallenge challenge = maybeChallenge!;
          expect(
            challenge.inputLabels.length,
            2,
            reason: 'the challenge validator requires exactly two inputs',
          );

          final int expectedOutputs =
              challenge.expectedOutputsByLabel?.length ??
              challenge.requiredOutputCount;
          expect(
            challenge.outputLabels.length,
            expectedOutputs,
            reason: challenge.id,
          );
          expect(challenge.expectedOutputs.length, 4, reason: challenge.id);
          for (final List<bool> rows
              in challenge.expectedOutputsByLabel?.values ??
                  const <List<bool>>[]) {
            expect(rows.length, 4, reason: challenge.id);
          }
        }
      }
    });

    test('the half adder challenge checks both outputs by label', () {
      final LearningChallenge challenge =
          kChallengeById['challenge_half_adder']!;
      expect(challenge.requiredOutputCount, 2);
      expect(challenge.outputLabels, <String>['S', 'C']);
      expect(challenge.expectedOutputsByLabel, <String, List<bool>>{
        'S': <bool>[false, true, true, false],
        'C': <bool>[false, false, false, true],
      });
    });
  });

  group('Sequential exercises', () {
    test('latches follow D while enabled and hold when closed', () {
      expect(dLatchTransparentExercise().states(), <bool?>[true, false]);
      expect(dLatchHoldExercise().states(), <bool?>[true, true, true]);
    });

    test('the SR latch sets and resets on level changes', () {
      expect(srLatchExercise().states(), <bool?>[true, false]);
    });

    test('the D flip-flop captures D on every rising edge', () {
      expect(dFlipFlopExercise().states(), <bool?>[true, false, true]);
    });

    test('the T flip-flop toggles on every edge', () {
      expect(tFlipFlopExercise().states(), <bool?>[true, false, true, false]);
    });

    test('counter bits divide the clock', () {
      expect(counterBitExercise(0).states(), <bool?>[true, false, true, false]);
      expect(counterBitExercise(1).states(), <bool?>[false, true, true, false]);
    });

    test('a wrong sequence reports only the mismatching steps', () {
      final SequenceStep step = SequenceStep(
        id: 'test_sequence',
        title: 'ترتیب',
        objective: 'مقدار Q را در هر لبه پیش‌بینی کنید.',
        explanation: 'در هر لبه Q برابر D همان لحظه می‌شود.',
        circuit: dFlipFlopExercise(),
      );
      final StepEvaluation wrong = step.check(<bool?>[true, false, false]);
      expect(wrong.correct, isFalse);
      expect(wrong.mismatchRows, <int>[2]);
      expect(wrong.feedback, contains('لبهٔ 3'));
      expect(wrong.feedback, isNot(contains('درست است')));
      expect(wrong.solution, contains('مقادیر درست'));

      final StepEvaluation right = step.check(<bool?>[true, false, true]);
      expect(right.correct, isTrue);
      expect(right.feedback, 'ترتیب مقادیر درست است.');
    });
  });

  group('Review bank', () {
    test('every review exercise evaluates without unknown values', () {
      for (final LessonStep step in kReviewBank) {
        _expectExercisesEvaluate(step);
      }
    });

    test('review exercises have unique ids and known concepts', () {
      final Set<String> ids = <String>{};
      for (final LessonStep step in kReviewBank) {
        expect(ids.add(step.id), isTrue, reason: step.id);
        expect(step.hints, isNotEmpty, reason: step.id);
        for (final String concept in step.concepts) {
          expect(kConceptLabels.containsKey(concept), isTrue, reason: step.id);
        }
      }
    });

    test('selection follows the struggling concepts without repeats', () {
      final List<LessonStep> steps = buildReviewSteps(<String>[
        'and',
      ], limit: 6);
      expect(steps.length, 6);
      expect(steps.first.id, 'review_and');
      expect(steps.first.concepts, contains('and'));
      expect(
        steps.map((LessonStep step) => step.id).toSet().length,
        steps.length,
      );
    });

    test('selection respects the limit and fills with related practice', () {
      final List<LessonStep> limited = buildReviewSteps(<String>[
        'comparator',
      ], limit: 4);
      expect(limited.length, 4);
      expect(limited.first.id, 'review_comparator');
      expect(
        limited.map((LessonStep step) => step.id).toSet().length,
        limited.length,
      );
    });
  });
}

void _expectExercisesEvaluate(LessonStep step) {
  switch (step) {
    case PredictionStep():
      expect(
        step.circuit.evaluate(step.inputs),
        isNotNull,
        reason: '${step.id} cannot be simulated',
      );
    case TruthTableStep():
      expect(step.expectedRows(), isNot(contains(null)), reason: step.id);
    case SequenceStep():
      expect(step.circuit.states(), isNot(contains(null)), reason: step.id);
    case GateChoiceStep():
      expect(step.behavior.truthRows(), isNot(contains(null)), reason: step.id);
    case TextChoiceStep():
      final ExerciseCircuit? behavior = step.behavior;
      if (behavior != null) {
        expect(behavior.truthRows(), isNot(contains(null)), reason: step.id);
      }
    case BuildCircuitStep():
      expect(challengeById(step.challengeId), isNotNull, reason: step.id);
    case ConceptStep():
      final ExerciseCircuit? circuit = step.circuit;
      if (circuit != null) {
        expect(circuit.truthRows(), isNot(contains(null)), reason: step.id);
      }
      final SequentialExercise? sequential = step.sequentialCircuit;
      if (sequential != null) {
        expect(sequential.states(), isNot(contains(null)), reason: step.id);
      }
  }
}
