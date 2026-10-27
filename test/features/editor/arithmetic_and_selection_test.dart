import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';

import '../../support/circuit_test_support.dart';

class _Built {
  const _Built(this.graph, this.inputs, this.probes);

  final CircuitGraph graph;
  final List<CircuitNode> inputs;
  final List<CircuitNode> probes;

  CircuitGraph withValues(List<bool> values) {
    return graph.copyWith(
      nodes: graph.nodes.map((CircuitNode node) {
        if (!node.type.isInput) {
          return node;
        }
        final int index = inputs.indexOf(node);
        return node.copyWith(inputValue: index >= 0 && values[index]);
      }).toList(),
    );
  }
}

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
  final CircuitNode component = builder.add(type, x: 250, inputs: inputCount);
  for (int i = 0; i < inputCount; i++) {
    builder.connect(inputs[i], component, toPort: i);
  }
  final List<CircuitNode> probes = <CircuitNode>[];
  for (int i = 0; i < component.outputCount; i++) {
    final CircuitNode probe = builder.add(
      ComponentType.outputPin,
      label: 'Y$i',
      x: 450 + i * 100.0,
    );
    builder.connect(component, probe, toPort: 0, fromPort: i);
    probes.add(probe);
  }
  return _Built(builder.build(), inputs, probes);
}

