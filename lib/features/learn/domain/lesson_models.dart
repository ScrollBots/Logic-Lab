import 'package:flutter/foundation.dart';

import '../../editor/domain/circuit_models.dart';
import '../../editor/domain/circuit_simulator.dart';

/// A small circuit whose behaviour is computed by the real simulator. Exercise
/// answers are never hard-coded twice: the expected value always comes from
/// [CircuitSimulator], so an exercise can never disagree with the editor.
///
/// Truth-table rows follow the canonical app order: `A=0,B=0`, `A=0,B=1`,
/// `A=1,B=0`, `A=1,B=1`.
@immutable
class ExerciseCircuit {
  const ExerciseCircuit({
    required this.expression,
    required this.inputLabels,
    required this.outputLabel,
    required this.outputNodeId,
    required this.build,
    this.gateType,
  });

  final String expression;
  final List<String> inputLabels;
  final String outputLabel;
  final String outputNodeId;
  final CircuitGraph Function(Map<String, bool> values) build;

  /// Present when the circuit is a single gate, so the UI can draw the
  /// standard schematic symbol instead of a generic preview.
  final ComponentType? gateType;

  bool? evaluate(Map<String, bool> values) {
    final CircuitGraph graph = build(values);
    final SimulationResult report = CircuitSimulator(graph).evaluate();
    if (report.hasErrors) {
      return null;
    }
    return report.signalOf(outputNodeId).booleanValue;
  }

  List<bool?> truthRows() {
    final List<bool?> rows = <bool?>[];
    final int count = inputLabels.length == 1 ? 2 : 4;
    for (int row = 0; row < count; row++) {
      rows.add(evaluate(valuesForRow(row)));
    }
    return rows;
  }

  Map<String, bool> valuesForRow(int row) {
    if (inputLabels.length == 1) {
      return <String, bool>{inputLabels.first: row == 1};
    }
    return <String, bool>{inputLabels[0]: row >= 2, inputLabels[1]: row.isOdd};
  }

  static String rowLabel(
    int row, {
    List<String> labels = const <String>['A', 'B'],
  }) {
    if (labels.length == 1) {
      return '${labels.first}=${row == 1 ? 1 : 0}';
    }
    return '${labels[0]}=${row >= 2 ? 1 : 0}, ${labels[1]}=${row.isOdd ? 1 : 0}';
  }
}

String expressionForGate(ComponentType type) {
  return switch (type) {
    ComponentType.andGate => 'Y = A · B',
    ComponentType.orGate => 'Y = A + B',
    ComponentType.notGate => 'Y = ¬A',
    ComponentType.nandGate => 'Y = ¬(A · B)',
    ComponentType.norGate => 'Y = ¬(A + B)',
    ComponentType.xorGate => 'Y = A ⊕ B',
    ComponentType.xnorGate => 'Y = A ⊙ B',
    ComponentType.bufferGate => 'Y = A',
    _ => 'Y = f(A, B)',
  };
}

