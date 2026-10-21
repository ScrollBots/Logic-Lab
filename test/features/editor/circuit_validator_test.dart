import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_validator.dart';

/// Builds a two-input, one-output circuit around [gate] and returns the
/// simulator report for a given input combination.
SimulationResult _simulateGate(
  ComponentType gate,
  bool a,
  bool b, {
  int inputCount = 2,
}) {
  final CircuitNode inputA = CircuitNode(
    id: 'a',
    type: ComponentType.inputPin,
    position: const CanvasPoint(0, 0),
    label: 'A',
    inputValue: a,
  );
  final CircuitNode inputB = CircuitNode(
    id: 'b',
    type: ComponentType.inputPin,
    position: const CanvasPoint(0, 100),
    label: 'B',
    inputValue: b,
  );
  final CircuitNode gateNode = CircuitNode(
    id: 'g',
    type: gate,
    position: const CanvasPoint(200, 50),
    label: gate.technicalName,
    inputCount: inputCount,
  );
  final CircuitNode output = CircuitNode(
    id: 'y',
    type: ComponentType.outputPin,
    position: const CanvasPoint(400, 50),
    label: 'Y',
  );
  final List<CircuitWire> wires = <CircuitWire>[
    CircuitWire(id: 'w1', fromNodeId: 'a', toNodeId: 'g', toInputIndex: 0),
    if (inputCount > 1)
      CircuitWire(id: 'w2', fromNodeId: 'b', toNodeId: 'g', toInputIndex: 1),
    CircuitWire(id: 'w3', fromNodeId: 'g', toNodeId: 'y', toInputIndex: 0),
  ];
  final CircuitGraph graph = CircuitGraph(
    nodes: <CircuitNode>[inputA, inputB, gateNode, output],
    wires: wires,
  );
  return CircuitValidator.simulate(graph);
}

