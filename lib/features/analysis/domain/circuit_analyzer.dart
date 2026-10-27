import '../../editor/domain/circuit_models.dart';
import '../../editor/domain/circuit_simulator.dart';
import '../../editor/domain/component_spec.dart';

/// Static description of a circuit, used by the analysis screen.
class CircuitStatistics {
  const CircuitStatistics({
    required this.gateCount,
    required this.componentCount,
    required this.wireCount,
    required this.inputCount,
    required this.outputCount,
    required this.depth,
    required this.sequentialCount,
  });

  final int gateCount;
  final int componentCount;
  final int wireCount;
  final int inputCount;
  final int outputCount;

  /// Longest combinational path in gates, measured from an input to an
  /// output. Zero for a circuit without gates.
  final int depth;

  /// Number of sequential elements (latches, flip-flops, counters).
  final int sequentialCount;
}

/// Result of comparing two circuits.
class CircuitComparison {
  const CircuitComparison({
    required this.equivalent,
    required this.firstMismatchIndex,
    required this.mismatchDescription,
    required this.comparedRows,
    required this.leftStatistics,
    required this.rightStatistics,
    required this.problems,
  });

  /// True when both circuits produce the same output for every input
  /// combination.
  final bool equivalent;

  /// Index of the first input combination where the outputs differ.
  final int? firstMismatchIndex;

  /// Human readable explanation of the first difference.
  final String mismatchDescription;

  final int comparedRows;
  final CircuitStatistics leftStatistics;
  final CircuitStatistics rightStatistics;
  final List<CircuitProblem> problems;
}

/// Circuit analysis: statistics, equivalence and diagnostics.
///
/// The comparison is done on the real truth tables of both circuits, so it
/// respects the simulator semantics instead of comparing syntax.
class CircuitAnalyzer {
  const CircuitAnalyzer._();

  static CircuitStatistics statisticsOf(CircuitGraph graph) {
    int gates = 0;
    int sequential = 0;
    for (final CircuitNode node in graph.nodes) {
      final ComponentSpec spec = ComponentLibrary.specOf(node.type);
      if (spec.kind == ComponentKind.sequential) {
        sequential++;
      } else if (spec.kind == ComponentKind.gate) {
        gates++;
      }
    }
    return CircuitStatistics(
      gateCount: gates,
      componentCount: graph.nodes.length,
      wireCount: graph.wires.length,
      inputCount: graph.inputs.length,
      outputCount: graph.outputs.length,
      depth: _depthOf(graph),
      sequentialCount: sequential,
    );
  }

  /// Longest path through the circuit, counted in gates.
  static int _depthOf(CircuitGraph graph) {
    final Map<String, int> depth = <String, int>{
      for (final CircuitNode node in graph.nodes) node.id: 0,
    };
    final Map<String, List<String>> outgoing = <String, List<String>>{};
    for (final CircuitWire wire in graph.wires) {
      outgoing
          .putIfAbsent(wire.fromNodeId, () => <String>[])
          .add(wire.toNodeId);
    }
    int result = 0;
    // The graph may contain cycles; the iteration count is bounded by the
    // number of nodes, which keeps the analysis finite.
    for (int pass = 0; pass < graph.nodes.length; pass++) {
      bool changed = false;
      for (final CircuitWire wire in graph.wires) {
        final CircuitNode? source = graph.nodeById(wire.fromNodeId);
        if (source == null) {
          continue;
        }
        final ComponentSpec spec = ComponentLibrary.specOf(source.type);
        final int sourceDepth = depth[wire.fromNodeId] ?? 0;
        final int candidate = spec.kind == ComponentKind.gate
            ? sourceDepth + 1
            : sourceDepth;
        if (candidate > (depth[wire.toNodeId] ?? 0)) {
          depth[wire.toNodeId] = candidate;
          changed = true;
          if (candidate > result) {
            result = candidate;
          }
        }
      }
      if (!changed) {
        break;
      }
    }
    return result;
  }