/// Builds a two-input (or unary) gate exercise backed by a real graph.
ExerciseCircuit gateExercise(
  ComponentType type, {
  String? expression,
  int? inputCount,
}) {
  final bool unary =
      type == ComponentType.notGate || type == ComponentType.bufferGate;
  final int ports = inputCount ?? (unary ? 1 : 2);
  final List<String> labels = ports == 1
      ? const <String>['A']
      : const <String>['A', 'B'];
  return ExerciseCircuit(
    expression: expression ?? expressionForGate(type),
    inputLabels: labels,
    outputLabel: 'Y',
    outputNodeId: 'exercise-out',
    gateType: type,
    build: (Map<String, bool> values) {
      final List<CircuitNode> inputs = <CircuitNode>[
        for (int index = 0; index < labels.length; index++)
          CircuitNode(
            id: 'exercise-in-${labels[index].toLowerCase()}',
            type: ComponentType.inputPin,
            position: CanvasPoint(70, 120 + index * 130),
            label: labels[index],
            inputValue: values[labels[index]] ?? false,
          ),
      ];
      final CircuitNode gate = CircuitNode(
        id: 'exercise-gate',
        type: type,
        position: const CanvasPoint(310, 150),
        label: type.technicalName,
        inputCount: ports,
      );
      final CircuitNode output = CircuitNode(
        id: 'exercise-out',
        type: ComponentType.outputPin,
        position: const CanvasPoint(560, 150),
        label: 'Y',
      );
      return CircuitGraph(
        nodes: <CircuitNode>[...inputs, gate, output],
        wires: <CircuitWire>[
          for (int index = 0; index < inputs.length; index++)
            CircuitWire(
              id: 'exercise-wire-$index',
              fromNodeId: inputs[index].id,
              toNodeId: gate.id,
              toInputIndex: index,
            ),
          CircuitWire(
            id: 'exercise-wire-out',
            fromNodeId: gate.id,
            toNodeId: output.id,
            toInputIndex: 0,
          ),
        ],
      );
    },
  );
}

/// Builds a compound circuit from a compact description. Wiring mistakes throw
/// while the content is authored, which keeps the exercise bank honest.
CircuitGraph buildCompound({
  required List<ComponentType> gates,
  required List<(int from, int to, int input)> wires,
  Map<String, bool> values = const <String, bool>{},
  int inputCount = 2,
}) {
  final List<String> labels = inputCount == 1
      ? const <String>['A']
      : const <String>['A', 'B'];
  final List<CircuitNode> nodes = <CircuitNode>[
    for (int index = 0; index < labels.length; index++)
      CircuitNode(
        id: 'exercise-in-${labels[index].toLowerCase()}',
        type: ComponentType.inputPin,
        position: CanvasPoint(60, 110 + index * 130),
        label: labels[index],
        inputValue: values[labels[index]] ?? false,
      ),
    for (int index = 0; index < gates.length; index++)
      CircuitNode(
        id: 'exercise-g-$index',
        type: gates[index],
        position: CanvasPoint(
          250 + (index % 3) * 170,
          110 + (index ~/ 3) * 140,
        ),
        label: gates[index].technicalName,
      ),
    CircuitNode(
      id: 'exercise-out',
      type: ComponentType.outputPin,
      position: CanvasPoint(740, 180),
      label: 'Y',
    ),
  ];
  final List<String> ids = nodes.map((CircuitNode node) => node.id).toList();
  return CircuitGraph(
    nodes: nodes,
    wires: <CircuitWire>[
      for (int index = 0; index < wires.length; index++)
        CircuitWire(
          id: 'exercise-wire-$index',
          fromNodeId: ids[wires[index].$1],
          toNodeId: ids[wires[index].$2],
          toInputIndex: wires[index].$3,
        ),
    ],
  );
}

ExerciseCircuit compoundExercise({
  required String expression,
  required CircuitGraph Function(Map<String, bool> values) build,
  List<String> inputLabels = const <String>['A', 'B'],
}) {
  return ExerciseCircuit(
    expression: expression,
    inputLabels: inputLabels,
    outputLabel: 'Y',
    outputNodeId: 'exercise-out',
    build: build,
  );
}

/// `Y = A·B + A·B̅`, which simplifies to `Y = A`.
ExerciseCircuit combiningExercise() {
  return compoundExercise(
    expression: 'Y = A·B + A·B̅',
    build: (Map<String, bool> values) => buildCompound(
      values: values,
      gates: const <ComponentType>[
        ComponentType.notGate,
        ComponentType.andGate,
        ComponentType.andGate,
        ComponentType.orGate,
      ],
      wires: const <(int, int, int)>[
        (1, 2, 0),
        (0, 3, 0),
        (1, 3, 1),
        (0, 4, 0),
        (2, 4, 1),
        (3, 5, 0),
        (4, 5, 1),
        (5, 6, 0),
      ],
    ),
  );
}

