import 'component_spec.dart';
import 'component_type.dart';

export 'component_type.dart';

/// A node of the circuit graph.
///
/// Besides classic gates a node can be a compound module with several inputs
/// and outputs (a full adder, a multiplexer, a decoder …) or a sequential
/// element (a latch, a flip-flop, a counter). The number of ports is derived
/// from the component specification so the model stays consistent.
class CircuitNode {
  CircuitNode({
    required this.id,
    required this.type,
    required this.position,
    required this.label,
    this.inputValue = false,
    int? inputCount,
    int? outputCount,
  }) : inputCount = _validatedInputCount(type, inputCount),
       outputCount = _validatedOutputCount(type, outputCount);

  final String id;
  final ComponentType type;
  final CanvasPoint position;
  final String label;

  /// Only meaningful for input pins. Always stored as a bool; the simulator
  /// turns it into a definitive HIGH or LOW.
  final bool inputValue;

  /// Number of input ports.
  final int inputCount;

  /// Number of output ports (0 for a sink, 1 for gates, N for modules).
  final int outputCount;

  static int _validatedInputCount(ComponentType type, int? value) {
    final ComponentSpec spec = ComponentLibrary.specOf(type);
    if (spec.configurableInputs) {
      final int requested = value ?? spec.minInputs;
      return requested.clamp(spec.minInputs, spec.maxInputs);
    }
    if (spec.fixedInputCount > 0) {
      return spec.fixedInputCount;
    }
    return value ?? 0;
  }

  static int _validatedOutputCount(ComponentType type, int? value) {
    final ComponentSpec spec = ComponentLibrary.specOf(type);
    if (spec.outputLabels.isNotEmpty) {
      return spec.outputLabels.length;
    }
    return value ?? 0;
  }

  CircuitNode copyWith({
    String? id,
    ComponentType? type,
    CanvasPoint? position,
    String? label,
    bool? inputValue,
    int? inputCount,
    int? outputCount,
  }) {
    return CircuitNode(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      label: label ?? this.label,
      inputValue: inputValue ?? this.inputValue,
      inputCount: inputCount ?? this.inputCount,
      outputCount: outputCount ?? this.outputCount,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.jsonName,
    'x': position.x,
    'y': position.y,
    'label': label,
    'inputValue': inputValue,
    'inputCount': inputCount,
    'outputCount': outputCount,
  };

  factory CircuitNode.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('قطعه مدار باید یک شیء باشد.');
    }
    final Object? rawId = raw['id'];
    final Object? rawType = raw['type'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('شناسه قطعه معتبر نیست.');
    }
    if (rawType is! String) {
      throw const FormatException('نوع قطعه معتبر نیست.');
    }
    final Object? rawX = raw['x'];
    final Object? rawY = raw['y'];
    if (rawX is! num || rawY is! num) {
      throw const FormatException('موقعیت قطعه معتبر نیست.');
    }
    final double x = rawX.toDouble();
    final double y = rawY.toDouble();
    if (!x.isFinite || !y.isFinite || x.abs() > 100000 || y.abs() > 100000) {
      throw const FormatException('موقعیت قطعه خارج از محدوده است.');
    }
    final Object? rawInputCount = raw['inputCount'];
    final Object? rawOutputCount = raw['outputCount'];
    final String parsedLabel =
        (raw['label'] as String? ?? '').trim().isEmpty
            ? ComponentLibrary.specOf(ComponentType.fromJson(rawType)).title
            : (raw['label'] as String).trim();
    return CircuitNode(
      id: rawId,
      type: ComponentType.fromJson(rawType),
      position: CanvasPoint(x, y),
      label: parsedLabel,
      inputValue: raw['inputValue'] as bool? ?? false,
      inputCount: rawInputCount is num ? rawInputCount.toInt() : null,
      outputCount: rawOutputCount is num ? rawOutputCount.toInt() : null,
    );
  }

  @override
  String toString() => 'CircuitNode($id, ${type.jsonName}, $label)';
}

