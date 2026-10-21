import '../../editor/domain/circuit_models.dart';
import '../../editor/domain/circuit_simulator.dart';

class TruthTableLimits {
  const TruthTableLimits({this.maxInputs = 8, this.maxRows = 256});

  final int maxInputs;
  final int maxRows;

  TruthTableLimits copyWith({int? maxInputs, int? maxRows}) {
    return TruthTableLimits(
      maxInputs: maxInputs ?? this.maxInputs,
      maxRows: maxRows ?? this.maxRows,
    );
  }

  int get maxSupportedRows {
    if (maxInputs <= 0) {
      return 1;
    }
    if (maxInputs >= 30) {
      return maxRows;
    }
    return 1 << maxInputs;
  }

  TruthTableLimits withMaxRows(int rows) {
    return TruthTableLimits(maxInputs: maxInputs, maxRows: rows);
  }
}

class TruthTableGenerationException implements Exception {
  const TruthTableGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One output column of the table.
class TruthTableOutput {
  const TruthTableOutput({
    required this.nodeId,
    required this.port,
    required this.label,
  });

  final String nodeId;
  final int port;
  final String label;
}

class TruthTableRow {
  const TruthTableRow({
    required this.index,
    required this.inputs,
    required this.outputs,
    required this.circuitValid,
    required this.unknownCount,
  });

  final int index;
  final Map<String, bool> inputs;

  /// Unknown outputs are null and are rendered as «؟», never fabricated.
  final Map<String, bool?> outputs;
  final bool circuitValid;
  final int unknownCount;
}

class TruthTableResult {
  const TruthTableResult({
    required this.rows,
    required this.inputNodes,
    required this.outputs,
    required this.limits,
    required this.problems,
    required this.allRowsValid,
    required this.currentInputRow,
  });

  final List<TruthTableRow> rows;
  final List<CircuitNode> inputNodes;

  /// Output columns: probes first, otherwise the outputs of multi-output
  /// modules (a full adder, a decoder, …).
  final List<TruthTableOutput> outputs;
  final TruthTableLimits limits;
  final List<CircuitProblem> problems;
  final bool allRowsValid;

  /// Index of the binary combination matching the current input switches, or
  /// null when the table was limited and the combination is absent.
  final int? currentInputRow;

  int get inputCount => inputNodes.length;
  int get outputCount => outputs.length;

  List<String> get inputLabels =>
      inputNodes.map((CircuitNode node) => node.label).toList(growable: false);

  List<String> get outputLabels => outputs
      .map((TruthTableOutput output) => output.label)
      .toList(growable: false);

  /// CSV with ASCII bits so values remain portable and unambiguous. A UTF-8
  /// BOM is available for spreadsheet apps on Android.
  String toCsv({bool includeBom = false}) {
    final StringBuffer buffer = StringBuffer();
    if (includeBom) {
      buffer.write('\uFEFF');
    }
    buffer.writeln(
      <String>[
        ...inputLabels.map(_escapeCsv),
        ...outputLabels.map(_escapeCsv),
      ].join(','),
    );
    for (final TruthTableRow row in rows) {
      final List<String> cells = <String>[
        for (final CircuitNode node in inputNodes)
          (row.inputs[node.id] ?? false) ? '1' : '0',
        for (final TruthTableOutput output in outputs)
          switch (row.outputs[_outputKey(output)]) {
            true => '1',
            false => '0',
            null => '?',
          },
      ];
      buffer.writeln(cells.join(','));
    }
    return buffer.toString();
  }

  static String _outputKey(TruthTableOutput output) =>
      output.port == 0 ? output.nodeId : '${output.nodeId}#${output.port}';

