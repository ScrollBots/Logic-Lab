import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_validator.dart';
import 'package:logic_lab/features/truth_table/domain/truth_table.dart';

CircuitGraph _andGraph() {
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
        position: const CanvasPoint(220, 60),
        label: 'AND',
      ),
      CircuitNode(
        id: 'y',
        type: ComponentType.outputPin,
        position: const CanvasPoint(440, 60),
        label: 'Y',
      ),
    ],
    wires: <CircuitWire>[
      CircuitWire(id: 'w1', fromNodeId: 'a', toNodeId: 'g', toInputIndex: 0),
      CircuitWire(id: 'w2', fromNodeId: 'b', toNodeId: 'g', toInputIndex: 1),
      CircuitWire(id: 'w3', fromNodeId: 'g', toNodeId: 'y', toInputIndex: 0),
    ],
  );
}

void main() {
  group('Truth table generation', () {
    test('produces every combination of the real inputs', () {
      final TruthTableResult table = const TruthTableGenerator().generate(
        _andGraph(),
      );
      expect(table.inputCount, 2);
      expect(table.outputCount, 1);
      expect(table.rows.length, 4);
      expect(table.allRowsValid, isTrue);
      expect(
        table.rows.map((TruthTableRow row) => row.outputs['y']).toList(),
        <bool>[false, false, false, true],
      );
    });

    test('the generated values match the simulator for each combination', () {
      final TruthTableResult table = const TruthTableGenerator().generate(
        _andGraph(),
      );
      for (final TruthTableRow row in table.rows) {
        final CircuitGraph graph = _andGraph().copyWith(
          nodes:
              _andGraph().nodes
                  .map(
                    (CircuitNode node) =>
                        node.type.isInput
                            ? node.copyWith(
                              inputValue: row.inputs[node.id] ?? false,
                            )
                            : node,
                  )
                  .toList(),
        );
        final SimulationResult report = CircuitValidator.simulate(graph);
        expect(report.signalOf('y'), isNotNull);
        expect(
          row.outputs['y'],
          report.signalOf('y').booleanValue,
          reason: 'row ${row.index} must equal the simulator output',
        );
      }
    });

    test('unknown values are never fabricated for an invalid circuit', () {
      final CircuitGraph broken = _andGraph().copyWith(
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w1',
            fromNodeId: 'a',
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
      final TruthTableResult table = const TruthTableGenerator().generate(
        broken,
      );
      expect(table.allRowsValid, isFalse);
      for (final TruthTableRow row in table.rows) {
        expect(row.outputs['y'], isNull);
      }
    });

    test('a circuit with no inputs still yields a single row', () {
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'g',
            type: ComponentType.notGate,
            position: const CanvasPoint(0, 0),
            label: 'NOT',
            inputCount: 1,
          ),
          CircuitNode(
            id: 'y',
            type: ComponentType.outputPin,
            position: const CanvasPoint(200, 0),
            label: 'Y',
          ),
        ],
      );
      final TruthTableResult table = const TruthTableGenerator().generate(
        graph,
      );
      expect(table.rows.length, 1);
      expect(table.inputCount, 0);
    });

    test('the computation limit protects against huge tables', () {
      final List<CircuitNode> nodes = <CircuitNode>[];
      final List<CircuitWire> wires = <CircuitWire>[];
      for (int index = 0; index < 12; index++) {
        nodes.add(
          CircuitNode(
            id: 'i$index',
            type: ComponentType.inputPin,
            position: CanvasPoint(0, index * 40.0),
            label: 'I$index',
          ),
        );
      }
      nodes.add(
        CircuitNode(
          id: 'y',
          type: ComponentType.outputPin,
          position: const CanvasPoint(300, 200),
          label: 'Y',
        ),
      );
      wires.add(
        CircuitWire(id: 'w', fromNodeId: 'i0', toNodeId: 'y', toInputIndex: 0),
      );
      final CircuitGraph graph = CircuitGraph(nodes: nodes, wires: wires);
      expect(
        () => const TruthTableGenerator().generate(
          graph,
          limits: const TruthTableLimits(maxInputs: 8, maxRows: 256),
        ),
        throwsA(isA<TruthTableGenerationException>()),
      );
    });

    test('CSV export keeps ASCII bits and a stable column order', () {
      final TruthTableResult table = const TruthTableGenerator().generate(
        _andGraph(),
      );
      final String csv = table.toCsv();
      final List<String> lines = csv.trim().split('\n');
      expect(lines.first, 'A,B,Y');
      expect(lines[1], '0,0,0');
      expect(lines[4], '1,1,1');
    });
  });
}
