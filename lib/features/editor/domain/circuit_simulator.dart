import 'component_spec.dart';
import 'circuit_models.dart';

/// Result of one simulation step.
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
    final LogicSignal signal = inputOf(outputNodeId, 0);
    return signal.booleanValue;
  }

  /// Compact result used by truth tables: unknown values are encoded as null.
  List<bool?> outputValuesFor(CircuitGraph graph) {
    return graph.outputs
        .map((CircuitNode node) => probeValue(node.id))
        .toList(growable: false);
  }
}

/// Stateful simulation engine for combinational and sequential circuits.
///
/// ## Simulation step model
///
/// One evaluation of the engine is one *simulation step* and always runs the
/// same four phases:
///
/// 1. **Validation** – the graph is checked (missing nodes, invalid ports,
///    duplicated connections, unconnected inputs, combinational cycles).
/// 2. **Signal phase** – every combinational node is evaluated from the
///    sequential state that was current at the *start* of the step. The
///    evaluation order is a topological order of the combinational subgraph;
///    stateful nodes are *sources* in that subgraph because their output comes
///    from their stored state, not from their inputs.
/// 3. **State phase** – the inputs of every stateful node are read from the
///    settled signals of phase 2 and the stored state is updated: edge
///    triggered elements capture on a rising clock edge, level sensitive
///    elements (latches) update while they are enabled.
/// 4. **Settling** – phases 2 and 3 are repeated while the state keeps
///    changing (a latch that feeds logic back into itself settles in a few
///    rounds). The iteration count is bounded, an unstable feedback loop is
///    reported instead of hanging the app. The reported signals always belong
///    to the *final* state of the step.
///
/// Because the data inputs of a flip-flop are read in phase 3, they are always
/// the settled values of phase 2 – a flip-flop can never capture a value that
/// was simply not computed yet.
class CircuitSimulator {
  CircuitSimulator(CircuitGraph graph) : _graph = graph {
    _states = <String, ComponentState>{};
    _nodeIndex = _buildNodeIndex(graph);
    for (final CircuitNode node in graph.nodes) {
      final ComponentState? initial =
          ComponentLibrary.specOf(node.type).initialState?.call();
      if (initial != null) {
        _states[node.id] = initial;
      }
    }
  }

  /// Upper bound for the settling rounds of a feedback loop.
  static const int maxIterations = 24;

  CircuitGraph _graph;
  late Map<String, ComponentState> _states;

  /// Cached node lookup. The graph only changes through [updateGraph], so the
  /// index is rebuilt there instead of on every evaluation.
  late Map<String, CircuitNode> _nodeIndex;
  bool _clockLevel = false;
  SimulationResult? _lastResult;

  static Map<String, CircuitNode> _buildNodeIndex(CircuitGraph graph) {
    return <String, CircuitNode>{
      for (final CircuitNode node in graph.nodes) node.id: node,
    };
  }

  CircuitGraph get currentGraph => _graph;
  bool get clockLevel => _clockLevel;
  Map<String, ComponentState> get states =>
      Map<String, ComponentState>.unmodifiable(_states);

  SimulationResult get result => _lastResult ?? evaluate();

