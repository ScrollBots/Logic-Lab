import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';

CircuitProject _project() {
  return CircuitProject(
    id: 'p1',
    name: 'مدار نمونه',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
    graph: CircuitGraph(
      nodes: <CircuitNode>[
        CircuitNode(
          id: 'a',
          type: ComponentType.inputPin,
          position: const CanvasPoint(10, 20),
          label: 'A',
        ),
        CircuitNode(
          id: 'g',
          type: ComponentType.andGate,
          position: const CanvasPoint(120, 20),
          label: 'AND',
        ),
        CircuitNode(
          id: 'y',
          type: ComponentType.outputPin,
          position: const CanvasPoint(240, 20),
          label: 'Y',
        ),
      ],
      wires: <CircuitWire>[
        CircuitWire(id: 'w1', fromNodeId: 'a', toNodeId: 'g', toInputIndex: 0),
        CircuitWire(id: 'w2', fromNodeId: 'g', toNodeId: 'y', toInputIndex: 0),
      ],
    ),
  );
}

Map<String, Object?> _envelope(CircuitProject project) {
  return <String, Object?>{
    'format': ProjectCodec.formatId,
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'project': project.toJson(),
  };
}

void main() {
  group('Round trip', () {
    test('a project survives an export and import', () {
      final CircuitProject original = _project();
      final CircuitProject restored = ProjectCodec.decode(
        ProjectCodec.encode(original),
      );
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.graph.nodes.length, 3);
      expect(restored.graph.wires.length, 2);
      expect(
        restored.graph.nodeById('g')!.position.x,
        original.graph.nodeById('g')!.position.x,
      );
    });

    test('an imported copy gets a new identity', () {
      final CircuitProject original = _project();
      final CircuitProject copy = ProjectCodec.decode(
        ProjectCodec.encode(original),
        asCopy: true,
      );
      expect(copy.id, isNot(original.id));
      expect(copy.name, contains(original.name));
    });

    test('the exported file contains no local paths', () {
      final String encoded = ProjectCodec.encode(_project());
      expect(encoded.contains('C:\\'), isFalse);
      expect(encoded.contains('/data/'), isFalse);
      expect(encoded.contains('AppData'), isFalse);
    });
  });

  group('Import failures are handled', () {
    test('malformed JSON is rejected', () {
      expect(
        () => ProjectCodec.decode('{not json'),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('a foreign file is rejected', () {
      expect(
        () => ProjectCodec.decode(jsonEncode(<String, Object?>{'a': 1})),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('a newer schema version is rejected', () {
      final Map<String, Object?> envelope = _envelope(_project());
      envelope['version'] = 99;
      expect(
        () => ProjectCodec.decode(jsonEncode(envelope)),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('an oversized file is rejected before it is parsed', () {
      final String huge = 'x' * (ProjectCodec.maxFileLength + 10);
      expect(
        () => ProjectCodec.decode(huge),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('a wire that points at a missing node is rejected', () {
      final Map<String, Object?> envelope = _envelope(_project());
      final Map<String, Object?> project =
          envelope['project']! as Map<String, Object?>;
      final Map<String, Object?> circuit =
          project['circuit']! as Map<String, Object?>;
      (circuit['wires']! as List<Object?>).add(<String, Object?>{
        'id': 'w9',
        'from': 'a',
        'to': 'does-not-exist',
        'toInput': 0,
        'fromPort': 0,
      });
      expect(
        () => ProjectCodec.decode(jsonEncode(envelope)),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('a wire with an impossible port index is rejected', () {
      final Map<String, Object?> envelope = _envelope(_project());
      final Map<String, Object?> project =
          envelope['project']! as Map<String, Object?>;
      final Map<String, Object?> circuit =
          project['circuit']! as Map<String, Object?>;
      (circuit['wires']! as List<Object?>).add(<String, Object?>{
        'id': 'w9',
        'from': 'g',
        'to': 'y',
        'toInput': 7,
        'fromPort': 0,
      });
      expect(
        () => ProjectCodec.decode(jsonEncode(envelope)),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('duplicate node identifiers are rejected', () {
      final Map<String, Object?> envelope = _envelope(_project());
      final Map<String, Object?> project =
          envelope['project']! as Map<String, Object?>;
      final Map<String, Object?> circuit =
          project['circuit']! as Map<String, Object?>;
      final List<Object?> nodes = circuit['nodes']! as List<Object?>;
      nodes.add(nodes.first);
      expect(
        () => ProjectCodec.decode(jsonEncode(envelope)),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('a node with a non-string label is rejected cleanly', () {
      final Map<String, Object?> envelope = _envelope(_project());
      final Map<String, Object?> project =
          envelope['project']! as Map<String, Object?>;
      final Map<String, Object?> circuit =
          project['circuit']! as Map<String, Object?>;
      final Map<String, Object?> node =
          (circuit['nodes']! as List<Object?>).first! as Map<String, Object?>;
      node['label'] = 42;
      expect(
        () => ProjectCodec.decode(jsonEncode(envelope)),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('a node with a non-boolean inputValue is rejected cleanly', () {
      final Map<String, Object?> envelope = _envelope(_project());
      final Map<String, Object?> project =
          envelope['project']! as Map<String, Object?>;
      final Map<String, Object?> circuit =
          project['circuit']! as Map<String, Object?>;
      final Map<String, Object?> node =
          (circuit['nodes']! as List<Object?>).first! as Map<String, Object?>;
      node['inputValue'] = 'true';
      expect(
        () => ProjectCodec.decode(jsonEncode(envelope)),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('a wire with a negative port index is rejected cleanly', () {
      final Map<String, Object?> envelope = _envelope(_project());
      final Map<String, Object?> project =
          envelope['project']! as Map<String, Object?>;
      final Map<String, Object?> circuit =
          project['circuit']! as Map<String, Object?>;
      final Map<String, Object?> wire =
          (circuit['wires']! as List<Object?>).first! as Map<String, Object?>;
      wire['toInput'] = -1;
      expect(
        () => ProjectCodec.decode(jsonEncode(envelope)),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });
  });

  group('Backward compatibility', () {
    test('a project without the outputCount field still loads', () {
      final String legacy = jsonEncode(<String, Object?>{
        'format': ProjectCodec.formatId,
        'version': 1,
        'project': <String, Object?>{
          'id': 'legacy',
          'name': 'مدار قدیمی',
          'createdAt': '2024-05-01T10:00:00.000Z',
          'updatedAt': '2024-05-02T10:00:00.000Z',
          'circuit': <String, Object?>{
            'schemaVersion': 1,
            'nodes': <Object?>[
              <String, Object?>{
                'id': 'in',
                'type': 'input',
                'x': 0.0,
                'y': 0.0,
                'label': 'A',
                'inputValue': true,
                'inputCount': 0,
              },
              <String, Object?>{
                'id': 'out',
                'type': 'output',
                'x': 100.0,
                'y': 0.0,
                'label': 'Y',
                'inputCount': 1,
              },
            ],
            'wires': <Object?>[
              <String, Object?>{
                'id': 'w',
                'from': 'in',
                'to': 'out',
                'toInput': 0,
                'fromPort': 0,
              },
            ],
          },
        },
      });

      final CircuitProject project = ProjectCodec.decode(legacy);
      expect(project.name, 'مدار قدیمی');
      expect(project.graph.nodes.length, 2);
      expect(project.graph.nodeById('in')!.inputValue, isTrue);
      expect(project.graph.nodeById('out')!.outputCount, 1);

      final SimulationResult result =
          CircuitSimulator(project.graph).evaluate();
      expect(result.signalOf('out'), LogicSignal.high);
    });

    test('a component type from a newer build is kept but reported', () {
      final String future = jsonEncode(<String, Object?>{
        'format': ProjectCodec.formatId,
        'version': 1,
        'project': <String, Object?>{
          'id': 'future',
          'name': 'مدار آینده',
          'createdAt': '2026-05-01T10:00:00.000Z',
          'updatedAt': '2026-05-01T10:00:00.000Z',
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
      expect(project.graph.nodeById('x')!.type, ComponentType.unknown);

      final SimulationResult result =
          CircuitSimulator(project.graph).evaluate();
      expect(
        result.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.unsupportedComponent,
        ),
        isTrue,
      );
    });
  });

  group('Graph validation', () {
    test('duplicate identifiers are rejected by the graph itself', () {
      final CircuitNode node = CircuitNode(
        id: 'same',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
      );
      expect(
        () => CircuitGraph(nodes: <CircuitNode>[node, node]),
        throwsA(isA<FormatException>()),
      );
    });

    test('a malformed wire is reported instead of crashing', () {
      final CircuitGraph graph = CircuitGraph(
        nodes: <CircuitNode>[
          CircuitNode(
            id: 'a',
            type: ComponentType.inputPin,
            position: const CanvasPoint(0, 0),
            label: 'A',
          ),
        ],
        wires: <CircuitWire>[
          CircuitWire(
            id: 'w',
            fromNodeId: 'a',
            toNodeId: 'ghost',
            toInputIndex: 0,
          ),
        ],
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(
        result.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.malformedWire,
        ),
        isTrue,
      );
    });

    test('an invalid port index is reported', () {
      final CircuitGraph graph = CircuitGraph(
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
            position: const CanvasPoint(100, 0),
            label: 'AND',
          ),
        ],
        wires: <CircuitWire>[
          CircuitWire(id: 'w', fromNodeId: 'a', toNodeId: 'g', toInputIndex: 9),
        ],
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(
        result.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.invalidPort,
        ),
        isTrue,
      );
    });
  });
}