class CircuitWire {
  const CircuitWire({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.toInputIndex,
    this.fromPortIndex = 0,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final int toInputIndex;
  final int fromPortIndex;

  CircuitWire copyWith({
    String? id,
    String? fromNodeId,
    String? toNodeId,
    int? toInputIndex,
    int? fromPortIndex,
  }) {
    return CircuitWire(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      toInputIndex: toInputIndex ?? this.toInputIndex,
      fromPortIndex: fromPortIndex ?? this.fromPortIndex,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'from': fromNodeId,
    'to': toNodeId,
    'toInput': toInputIndex,
    'fromPort': fromPortIndex,
  };

  factory CircuitWire.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('سیم باید یک شیء باشد.');
    }
    final Object? id = raw['id'];
    final Object? from = raw['from'];
    final Object? to = raw['to'];
    final Object? toInput = raw['toInput'];
    final Object? fromPort = raw['fromPort'] ?? 0;
    if (id is! String || id.isEmpty || from is! String || to is! String) {
      throw const FormatException('اطلاعات سیم کامل نیست.');
    }
    if (toInput is! num || fromPort is! num) {
      throw const FormatException('شماره پایه سیم معتبر نیست.');
    }
    return CircuitWire(
      id: id,
      fromNodeId: from,
      toNodeId: to,
      toInputIndex: toInput.toInt(),
      fromPortIndex: fromPort.toInt(),
    );
  }
}

enum CircuitProblemCode {
  malformedWire,
  sourceIsOutput,
  targetIsInput,
  invalidPort,
  duplicateInputConnection,
  unconnectedInput,
  noOutput,
  noInputs,
  cycle,
  unsupportedComponent,
  illegalLatchState,
  unknownClock,
  unstableFeedback,
}

class CircuitProblem {
  const CircuitProblem({
    required this.code,
    required this.message,
    this.nodeId,
    this.wireId,
    this.severity = CircuitProblemSeverity.error,
  });

  final CircuitProblemCode code;
  final String message;
  final String? nodeId;
  final String? wireId;
  final CircuitProblemSeverity severity;

  bool get isError => severity == CircuitProblemSeverity.error;

  @override
  String toString() => 'CircuitProblem($code, $message)';
}

enum CircuitProblemSeverity { error, warning }

/// Immutable circuit graph. All editing operations return new graphs, which
/// makes undo/redo and autosave snapshots straightforward and predictable.
class CircuitGraph {
  CircuitGraph({
    Iterable<CircuitNode> nodes = const <CircuitNode>[],
    Iterable<CircuitWire> wires = const <CircuitWire>[],
  }) : nodes = List<CircuitNode>.unmodifiable(nodes),
       wires = List<CircuitWire>.unmodifiable(wires) {
    _index = _buildIndex();
  }

  factory CircuitGraph.empty() => CircuitGraph();

  final List<CircuitNode> nodes;
  final List<CircuitWire> wires;

  /// Lookup table for [nodeById]. The graph is immutable, so the index is
  /// built once instead of scanning the node list on every lookup: the canvas
  /// painter and the simulator look up nodes for every wire on every frame.
  late final Map<String, CircuitNode> _index;

  Map<String, CircuitNode> _buildIndex() {
    final Map<String, CircuitNode> index = <String, CircuitNode>{};
    for (final CircuitNode node in nodes) {
      if (index.containsKey(node.id)) {
        throw FormatException('شناسه تکراری قطعه: ${node.id}');
      }
      index[node.id] = node;
    }
    final Set<String> wireIds = <String>{};
    for (final CircuitWire wire in wires) {
      if (!wireIds.add(wire.id)) {
        throw FormatException('شناسه تکراری سیم: ${wire.id}');
      }
    }
    return index;
  }

  bool get isEmpty => nodes.isEmpty && wires.isEmpty;
  bool get hasOutput => nodes.any((CircuitNode n) => n.type.isOutput);

  List<CircuitNode> get inputs =>
      nodes.where((CircuitNode n) => n.type.isInput).toList(growable: false);

  List<CircuitNode> get outputs =>
      nodes.where((CircuitNode n) => n.type.isOutput).toList(growable: false);