  /// Replaces the graph while keeping the state of components that still
  /// exist. This lets the editor keep the counter/flip-flop state alive while
  /// the user is still wiring the circuit.
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
    _nodeIndex = _buildNodeIndex(newGraph);
    _lastResult = null;
  }

  /// Clears every sequential state and returns the clock to its low level.
  void reset() {
    _states = <String, ComponentState>{};
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

    // ------------------------------------------------------------------
    // Phase 1 – validation of the graph structure.
    // ------------------------------------------------------------------
    final Map<String, CircuitNode> nodesById = _nodeIndex;

    final Set<String> malformedPorts = <String>{};
    final Set<String> duplicatePorts = <String>{};
    final Map<String, CircuitWire> validWireByPort = <String, CircuitWire>{};
    final _WireIndex wires = _WireIndex(
      byPort: validWireByPort,
      malformedPorts: malformedPorts,
      duplicatePorts: duplicatePorts,
    );
    final List<CircuitWire> structuralWires = <CircuitWire>[];

    for (final CircuitWire wire in _graph.wires) {
      final CircuitNode? source = nodesById[wire.fromNodeId];
      final CircuitNode? target = nodesById[wire.toNodeId];
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

    // ------------------------------------------------------------------
    // Phase 2 – classification and evaluation order.
    // ------------------------------------------------------------------
    final Set<String> statefulIds = <String>{};
    for (final CircuitNode node in _graph.nodes) {
      final ComponentSpec spec = ComponentLibrary.specOf(node.type);
      if (spec.edgeUpdater != null || spec.latchUpdater != null) {
        statefulIds.add(node.id);
      }
    }

    // The combinational subgraph only contains combinational nodes. A stateful
    // node is a *source* in that graph (its output is its stored state) and a
    // *sink* (its inputs are read after the combinational part settled).
    // A loop through a flip-flop or latch is therefore valid sequential
    // feedback, while a loop of pure gates is a combinational cycle.
    final Map<String, int> indegree = <String, int>{
      for (final CircuitNode node in _graph.nodes)
        if (!statefulIds.contains(node.id)) node.id: 0,
    };
    final Map<String, List<String>> adjacency = <String, List<String>>{
      for (final CircuitNode node in _graph.nodes)
        if (!statefulIds.contains(node.id)) node.id: <String>[],
    };
    for (final CircuitWire wire in structuralWires) {
      if (!indegree.containsKey(wire.fromNodeId) ||
          !indegree.containsKey(wire.toNodeId)) {
        continue;
      }
      adjacency[wire.fromNodeId]!.add(wire.toNodeId);
      indegree[wire.toNodeId] = indegree[wire.toNodeId]! + 1;
    }

    final List<String> ready = <String>[
      for (final String id in indegree.keys)
        if (indegree[id] == 0) id,
    ];
    final List<String> ordered = <String>[];
    // A cursor instead of `removeAt(0)`: removing the first element of a
    // list shifts every remaining element, which made the topological sort
    // quadratic for larger circuits.
    int cursor = 0;
    while (cursor < ready.length) {
      final String current = ready[cursor++];
      ordered.add(current);
      for (final String next in adjacency[current]!) {
        indegree[next] = indegree[next]! - 1;
        if (indegree[next] == 0) {
          ready.add(next);
        }
      }
    }

    final Set<String> cycleNodes = indegree.keys.toSet()..removeAll(ordered);
    if (cycleNodes.isNotEmpty) {
      addProblem(
        CircuitProblem(
          code: CircuitProblemCode.cycle,
          message:
              'چرخه ترکیبی در مدار شناسایی شد. سیگنال‌های این مسیر نامشخص‌اند؛ برای محاسبه نتیجه، چرخه را برطرف کنید.',
          nodeId: cycleNodes.first,
        ),
      );
    }

    // ------------------------------------------------------------------
    // Phase 3 and 4 – signals, state update and settling.
    // ------------------------------------------------------------------
    Map<String, List<LogicSignal>> inputSignals = <String, List<LogicSignal>>{};
    Map<String, ComponentState> state = Map<String, ComponentState>.of(_states);
    Map<String, List<LogicSignal>> outputSignals =
        <String, List<LogicSignal>>{};

    Map<String, List<LogicSignal>> evaluateSignals(
      Map<String, ComponentState> currentState,
    ) {
      final Map<String, List<LogicSignal>> outputs =
          <String, List<LogicSignal>>{};

      // Stateful nodes are evaluated first: their output is their state and
      // does not depend on the combinational part.
      for (final String id in statefulIds) {
        final CircuitNode node = nodesById[id]!;
        final ComponentSpec spec = ComponentLibrary.specOf(node.type);
        final List<LogicSignal> result =
            spec.evaluator?.call(
              const <LogicSignal>[],
              currentState[id] ?? const ComponentState(),
            ) ??
            List<LogicSignal>.filled(node.outputCount, LogicSignal.unknown);
        outputs[id] = _fit(result, node.outputCount);
      }

      // Then the combinational nodes in topological order.
      for (final String id in ordered) {
        final CircuitNode node = nodesById[id]!;
        if (node.type.isInput) {
          outputs[id] = <LogicSignal>[
            node.inputValue ? LogicSignal.high : LogicSignal.low,
          ];
          continue;
        }
        if (node.type.isClock) {
          outputs[id] = <LogicSignal>[
            _clockLevel ? LogicSignal.high : LogicSignal.low,
          ];
          continue;
        }
        if (node.type == ComponentType.unknown) {
          outputs[id] = List<LogicSignal>.filled(
            node.outputCount,
            LogicSignal.unknown,
          );
          continue;
        }
        final ComponentSpec spec = ComponentLibrary.specOf(node.type);
        final List<LogicSignal> inputs = _readInputs(node, outputs, wires);
        if (node.type.isOutput) {
          // An output probe only displays the signal it receives.
          outputs[id] = <LogicSignal>[
            inputs.isEmpty ? LogicSignal.unknown : inputs.first,
          ];
          continue;
        }
        final List<LogicSignal> result =
            spec.evaluator?.call(
              inputs,
              currentState[id] ?? const ComponentState(),
            ) ??
            List<LogicSignal>.filled(node.outputCount, LogicSignal.unknown);
        outputs[id] = _fit(result, node.outputCount);
      }

      // Nodes inside a combinational cycle can never be resolved.
      for (final String id in cycleNodes) {
        final CircuitNode? node = nodesById[id];
        if (node == null) {
          continue;
        }
        outputs[id] = List<LogicSignal>.filled(
          node.outputCount,
          LogicSignal.unknown,
        );
      }
      return outputs;
    }

    Map<String, ComponentState> updateState(
      Map<String, ComponentState> currentState,
      Map<String, List<LogicSignal>> outputs,
    ) {
      final Map<String, ComponentState> next = Map<String, ComponentState>.of(
        currentState,
      );
      for (final String id in statefulIds) {
        final CircuitNode node = nodesById[id]!;
        final ComponentSpec spec = ComponentLibrary.specOf(node.type);
        final List<LogicSignal> inputs = _readInputs(node, outputs, wires);
        final ComponentState previous =
            currentState[id] ?? const ComponentState();
        ComponentState updated = previous;

        if (spec.edgeUpdater != null) {
          final int clockIndex = _clockPortIndex(spec);
          if (clockIndex >= 0 && clockIndex < inputs.length) {
            final LogicSignal clock = inputs[clockIndex];
            final bool clockHigh = clock == LogicSignal.high;
            if (clockHigh && !previous.prevClock) {
              updated = spec.edgeUpdater!(inputs, previous);
            }
            updated = updated.copyWith(prevClock: clockHigh);
            if (clock != LogicSignal.high && clock != LogicSignal.low) {
              addProblem(
                CircuitProblem(
                  code: CircuitProblemCode.unknownClock,
                  message:
                      'پایه کلاک «${node.label}» نامشخص است؛ در این مرحله لبه‌ای رخ نمی‌دهد.',
                  nodeId: node.id,
                  severity: CircuitProblemSeverity.warning,
                ),
              );
            }
          }
        } else if (spec.latchUpdater != null) {
          updated = spec.latchUpdater!(inputs, previous);
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
        next[id] = updated;
      }
      return next;
    }

    bool settled = false;
    int iteration = 0;
    while (!settled && iteration < maxIterations) {
      iteration++;
      outputSignals = evaluateSignals(state);
      final Map<String, ComponentState> next = updateState(
        state,
        outputSignals,
      );
      final bool changed = !_statesEqual(next, state);
      state = next;
      settled = !changed;
    }
    if (!settled) {
      addProblem(
        const CircuitProblem(
          code: CircuitProblemCode.unstableFeedback,
          message:
              'بازخورد این بخش از مدار پس از چند تکرار به مقدار پایدار نرسید؛ نتیجهٔ آن نامشخص در نظر گرفته شد.',
        ),
      );
      for (final String id in statefulIds) {
        state[id] = state[id]!.copyWith(
          q: LogicSignal.unknown,
          qBar: LogicSignal.unknown,
        );
      }
      outputSignals = evaluateSignals(state);
    }

    // The reported signals belong to the final state of this step.
    inputSignals = <String, List<LogicSignal>>{};
    for (final CircuitNode node in _graph.nodes) {
      if (node.type.isInput || node.type.isClock) {
        continue;
      }
      inputSignals[node.id] = _readInputs(node, outputSignals, wires);
    }

    _states = state;

    final SimulationResult result = SimulationResult(
      outputSignals: Map<String, List<LogicSignal>>.unmodifiable(
        outputSignals.map(
          (String key, List<LogicSignal> value) =>
              MapEntry<String, List<LogicSignal>>(
                key,
                List<LogicSignal>.unmodifiable(value),
              ),
        ),
      ),
      inputSignals: Map<String, List<LogicSignal>>.unmodifiable(
        inputSignals.map(
          (String key, List<LogicSignal> value) =>
              MapEntry<String, List<LogicSignal>>(
                key,
                List<LogicSignal>.unmodifiable(value),
              ),
        ),
      ),
      problems: List<CircuitProblem>.unmodifiable(problems),
      evaluatedNodeIds: Set<String>.unmodifiable(<String>{
        ...ordered,
        ...statefulIds,
      }),
      clockLevel: _clockLevel,
    );
    _lastResult = result;
    return result;
  }

  /// Reads the input signals of a node from the already evaluated outputs.
  List<LogicSignal> _readInputs(
    CircuitNode node,
    Map<String, List<LogicSignal>> outputs,
    _WireIndex wires,
  ) {
    final List<LogicSignal> inputs = <LogicSignal>[];
    for (int port = 0; port < node.inputCount; port++) {
      final String key = '${node.id}:$port';
      LogicSignal value = LogicSignal.unknown;
      if (!wires.duplicatePorts.contains(key) &&
          !wires.malformedPorts.contains(key)) {
        final CircuitWire? wire = wires.byPort[key];
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
    return inputs;
  }

  List<LogicSignal> _fit(List<LogicSignal> values, int count) {
    if (values.length == count) {
      return values;
    }
    final List<LogicSignal> padded = List<LogicSignal>.filled(
      count,
      LogicSignal.unknown,
    );
    for (int i = 0; i < values.length && i < padded.length; i++) {
      padded[i] = values[i];
    }
    return padded;
  }

  bool _statesEqual(
    Map<String, ComponentState> a,
    Map<String, ComponentState> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final MapEntry<String, ComponentState> entry in a.entries) {
      final ComponentState? other = b[entry.key];
      if (other == null || !entry.value.sameAs(other)) {
        return false;
      }
    }
    return true;
  }

  int _clockPortIndex(ComponentSpec spec) {
    return spec.inputLabels.indexOf('CLK');
  }
}

/// Index of the valid wire connections of a graph, used while reading the
/// input signals of a node.
class _WireIndex {
  const _WireIndex({
    required this.byPort,
    required this.malformedPorts,
    required this.duplicatePorts,
  });

  final Map<String, CircuitWire> byPort;
  final Set<String> malformedPorts;
  final Set<String> duplicatePorts;
}