/// `Y = ¬A + B`, the material implication `A → B`.
ExerciseCircuit implicationExercise() {
  return compoundExercise(
    expression: 'Y = ¬A + B',
    build: (Map<String, bool> values) => buildCompound(
      values: values,
      gates: const <ComponentType>[ComponentType.notGate, ComponentType.orGate],
      wires: const <(int, int, int)>[
        (0, 2, 0),
        (2, 3, 0),
        (1, 3, 1),
        (3, 4, 0),
      ],
    ),
  );
}

/// XNOR assembled from AND, OR and NOT instead of using a single gate.
ExerciseCircuit xnorFromGatesExercise() {
  return compoundExercise(
    expression: 'Y = A·B + A̅·B̅',
    build: (Map<String, bool> values) => buildCompound(
      values: values,
      gates: const <ComponentType>[
        ComponentType.notGate,
        ComponentType.notGate,
        ComponentType.andGate,
        ComponentType.andGate,
        ComponentType.orGate,
      ],
      wires: const <(int, int, int)>[
        (0, 2, 0),
        (1, 3, 0),
        (0, 4, 0),
        (1, 4, 1),
        (2, 5, 0),
        (3, 5, 1),
        (4, 6, 0),
        (5, 6, 1),
        (6, 7, 0),
      ],
    ),
  );
}

/// A stateful exercise whose expected states are produced by the real
/// simulator, one step at a time.
///
/// For clocked circuits every step applies [steps] and then performs a full
/// clock cycle (rising then falling edge), so a flip-flop captures exactly as
/// it does in the editor. For level-sensitive circuits (latches) a step only
/// applies the inputs and re-evaluates, which is what makes an enabled latch
/// transparent and a disabled one hold its value.
@immutable
class SequentialExercise {
  const SequentialExercise({
    required this.expression,
    required this.inputLabels,
    required this.outputLabel,
    required this.outputNodeId,
    required this.steps,
    required this.build,
    this.clocked = true,
    this.visibleInputLabels,
  });

  final String expression;
  final List<String> inputLabels;
  final String outputLabel;
  final String outputNodeId;

  /// Input values applied before every step.
  final List<Map<String, bool>> steps;

  final CircuitGraph Function(Map<String, bool> values) build;

  /// True when each step is one clock cycle; false for latch/level exercises.
  final bool clocked;

  /// Inputs worth showing in the question row. Defaults to every input.
  final List<String>? visibleInputLabels;

  List<String> get shownInputLabels => visibleInputLabels ?? inputLabels;

  List<bool?> states() {
    final CircuitSimulator simulator = CircuitSimulator(
      build(const <String, bool>{}),
    );
    simulator.evaluate();
    final List<bool?> states = <bool?>[];
    for (final Map<String, bool> values in steps) {
      simulator.updateGraph(build(values));
      final SimulationResult result = clocked
          ? simulator.stepClock()
          : simulator.evaluate();
      states.add(
        result.hasErrors ? null : result.signalOf(outputNodeId).booleanValue,
      );
    }
    return states;
  }
}

