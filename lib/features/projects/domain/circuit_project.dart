import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/utils/id_generator.dart';
import '../../../features/editor/domain/circuit_models.dart';

@immutable
class CircuitProject {
  const CircuitProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.graph,
  });

  static const int schemaVersion = 1;

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CircuitGraph graph;

  int get componentCount => graph.nodes.length;
  int get wireCount => graph.wires.length;
  int get inputCount => graph.inputs.length;
  int get outputCount => graph.outputs.length;

  CircuitProject copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    CircuitGraph? graph,
  }) {
    return CircuitProject(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      graph: graph ?? this.graph,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'circuit': graph.toJson(),
  };

  factory CircuitProject.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('اطلاعات پروژه باید یک شیء باشد.');
    }
    final Object? id = raw['id'];
    final Object? name = raw['name'];
    final Object? createdAtRaw = raw['createdAt'];
    final Object? updatedAtRaw = raw['updatedAt'];
    final Object? circuit = raw['circuit'] ?? raw['graph'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('شناسه پروژه معتبر نیست.');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('نام پروژه نمی‌تواند خالی باشد.');
    }
    if (name.trim().length > 80) {
      throw const FormatException('نام پروژه بیش از ۸۰ نویسه است.');
    }
    if (createdAtRaw is! String || updatedAtRaw is! String) {
      throw const FormatException('تاریخ‌های پروژه معتبر نیستند.');
    }
    final DateTime? createdAt = DateTime.tryParse(createdAtRaw);
    final DateTime? updatedAt = DateTime.tryParse(updatedAtRaw);
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('قالب تاریخ پروژه معتبر نیست.');
    }
    return CircuitProject(
      id: id,
      name: name.trim(),
      createdAt: createdAt.toLocal(),
      updatedAt: updatedAt.toLocal(),
      graph: CircuitGraph.fromJson(circuit),
    );
  }

  bool get isValid => graph.hasOutput;

  @override
  String toString() => 'CircuitProject($id, $name)';
}

class ProjectFileFormatException implements Exception {
  const ProjectFileFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Portable project envelope. It contains only portable JSON and never stores
/// absolute file paths or platform-specific state.
class ProjectCodec {
  const ProjectCodec._();

  static const String formatId = 'logic-lab-project';
  static const int formatVersion = 1;

