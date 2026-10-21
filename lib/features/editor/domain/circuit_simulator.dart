import 'component_spec.dart';
import 'circuit_models.dart';

/// Result of one simulation pass.
class SimulationResult {
  const SimulationResult({
    required this.outputSignals,
    required this.inputSignals,
    required this.problems,
    required this.evaluatedNodeIds,
    required this.clockLevel,
  });

  /// Signal of every output port of every node, indexed by node id and then
  /// by output port index.
  final Map<String, List<LogicSignal>> outputSignals;

  /// Signal reaching every input port, indexed by node id and then by port.
  final Map<String, List<LogicSignal>> inputSignals;

  final List<CircuitProblem> problems;
  final Set<String> evaluatedNodeIds;

  /// Current level of the clock generator (0 or 1).
  final bool clockLevel;

  bool get isValid => problems.every((CircuitProblem p) => !p.isError);
  bool get hasErrors => !isValid;

  List<CircuitProblem> get errors =>
      problems.where((CircuitProblem p) => p.isError).toList(growable: false);

  List<CircuitProblem> get warnings =>
      problems.where((CircuitProblem p) => !p.isError).toList(growable: false);

  /// Signal of one output port.
  LogicSignal signalOf(String nodeId, [int port = 0]) {
    final List<LogicSignal>? signals = outputSignals[nodeId];
    if (signals == null || port >= signals.length) {
      return LogicSignal.unknown;
    }
    return signals[port];
  }

  /// Signal of one input port.
  LogicSignal inputOf(String nodeId, int port) {
    final List<LogicSignal>? signals = inputSignals[nodeId];
    if (signals == null || port >= signals.length) {
      return LogicSignal.unknown;
    }
    return signals[port];
  }

  /// Signal of a wire, taken from the driver of the wire.
  LogicSignal signalForWire(CircuitWire wire) {
    return signalOf(wire.fromNodeId, wire.fromPortIndex);
  }

  /// The value shown by an output probe (the signal that reaches it).
  bool? probeValue(String outputNodeId) {
    return inputOf(outputNodeId, 0).booleanValue;
  }

  /// Compact result used by truth tables: unknown values are encoded as null.
  List<bool?> outputValuesFor(CircuitGraph graph) {
    return graph.outputs
        .map((CircuitNode node) => probeValue(node.id))
        .toList(growable: false);
  }
}

/// Stateful simulation engine.
///
/// The engine evaluates a combinational network with a three-valued (plus
/// high-impedance) signal model and keeps the state of sequential elements so
/// that latches, flip-flops, registers and counters behave like real digital
/// hardware:
///
/// * Level-sensitive elements (latches) update their state while they are
///   enabled. This can create a feedback loop, so the engine iterates the
///   evaluation until it converges or reports an unstable circuit.
/// * Edge-triggered elements (flip-flops, registers, counters) only capture
///   their input on a rising clock edge, which the user controls manually
///   with [stepClock] or with the automatic clock in the editor.
class CircuitSimulator {
  CircuitSimulator(CircuitGraph graph) : _graph = graph {
    _states = <String, ComponentState>{};
    for (final CircuitNode node in _graph.nodes) {
      final ComponentState? initial =
          ComponentLibrary.specOf(node.type).initialState?.call();
      if (initial != null) {
        _states[node.id] = initial;
      }
    }
  }

  /// Upper bound for the fix-point iterations of feedback loops.
  static const int maxIterations = 24;

  CircuitGraph _graph;
  late final Map<String, ComponentState> _states;
  bool _clockLevel = false;
  SimulationResult? _lastResult;

  CircuitGraph get currentGraph => _graph;
  bool get clockLevel => _clockLevel;
  Map<String, ComponentState> get states =>
      Map<String, ComponentState>.unmodifiable(_states);

  SimulationResult get result => _lastResult ?? evaluate();