  static String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class TruthTableGenerator {
  const TruthTableGenerator();

  TruthTableResult generate(
    CircuitGraph graph, {
    TruthTableLimits limits = const TruthTableLimits(),
  }) {
    final List<CircuitNode> inputs = graph.inputs.toList()..sort(_compareNodes);
    final List<TruthTableOutput> outputs = _collectOutputs(graph);

    if (inputs.length > limits.maxInputs) {
      throw TruthTableGenerationException(
        'این مدار ${inputs.length} ورودی دارد؛ '
        'جدول حقیقت حداکثر برای ${limits.maxInputs} ورودی در این نسخه محاسبه می‌شود.',
      );
    }

    final int combinationCount = inputs.isEmpty ? 1 : (1 << inputs.length);
    if (combinationCount > limits.maxRows) {
      throw TruthTableGenerationException(
        'تعداد ردیف‌ها ($combinationCount) از سقف محاسبه '
        '(${limits.maxRows}) بیشتر است. سقف را افزایش دهید یا ورودی‌ها را کم کنید.',
      );
    }

    final List<TruthTableRow> rows = <TruthTableRow>[];
    List<CircuitProblem> lastProblems = const <CircuitProblem>[];
    bool allRowsValid = true;
    int? currentRow;
    final int? currentCombination = _combinationForCurrentInputs(inputs);
    if (currentCombination != null) {
      currentRow = currentCombination;
    }

    for (int combination = 0; combination < combinationCount; combination++) {
      final Map<String, bool> values = <String, bool>{};
      for (int i = 0; i < inputs.length; i++) {
        final int shift = inputs.length - 1 - i;
        values[inputs[i].id] = ((combination >> shift) & 1) == 1;
      }
      final CircuitGraph subset = graph.copyWith(
        nodes: graph.nodes.map((CircuitNode node) {
          if (!node.type.isInput) {
            return node;
          }
          return node.copyWith(inputValue: values[node.id] ?? false);
        }),
      );
      final SimulationResult report = CircuitSimulator(subset).evaluate();
      if (report.hasErrors) {
        allRowsValid = false;
      }
      lastProblems = report.problems;
      int unknown = 0;
      final Map<String, bool?> outputValues = <String, bool?>{};
      for (final TruthTableOutput output in outputs) {
        final bool? value =
            report.isValid
                ? report.signalOf(output.nodeId, output.port).booleanValue
                : null;
        outputValues[_key(output)] = value;
        if (value == null) {
          unknown++;
        }
      }
      rows.add(
        TruthTableRow(
          index: combination,
          inputs: Map<String, bool>.unmodifiable(values),
          outputs: Map<String, bool?>.unmodifiable(outputValues),
          circuitValid: report.isValid,
          unknownCount: unknown,
        ),
      );
    }

    return TruthTableResult(
      rows: List<TruthTableRow>.unmodifiable(rows),
      inputNodes: List<CircuitNode>.unmodifiable(inputs),
      outputs: List<TruthTableOutput>.unmodifiable(outputs),
      limits: limits,
      problems: List<CircuitProblem>.unmodifiable(lastProblems),
      allRowsValid: allRowsValid && outputs.isNotEmpty,
      currentInputRow: currentRow,
    );
  }

  static String _key(TruthTableOutput output) =>
      output.port == 0 ? output.nodeId : '${output.nodeId}#${output.port}';

  /// Probes are preferred; when a circuit has none, the outputs of the
  /// multi-output modules are used instead.
  static List<TruthTableOutput> _collectOutputs(CircuitGraph graph) {
    final List<TruthTableOutput> probes = <TruthTableOutput>[];
    for (final CircuitNode node in graph.outputs) {
      probes.add(TruthTableOutput(nodeId: node.id, port: 0, label: node.label));
    }
    if (probes.isNotEmpty) {
      return probes;
    }
    final List<TruthTableOutput> moduleOutputs = <TruthTableOutput>[];
    for (final CircuitNode node in graph.nodes) {
      if (node.type.isOutput || node.type.isInput) {
        continue;
      }
      if (node.outputCount <= 1) {
        continue;
      }
      for (int port = 0; port < node.outputCount; port++) {
        moduleOutputs.add(
          TruthTableOutput(
            nodeId: node.id,
            port: port,
            label: port == 0 ? node.label : '${node.label}.$port',
          ),
        );
      }
    }
    return moduleOutputs;
  }

  int? _combinationForCurrentInputs(List<CircuitNode> inputs) {
    int combination = 0;
    for (final CircuitNode input in inputs) {
      combination = (combination << 1) | (input.inputValue ? 1 : 0);
    }
    return combination;
  }

  static int _compareNodes(CircuitNode a, CircuitNode b) {
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
