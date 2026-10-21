import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/boolean_tools/domain/boolean_expression.dart';
import 'package:logic_lab/features/boolean_tools/domain/expression_equivalence.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';

CircuitGraph _andCircuit() {
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
  group('Expression and circuit equivalence', () {
    test('an equivalent expression is detected', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A & B');
      final ExpressionEquivalenceResult result = ExpressionEquivalence.compare(
        expression,
        _andCircuit(),
      );
      expect(result.comparable, isTrue);
      expect(result.equivalent, isTrue);
    });

    test('a different expression is detected with the mismatching rows', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A | B');
      final ExpressionEquivalenceResult result = ExpressionEquivalence.compare(
        expression,
        _andCircuit(),
      );
      expect(result.comparable, isTrue);
      expect(result.equivalent, isFalse);
      expect(result.mismatches, isNotEmpty);
    });

    test('different input sets are reported as not comparable', () {
      final BoolExpr expression = BooleanExpressionParser.parse('A');
      final ExpressionEquivalenceResult result = ExpressionEquivalence.compare(
        expression,
        _andCircuit(),
      );
      expect(result.comparable, isFalse);
    });
  });

  group('Project format compatibility', () {
    test('a project saved by an older build still loads', () {
      // Legacy payload: no outputCount field and only the original gates.
      final String legacy = jsonEncode(<String, Object?>{
        'format': ProjectCodec.formatId,
        'version': 1,
        'project': <String, Object?>{
          'id': 'legacy-1',
          'name': 'مدار قدیمی',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
          'circuit': <String, Object?>{
            'schemaVersion': 1,
            'nodes': <Object?>[
              <String, Object?>{
                'id': 'a',
                'type': 'input',
                'x': 0.0,
                'y': 0.0,
                'label': 'A',
                'inputValue': true,
                'inputCount': 0,
              },
              <String, Object?>{
                'id': 'g',
                'type': 'and',
                'x': 100.0,
                'y': 0.0,
                'label': 'AND',
                'inputCount': 2,
              },
              <String, Object?>{
                'id': 'y',
                'type': 'output',
                'x': 200.0,
                'y': 0.0,
                'label': 'Y',
                'inputCount': 1,
              },
            ],
            'wires': <Object?>[
              <String, Object?>{
                'id': 'w1',
                'from': 'a',
                'to': 'g',
                'toInput': 0,
                'fromPort': 0,
              },
              <String, Object?>{
                'id': 'w2',
                'from': 'g',
                'to': 'y',
                'toInput': 0,
                'fromPort': 0,
              },
            ],
          },
        },
      });

      final CircuitProject project = ProjectCodec.decode(legacy);
      expect(project.name, 'مدار قدیمی');
      expect(project.graph.nodes.length, 3);
      expect(project.graph.nodeById('a')!.inputValue, isTrue);
      expect(project.graph.nodeById('g')!.inputCount, 2);
      expect(project.graph.nodeById('g')!.outputCount, 1);
    });

    test('a component type from a newer build loads as unsupported', () {
      final String future = jsonEncode(<String, Object?>{
        'format': ProjectCodec.formatId,
        'version': 1,
        'project': <String, Object?>{
          'id': 'future-1',
          'name': 'مدار آینده',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
          'circuit': <String, Object?>{
            'schemaVersion': 1,
            'nodes': <Object?>[
              <String, Object?>{
                'id': 'x',
                'type': 'quantum_gate',
                'x': 0.0,
                'y': 0.0,
                'label': 'Q',
              },
            ],
            'wires': <Object?>[],
          },
        },
      });
      final CircuitProject project = ProjectCodec.decode(future);
      expect(
        project.graph.nodeById('x')!.type,
        ComponentType.unknown,
        reason: 'unknown types must not break the whole project',
      );
    });

    test('the new component types survive a JSON round trip', () {
      final CircuitNode adder = CircuitNode(
        id: 'fa',
        type: ComponentType.fullAdder,
        position: const CanvasPoint(10, 20),
        label: 'FA',
      );
      final CircuitGraph graph = CircuitGraph(nodes: <CircuitNode>[adder]);
      final CircuitGraph decoded = CircuitGraph.fromJson(graph.toJson());
      final CircuitNode restored = decoded.nodes.first;
      expect(restored.type, ComponentType.fullAdder);
      expect(restored.inputCount, 3);
      expect(restored.outputCount, 2);
    });
  });
}