  /// Replaces the graph while keeping the state of components that still
  /// exist. This lets the editor keep the counter or flip-flop state alive
  /// while the user is still wiring the circuit.
  void updateGraph(CircuitGraph newGraph) {
    _states.removeWhere(
      (String key, ComponentState value) => newGraph.nodeById(key) == null,
    );
    for (final CircuitNode node in newGraph.nodes) {
      if (_states.containsKey(node.id)) {
        continue;
      }
      final ComponentState? initial =
          ComponentLibrary.specOf(node.type).initialState?.call();
      if (initial != null) {
        _states[node.id] = initial;
      }
    }
    _graph = newGraph;
    _lastResult = null;
  }

  /// Clears every sequential state and returns the clock to its low level.
  void reset() {
    for (final CircuitNode node in _graph.nodes) {
      final ComponentState? initial =
          ComponentLibrary.specOf(node.type).initialState?.call();
      if (initial != null) {
        _states[node.id] = initial;
      }
    }
    _clockLevel = false;
    _lastResult = evaluate();
  }

  /// Performs one complete clock cycle: a rising edge (which captures the
  /// state of edge-triggered elements) followed by a falling edge.
  SimulationResult stepClock() {
    _clockLevel = true;
    SimulationResult result = evaluate();
    _clockLevel = false;
    result = evaluate();
    return result;
  }

  /// Sets the clock level explicitly (used by the editor's clock control).
  SimulationResult setClockLevel(bool level) {
    _clockLevel = level;
    return evaluate();
  }