CircuitGraph _statefulExerciseGraph({
  required ComponentType type,
  required Map<String, bool> values,
  required Map<String, int> inputPorts,
  int? clockPort,
  int outputPort = 0,
  String outputLabel = 'Q',
}) {
  final List<String> labels = inputPorts.keys.toList();
  final List<CircuitNode> nodes = <CircuitNode>[
    for (int index = 0; index < labels.length; index++)
      CircuitNode(
        id: 'exercise-in-${labels[index].toLowerCase()}',
        type: ComponentType.inputPin,
        position: CanvasPoint(60, 80 + index * 110),
        label: labels[index],
        inputValue: values[labels[index]] ?? false,
      ),
    if (clockPort != null)
      CircuitNode(
        id: 'exercise-clock',
        type: ComponentType.clockSource,
        position: const CanvasPoint(60, 330),
        label: 'CLK',
      ),
    CircuitNode(
      id: 'exercise-state',
      type: type,
      position: const CanvasPoint(300, 150),
      label: type.technicalName,
    ),
    CircuitNode(
      id: 'exercise-out',
      type: ComponentType.outputPin,
      position: const CanvasPoint(580, 150),
      label: outputLabel,
    ),
  ];
  return CircuitGraph(
    nodes: nodes,
    wires: <CircuitWire>[
      for (int index = 0; index < labels.length; index++)
        CircuitWire(
          id: 'exercise-wire-$index',
          fromNodeId: 'exercise-in-${labels[index].toLowerCase()}',
          toNodeId: 'exercise-state',
          toInputIndex: inputPorts[labels[index]]!,
        ),
      if (clockPort != null)
        CircuitWire(
          id: 'exercise-wire-clock',
          fromNodeId: 'exercise-clock',
          toNodeId: 'exercise-state',
          toInputIndex: clockPort,
        ),
      CircuitWire(
        id: 'exercise-wire-out',
        fromNodeId: 'exercise-state',
        toNodeId: 'exercise-out',
        toInputIndex: 0,
        fromPortIndex: outputPort,
      ),
    ],
  );
}

/// An enabled D latch follows D; the asked state is after each level change.
SequentialExercise dLatchTransparentExercise() {
  return SequentialExercise(
    expression: 'EN=۱ ⇒ Q = D',
    inputLabels: const <String>['D', 'EN'],
    outputLabel: 'Q',
    outputNodeId: 'exercise-out',
    clocked: false,
    steps: const <Map<String, bool>>[
      <String, bool>{'D': true, 'EN': true},
      <String, bool>{'D': false, 'EN': true},
    ],
    build: (Map<String, bool> values) => _statefulExerciseGraph(
      type: ComponentType.dLatch,
      values: values,
      inputPorts: const <String, int>{'D': 0, 'EN': 1},
    ),
  );
}

/// A D latch keeps the last value once EN goes low, even while D changes.
SequentialExercise dLatchHoldExercise() {
  return SequentialExercise(
    expression: 'EN=۰ ⇒ Q حفظ می‌شود',
    inputLabels: const <String>['D', 'EN'],
    outputLabel: 'Q',
    outputNodeId: 'exercise-out',
    clocked: false,
    steps: const <Map<String, bool>>[
      <String, bool>{'D': true, 'EN': true},
      <String, bool>{'D': false, 'EN': false},
      <String, bool>{'D': true, 'EN': false},
    ],
    build: (Map<String, bool> values) => _statefulExerciseGraph(
      type: ComponentType.dLatch,
      values: values,
      inputPorts: const <String, int>{'D': 0, 'EN': 1},
    ),
  );
}

/// Set then reset an SR latch; both changes are level sensitive.
SequentialExercise srLatchExercise() {
  return SequentialExercise(
    expression: 'S=۱ ⇒ Q=۱ / R=۱ ⇒ Q=۰',
    inputLabels: const <String>['S', 'R'],
    outputLabel: 'Q',
    outputNodeId: 'exercise-out',
    clocked: false,
    steps: const <Map<String, bool>>[
      <String, bool>{'S': true, 'R': false},
      <String, bool>{'S': false, 'R': true},
    ],
    build: (Map<String, bool> values) => _statefulExerciseGraph(
      type: ComponentType.srLatch,
      values: values,
      inputPorts: const <String, int>{'S': 0, 'R': 1},
    ),
  );
}

