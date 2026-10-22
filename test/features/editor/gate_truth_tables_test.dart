import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';

import '../../support/circuit_test_support.dart';

class _Built {
  const _Built(this.graph, this.inputs, this.probes);

  final CircuitGraph graph;
  final List<CircuitNode> inputs;
  final List<CircuitNode> probes;

  /// Returns the same circuit with new switch positions.
  CircuitGraph withValues(List<bool> values) {
    return graph.copyWith(
      nodes:
          graph.nodes.map((CircuitNode node) {
            if (!node.type.isInput) {
              return node;
            }
            final int index = inputs.indexOf(node);
            return node.copyWith(inputValue: index >= 0 && values[index]);
          }).toList(),
    );
  }
}

/// Builds a circuit with one input pin per component input, the component
/// itself and one output probe per output port.
_Built _build(ComponentType type, int inputCount) {
  final CircuitBuilder builder = CircuitBuilder();
  final List<CircuitNode> inputs = <CircuitNode>[];
  for (int i = 0; i < inputCount; i++) {
    inputs.add(
      builder.add(
        ComponentType.inputPin,
        label: String.fromCharCode(65 + i),
        x: i * 100.0,
      ),
    );
  }
  final CircuitNode component = builder.add(type, x: 200, inputs: inputCount);
  for (int i = 0; i < inputCount; i++) {
    builder.connect(inputs[i], component, toPort: i);
  }
  final List<CircuitNode> probes = <CircuitNode>[];
  for (int i = 0; i < component.outputCount; i++) {
    final CircuitNode probe = builder.add(
      ComponentType.outputPin,
      label: 'Y$i',
      x: 400 + i * 100.0,
    );
    builder.connect(component, probe, toPort: 0, fromPort: i);
    probes.add(probe);
  }
  return _Built(builder.build(), inputs, probes);
}