  static String encode(CircuitProject project) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'format': formatId,
      'version': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'project': project.toJson(),
    });
  }

  static CircuitProject decode(String source, {bool asCopy = false}) {
    if (source.length > maxFileLength) {
      throw ProjectFileFormatException(
        'حجم فایل بیش از حد مجاز است (حداکثر ${maxFileLength ~/ (1024 * 1024)} مگابایت).',
      );
    }
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      throw const ProjectFileFormatException(
        'فایل JSON معتبر نیست. ممکن است فایل آسیب دیده یا ناقص باشد.',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw const ProjectFileFormatException('ساختار فایل پروژه معتبر نیست.');
    }
    final Object? format = raw['format'];
    final Object? version = raw['version'];
    if (format != formatId) {
      throw const ProjectFileFormatException(
        'این فایل مربوط به Logic Lab نیست.',
      );
    }
    if (version is! num) {
      throw const ProjectFileFormatException('نسخه فایل مشخص نیست.');
    }
    if (version.toInt() > formatVersion) {
      throw ProjectFileFormatException(
        'نسخه فایل (${version.toInt()}) جدیدتر از نسخه پشتیبانی‌شده است.',
      );
    }
    if (version.toInt() < 1) {
      throw const ProjectFileFormatException('نسخه فایل پشتیبانی نمی‌شود.');
    }
    try {
      final CircuitProject project = CircuitProject.fromJson(raw['project']);
      // The whole circuit is validated before the project is accepted, so a
      // broken file can never replace the work that is already open.
      validateCircuit(project.graph);
      if (!asCopy) {
        return project;
      }
      final DateTime now = DateTime.now();
      return project.copyWith(
        id: IdGenerator.next('p'),
        name: '${project.name} (واردشده)',
        createdAt: now,
        updatedAt: now,
      );
    } on ProjectFileFormatException {
      rethrow;
    } on FormatException catch (error) {
      throw ProjectFileFormatException(
        'محتوای پروژه معتبر نیست: ${error.message}',
      );
    } catch (_) {
      // A hand-edited file with wrong value types must produce a readable
      // import error, not a raw TypeError inside the editor.
      throw const ProjectFileFormatException(
        'محتوای پروژه معتبر نیست. فایل ممکن است آسیب دیده باشد.',
      );
    }
  }

  /// Maximum size of a project file that is accepted.
  static const int maxFileLength = 4 * 1024 * 1024;

  /// Verifies that every wire of the circuit points at existing components and
  /// at ports that really exist.
  static void validateCircuit(CircuitGraph graph) {
    for (final CircuitWire wire in graph.wires) {
      final CircuitNode? from = graph.nodeById(wire.fromNodeId);
      final CircuitNode? to = graph.nodeById(wire.toNodeId);
      if (from == null || to == null) {
        throw const ProjectFileFormatException(
          'یکی از سیم‌های مدار به قطعه‌ای ناموجود اشاره می‌کند.',
        );
      }
      if (wire.toInputIndex < 0 || wire.toInputIndex >= to.inputCount) {
        throw ProjectFileFormatException(
          'اتصال به پایهٔ ورودی نامعتبر «${to.label}» در فایل وجود دارد.',
        );
      }
      if (wire.fromPortIndex < 0 || wire.fromPortIndex >= from.outputCount) {
        throw ProjectFileFormatException(
          'اتصال به پایهٔ خروجی نامعتبر «${from.label}» در فایل وجود دارد.',
        );
      }
    }
  }

  static String safeFileName(String name) {
    final String cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'logic-lab-project';
    }
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }
}

class ProjectTemplate {
  const ProjectTemplate._();

  static CircuitGraph quickGateCircuit(
    ComponentType gateType, {
    int inputCount = 2,
  }) {
    final List<CircuitNode> nodes = <CircuitNode>[];
    final List<CircuitWire> wires = <CircuitWire>[];
    final int count = gateType == ComponentType.notGate
        ? 1
        : inputCount.clamp(2, 4);
    final double gateY = 220;
    for (int i = 0; i < count; i++) {
      final CircuitNode input = CircuitNode(
        id: IdGenerator.next('in'),
        type: ComponentType.inputPin,
        position: CanvasPoint(110, 130 + i * 140),
        label: String.fromCharCode(65 + i),
        inputValue: false,
      );
      nodes.add(input);
      wires.add(
        CircuitWire(
          id: IdGenerator.next('w'),
          fromNodeId: input.id,
          toNodeId: '@gate',
          toInputIndex: i,
        ),
      );
    }
    final CircuitNode gate = CircuitNode(
      id: IdGenerator.next('g'),
      type: gateType,
      position: CanvasPoint(390, gateY),
      label: gateType.technicalName,
      inputCount: count,
    );
    final CircuitNode output = CircuitNode(
      id: IdGenerator.next('out'),
      type: ComponentType.outputPin,
      position: CanvasPoint(670, gateY),
      label: 'Y',
    );
    nodes
      ..add(gate)
      ..add(output);
    final List<CircuitWire> finalWires = wires.map((CircuitWire wire) {
      return wire.toNodeId == '@gate' ? wire.copyWith(toNodeId: gate.id) : wire;
    }).toList();
    finalWires.add(
      CircuitWire(
        id: IdGenerator.next('w'),
        fromNodeId: gate.id,
        toNodeId: output.id,
        toInputIndex: 0,
      ),
    );
    return CircuitGraph(nodes: nodes, wires: finalWires);
  }

  static CircuitGraph blank() {
    return CircuitGraph(
      nodes: <CircuitNode>[
        CircuitNode(
          id: IdGenerator.next('in'),
          type: ComponentType.inputPin,
          position: const CanvasPoint(150, 220),
          label: 'A',
        ),
      ],
    );
  }
}