/// A D flip-flop captures D on every rising clock edge.
SequentialExercise dFlipFlopExercise() {
  return SequentialExercise(
    expression: 'Q ← D در لبهٔ بالارونده',
    inputLabels: const <String>['D'],
    outputLabel: 'Q',
    outputNodeId: 'exercise-out',
    steps: const <Map<String, bool>>[
      <String, bool>{'D': true},
      <String, bool>{'D': false},
      <String, bool>{'D': true},
    ],
    build: (Map<String, bool> values) => _statefulExerciseGraph(
      type: ComponentType.dFlipFlop,
      values: values,
      inputPorts: const <String, int>{'D': 0},
      clockPort: 1,
    ),
  );
}

/// A T flip-flop inverts its stored value on every edge while T stays high.
SequentialExercise tFlipFlopExercise() {
  return SequentialExercise(
    expression: 'T=۱ ⇒ Q در هر لبه وارونه می‌شود',
    inputLabels: const <String>['T'],
    outputLabel: 'Q',
    outputNodeId: 'exercise-out',
    steps: const <Map<String, bool>>[
      <String, bool>{'T': true},
      <String, bool>{'T': true},
      <String, bool>{'T': true},
      <String, bool>{'T': true},
    ],
    build: (Map<String, bool> values) => _statefulExerciseGraph(
      type: ComponentType.tFlipFlop,
      values: values,
      inputPorts: const <String, int>{'T': 0},
      clockPort: 1,
    ),
  );
}

/// One bit of a 4-bit up counter driven by the real `counter4` component.
SequentialExercise counterBitExercise(int bit) {
  return SequentialExercise(
    expression: 'هر لبه یک واحد به شمارنده اضافه می‌کند',
    inputLabels: const <String>['RST'],
    outputLabel: 'Q$bit',
    outputNodeId: 'exercise-out',
    visibleInputLabels: const <String>[],
    steps: const <Map<String, bool>>[
      <String, bool>{'RST': false},
      <String, bool>{'RST': false},
      <String, bool>{'RST': false},
      <String, bool>{'RST': false},
    ],
    build: (Map<String, bool> values) => _statefulExerciseGraph(
      type: ComponentType.counter4,
      values: values,
      inputPorts: const <String, int>{'RST': 1},
      clockPort: 0,
      outputPort: bit,
      outputLabel: 'Q$bit',
    ),
  );
}

@immutable
class StepEvaluation {
  const StepEvaluation({
    required this.correct,
    required this.feedback,
    required this.solution,
    this.correctLabel,
    this.mismatchRows = const <int>[],
  });

  final bool correct;

  /// Shown immediately. It must not reveal the answer.
  final String feedback;

  /// Shown after a correct answer or after the learner has exhausted an
  /// attempt, and always contains the reasoning.
  final String solution;

  /// Human readable correct answer, revealed with [solution].
  final String? correctLabel;

  final List<int> mismatchRows;
}

sealed class LessonStep {
  const LessonStep({
    required this.id,
    required this.title,
    required this.objective,
    required this.explanation,
    this.concepts = const <String>[],
    this.hints = const <String>[],
  });

  final String id;
  final String title;

  /// One sentence describing what the learner has to do or learn.
  final String objective;

  /// The reasoning shown after the answer.
  final String explanation;

  /// Concept ids used for mastery tracking and spaced review.
  final List<String> concepts;

  /// Progressive hints, from the gentlest to the most direct.
  final List<String> hints;

  bool get awardsXp => true;
}

final class ConceptStep extends LessonStep {
  const ConceptStep({
    required super.id,
    required super.title,
    required super.objective,
    required super.explanation,
    required this.paragraphs,
    this.gateType,
    this.circuit,
    this.sequentialCircuit,
    super.concepts,
    super.hints,
  });

  final List<String> paragraphs;
  final ComponentType? gateType;
  final ExerciseCircuit? circuit;

  /// A stateful circuit shown as a preview on the concept card.
  final SequentialExercise? sequentialCircuit;

  @override
  bool get awardsXp => false;
}

final class PredictionStep extends LessonStep {
  const PredictionStep({
    required super.id,
    required super.title,
    required super.objective,
    required super.explanation,
    required this.circuit,
    required this.inputs,
    super.concepts,
    super.hints,
  });