  /// Evaluates the circuit and returns the current state of every node.
  SimulationResult evaluate() {
    final List<CircuitProblem> problems = <CircuitProblem>[];
    final Set<String> issueKeys = <String>{};

    void addProblem(CircuitProblem problem) {
      final String key =
          '${problem.code.name}|${problem.nodeId}|${problem.wireId}|${problem.message}';
      if (issueKeys.add(key)) {
        problems.add(problem);
      }
    }

    final Map<String, LogicSignal> inputNodeValues = <String, LogicSignal>{
      for (final CircuitNode node in _graph.nodes)
        if (node.type.isInput)
          node.id: node.inputValue ? LogicSignal.high : LogicSignal.low,
    };

    if (!_graph.hasOutput) {
      addProblem(
        const CircuitProblem(
          code: CircuitProblemCode.noOutput,
          message:
              'مدار پایه خروجی ندارد؛ برای محاسبه نتیجه یک خروجی اضافه کنید.',
        ),
      );
    }
    if (_graph.inputs.isEmpty) {
      addProblem(
        const CircuitProblem(
          code: CircuitProblemCode.noInputs,
          message: 'این مدار ورودی مستقل ندارد.',
          severity: CircuitProblemSeverity.warning,
        ),
      );
    }

    final Set<String> malformedPorts = <String>{};
    final Set<String> duplicatePorts = <String>{};
    final Map<String, CircuitWire> validWireByPort = <String, CircuitWire>{};
    final List<CircuitWire> structuralWires = <CircuitWire>[];

    for (final CircuitWire wire in _graph.wires) {
      final CircuitNode? source = _graph.nodeById(wire.fromNodeId);
      final CircuitNode? target = _graph.nodeById(wire.toNodeId);
      if (source == null || target == null) {
        addProblem(
          CircuitProblem(
            code: CircuitProblemCode.malformedWire,
            message: 'یکی از سیم‌ها به قطعه‌ای ناموجود وصل است.',
            wireId: wire.id,
          ),
        );
        continue;
      }
      if (source.type.isOutput) {
        addProblem(
          CircuitProblem(
            code: CircuitProblemCode.sourceIsOutput,
            message: 'سیم از پایه‌ای شروع می‌شود که سیگنال تولید نمی‌کند.',
            wireId: wire.id,
            nodeId: source.id,
          ),
        );
        continue;
      }
      if (target.type.isInput) {
        addProblem(
          CircuitProblem(
            code: CircuitProblemCode.targetIsInput,
            message: 'سیم به ورودی متصل شده است؛ ورودی سیگنال نمی‌پذیرد.',
            wireId: wire.id,
            nodeId: target.id,
          ),
        );
        continue;
      }
      if (wire.toInputIndex < 0 ||
          wire.toInputIndex >= target.inputCount ||
          wire.fromPortIndex < 0 ||
          wire.fromPortIndex >= source.outputCount) {
        addProblem(
          CircuitProblem(
            code: CircuitProblemCode.invalidPort,
            message: 'اتصال به پایه‌ای نامعتبر انجام شده است.',
            wireId: wire.id,
            nodeId: target.id,
          ),
        );
        malformedPorts.add('${target.id}:${wire.toInputIndex}');
        continue;
      }
      final String portKey = '${target.id}:${wire.toInputIndex}';
      structuralWires.add(wire);
      if (validWireByPort.containsKey(portKey)) {
        duplicatePorts.add(portKey);
        addProblem(
          CircuitProblem(
            code: CircuitProblemCode.duplicateInputConnection,
            message: 'بیش از یک سیم به یک پایه ورودی وصل شده است.',
            wireId: wire.id,
            nodeId: target.id,
          ),
        );
        continue;
      }
      validWireByPort[portKey] = wire;
    }

    for (final CircuitNode node in _graph.nodes) {
      if (node.type.isInput || node.type.isClock) {
        continue;
      }
      if (node.type == ComponentType.unknown) {
        addProblem(
          CircuitProblem(
            code: CircuitProblemCode.unsupportedComponent,
            message:
                'نوع قطعه «${node.label}» در این نسخه پشتیبانی نمی‌شود و محاسبه نمی‌شود.',
            nodeId: node.id,
          ),
        );
        continue;
      }
      for (int port = 0; port < node.inputCount; port++) {
        final String key = '${node.id}:$port';
        if (!validWireByPort.containsKey(key)) {
          addProblem(
            CircuitProblem(
              code: CircuitProblemCode.unconnectedInput,
              message:
                  'پایه ورودی ${port + 1} از «${node.label}» متصل نیست و مقدار آن نامشخص است.',
              nodeId: node.id,
            ),
          );
        }
      }
    }

    // Dependency order over the combinational part of the circuit. Sources
    // that only depend on their stored state (flip-flops, registers) do not
    // create ordering constraints, so they are evaluated first.
    final Map<String, int> indegree = <String, int>{
      for (final CircuitNode node in _graph.nodes) node.id: 0,
    };
    final Map<String, List<String>> adjacency = <String, List<String>>{
      for (final CircuitNode node in _graph.nodes) node.id: <String>[],
    };
    for (final CircuitWire wire in structuralWires) {
      adjacency[wire.fromNodeId]!.add(wire.toNodeId);
      indegree[wire.toNodeId] = indegree[wire.toNodeId]! + 1;
    }
    for (final CircuitNode node in _graph.nodes) {
      if (ComponentLibrary.specOf(node.type).edgeUpdater == null) {
        continue;
      }
      // Edge-triggered elements are cut points in the combinational graph:
      // their output comes from their stored state, so a loop through a
      // flip-flop (Q -> logic -> D) is not a combinational cycle. Their
      // outgoing edges still constrain the nodes they feed, so a probe
      // behind a flip-flop is always evaluated after it.
      indegree[node.id] = 0;
      for (final List<String> targets in adjacency.values) {
        targets.remove(node.id);
      }
    }

    final List<String> ready = <String>[
      for (final CircuitNode node in _graph.nodes)
        if (indegree[node.id] == 0) node.id,
    ];
    final List<String> ordered = <String>[];
    while (ready.isNotEmpty) {
      final String current = ready.removeAt(0);
      ordered.add(current);
      for (final String next in adjacency[current]!) {
        indegree[next] = indegree[next]! - 1;
        if (indegree[next] == 0) {
          ready.add(next);
        }
      }
    }

    final Set<String> unordered =
        _graph.nodes.map((CircuitNode node) => node.id).toSet()
          ..removeAll(ordered);
    if (unordered.isNotEmpty) {
      addProblem(
        CircuitProblem(
          code: CircuitProblemCode.cycle,
          message:
              'چرخه ترکیبی در مدار شناسایی شد. سیگنال‌های این مسیر نامشخص‌اند؛ برای محاسبه نتیجه، چرخه را برطرف کنید.',
          nodeId: unordered.first,
        ),
      );
    }

    final Map<String, List<LogicSignal>> outputSignals =
        <String, List<LogicSignal>>{};
    final Map<String, List<LogicSignal>> inputSignals =
        <String, List<LogicSignal>>{};

    // Output probes mirror the signal that reaches them so that the canvas
    // and the truth table can read a single value per node.
    void evaluateNode(
      CircuitNode node,
      Map<String, List<LogicSignal>> outputs,
    ) {
      final ComponentSpec spec = ComponentLibrary.specOf(node.type);
      if (node.type.isInput) {
        outputs[node.id] = <LogicSignal>[
          inputNodeValues[node.id] ?? LogicSignal.low,
        ];
        return;
      }
      if (node.type.isClock) {
        outputs[node.id] = <LogicSignal>[
          _clockLevel ? LogicSignal.high : LogicSignal.low,
        ];
        return;
      }
      if (node.type == ComponentType.unknown) {
        outputs[node.id] = List<LogicSignal>.filled(
          node.outputCount,
          LogicSignal.unknown,
        );
        return;
      }

      final List<LogicSignal> inputs = <LogicSignal>[];
      for (int port = 0; port < node.inputCount; port++) {
        final String key = '${node.id}:$port';
        LogicSignal value = LogicSignal.unknown;
        if (!duplicatePorts.contains(key) && !malformedPorts.contains(key)) {
          final CircuitWire? wire = validWireByPort[key];
          if (wire != null) {
            final List<LogicSignal>? sourceSignals = outputs[wire.fromNodeId];
            if (sourceSignals != null &&
                wire.fromPortIndex < sourceSignals.length) {
              value = sourceSignals[wire.fromPortIndex];
            }
          }
        }
        inputs.add(value);
      }
      inputSignals[node.id] = List<LogicSignal>.unmodifiable(inputs);

      if (node.type.isOutput) {
        // An output probe only displays the signal it receives.
        outputs[node.id] = <LogicSignal>[
          inputs.isEmpty ? LogicSignal.unknown : inputs.first,
        ];
        return;
      }

      final ComponentState state = _states[node.id] ?? const ComponentState();
      if (spec.evaluator == null) {
        outputs[node.id] = List<LogicSignal>.filled(
          node.outputCount,
          LogicSignal.unknown,
        );
        return;
      }
      final List<LogicSignal> result = spec.evaluator!(inputs, state);
      final List<LogicSignal> padded = List<LogicSignal>.filled(
        node.outputCount,
        LogicSignal.unknown,
      );
      for (int i = 0; i < result.length && i < padded.length; i++) {
        padded[i] = result[i];
      }
      outputs[node.id] = padded;
    }

    // First pass: evaluate everything that has a known order.
    for (final String nodeId in ordered) {
      final CircuitNode node = _graph.nodeById(nodeId)!;
      evaluateNode(node, outputSignals);
    }

    // Feedback loops (latches) are resolved with a bounded fix-point loop.
    if (unordered.isNotEmpty) {
      bool changed = true;
      int iteration = 0;
      while (changed && iteration < maxIterations) {
        changed = false;
        iteration++;
        final Map<String, List<LogicSignal>> before =
            <String, List<LogicSignal>>{
              for (final MapEntry<String, List<LogicSignal>> entry
                  in outputSignals.entries)
                entry.key: List<LogicSignal>.from(entry.value),
            };
        for (final String nodeId in unordered) {
          final CircuitNode? node = _graph.nodeById(nodeId);
          if (node == null) {
            continue;
          }
          evaluateNode(node, outputSignals);
        }
        for (final MapEntry<String, List<LogicSignal>> entry
            in outputSignals.entries) {
          final List<LogicSignal>? previous = before[entry.key];
          if (previous == null || previous.length != entry.value.length) {
            changed = true;
            break;
          }
          for (int i = 0; i < previous.length; i++) {
            if (previous[i] != entry.value[i]) {
              changed = true;
              break;
            }
          }
          if (changed) {
            break;
          }
        }
      }
      if (iteration >= maxIterations) {
        for (final String nodeId in unordered) {
          outputSignals[nodeId] = List<LogicSignal>.filled(
            _graph.nodeById(nodeId)?.outputCount ?? 1,
            LogicSignal.unknown,
          );
        }
        addProblem(
          const CircuitProblem(
            code: CircuitProblemCode.cycle,
            message:
                'این بخش از مدار پس از چند تکرار به مقدار پایدار نرسید؛ احتمالاً یک حلقه بازخورد ناپایدار وجود دارد.',
          ),
        );
      }
    }

    // Latches commit their new state after the combinational part settled.
    for (final CircuitNode node in _graph.nodes) {
      final ComponentSpec spec = ComponentLibrary.specOf(node.type);
      if (spec.latchUpdater == null) {
        continue;
      }
      final List<LogicSignal> inputs =
          inputSignals[node.id] ?? const <LogicSignal>[];
      final ComponentState updated = spec.latchUpdater!(
        inputs,
        _states[node.id] ?? const ComponentState(),
      );
      _states[node.id] = updated;
      if (node.type == ComponentType.srLatch &&
          inputs.length >= 2 &&
          inputs[0] == LogicSignal.high &&
          inputs[1] == LogicSignal.high) {
        addProblem(
          CircuitProblem(
            code: CircuitProblemCode.illegalLatchState,
            message:
                'ورودی S و R هم‌زمان فعال‌اند؛ این حالت برای قفل SR غیرمجاز است.',
            nodeId: node.id,
          ),
        );
      }
    }

    // Clock edges: only edge-triggered elements capture their input.
    for (final CircuitNode node in _graph.nodes) {
      final ComponentSpec spec = ComponentLibrary.specOf(node.type);
      if (spec.edgeUpdater == null) {
        continue;
      }
      final List<LogicSignal> inputs =
          inputSignals[node.id] ?? const <LogicSignal>[];
      final int clockIndex = _clockPortIndex(spec);
      if (clockIndex < 0 || clockIndex >= inputs.length) {
        continue;
      }
      final ComponentState state = _states[node.id] ?? const ComponentState();
      final bool clockHigh = inputs[clockIndex] == LogicSignal.high;
      if (clockHigh && !state.prevClock) {
        _states[node.id] = spec.edgeUpdater!(inputs, state);
      }
      _states[node.id] = (_states[node.id] ?? state).copyWith(
        prevClock: clockHigh,
      );
    }

    // Re-evaluate so the reported values reflect the captured state.
    final Map<String, List<LogicSignal>> finalSignals =
        <String, List<LogicSignal>>{};
    for (final String nodeId in ordered) {
      final CircuitNode node = _graph.nodeById(nodeId)!;
      evaluateNode(node, finalSignals);
    }
    if (unordered.isNotEmpty) {
      for (final String nodeId in unordered) {
        final CircuitNode? node = _graph.nodeById(nodeId);
        if (node == null) {
          continue;
        }
        evaluateNode(node, finalSignals);
      }
    }

    final SimulationResult result = SimulationResult(
      outputSignals: Map<String, List<LogicSignal>>.unmodifiable(
        finalSignals.map(
          (String key, List<LogicSignal> value) =>
              MapEntry<String, List<LogicSignal>>(
                key,
                List<LogicSignal>.unmodifiable(value),
              ),
        ),
      ),
      inputSignals: Map<String, List<LogicSignal>>.unmodifiable(inputSignals),
      problems: List<CircuitProblem>.unmodifiable(problems),
      evaluatedNodeIds: Set<String>.unmodifiable(ordered.toSet()),
      clockLevel: _clockLevel,
    );
    _lastResult = result;
    return result;
  }

  int _clockPortIndex(ComponentSpec spec) {
    final int index = spec.inputLabels.indexOf('CLK');
    return index;
  }
}