void main() {
  group('Gate truth tables', () {
    const List<List<bool>> combinations = <List<bool>>[
      <bool>[false, false],
      <bool>[false, true],
      <bool>[true, false],
      <bool>[true, true],
    ];

    test('AND is high only when every input is high', () {
      const List<bool> expected = <bool>[false, false, false, true];
      for (int index = 0; index < combinations.length; index++) {
        final SimulationResult report = _simulateGate(
          ComponentType.andGate,
          combinations[index][0],
          combinations[index][1],
        );
        expect(report.isValid, isTrue, reason: 'circuit must be valid');
        expect(
          report.signalOf('y'),
          expected[index] ? LogicSignal.high : LogicSignal.low,
          reason: 'AND row $index',
        );
      }
    });

    test('OR is high when at least one input is high', () {
      const List<bool> expected = <bool>[false, true, true, true];
      for (int index = 0; index < combinations.length; index++) {
        final SimulationResult report = _simulateGate(
          ComponentType.orGate,
          combinations[index][0],
          combinations[index][1],
        );
        expect(
          report.signalOf('y'),
          expected[index] ? LogicSignal.high : LogicSignal.low,
          reason: 'OR row $index',
        );
      }
    });

    test('NOT inverts its single input', () {
      final SimulationResult low = _simulateGate(
        ComponentType.notGate,
        false,
        false,
        inputCount: 1,
      );
      final SimulationResult high = _simulateGate(
        ComponentType.notGate,
        true,
        false,
        inputCount: 1,
      );
      expect(low.signalOf('y'), LogicSignal.high);
      expect(high.signalOf('y'), LogicSignal.low);
    });

    test('NAND is the inverse of AND', () {
      const List<bool> expected = <bool>[true, true, true, false];
      for (int index = 0; index < combinations.length; index++) {
        final SimulationResult report = _simulateGate(
          ComponentType.nandGate,
          combinations[index][0],
          combinations[index][1],
        );
        expect(
          report.signalOf('y'),
          expected[index] ? LogicSignal.high : LogicSignal.low,
          reason: 'NAND row $index',
        );
      }
    });

    test('NOR is the inverse of OR', () {
      const List<bool> expected = <bool>[true, false, false, false];
      for (int index = 0; index < combinations.length; index++) {
        final SimulationResult report = _simulateGate(
          ComponentType.norGate,
          combinations[index][0],
          combinations[index][1],
        );
        expect(
          report.signalOf('y'),
          expected[index] ? LogicSignal.high : LogicSignal.low,
          reason: 'NOR row $index',
        );
      }
    });

    test('XOR is high when the inputs differ', () {
      const List<bool> expected = <bool>[false, true, true, false];
      for (int index = 0; index < combinations.length; index++) {
        final SimulationResult report = _simulateGate(
          ComponentType.xorGate,
          combinations[index][0],
          combinations[index][1],
        );
        expect(
          report.signalOf('y'),
          expected[index] ? LogicSignal.high : LogicSignal.low,
          reason: 'XOR row $index',
        );
      }
    });

    test('XNOR is high when the inputs are equal', () {
      const List<bool> expected = <bool>[true, false, false, true];
      for (int index = 0; index < combinations.length; index++) {
        final SimulationResult report = _simulateGate(
          ComponentType.xnorGate,
          combinations[index][0],
          combinations[index][1],
        );
        expect(
          report.signalOf('y'),
          expected[index] ? LogicSignal.high : LogicSignal.low,
          reason: 'XNOR row $index',
        );
      }
    });

    test('XOR of three inputs is high for an odd number of highs', () {
      final CircuitNode a = CircuitNode(
        id: 'a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
        inputValue: true,
      );
      final CircuitNode b = CircuitNode(
        id: 'b',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 100),
        label: 'B',
        inputValue: true,
      );
      final CircuitNode c = CircuitNode(
        id: 'c',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 200),
        label: 'C',
        inputValue: true,
      );
      final CircuitNode gate = CircuitNode(
        id: 'g',
        type: ComponentType.xorGate,
        position: const CanvasPoint(200, 100),
        label: 'XOR',
        inputCount: 3,
      );
      final CircuitNode output = CircuitNode(
        id: 'y',
        type: ComponentType.outputPin,
        position: const CanvasPoint(400, 100),
        label: 'Y',
      );
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[a, b, c, gate, output],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'g',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'b',
            toNodeId: 'g',
            toInputIndex: 1,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'c',
            toNodeId: 'g',
            toInputIndex: 2,
          ),
          CircuitWire(
            id: 'w4',
            fromNodeId: 'g',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isTrue);
      expect(report.signalOf('y'), LogicSignal.high);
    });
  });

  group('Multi stage composition', () {
    test('two chained NOT gates restore the original signal', () {
      final CircuitNode input = CircuitNode(
        id: 'a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
        inputValue: true,
      );
      final CircuitNode not1 = CircuitNode(
        id: 'n1',
        type: ComponentType.notGate,
        position: const CanvasPoint(150, 0),
        label: 'NOT',
        inputCount: 1,
      );
      final CircuitNode not2 = CircuitNode(
        id: 'n2',
        type: ComponentType.notGate,
        position: const CanvasPoint(300, 0),
        label: 'NOT',
        inputCount: 1,
      );
      final CircuitNode output = CircuitNode(
        id: 'y',
        type: ComponentType.outputPin,
        position: const CanvasPoint(450, 0),
        label: 'Y',
      );
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[input, not1, not2, output],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'n1',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'n1',
            toNodeId: 'n2',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'n2',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isTrue);
      expect(report.signalOf('n1'), LogicSignal.low);
      expect(report.signalOf('n2'), LogicSignal.high);
      expect(report.signalOf('y'), LogicSignal.high);
    });

    test('a half adder produces the correct sum and carry', () {
      final CircuitNode a = CircuitNode(
        id: 'a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
        inputValue: true,
      );
      final CircuitNode b = CircuitNode(
        id: 'b',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 120),
        label: 'B',
        inputValue: true,
      );
      final CircuitNode xor = CircuitNode(
        id: 'x',
        type: ComponentType.xorGate,
        position: const CanvasPoint(200, 40),
        label: 'XOR',
      );
      final CircuitNode and = CircuitNode(
        id: 'an',
        type: ComponentType.andGate,
        position: const CanvasPoint(200, 180),
        label: 'AND',
      );
      final CircuitNode sum = CircuitNode(
        id: 's',
        type: ComponentType.outputPin,
        position: const CanvasPoint(400, 40),
        label: 'S',
      );
      final CircuitNode carry = CircuitNode(
        id: 'c',
        type: ComponentType.outputPin,
        position: const CanvasPoint(400, 180),
        label: 'C',
      );
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[a, b, xor, and, sum, carry],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'x',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'b',
            toNodeId: 'x',
            toInputIndex: 1,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'a',
            toNodeId: 'an',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w4',
            fromNodeId: 'b',
            toNodeId: 'an',
            toInputIndex: 1,
          ),
          CircuitWire(
            id: 'w5',
            fromNodeId: 'x',
            toNodeId: 's',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w6',
            fromNodeId: 'an',
            toNodeId: 'c',
            toInputIndex: 0,
          ),
        ],
      );
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isTrue);
      expect(report.signalOf('s'), LogicSignal.low);
      expect(report.signalOf('c'), LogicSignal.high);
    });

    test('fan-out from one output feeds several gates', () {
      final CircuitNode input = CircuitNode(
        id: 'a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
        inputValue: true,
      );
      final CircuitNode and1 = CircuitNode(
        id: 'g1',
        type: ComponentType.andGate,
        position: const CanvasPoint(200, -50),
        label: 'AND',
      );
      final CircuitNode and2 = CircuitNode(
        id: 'g2',
        type: ComponentType.andGate,
        position: const CanvasPoint(200, 100),
        label: 'AND',
      );
      final CircuitNode output = CircuitNode(
        id: 'y',
        type: ComponentType.outputPin,
        position: const CanvasPoint(400, 20),
        label: 'Y',
      );
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[input, and1, and2, output],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'g1',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'a',
            toNodeId: 'g2',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'g1',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isFalse);
      expect(
        report.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.unconnectedInput,
        ),
        isTrue,
      );
      expect(report.signalOf('y'), LogicSignal.unknown);
    });
  });

  group('Invalid circuits', () {
    test('a gate with an unconnected input is invalid and unresolved', () {
      final CircuitNode input = CircuitNode(
        id: 'a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
        inputValue: true,
      );
      final CircuitNode gate = CircuitNode(
        id: 'g',
        type: ComponentType.andGate,
        position: const CanvasPoint(200, 0),
        label: 'AND',
      );
      final CircuitNode output = CircuitNode(
        id: 'y',
        type: ComponentType.outputPin,
        position: const CanvasPoint(400, 0),
        label: 'Y',
      );
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[input, gate, output],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'g',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'g',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isFalse);
      expect(report.signalOf('g'), LogicSignal.unknown);
      expect(report.signalOf('y'), LogicSignal.unknown);
      expect(
        report.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.unconnectedInput,
        ),
        isTrue,
      );
    });

    test('a combinational cycle is reported and never resolved', () {
      final CircuitNode input = CircuitNode(
        id: 'a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
      );
      final CircuitNode gate1 = CircuitNode(
        id: 'g1',
        type: ComponentType.notGate,
        position: const CanvasPoint(200, 0),
        label: 'NOT',
        inputCount: 1,
      );
      final CircuitNode gate2 = CircuitNode(
        id: 'g2',
        type: ComponentType.notGate,
        position: const CanvasPoint(400, 0),
        label: 'NOT',
        inputCount: 1,
      );
      final CircuitNode output = CircuitNode(
        id: 'y',
        type: ComponentType.outputPin,
        position: const CanvasPoint(600, 0),
        label: 'Y',
      );
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[input, gate1, gate2, output],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'g1',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'g1',
            toNodeId: 'g2',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'g2',
            toNodeId: 'g1',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w4',
            fromNodeId: 'g2',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isFalse);
      expect(
        report.problems.any(
          (CircuitProblem problem) => problem.code == CircuitProblemCode.cycle,
        ),
        isTrue,
      );
      expect(report.signalOf('g1'), LogicSignal.unknown);
      expect(report.signalOf('y'), LogicSignal.unknown);
    });

    test('a circuit without an output is invalid', () {
      final CircuitNode input = CircuitNode(
        id: 'a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
      );
      final CircuitGraph graph = CircuitGraph(nodes: <CircuitNode>[input]);
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isFalse);
      expect(
        report.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.noOutput,
        ),
        isTrue,
      );
    });

    test('two wires on the same input port are rejected', () {
      final CircuitNode a = CircuitNode(
        id: 'a',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
        inputValue: true,
      );
      final CircuitNode b = CircuitNode(
        id: 'b',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 120),
        label: 'B',
      );
      final CircuitNode gate = CircuitNode(
        id: 'g',
        type: ComponentType.andGate,
        position: const CanvasPoint(200, 60),
        label: 'AND',
      );
      final CircuitNode output = CircuitNode(
        id: 'y',
        type: ComponentType.outputPin,
        position: const CanvasPoint(400, 60),
        label: 'Y',
      );
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[a, b, gate, output],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
            toNodeId: 'g',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w2',
            fromNodeId: 'b',
            toNodeId: 'g',
            toInputIndex: 0,
          ),
          CircuitWire(
            id: 'w3',
            fromNodeId: 'g',
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      final SimulationResult report = CircuitValidator.simulate(graph);
      expect(report.isValid, isFalse);
      expect(
        report.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.duplicateInputConnection,
        ),
        isTrue,
      );
      expect(report.signalOf('g'), LogicSignal.unknown);
    });
  });

  group('Connection rules', () {
    CircuitGraph buildBaseGraph() {
      return CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
          ),
          CircuitNode(
            id: 'b',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 120),
            label: 'B',
          ),
          CircuitNode(
            id: 'g',
            type: ComponentType.andGate,
            position: const CanvasPoint(200, 0),
            label: 'AND',
          ),
          CircuitNode(
            id: 'y',
            type: ComponentType.outputPin,
            position: const CanvasPoint(400, 0),
            label: 'Y',
          ),
        ],
      );
    }

    test('connecting an output to an input is allowed', () {
      final ConnectionCheck check = CircuitValidator.canConnect(
        graph: buildBaseGraph(),
        fromNodeId: 'a',
        toNodeId: 'g',
        toInputIndex: 0,
      );
      expect(check.allowed, isTrue);
    });

    test('connecting into an input pin is rejected', () {
      final ConnectionCheck check = CircuitValidator.canConnect(
        graph: buildBaseGraph(),
        fromNodeId: 'a',
        toNodeId: 'b',
        toInputIndex: 0,
      );
      expect(check.allowed, isFalse);
      expect(check.code, CircuitProblemCode.targetIsInput);
    });

    test('connecting from an output pin is rejected', () {
      final ConnectionCheck check = CircuitValidator.canConnect(
        graph: buildBaseGraph(),
        fromNodeId: 'y',
        toNodeId: 'g',
        toInputIndex: 0,
      );
      expect(check.allowed, isFalse);
      expect(check.code, CircuitProblemCode.sourceIsOutput);
    });

    test('connecting to an already used port is rejected', () {
      final CircuitGraph graph = buildBaseGraph().addWire(
        CircuitWire(id: 'w', fromNodeId: 'a', toNodeId: 'g', toInputIndex: 0),
      );
      final ConnectionCheck check = CircuitValidator.canConnect(
        graph: graph,
        fromNodeId: 'a',
        toNodeId: 'g',
        toInputIndex: 0,
      );
      expect(check.allowed, isFalse);
      expect(check.code, CircuitProblemCode.duplicateInputConnection);
    });

    test('creating a combinational cycle is rejected', () {
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'n1',
            type: ComponentType.notGate,
            position: const CanvasPoint(0, 0),
            label: 'NOT',
            inputCount: 1,
          ),
          CircuitNode(
            id: 'n2',
            type: ComponentType.notGate,
            position: const CanvasPoint(200, 0),
            label: 'NOT',
            inputCount: 1,
          ),
        ],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'n1',
            toNodeId: 'n2',
            toInputIndex: 0,
          ),
        ],
      );
      final ConnectionCheck check = CircuitValidator.canConnect(
        graph: graph,
        fromNodeId: 'n2',
        toNodeId: 'n1',
        toInputIndex: 0,
      );
      expect(check.allowed, isFalse);
      expect(check.code, CircuitProblemCode.cycle);
    });
  });
}