  final ExerciseCircuit circuit;
  final Map<String, bool> inputs;

  StepEvaluation check(bool answer) {
    final bool? expected = circuit.evaluate(inputs);
    final String inputLabel = circuit.inputLabels
        .map((String label) => '$label=${inputs[label] == true ? 1 : 0}')
        .join(', ');
    if (expected == null) {
      return const StepEvaluation(
        correct: false,
        feedback: 'این مدار در وضعیت فعلی قابل محاسبه نیست.',
        solution: 'اتصال‌های مدار را بررسی کنید و دوباره تلاش کنید.',
      );
    }
    final String expectedLabel = expected ? '۱' : '۰';
    if (answer == expected) {
      return StepEvaluation(
        correct: true,
        feedback: 'درست است.',
        solution: explanation,
        correctLabel: expectedLabel,
      );
    }
    return StepEvaluation(
      correct: false,
      feedback:
          'هنوز درست نیست. ورودی‌ها را در عبارت $inputLabel جای‌گذاری کنید و '
          'رفتار گیت را دوباره بررسی کنید.',
      solution: explanation,
      correctLabel: expectedLabel,
    );
  }
}

final class TruthTableStep extends LessonStep {
  const TruthTableStep({
    required super.id,
    required super.title,
    required super.objective,
    required super.explanation,
    required this.circuit,
    super.concepts,
    super.hints,
  });

  final ExerciseCircuit circuit;

  List<bool?> expectedRows() => circuit.truthRows();

  StepEvaluation check(List<bool?> answers) {
    final List<bool?> expected = expectedRows();
    final List<int> mismatches = <int>[];
    for (int row = 0; row < expected.length; row++) {
      final bool? answer = row < answers.length ? answers[row] : null;
      if (answer == null || answer != expected[row]) {
        mismatches.add(row);
      }
    }
    final String table = <String>[
      for (int row = 0; row < expected.length; row++)
        '${ExerciseCircuit.rowLabel(row, labels: circuit.inputLabels)} → '
            '${expected[row] == true ? '۱' : '۰'}',
    ].join('، ');
    if (mismatches.isEmpty) {
      return StepEvaluation(
        correct: true,
        feedback: 'جدول کامل و درست است.',
        solution: explanation,
      );
    }
    return StepEvaluation(
      correct: false,
      feedback:
          'در ${mismatches.length} ردیف اختلاف وجود دارد. '
          'ردیف‌های ${mismatches.map((int row) => row + 1).join('، ')} را دوباره بررسی کنید.',
      solution: '$explanation\nجدول درست: $table',
      mismatchRows: mismatches,
    );
  }
}

final class GateChoiceStep extends LessonStep {
  const GateChoiceStep({
    required super.id,
    required super.title,
    required super.objective,
    required super.explanation,
    required this.options,
    required this.correct,
    required this.behavior,
    this.showBehaviorTable = true,
    super.concepts,
    super.hints,
  });

  final List<ComponentType> options;
  final ComponentType correct;
  final ExerciseCircuit behavior;

  /// When false only the behaviour description is shown, which makes the
  /// question a real recall check instead of reading a table.
  final bool showBehaviorTable;

  StepEvaluation check(ComponentType choice) {
    final bool isCorrect = choice == correct;
    return StepEvaluation(
      correct: isCorrect,
      feedback: isCorrect
          ? 'درست است.'
          : 'این گزینه درست نیست. رفتار گیت‌ها را در جدول یا تعریفشان '
                'دوباره مقایسه کنید.',
      solution: explanation,
      correctLabel: correct.persianName,
    );
  }
}

@immutable
class LessonOption {
  const LessonOption({
    required this.text,
    required this.correct,
    this.technical = false,
  });

  final String text;
  final bool correct;

  /// Technical options (Boolean expressions, port names) are rendered LTR.
  final bool technical;
}