void main() {
  group('Exhaustive truth tables of the basic gates', () {
    const Map<ComponentType, int> gates = <ComponentType, int>{
      ComponentType.andGate: 2,
      ComponentType.orGate: 2,
      ComponentType.notGate: 1,
      ComponentType.nandGate: 2,
      ComponentType.norGate: 2,
      ComponentType.xorGate: 2,
      ComponentType.xnorGate: 2,
      ComponentType.bufferGate: 1,
    };

    gates.forEach((ComponentType type, int inputCount) {
      test('${type.technicalName} matches its reference table', () {
        final _Built built = _build(type, inputCount);
        for (
          int combination = 0;
          combination < (1 << inputCount);
          combination++
        ) {
          final List<bool> values = <bool>[
            for (int i = 0; i < inputCount; i++)
              (combination >> (inputCount - i - 1)) & 1 == 1,
          ];
          final SimulationResult result =
              CircuitSimulator(built.withValues(values)).evaluate();
          expect(
            result.signalOf(built.probes.first.id),
            GateReference.apply(type, values)
                ? LogicSignal.high
                : LogicSignal.low,
            reason: '${type.technicalName} for $values',
          );
        }
      });
    });
  });

  group('Compound gates', () {
    const Map<ComponentType, int> gates = <ComponentType, int>{
      ComponentType.aoi21: 3,
      ComponentType.aoi22: 4,
      ComponentType.oai21: 3,
      ComponentType.oai22: 4,
    };

    gates.forEach((ComponentType type, int inputCount) {
      test('${type.technicalName} matches its reference table', () {
        final _Built built = _build(type, inputCount);
        for (
          int combination = 0;
          combination < (1 << inputCount);
          combination++
        ) {
          final List<bool> values = <bool>[
            for (int i = 0; i < inputCount; i++)
              (combination >> (inputCount - i - 1)) & 1 == 1,
          ];
          final SimulationResult result =
              CircuitSimulator(built.withValues(values)).evaluate();
          expect(
            result.signalOf(built.probes.first.id),
            GateReference.apply(type, values)
                ? LogicSignal.high
                : LogicSignal.low,
            reason: '${type.technicalName} for $values',
          );
        }
      });
    });
  });

  group('Multi input gates', () {
    test('AND with four inputs is high only when all inputs are high', () {
      final _Built built = _build(ComponentType.andGate, 4);
      for (int combination = 0; combination < 16; combination++) {
        final List<bool> values = <bool>[
          for (int i = 0; i < 4; i++) (combination >> (3 - i)) & 1 == 1,
        ];
        final SimulationResult result =
            CircuitSimulator(built.withValues(values)).evaluate();
        expect(
          result.signalOf(built.probes.first.id),
          values.every((bool bit) => bit) ? LogicSignal.high : LogicSignal.low,
          reason: 'AND4 for $values',
        );
      }
    });

    test('XOR with three inputs implements odd parity', () {
      final _Built built = _build(ComponentType.xorGate, 3);
      for (int combination = 0; combination < 8; combination++) {
        final List<bool> values = <bool>[
          for (int i = 0; i < 3; i++) (combination >> (2 - i)) & 1 == 1,
        ];
        final SimulationResult result =
            CircuitSimulator(built.withValues(values)).evaluate();
        expect(
          result.signalOf(built.probes.first.id),
          values.where((bool bit) => bit).length.isOdd
              ? LogicSignal.high
              : LogicSignal.low,
          reason: 'XOR3 for $values',
        );
      }
    });
  });

  group('Tri-state buffer', () {
    test('drives the line when enabled and floats it when disabled', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode data = builder.add(ComponentType.inputPin, label: 'A');
      final CircuitNode enable = builder.add(
        ComponentType.inputPin,
        label: 'EN',
      );
      final CircuitNode buffer = builder.add(ComponentType.triStateBuffer);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Y',
      );
      builder.connect(data, buffer, toPort: 0);
      builder.connect(enable, buffer, toPort: 1);
      builder.connect(buffer, probe, toPort: 0);
      final CircuitGraph graph = builder.build();

      CircuitGraph withValues(bool dataValue, bool enableValue) {
        return graph.copyWith(
          nodes:
              graph.nodes
                  .map(
                    (CircuitNode node) =>
                        node.type.isInput
                            ? node.copyWith(
                              inputValue:
                                  node.label == 'A' ? dataValue : enableValue,
                            )
                            : node,
                  )
                  .toList(),
        );
      }

      SimulationResult result =
          CircuitSimulator(withValues(true, true)).evaluate();
      expect(result.signalOf(probe.id), LogicSignal.high);

      result = CircuitSimulator(withValues(true, false)).evaluate();
      expect(result.signalOf(probe.id), LogicSignal.highImpedance);
      expect(result.signalOf(probe.id).isKnown, isFalse);

      result = CircuitSimulator(withValues(false, true)).evaluate();
      expect(result.signalOf(probe.id), LogicSignal.low);
    });
  });

  group('Three valued propagation', () {
    test(
      'AND with a low input stays low even when the other input is unknown',
      () {
        final CircuitBuilder builder = CircuitBuilder();
        final CircuitNode low = builder.add(
          ComponentType.inputPin,
          label: 'A',
          value: false,
        );
        final CircuitNode gate = builder.add(ComponentType.andGate);
        final CircuitNode probe = builder.add(
          ComponentType.outputPin,
          label: 'Y',
        );
        builder.connect(low, gate, toPort: 0);
        builder.connect(gate, probe, toPort: 0);
        // The second input of the AND gate stays unconnected -> unknown.
        final SimulationResult result =
            CircuitSimulator(builder.build()).evaluate();
        expect(result.signalOf(probe.id), LogicSignal.low);
        expect(result.hasErrors, isTrue);
      },
    );

    test(
      'OR with a high input stays high even when the other input is unknown',
      () {
        final CircuitBuilder builder = CircuitBuilder();
        final CircuitNode high = builder.add(
          ComponentType.inputPin,
          label: 'A',
          value: true,
        );
        final CircuitNode gate = builder.add(ComponentType.orGate);
        final CircuitNode probe = builder.add(
          ComponentType.outputPin,
          label: 'Y',
        );
        builder.connect(high, gate, toPort: 0);
        builder.connect(gate, probe, toPort: 0);
        final SimulationResult result =
            CircuitSimulator(builder.build()).evaluate();
        expect(result.signalOf(probe.id), LogicSignal.high);
      },
    );

    test('an unconnected input makes the dependent output unknown', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode gate = builder.add(ComponentType.andGate);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Y',
      );
      builder.connect(gate, probe, toPort: 0);
      final SimulationResult result =
          CircuitSimulator(builder.build()).evaluate();
      expect(result.signalOf(probe.id), LogicSignal.unknown);
      expect(
        result.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.unconnectedInput,
        ),
        isTrue,
      );
    });
  });
}