  /// Compares two combinational circuits through their truth tables.
  static CircuitComparison compare(
    CircuitGraph left,
    CircuitGraph right, {
    int maxInputs = 6,
  }) {
    final CircuitStatistics leftStats = statisticsOf(left);
    final CircuitStatistics rightStats = statisticsOf(right);
    final List<CircuitProblem> problems = <CircuitProblem>[];

    if (left.inputs.length != right.inputs.length) {
      return CircuitComparison(
        equivalent: false,
        firstMismatchIndex: null,
        mismatchDescription:
            'تعداد ورودی‌های دو مدار یکسان نیست (${left.inputs.length} در برابر ${right.inputs.length}).',
        comparedRows: 0,
        leftStatistics: leftStats,
        rightStatistics: rightStats,
        problems: problems,
      );
    }

    final int inputCount = left.inputs.length;
    if (inputCount > maxInputs) {
      return CircuitComparison(
        equivalent: false,
        firstMismatchIndex: null,
        mismatchDescription:
            'برای مقایسه، حداکثر $maxInputs ورودی پشتیبانی می‌شود.',
        comparedRows: 0,
        leftStatistics: leftStats,
        rightStatistics: rightStats,
        problems: problems,
      );
    }

    final List<CircuitNode> inputs = left.inputs.toList()..sort(_compare);
    final int rows = inputCount == 0 ? 1 : (1 << inputCount);
    int? firstMismatch;
    String description = 'هر دو مدار برای همه ترکیب‌ها رفتار یکسانی دارند.';

    for (int combination = 0; combination < rows; combination++) {
      final Map<String, bool> values = <String, bool>{};
      for (int i = 0; i < inputs.length; i++) {
        values['$i'] = ((combination >> (inputs.length - i - 1)) & 1) == 1;
      }
      final SimulationResult leftResult = CircuitSimulator(
        _withInputs(left, values),
      ).evaluate();
      final SimulationResult rightResult = CircuitSimulator(
        _withInputs(right, values),
      ).evaluate();
      problems
        ..addAll(leftResult.errors)
        ..addAll(rightResult.errors);

      final List<bool?> leftValues = _outputValues(left, leftResult);
      final List<bool?> rightValues = _outputValues(right, rightResult);
      if (leftValues.length != rightValues.length) {
        return CircuitComparison(
          equivalent: false,
          firstMismatchIndex: combination,
          mismatchDescription:
              'تعداد خروجی‌های دو مدار یکسان نیست (${leftValues.length} در برابر ${rightValues.length}).',
          comparedRows: combination + 1,
          leftStatistics: leftStats,
          rightStatistics: rightStats,
          problems: problems,
        );
      }
      for (int index = 0; index < leftValues.length; index++) {
        if (leftValues[index] != rightValues[index]) {
          firstMismatch = combination;
          final String rowLabel = _rowLabel(inputs, combination);
          description =
              'در ترکیب $rowLabel خروجی شماره ${index + 1} در مدار اول '
              '${_describe(leftValues[index])} و در مدار دوم ${_describe(rightValues[index])} است.';
          break;
        }
      }
      if (firstMismatch != null) {
        break;
      }
    }

    return CircuitComparison(
      equivalent: firstMismatch == null,
      firstMismatchIndex: firstMismatch,
      mismatchDescription: description,
      comparedRows: rows,
      leftStatistics: leftStats,
      rightStatistics: rightStats,
      problems: problems,
    );
  }

  /// Applies the input values to a graph. The values are applied by the
  /// position of the input pins, so two circuits with different identifiers
  /// can still be compared.
  static CircuitGraph _withInputs(
    CircuitGraph graph,
    Map<String, bool> values,
  ) {
    final List<CircuitNode> ordered = graph.inputs.toList()..sort(_compare);
    return graph.copyWith(
      nodes: graph.nodes.map((CircuitNode node) {
        if (!node.type.isInput) {
          return node;
        }
        final int index = ordered.indexWhere(
          (CircuitNode input) => input.id == node.id,
        );
        return node.copyWith(
          inputValue: index >= 0 ? (values['$index'] ?? false) : false,
        );
      }).toList(),
    );
  }

  static List<bool?> _outputValues(
    CircuitGraph graph,
    SimulationResult result,
  ) {
    final List<bool?> values = <bool?>[];
    if (graph.outputs.isNotEmpty) {
      for (final CircuitNode probe in graph.outputs) {
        values.add(result.probeValue(probe.id));
      }
      return values;
    }
    for (final CircuitNode node in graph.nodes) {
      if (node.type.isOutput || node.type.isInput || node.outputCount <= 1) {
        continue;
      }
      for (int port = 0; port < node.outputCount; port++) {
        values.add(result.signalOf(node.id, port).booleanValue);
      }
    }
    return values;
  }

  static String _describe(bool? value) {
    if (value == null) {
      return 'نامشخص';
    }
    return value ? '۱' : '۰';
  }

  static String _rowLabel(List<CircuitNode> inputs, int combination) {
    if (inputs.isEmpty) {
      return 'بدون ورودی';
    }
    final List<String> parts = <String>[];
    for (int i = 0; i < inputs.length; i++) {
      final bool value = ((combination >> (inputs.length - i - 1)) & 1) == 1;
      parts.add('${inputs[i].label}=${value ? '1' : '0'}');
    }
    return parts.join('، ');
  }

  static int _compare(CircuitNode a, CircuitNode b) {
    final int byX = a.position.x.compareTo(b.position.x);
    if (byX != 0) {
      return byX;
    }
    final int byY = a.position.y.compareTo(b.position.y);
    if (byY != 0) {
      return byY;
    }
    return a.id.compareTo(b.id);
  }
}