final class TextChoiceStep extends LessonStep {
  const TextChoiceStep({
    required super.id,
    required super.title,
    required super.objective,
    required super.explanation,
    required this.options,
    this.behavior,
    super.concepts,
    super.hints,
  });

  final List<LessonOption> options;
  final ExerciseCircuit? behavior;

  LessonOption get correctOption =>
      options.firstWhere((LessonOption option) => option.correct);

  StepEvaluation check(LessonOption choice) {
    final bool isCorrect = choice.correct;
    return StepEvaluation(
      correct: isCorrect,
      feedback: isCorrect
          ? 'درست است.'
          : 'این گزینه درست نیست. به جدول یا تعریف صورت مسئله برگردید.',
      solution: explanation,
      correctLabel: correctOption.text,
    );
  }
}

final class SequenceStep extends LessonStep {
  const SequenceStep({
    required super.id,
    required super.title,
    required super.objective,
    required super.explanation,
    required this.circuit,
    super.concepts,
    super.hints,
  });

  final SequentialExercise circuit;

  List<bool?> expectedStates() => circuit.states();

  String stateLabel(int index) {
    final String kind = circuit.clocked ? 'لبهٔ' : 'گام';
    return '$kind ${index + 1}';
  }

  StepEvaluation check(List<bool?> answers) {
    final List<bool?> expected = expectedStates();
    final List<int> mismatches = <int>[];
    for (int index = 0; index < expected.length; index++) {
      final bool? answer = index < answers.length ? answers[index] : null;
      if (answer == null || answer != expected[index]) {
        mismatches.add(index);
      }
    }
    final String states = <String>[
      for (int index = 0; index < expected.length; index++)
        '${stateLabel(index)} → ${expected[index] == true ? '۱' : '۰'}',
    ].join('، ');
    if (mismatches.isEmpty) {
      return StepEvaluation(
        correct: true,
        feedback: 'ترتیب مقادیر درست است.',
        solution: explanation,
      );
    }
    return StepEvaluation(
      correct: false,
      feedback:
          'در ${mismatches.length} مرحله اختلاف وجود دارد. '
          '${mismatches.map(stateLabel).join('، ')} را دوباره بررسی کنید.',
      solution: '$explanation\nمقادیر درست: $states',
      mismatchRows: mismatches,
    );
  }
}

final class BuildCircuitStep extends LessonStep {
  const BuildCircuitStep({
    required super.id,
    required super.title,
    required super.objective,
    required super.explanation,
    required this.challengeId,
    this.circuit,
    super.concepts,
    super.hints,
  });

  final String challengeId;
  final ExerciseCircuit? circuit;
}

@immutable
class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.steps,
  });

  final String id;
  final String title;
  final String subtitle;
  final int minutes;
  final List<LessonStep> steps;

  Set<String> get concepts => <String>{
    for (final LessonStep step in steps) ...step.concepts,
  };
}

@immutable
class LearningUnit {
  const LearningUnit({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lessons,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<LearningLesson> lessons;
}

const Map<String, String> kConceptLabels = <String, String>{
  'signal': 'سیگنال دیجیتال',
  'wiring': 'سیم‌کشی مدار',
  'buffer': 'بافر',
  'and': 'گیت AND',
  'or': 'گیت OR',
  'not': 'گیت NOT',
  'nand': 'گیت NAND',
  'nor': 'گیت NOR',
  'xor': 'گیت XOR',
  'xnor': 'گیت XNOR',
  'truth-table': 'جدول حقیقت',
  'sop': 'طراحی تابع',
  'half-adder': 'نیم‌جمع‌کننده',
  'comparator': 'مقایسه‌گر',
  'latch': 'قفل (Latch)',
  'flip-flop': 'فلیپ‌فلپ',
  'register': 'رجیستر',
  'counter': 'شمارنده',
};

String conceptLabel(String id) => kConceptLabels[id] ?? id;