void main() {
  group('Adders and subtractors', () {
    test('half adder matches the reference for every input pair', () {
      final _Built built = _build(ComponentType.halfAdder, 2);
      for (int combination = 0; combination < 4; combination++) {
        final List<bool> values = <bool>[
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = ArithmeticReference.halfAdder(
          values[0],
          values[1],
        );
        expect(
          result.signalOf(built.probes[0].id),
          expected[0] ? LogicSignal.high : LogicSignal.low,
        );
        expect(
          result.signalOf(built.probes[1].id),
          expected[1] ? LogicSignal.high : LogicSignal.low,
        );
      }
    });

    test('full adder matches the reference for every input triple', () {
      final _Built built = _build(ComponentType.fullAdder, 3);
      for (int combination = 0; combination < 8; combination++) {
        final List<bool> values = <bool>[
          (combination >> 2) & 1 == 1,
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = ArithmeticReference.fullAdder(
          values[0],
          values[1],
          values[2],
        );
        expect(
          result.signalOf(built.probes[0].id),
          expected[0] ? LogicSignal.high : LogicSignal.low,
        );
        expect(
          result.signalOf(built.probes[1].id),
          expected[1] ? LogicSignal.high : LogicSignal.low,
        );
      }
    });

    test('half subtractor matches the reference for every input pair', () {
      final _Built built = _build(ComponentType.halfSubtractor, 2);
      for (int combination = 0; combination < 4; combination++) {
        final List<bool> values = <bool>[
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = ArithmeticReference.halfSubtractor(
          values[0],
          values[1],
        );
        expect(
          result.signalOf(built.probes[0].id),
          expected[0] ? LogicSignal.high : LogicSignal.low,
        );
        expect(
          result.signalOf(built.probes[1].id),
          expected[1] ? LogicSignal.high : LogicSignal.low,
        );
      }
    });

    test('full subtractor matches the reference for every input triple', () {
      final _Built built = _build(ComponentType.fullSubtractor, 3);
      for (int combination = 0; combination < 8; combination++) {
        final List<bool> values = <bool>[
          (combination >> 2) & 1 == 1,
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = ArithmeticReference.fullSubtractor(
          values[0],
          values[1],
          values[2],
        );
        expect(
          result.signalOf(built.probes[0].id),
          expected[0] ? LogicSignal.high : LogicSignal.low,
        );
        expect(
          result.signalOf(built.probes[1].id),
          expected[1] ? LogicSignal.high : LogicSignal.low,
        );
      }
    });
  });

  group('Comparator', () {
    test('compares two bit numbers in every combination', () {
      final _Built built = _build(ComponentType.comparator, 4);
      for (int a = 0; a < 4; a++) {
        for (int b = 0; b < 4; b++) {
          final List<bool> values = <bool>[
            (a >> 1) & 1 == 1,
            a & 1 == 1,
            (b >> 1) & 1 == 1,
            b & 1 == 1,
          ];
          final SimulationResult result = CircuitSimulator(
            built.withValues(values),
          ).evaluate();
          final List<bool> expected = ArithmeticReference.comparator(a, b);
          expect(
            result.signalOf(built.probes[0].id),
            expected[0] ? LogicSignal.high : LogicSignal.low,
            reason: 'A=$a B=$b',
          );
          expect(
            result.signalOf(built.probes[1].id),
            expected[1] ? LogicSignal.high : LogicSignal.low,
            reason: 'A=$a B=$b',
          );
          expect(
            result.signalOf(built.probes[2].id),
            expected[2] ? LogicSignal.high : LogicSignal.low,
            reason: 'A=$a B=$b',
          );
        }
      }
    });
  });

  group('Multiplexers and demultiplexers', () {
    test('2:1 multiplexer matches the reference', () {
      final _Built built = _build(ComponentType.mux2, 3);
      for (int combination = 0; combination < 8; combination++) {
        final List<bool> values = <bool>[
          (combination >> 2) & 1 == 1,
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        expect(
          result.signalOf(built.probes[0].id),
          SelectionReference.mux2(values[0], values[1], values[2])
              ? LogicSignal.high
              : LogicSignal.low,
          reason: 'mux2 $values',
        );
      }
    });

    test('4:1 multiplexer matches the reference', () {
      final _Built built = _build(ComponentType.mux4, 6);
      for (int combination = 0; combination < 64; combination++) {
        final List<bool> values = <bool>[
          for (int i = 0; i < 6; i++) (combination >> (5 - i)) & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        expect(
          result.signalOf(built.probes[0].id),
          SelectionReference.mux4(
                values[0],
                values[1],
                values[2],
                values[3],
                values[4],
                values[5],
              )
              ? LogicSignal.high
              : LogicSignal.low,
          reason: 'mux4 $values',
        );
      }
    });

    test('1:2 demultiplexer routes the data', () {
      final _Built built = _build(ComponentType.demux1to2, 2);
      for (int combination = 0; combination < 4; combination++) {
        final List<bool> values = <bool>[
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = SelectionReference.demux2(
          values[0],
          values[1],
        );
        for (int i = 0; i < 2; i++) {
          expect(
            result.signalOf(built.probes[i].id),
            expected[i] ? LogicSignal.high : LogicSignal.low,
            reason: 'demux2 $values',
          );
        }
      }
    });

    test('1:4 demultiplexer routes the data', () {
      final _Built built = _build(ComponentType.demux1to4, 3);
      for (int combination = 0; combination < 8; combination++) {
        final List<bool> values = <bool>[
          (combination >> 2) & 1 == 1,
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = SelectionReference.demux4(
          values[0],
          values[1],
          values[2],
        );
        for (int i = 0; i < 4; i++) {
          expect(
            result.signalOf(built.probes[i].id),
            expected[i] ? LogicSignal.high : LogicSignal.low,
            reason: 'demux4 $values',
          );
        }
      }
    });
  });

  group('Decoders and encoders', () {
    test('2-to-4 decoder activates exactly one output', () {
      final _Built built = _build(ComponentType.decoder2to4, 2);
      for (int combination = 0; combination < 4; combination++) {
        final List<bool> values = <bool>[
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = SelectionReference.decoder4(
          values[0],
          values[1],
        );
        for (int i = 0; i < 4; i++) {
          expect(
            result.signalOf(built.probes[i].id),
            expected[i] ? LogicSignal.high : LogicSignal.low,
            reason: 'decoder4 $values',
          );
        }
      }
    });

    test('3-to-8 decoder activates exactly one output', () {
      final _Built built = _build(ComponentType.decoder3to8, 3);
      for (int combination = 0; combination < 8; combination++) {
        final List<bool> values = <bool>[
          (combination >> 2) & 1 == 1,
          (combination >> 1) & 1 == 1,
          combination & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = SelectionReference.decoder8(
          values[0],
          values[1],
          values[2],
        );
        for (int i = 0; i < 8; i++) {
          expect(
            result.signalOf(built.probes[i].id),
            expected[i] ? LogicSignal.high : LogicSignal.low,
            reason: 'decoder8 $values',
          );
        }
      }
    });

    test('4-to-2 encoder follows the classic encoding', () {
      final _Built built = _build(ComponentType.encoder4to2, 4);
      for (int combination = 0; combination < 16; combination++) {
        final List<bool> values = <bool>[
          for (int i = 0; i < 4; i++) (combination >> i) & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = SelectionReference.encoder4(
          values[0],
          values[1],
          values[2],
          values[3],
        );
        expect(
          result.signalOf(built.probes[0].id),
          expected[0] ? LogicSignal.high : LogicSignal.low,
          reason: 'encoder4 $values',
        );
        expect(
          result.signalOf(built.probes[1].id),
          expected[1] ? LogicSignal.high : LogicSignal.low,
          reason: 'encoder4 $values',
        );
      }
    });

    test('8-to-3 encoder prefers the highest active input', () {
      final _Built built = _build(ComponentType.encoder8to3, 8);
      for (int combination = 0; combination < 256; combination++) {
        final List<bool> values = <bool>[
          for (int i = 0; i < 8; i++) (combination >> i) & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = SelectionReference.encoder8(values);
        for (int i = 0; i < 3; i++) {
          expect(
            result.signalOf(built.probes[i].id),
            expected[i] ? LogicSignal.high : LogicSignal.low,
            reason: 'encoder8 $values',
          );
        }
      }
    });

    test('priority encoder reports the highest active input and V', () {
      final _Built built = _build(ComponentType.priorityEncoder, 8);
      for (int combination = 0; combination < 256; combination++) {
        final List<bool> values = <bool>[
          for (int i = 0; i < 8; i++) (combination >> i) & 1 == 1,
        ];
        final SimulationResult result = CircuitSimulator(
          built.withValues(values),
        ).evaluate();
        final List<bool> expected = SelectionReference.priorityEncoder(values);
        for (int i = 0; i < 4; i++) {
          expect(
            result.signalOf(built.probes[i].id),
            expected[i] ? LogicSignal.high : LogicSignal.low,
            reason: 'priority encoder $values',
          );
        }
      }
    });
  });
}
