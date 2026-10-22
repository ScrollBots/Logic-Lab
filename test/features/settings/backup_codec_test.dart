import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';
import 'package:logic_lab/features/settings/data/backup_codec.dart';

CircuitProject _project() {
  return CircuitProject(
    id: 'p1',
    name: 'پروژه نمونه',
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
          id: 'y',
          type: ComponentType.outputPin,
          position: const CanvasPoint(200, 20),
          label: 'Y',
        ),
      ],
      wires: <CircuitWire>[
        CircuitWire(id: 'w', fromNodeId: 'a', toNodeId: 'y', toInputIndex: 0),
      ],
    ),
  );
}

Map<String, Object?> _envelope({
  List<Object?>? projects,
  List<Object?>? progress,
}) {
  return <String, Object?>{
    'format': BackupCodec.formatId,
    'version': 1,
    'exportedAt': '2026-01-01T00:00:00.000Z',
    'projects': projects ?? <Object?>[_project().toJson()],
    'learningProgress': progress ?? <Object?>[],
    'settings': <String, Object?>{'themeMode': 'dark'},
  };
}

void main() {
  group('Backup decoding', () {
    test('a backup restores projects, progress and settings', () {
      final BackupPayload payload =
          BackupCodec.decode(
            jsonEncode(
              _envelope(
                progress: <Object?>[
                  <String, Object?>{
                    'itemId': 'lesson-a',
                    'completed': true,
                    'bestScore': 90,
                    'attempts': 3,
                    'updatedAt': '2026-01-03T00:00:00.000Z',
                  },
                ],
              ),
            ),
          )!;

      expect(payload.projects.single.name, 'پروژه نمونه');
      expect(payload.projects.single.graph.wires.length, 1);
      expect(payload.progress.single.itemId, 'lesson-a');
      expect(payload.progress.single.completed, isTrue);
      expect(payload.progress.single.bestScore, 90);
      expect(payload.progress.single.attempts, 3);
      expect(payload.settings?['themeMode'], 'dark');
    });

    test('wrong value types in progress do not abort the restore', () {
      final BackupPayload payload =
          BackupCodec.decode(
            jsonEncode(
              _envelope(
                progress: <Object?>[
                  <String, Object?>{
                    'itemId': 'lesson-a',
                    'completed': 'yes',
                    'bestScore': 'high',
                    'attempts': 2.5,
                    'updatedAt': '2026-01-03T00:00:00.000Z',
                  },
                  <String, Object?>{'completed': true},
                ],
              ),
            ),
          )!;

      expect(payload.progress.length, 1);
      expect(payload.progress.single.completed, isFalse);
      expect(payload.progress.single.bestScore, 0);
      expect(payload.progress.single.attempts, 2);
    });

    test('wrong project types are skipped, valid rows survive', () {
      final Map<String, Object?> broken = _project().toJson();
      final Map<String, Object?> circuit =
          broken['circuit']! as Map<String, Object?>;
      final Map<String, Object?> node =
          (circuit['nodes']! as List<Object?>).first! as Map<String, Object?>;
      node['label'] = 42;

      final BackupPayload payload =
          BackupCodec.decode(
            jsonEncode(
              _envelope(projects: <Object?>[broken, _project().toJson()]),
            ),
          )!;

      expect(payload.projects.length, 1);
      expect(payload.projects.single.id, 'p1');
    });

    test('a project with a dangling wire is skipped', () {
      final Map<String, Object?> broken = _project().toJson();
      final Map<String, Object?> circuit =
          broken['circuit']! as Map<String, Object?>;
      (circuit['wires']! as List<Object?>).add(<String, Object?>{
        'id': 'w9',
        'from': 'a',
        'to': 'ghost',
        'toInput': 0,
        'fromPort': 0,
      });

      final BackupPayload payload =
          BackupCodec.decode(
            jsonEncode(_envelope(projects: <Object?>[broken])),
          )!;

      expect(payload.projects, isEmpty);
    });

    test('malformed or foreign files are rejected', () {
      expect(BackupCodec.decode('{not json'), isNull);
      expect(
        BackupCodec.decode(jsonEncode(<String, Object?>{'format': 'other'})),
        isNull,
      );
      final Map<String, Object?> newer = _envelope();
      newer['format'] = BackupCodec.formatId;
      newer['version'] = 99;
      expect(BackupCodec.decode(jsonEncode(newer)), isNull);
    });
  });
}
