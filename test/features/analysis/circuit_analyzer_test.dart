import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/analysis/domain/circuit_analyzer.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';

CircuitGraph _andGraph({String suffix = ''}) {
  return CircuitGraph(
    nodes: <CircuitNode>[
      CircuitNode(
        id: 'a$suffix',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
      ),
      CircuitNode(
        id: 'b$suffix',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 120),
        label: 'B',
      ),
      CircuitNode(
        id: 'g$suffix',
        type: ComponentType.andGate,
        position: const CanvasPoint(200, 60),
        label: 'AND',
      ),
      CircuitNode(
        id: 'y$suffix',
        type: ComponentType.outputPin,
        position: const CanvasPoint(400, 60),
        label: 'Y',
      ),
    ],
    wires: <CircuitWire>[
      CircuitWire(
        id: 'w1$suffix',
        fromNodeId: 'a$suffix',
        toNodeId: 'g$suffix',
        toInputIndex: 0,
      ),
      CircuitWire(
        id: 'w2$suffix',
        fromNodeId: 'b$suffix',
        toNodeId: 'g$suffix',
        toInputIndex: 1,
      ),
      CircuitWire(
        id: 'w3$suffix',
        fromNodeId: 'g$suffix',
        toNodeId: 'y$suffix',
        toInputIndex: 0,
      ),
    ],
  );
}

CircuitGraph _nandGraph() {
  final CircuitGraph base = _andGraph(suffix: '2');
  return base.copyWith(
    nodes: base.nodes
        .map(
          (CircuitNode node) => node.id == 'g2'
              ? node.copyWith(type: ComponentType.nandGate)
              : node,
        )
        .toList(),
  );
}

void main() {
  group('Circuit statistics', () {
    test('counts gates, wires, inputs and outputs', () {
      final CircuitStatistics statistics = CircuitAnalyzer.statisticsOf(
        _andGraph(),
      );
      expect(statistics.gateCount, 1);
      expect(statistics.wireCount, 3);
      expect(statistics.inputCount, 2);
      expect(statistics.outputCount, 1);
      expect(statistics.componentCount, 4);
    });

    test('measures the combinational depth', () {
      final CircuitStatistics single = CircuitAnalyzer.statisticsOf(
        _andGraph(),
      );
      expect(single.depth, 1);

      // Two gates in series: the depth is two.
      final CircuitGraph chained = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
          ),
          CircuitNode(
            id: 'g1',
            type: ComponentType.andGate,
            position: const CanvasPoint(150, 0),
            label: 'AND',
          ),
          CircuitNode(
            id: 'g2',
            type: ComponentType.nandGate,
            position: const CanvasPoint(300, 0),
            label: 'NAND',
          ),
          CircuitNode(
            id: 'y',
            type: ComponentType.outputPin,
            position: const CanvasPoint(450, 0),
            label: 'Y',
          ),
        ],
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
            toNodeId: 'y',
            toInputIndex: 0,
          ),
        ],
      );
      expect(CircuitAnalyzer.statisticsOf(chained).depth, 2);
    });
  });

  group('Circuit comparison', () {
    test('two identical circuits are equivalent', () {
      final CircuitComparison result = CircuitAnalyzer.compare(
        _andGraph(),
        _andGraph(suffix: '2'),
      );
      expect(result.equivalent, isTrue);
      expect(result.firstMismatchIndex, isNull);
      expect(result.comparedRows, 4);
    });

    test('different circuits report the first mismatching combination', () {
      final CircuitComparison result = CircuitAnalyzer.compare(
        _andGraph(),
        _nandGraph(),
      );
      expect(result.equivalent, isFalse);
      expect(result.firstMismatchIndex, isNotNull);
      expect(result.mismatchDescription, contains('A='));
    });

    test('circuits with a different number of inputs are not comparable', () {
      final CircuitGraph singleInput = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
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
      final CircuitComparison result = CircuitAnalyzer.compare(
        _andGraph(),
        singleInput,
      );
      expect(result.equivalent, isFalse);
      expect(result.comparedRows, 0);
      expect(result.mismatchDescription, contains('ورودی'));
    });
  });
}
