import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';

CircuitProject _sampleProject() {
  return CircuitProject(
    id: 'p1',
    name: 'نیم‌جمع‌کننده',
    createdAt: DateTime.utc(2026, 1, 2, 3, 4),
    updatedAt: DateTime.utc(2026, 1, 3, 4, 5),
    graph: CircuitGraph(
      nodes: <CircuitNode>[
        CircuitNode(
          id: 'a',
          type: ComponentType.inputPin,
          position: const CanvasPoint(10, 20),
          label: 'A',
          inputValue: true,
        ),
        CircuitNode(
          id: 'y',
          type: ComponentType.outputPin,
          position: const CanvasPoint(200, 20),
          label: 'Y',
        ),
      ],
      wires: <CircuitWire>[
        CircuitWire(id: 'w1', fromNodeId: 'a', toNodeId: 'y', toInputIndex: 0),
      ],
    ),
  );
}

void main() {
  group('Project serialization', () {
    test('round trips a project through JSON', () {
      final CircuitProject original = _sampleProject();
      final String encoded = ProjectCodec.encode(original);
      final CircuitProject decoded = ProjectCodec.decode(encoded);
      expect(decoded.id, original.id);
      expect(decoded.name, original.name);
      expect(decoded.createdAt.toUtc(), original.createdAt.toUtc());
      expect(decoded.updatedAt.toUtc(), original.updatedAt.toUtc());
      expect(decoded.graph.nodes.length, original.graph.nodes.length);
      expect(decoded.graph.wires.length, original.graph.wires.length);
      expect(decoded.graph.nodes.first.inputValue, isTrue);
    });

    test('the exported file is portable and free of local paths', () {
      final String encoded = ProjectCodec.encode(_sampleProject());
      final Map<String, dynamic> json =
          jsonDecode(encoded) as Map<String, dynamic>;
      expect(json['format'], ProjectCodec.formatId);
      expect(json['version'], ProjectCodec.formatVersion);
      expect(encoded.contains('C:\\'), isFalse);
      expect(encoded.contains('/data/'), isFalse);
    });

    test('rejects a file that is not a Logic Lab project', () {
      expect(
        () => ProjectCodec.decode('{"format":"other","version":1}'),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('rejects a malformed JSON file', () {
      expect(
        () => ProjectCodec.decode('{not json'),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('rejects a newer, unsupported version', () {
      final String json = jsonEncode(<String, Object?>{
        'format': ProjectCodec.formatId,
        'version': 99,
        'project': <String, Object?>{},
      });
      expect(
        () => ProjectCodec.decode(json),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('rejects a project with a broken circuit', () {
      final Map<String, dynamic> json =
          jsonDecode(ProjectCodec.encode(_sampleProject()))
              as Map<String, dynamic>;
      (json['project'] as Map<String, dynamic>)['circuit'] = <String, Object?>{
        'nodes': 'not-a-list',
        'wires': <Object?>[],
      };
      expect(
        () => ProjectCodec.decode(jsonEncode(json)),
        throwsA(isA<ProjectFileFormatException>()),
      );
    });

    test('importing as a copy creates a new identity', () {
      final CircuitProject original = _sampleProject();
      final CircuitProject copy = ProjectCodec.decode(
        ProjectCodec.encode(original),
        asCopy: true,
      );
      expect(copy.id, isNot(original.id));
      expect(copy.name, contains(original.name));
    });

    test('a graph round trips with all node properties', () {
      final CircuitNode node = CircuitNode(
        id: 'g',
        type: ComponentType.nandGate,
        position: const CanvasPoint(11.5, 22.5),
        label: 'NAND',
        inputCount: 3,
      );
      final CircuitGraph graph = CircuitGraph(nodes: <CircuitNode>[node]);
      final CircuitGraph decoded = CircuitGraph.fromJson(graph.toJson());
      final CircuitNode decodedNode = decoded.nodes.first;
      expect(decodedNode.id, 'g');
      expect(decodedNode.type, ComponentType.nandGate);
      expect(decodedNode.position.x, 11.5);
      expect(decodedNode.position.y, 22.5);
      expect(decodedNode.inputCount, 3);
      expect(decodedNode.label, 'NAND');
    });

    test('rejects duplicate node identifiers', () {
      final CircuitNode node = CircuitNode(
        id: 'dup',
        type: ComponentType.inputPin,
        position: const CanvasPoint(0, 0),
        label: 'A',
      );
      expect(
        () => CircuitGraph(nodes: <CircuitNode>[node, node]),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