  /// Nodes that expose more than one output (compound modules).
  List<CircuitNode> get multiOutputNodes => nodes
      .where((CircuitNode node) => node.outputCount > 1)
      .toList(growable: false);

  /// True when the circuit contains stateful elements.
  bool get hasSequentialParts => nodes.any(
    (CircuitNode node) => ComponentLibrary.specOf(node.type).isStateful,
  );

  CircuitNode? nodeById(String id) => _index[id];

  CircuitNode? get firstOutput {
    for (final CircuitNode node in nodes) {
      if (node.type.isOutput) {
        return node;
      }
    }
    return null;
  }

  List<CircuitWire> incomingWires(String nodeId) {
    return wires
        .where((CircuitWire wire) => wire.toNodeId == nodeId)
        .toList(growable: false);
  }

  List<CircuitWire> outgoingWires(String nodeId) {
    return wires
        .where((CircuitWire wire) => wire.fromNodeId == nodeId)
        .toList(growable: false);
  }

  CircuitGraph copyWith({
    Iterable<CircuitNode>? nodes,
    Iterable<CircuitWire>? wires,
  }) {
    return CircuitGraph(nodes: nodes ?? this.nodes, wires: wires ?? this.wires);
  }

  CircuitGraph addNode(CircuitNode node) {
    if (nodeById(node.id) != null) {
      throw ArgumentError('شناسه قطعه تکراری است.');
    }
    return copyWith(nodes: <CircuitNode>[...nodes, node]);
  }

  CircuitGraph updateNode(CircuitNode updated) {
    if (nodeById(updated.id) == null) {
      throw ArgumentError('قطعه پیدا نشد.');
    }
    return copyWith(
      nodes: nodes
          .map((CircuitNode node) => node.id == updated.id ? updated : node)
          .toList(growable: false),
    );
  }

  CircuitGraph removeNode(String id) {
    return copyWith(
      nodes: nodes.where((CircuitNode node) => node.id != id).toList(),
      wires:
          wires
              .where(
                (CircuitWire wire) =>
                    wire.fromNodeId != id && wire.toNodeId != id,
              )
              .toList(),
    );
  }

  CircuitGraph clearChildren(String nodeId) {
    return copyWith(
      wires: wires
          .where((CircuitWire wire) => wire.toNodeId != nodeId)
          .toList(growable: false),
    );
  }

  CircuitGraph addWire(CircuitWire wire) {
    if (wires.any((CircuitWire existing) => existing.id == wire.id)) {
      throw ArgumentError('شناسه سیم تکراری است.');
    }
    return copyWith(wires: <CircuitWire>[...wires, wire]);
  }

  CircuitGraph removeWire(String wireId) {
    return copyWith(
      wires: wires.where((CircuitWire wire) => wire.id != wireId).toList(),
    );
  }

  CircuitGraph updateWire(CircuitWire wire) {
    return copyWith(
      wires:
          wires
              .map(
                (CircuitWire existing) =>
                    existing.id == wire.id ? wire : existing,
              )
              .toList(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'nodes': nodes.map((CircuitNode node) => node.toJson()).toList(),
    'wires': wires.map((CircuitWire wire) => wire.toJson()).toList(),
  };

  factory CircuitGraph.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('داده مدار باید یک شیء باشد.');
    }
    final Object? version = raw['schemaVersion'];
    if (version is num && version.toInt() > 1) {
      throw FormatException('نسخه مدار پشتیبانی نمی‌شود: $version');
    }
    final Object? rawNodes = raw['nodes'];
    final Object? rawWires = raw['wires'] ?? const <Object?>[];
    if (rawNodes is! List || rawWires is! List) {
      throw const FormatException('ساختار مدار نامعتبر است.');
    }
    if (rawNodes.length > 500 || rawWires.length > 2000) {
      throw const FormatException('مدار بیش از حد بزرگ است.');
    }
    return CircuitGraph(
      nodes: rawNodes.map(CircuitNode.fromJson).toList(),
      wires: rawWires.map(CircuitWire.fromJson).toList(),
    );
  }

  @override
  String toString() {
    return 'CircuitGraph(nodes: ${nodes.length}, wires: ${wires.length})';
  }
}
