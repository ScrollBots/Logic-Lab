import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';
import 'package:logic_lab/features/editor/domain/component_spec.dart';

/// Small helper that assembles a graph from inputs, a module and a probe.
class _Builder {
  _Builder();

  final List<CircuitNode> nodes = <CircuitNode>[];
  final List<CircuitWire> wires = <CircuitWire>[];
  int _inputIndex = 0;
  int _moduleIndex = 0;
  int _probeIndex = 0;
  int _wireIndex = 0;

  CircuitNode addInput(String label, {bool value = false}) {
    final CircuitNode node = CircuitNode(
      id: 'in${_inputIndex++}',
      type: ComponentType.inputPin,
      position: CanvasPoint(0, nodes.length * 120.0),
      label: label,
      inputValue: value,
    );
    nodes.add(node);
    return node;
  }

  CircuitNode addModule(ComponentType type, {int? inputs}) {
    final ComponentSpec spec = ComponentLibrary.specOf(type);
    final CircuitNode node = CircuitNode(
      id: 'm${_moduleIndex++}',
      type: type,
      position: CanvasPoint(300, 200),
      label: ComponentLibrary.specOf(type).title,
      inputCount: inputs ?? (spec.configurableInputs ? spec.minInputs : null),
    );
    nodes.add(node);
    return node;
  }

  CircuitNode addProbe(String label) {
    final CircuitNode node = CircuitNode(
      id: 'out${_probeIndex++}',
      type: ComponentType.outputPin,
      position: CanvasPoint(600, 200),
      label: label,
    );
    nodes.add(node);
    return node;
  }

  void connect(CircuitNode from, CircuitNode to, int port) {
    wires.add(
      CircuitWire(
        id: 'w${_wireIndex++}',
        fromNodeId: from.id,
        toNodeId: to.id,
        toInputIndex: port,
        fromPortIndex: 0,
      ),
    );
  }

  CircuitGraph build() => CircuitGraph(nodes: nodes, wires: wires);
}

/// Builds a circuit with one input, one module and one probe per output port.
CircuitGraph _singleModule(
  ComponentType type, {
  required List<bool> inputValues,
  int inputCount = 2,
  bool withProbe = true,
}) {
  final _Builder builder = _Builder();
  final List<CircuitNode> inputs = <CircuitNode>[];
  for (int i = 0; i < inputCount; i++) {
    inputs.add(
      builder.addInput(
        String.fromCharCode(65 + i),
        value: i < inputValues.length ? inputValues[i] : false,
      ),
    );
  }
  final CircuitNode module = builder.addModule(type, inputs: inputCount);
  for (int i = 0; i < inputCount; i++) {
    builder.connect(inputs[i], module, i);
  }
  if (withProbe) {
    final CircuitNode probe = builder.addProbe('Y');
    builder.connect(module, probe, 0);
  }
  return builder.build();
}

void main() {
  group('Multi-input gates', () {
    test('AND with three inputs needs every input high', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.andGate,
        inputValues: <bool>[true, true, false],
        inputCount: 3,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.isValid, isTrue, reason: result.problems.toString());
      expect(result.signalOf('m0'), LogicSignal.low);
    });

    test('OR with three inputs is high when one input is high', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.orGate,
        inputValues: <bool>[false, true, false],
        inputCount: 3,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0'), LogicSignal.high);
    });

    test('NAND and NOR support a configurable input count', () {
      final CircuitGraph nand = _singleModule(
        ComponentType.nandGate,
        inputValues: <bool>[true, true],
        inputCount: 2,
      );
      expect(CircuitSimulator(nand).evaluate().signalOf('m0'), LogicSignal.low);

      final CircuitGraph nor = _singleModule(
        ComponentType.norGate,
        inputValues: <bool>[false, false],
        inputCount: 2,
      );
      expect(CircuitSimulator(nor).evaluate().signalOf('m0'), LogicSignal.high);
    });

    test('XOR with three inputs implements odd parity', () {
      final CircuitGraph three = _singleModule(
        ComponentType.xorGate,
        inputValues: <bool>[true, true, true],
        inputCount: 3,
      );
      expect(
        CircuitSimulator(three).evaluate().signalOf('m0'),
        LogicSignal.high,
        reason: 'odd number of HIGH inputs',
      );
      final CircuitGraph two = _singleModule(
        ComponentType.xorGate,
        inputValues: <bool>[true, true],
        inputCount: 2,
      );
      expect(CircuitSimulator(two).evaluate().signalOf('m0'), LogicSignal.low);
    });

    test('XNOR with three inputs implements even parity', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.xnorGate,
        inputValues: <bool>[true, true, true],
        inputCount: 3,
      );
      expect(
        CircuitSimulator(graph).evaluate().signalOf('m0'),
        LogicSignal.low,
      );
    });

    test('a buffer copies its input', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.bufferGate,
        inputValues: <bool>[true],
        inputCount: 1,
      );
      expect(
        CircuitSimulator(graph).evaluate().signalOf('m0'),
        LogicSignal.high,
      );
    });
  });

  group('Three-valued logic', () {
    test('AND with a LOW input is LOW even when another input is unknown', () {
      final _Builder builder = _Builder();
      final CircuitNode a = builder.addInput('A');
      final CircuitNode gate = builder.addModule(ComponentType.andGate);
      builder.connect(a, gate, 0);
      // The second input stays unconnected, so it is unknown.
      final SimulationResult result = CircuitSimulator(builder.build())
          .evaluate();
      expect(result.signalOf(gate.id), LogicSignal.low);
    });

    test('OR with a HIGH input is HIGH even when another input is unknown', () {
      final _Builder builder = _Builder();
      final CircuitNode a = builder.addInput('A', value: true);
      final CircuitNode gate = builder.addModule(ComponentType.orGate);
      builder.connect(a, gate, 0);
      final SimulationResult result = CircuitSimulator(builder.build())
          .evaluate();
      expect(result.signalOf(gate.id), LogicSignal.high);
    });

    test('an unconnected input is reported and makes the gate uncertain', () {
      final _Builder builder = _Builder();
      final CircuitNode a = builder.addInput('A');
      final CircuitNode gate = builder.addModule(ComponentType.andGate);
      builder.connect(a, gate, 0);
      final SimulationResult result = CircuitSimulator(builder.build())
          .evaluate();
      // AND with a LOW input is LOW even if the other input is unknown, but
      // the circuit itself is still reported as incomplete.
      expect(result.signalOf(gate.id), LogicSignal.low);
      expect(result.isValid, isFalse);
      expect(
        result.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.unconnectedInput,
        ),
        isTrue,
      );
    });
  });

  group('Tri-state buffer', () {
    test('drives the line when enabled', () {
      final _Builder builder = _Builder();
      final CircuitNode data = builder.addInput('A', value: true);
      final CircuitNode enable = builder.addInput('EN', value: true);
      final CircuitNode buffer = builder.addModule(
        ComponentType.triStateBuffer,
      );
      builder.connect(data, buffer, 0);
      builder.connect(enable, buffer, 1);
      final SimulationResult result = CircuitSimulator(builder.build())
          .evaluate();
      expect(result.signalOf(buffer.id), LogicSignal.high);
    });

    test('reports the high-impedance state when disabled', () {
      final _Builder builder = _Builder();
      final CircuitNode data = builder.addInput('A', value: true);
      final CircuitNode enable = builder.addInput('EN');
      final CircuitNode buffer = builder.addModule(
        ComponentType.triStateBuffer,
      );
      builder.connect(data, buffer, 0);
      builder.connect(enable, buffer, 1);
      final SimulationResult result = CircuitSimulator(builder.build())
          .evaluate();
      expect(result.signalOf(buffer.id), LogicSignal.highImpedance);
      expect(result.signalOf(buffer.id).isKnown, isFalse);
    });
  });

  group('Compound gates', () {
    test('AOI21 computes NOT((A AND B) OR C)', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.aoi21,
        inputValues: <bool>[true, true, false],
        inputCount: 3,
      );
      expect(
        CircuitSimulator(graph).evaluate().signalOf('m0'),
        LogicSignal.low,
      );

      final CircuitGraph other = _singleModule(
        ComponentType.aoi21,
        inputValues: <bool>[false, false, false],
        inputCount: 3,
      );
      expect(
        CircuitSimulator(other).evaluate().signalOf('m0'),
        LogicSignal.high,
      );
    });

    test('AOI22 computes NOT((A AND B) OR (C AND D))', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.aoi22,
        inputValues: <bool>[true, true, false, false],
        inputCount: 4,
      );
      expect(
        CircuitSimulator(graph).evaluate().signalOf('m0'),
        LogicSignal.low,
      );
    });

    test('OAI21 computes NOT((A OR B) AND C)', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.oai21,
        inputValues: <bool>[false, false, true],
        inputCount: 3,
      );
      expect(
        CircuitSimulator(graph).evaluate().signalOf('m0'),
        LogicSignal.high,
      );

      final CircuitGraph other = _singleModule(
        ComponentType.oai21,
        inputValues: <bool>[true, false, true],
        inputCount: 3,
      );
      expect(
        CircuitSimulator(other).evaluate().signalOf('m0'),
        LogicSignal.low,
      );
    });

    test('OAI22 computes NOT((A OR B) AND (C OR D))', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.oai22,
        inputValues: <bool>[true, false, true, false],
        inputCount: 4,
      );
      expect(
        CircuitSimulator(graph).evaluate().signalOf('m0'),
        LogicSignal.low,
      );
    });
  });

  group('Arithmetic modules', () {
    test('the half adder produces sum and carry', () {
      final _Builder builder = _Builder();
      final CircuitNode a = builder.addInput('A');
      final CircuitNode b = builder.addInput('B');
      final CircuitNode adder = builder.addModule(ComponentType.halfAdder);
      builder.connect(a, adder, 0);
      builder.connect(b, adder, 1);
      final SimulationResult result = CircuitSimulator(builder.build())
          .evaluate();
      expect(result.signalOf(adder.id, 0), LogicSignal.low);
      expect(result.signalOf(adder.id, 1), LogicSignal.low);

      final CircuitGraph both = _singleModule(
        ComponentType.halfAdder,
        inputValues: <bool>[true, true],
        inputCount: 2,
        withProbe: false,
      );
      final SimulationResult high = CircuitSimulator(both).evaluate();
      expect(high.signalOf('m0', 0), LogicSignal.low);
      expect(high.signalOf('m0', 1), LogicSignal.high);
    });

    test('the full adder adds three bits', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.fullAdder,
        inputValues: <bool>[true, true, true],
        inputCount: 3,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.high, reason: '1+1+1 = 3');
      expect(result.signalOf('m0', 1), LogicSignal.high, reason: 'carry out');
    });

    test('the half subtractor produces difference and borrow', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.halfSubtractor,
        inputValues: <bool>[false, true],
        inputCount: 2,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.high);
      expect(result.signalOf('m0', 1), LogicSignal.high);
    });

    test('the comparator reports less, equal and greater', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.comparator,
        inputValues: <bool>[false, true, true, false],
        inputCount: 4,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.high, reason: 'LT');
      expect(result.signalOf('m0', 1), LogicSignal.low, reason: 'EQ');
      expect(result.signalOf('m0', 2), LogicSignal.low, reason: 'GT');
    });
  });

  group('Selection and coding modules', () {
    test('the 2:1 multiplexer selects the right input', () {
      final CircuitGraph low = _singleModule(
        ComponentType.mux2,
        inputValues: <bool>[true, false, false],
        inputCount: 3,
      );
      expect(CircuitSimulator(low).evaluate().signalOf('m0'), LogicSignal.high);

      final CircuitGraph high = _singleModule(
        ComponentType.mux2,
        inputValues: <bool>[true, false, true],
        inputCount: 3,
      );
      expect(CircuitSimulator(high).evaluate().signalOf('m0'), LogicSignal.low);
    });

    test('the 4:1 multiplexer uses two select lines', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.mux4,
        inputValues: <bool>[false, true, false, false, false, true],
        inputCount: 6,
      );
      expect(
        CircuitSimulator(graph).evaluate().signalOf('m0'),
        LogicSignal.high,
      );
    });

    test('the 1:2 demultiplexer routes the data', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.demux1to2,
        inputValues: <bool>[true, false],
        inputCount: 2,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.high);
      expect(result.signalOf('m0', 1), LogicSignal.low);
    });

    test('the 1:4 demultiplexer routes the data', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.demux1to4,
        inputValues: <bool>[true, false, true],
        inputCount: 3,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.low);
      expect(result.signalOf('m0', 1), LogicSignal.high, reason: 'S1=0,S0=1');
      expect(result.signalOf('m0', 2), LogicSignal.low);
      expect(result.signalOf('m0', 3), LogicSignal.low);
    });

    test('the 2-to-4 decoder activates exactly one output', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.decoder2to4,
        inputValues: <bool>[false, true],
        inputCount: 2,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.low);
      expect(result.signalOf('m0', 1), LogicSignal.high);
      expect(result.signalOf('m0', 2), LogicSignal.low);
      expect(result.signalOf('m0', 3), LogicSignal.low);
    });

    test('the 3-to-8 decoder activates exactly one output', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.decoder3to8,
        inputValues: <bool>[true, false, true],
        inputCount: 3,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      final List<LogicSignal> outputs = result.outputSignals['m0']!;
      expect(outputs.where((LogicSignal s) => s == LogicSignal.high).length, 1);
      expect(outputs[5], LogicSignal.high);
    });

    test('the 4-to-2 encoder encodes the active input', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.encoder4to2,
        inputValues: <bool>[false, true, false, false],
        inputCount: 4,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.low, reason: 'Y1');
      expect(result.signalOf('m0', 1), LogicSignal.high, reason: 'Y0');
    });

    test('the 8-to-3 encoder encodes the active input', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.encoder8to3,
        inputValues: <bool>[
          false,
          false,
          false,
          true,
          false,
          false,
          false,
          false,
        ],
        inputCount: 8,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.low, reason: 'Y2');
      expect(result.signalOf('m0', 1), LogicSignal.high, reason: 'Y1');
      expect(result.signalOf('m0', 2), LogicSignal.high, reason: 'Y0');
    });

    test('the priority encoder prefers the highest active input', () {
      final CircuitGraph graph = _singleModule(
        ComponentType.priorityEncoder,
        inputValues: <bool>[
          true,
          true,
          false,
          true,
          false,
          false,
          false,
          false,
        ],
        inputCount: 8,
        withProbe: false,
      );
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.low, reason: 'Y2');
      expect(result.signalOf('m0', 1), LogicSignal.high, reason: 'Y1');
      expect(result.signalOf('m0', 2), LogicSignal.high, reason: 'Y0');
      expect(result.signalOf('m0', 3), LogicSignal.high, reason: 'V');
    });
  });

  group('Sequential logic', () {
    CircuitGraph latchCircuit(ComponentType type, List<bool> values) {
      final _Builder builder = _Builder();
      final List<CircuitNode> inputs = <CircuitNode>[];
      for (int i = 0; i < values.length; i++) {
        inputs.add(
          builder.addInput(String.fromCharCode(65 + i), value: values[i]),
        );
      }
      final CircuitNode latch = builder.addModule(type);
      for (int i = 0; i < values.length; i++) {
        builder.connect(inputs[i], latch, i);
      }
      return builder.build();
    }

    test('the SR latch stores a set and a reset', () {
      final CircuitGraph set = latchCircuit(ComponentType.srLatch, <bool>[
        true,
        false,
      ]);
      SimulationResult result = CircuitSimulator(set).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.high);
      expect(result.signalOf('m0', 1), LogicSignal.low);

      final CircuitGraph reset = latchCircuit(ComponentType.srLatch, <bool>[
        false,
        true,
      ]);
      result = CircuitSimulator(reset).evaluate();
      expect(result.signalOf('m0', 0), LogicSignal.low);
    });

    test('the SR latch reports the illegal state', () {
      final CircuitGraph illegal = latchCircuit(ComponentType.srLatch, <bool>[
        true,
        true,
      ]);
      final SimulationResult result = CircuitSimulator(illegal).evaluate();
      expect(
        result.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.illegalLatchState,
        ),
        isTrue,
      );
    });

    test('the D latch is transparent while enabled', () {
      final _Builder builder = _Builder();
      final CircuitNode data = builder.addInput('D', value: true);
      final CircuitNode enable = builder.addInput('EN', value: true);
      final CircuitNode latch = builder.addModule(ComponentType.dLatch);
      builder.connect(data, latch, 0);
      builder.connect(enable, latch, 1);
      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      SimulationResult result = simulator.evaluate();
      expect(result.signalOf(latch.id, 0), LogicSignal.high);

      // With the enable low the latch keeps its value.
      final CircuitGraph hold = builder.build().copyWith(
        nodes: builder
            .build()
            .nodes
            .map(
              (CircuitNode node) =>
                  node.label == 'EN' ? node.copyWith(inputValue: false) : node,
            )
            .toList(),
      );
      simulator.updateGraph(hold);
      result = simulator.evaluate();
      expect(result.signalOf(latch.id, 0), LogicSignal.high);
    });

    /// Builds a flip-flop whose clock comes from a clock source component.
    CircuitGraph clockedFlipFlop(
      ComponentType type, {
      required List<bool> values,
    }) {
      final _Builder builder = _Builder();
      final List<CircuitNode> inputs = <CircuitNode>[];
      for (int i = 0; i < values.length; i++) {
        inputs.add(
          builder.addInput(String.fromCharCode(65 + i), value: values[i]),
        );
      }
      final CircuitNode clock = builder.addModule(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.addModule(type);
      for (int i = 0; i < values.length; i++) {
        builder.connect(inputs[i], flipFlop, i);
      }
      builder.connect(clock, flipFlop, flipFlop.inputCount - 1);
      return builder.build();
    }

    test('the D flip-flop captures on the rising clock edge', () {
      final CircuitGraph graph = clockedFlipFlop(
        ComponentType.dFlipFlop,
        values: <bool>[true],
      );
      final CircuitSimulator simulator = CircuitSimulator(graph);
      SimulationResult result = simulator.evaluate();
      expect(
        result.signalOf('m1', 0),
        LogicSignal.low,
        reason: 'no edge has happened yet',
      );

      result = simulator.stepClock();
      expect(
        result.signalOf('m1', 0),
        LogicSignal.high,
        reason: 'D was high at the rising edge',
      );
    });

    test('the T flip-flop toggles when T is high', () {
      final CircuitGraph graph = clockedFlipFlop(
        ComponentType.tFlipFlop,
        values: <bool>[true],
      );
      final CircuitSimulator simulator = CircuitSimulator(graph);
      expect(simulator.stepClock().signalOf('m1', 0), LogicSignal.high);
      expect(simulator.stepClock().signalOf('m1', 0), LogicSignal.low);
    });

    test('the JK flip-flop follows the JK truth table', () {
      final CircuitGraph hold = clockedFlipFlop(
        ComponentType.jkFlipFlop,
        values: <bool>[false, false],
      );
      final CircuitSimulator simulator = CircuitSimulator(hold);
      expect(simulator.stepClock().signalOf('m1', 0), LogicSignal.low);
      expect(simulator.stepClock().signalOf('m1', 0), LogicSignal.low);

      final CircuitGraph toggle = clockedFlipFlop(
        ComponentType.jkFlipFlop,
        values: <bool>[true, true],
      );
      final CircuitSimulator toggleSimulator = CircuitSimulator(toggle);
      expect(toggleSimulator.stepClock().signalOf('m1', 0), LogicSignal.high);
      expect(toggleSimulator.stepClock().signalOf('m1', 0), LogicSignal.low);
    });

    test('the 4-bit register stores its data on the clock edge', () {
      final _Builder builder = _Builder();
      final List<CircuitNode> data = <CircuitNode>[
        builder.addInput('D0', value: true),
        builder.addInput('D1'),
        builder.addInput('D2'),
        builder.addInput('D3'),
      ];
      final CircuitNode clock = builder.addModule(ComponentType.clockSource);
      final CircuitNode register = builder.addModule(ComponentType.register4);
      for (int i = 0; i < 4; i++) {
        builder.connect(data[i], register, i);
      }
      builder.connect(clock, register, 4);
      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      SimulationResult result = simulator.evaluate();
      expect(result.signalOf(register.id, 0), LogicSignal.low);

      result = simulator.stepClock();
      expect(result.signalOf(register.id, 0), LogicSignal.high);
      expect(result.signalOf(register.id, 1), LogicSignal.low);
    });

    test('the shift register moves its bits on every clock edge', () {
      final _Builder builder = _Builder();
      final CircuitNode data = builder.addInput('D', value: true);
      // DIR = 0 shifts to the right, so the data enters through Q0.
      final CircuitNode direction = builder.addInput('DIR');
      final CircuitNode clock = builder.addModule(ComponentType.clockSource);
      final CircuitNode register = builder.addModule(
        ComponentType.shiftRegister4,
      );
      builder.connect(data, register, 0);
      builder.connect(direction, register, 1);
      builder.connect(clock, register, 2);
      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      SimulationResult result = simulator.stepClock();
      expect(result.signalOf(register.id, 0), LogicSignal.high);
      result = simulator.stepClock();
      expect(result.signalOf(register.id, 1), LogicSignal.high);
    });

    test('the binary counter increments on every clock edge', () {
      final _Builder builder = _Builder();
      final CircuitNode clock = builder.addModule(ComponentType.clockSource);
      final CircuitNode reset = builder.addInput('RST');
      final CircuitNode counter = builder.addModule(ComponentType.counter4);
      builder.connect(clock, counter, 0);
      builder.connect(reset, counter, 1);
      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      SimulationResult result = simulator.stepClock();
      expect(
        result.signalOf(counter.id, 0),
        LogicSignal.high,
        reason: 'count = 1',
      );
      result = simulator.stepClock();
      expect(
        result.signalOf(counter.id, 0),
        LogicSignal.low,
        reason: 'count = 2',
      );
      expect(result.signalOf(counter.id, 1), LogicSignal.high);
    });

    test('the up/down counter counts down when UP is low', () {
      final _Builder builder = _Builder();
      final CircuitNode clock = builder.addModule(ComponentType.clockSource);
      final CircuitNode reset = builder.addInput('RST');
      final CircuitNode up = builder.addInput('UP');
      final CircuitNode counter = builder.addModule(
        ComponentType.upDownCounter4,
      );
      builder.connect(clock, counter, 0);
      builder.connect(reset, counter, 1);
      builder.connect(up, counter, 2);
      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      // With UP low the counter counts down: 0 becomes 15 after one edge.
      final SimulationResult result = simulator.stepClock();
      expect(
        result.signalOf(counter.id, 0),
        LogicSignal.high,
        reason: 'counted down to 15',
      );
      expect(result.signalOf(counter.id, 3), LogicSignal.high);
    });

    test('reset clears the counter state', () {
      final _Builder builder = _Builder();
      final CircuitNode clock = builder.addModule(ComponentType.clockSource);
      final CircuitNode reset = builder.addInput('RST');
      final CircuitNode counter = builder.addModule(ComponentType.counter4);
      builder.connect(clock, counter, 0);
      builder.connect(reset, counter, 1);
      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.stepClock();
      expect(
        simulator.result.signalOf(counter.id, 0),
        LogicSignal.high,
        reason: 'count = 1',
      );
      simulator.reset();
      expect(simulator.result.signalOf(counter.id, 0), LogicSignal.low);
    });

    test('a clock source drives the flip-flop', () {
      final _Builder builder = _Builder();
      final CircuitNode data = builder.addInput('D', value: true);
      final CircuitNode clock = builder.addModule(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.addModule(ComponentType.dFlipFlop);
      builder.connect(data, flipFlop, 0);
      builder.connect(clock, flipFlop, 1);
      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      expect(simulator.result.signalOf(flipFlop.id, 0), LogicSignal.low);
      simulator.stepClock();
      expect(simulator.result.signalOf(flipFlop.id, 0), LogicSignal.high);
    });
  });

  group('Unsupported components', () {
    test('an unknown component type is reported instead of crashing', () {
      final CircuitNode unknown = CircuitNode(
        id: 'x',
        type: ComponentType.unknown,
        position: const CanvasPoint(0, 0),
        label: 'قطعه آینده',
      );
      final CircuitGraph graph = CircuitGraph(nodes: <CircuitNode>[unknown]);
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(
        result.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.unsupportedComponent,
        ),
        isTrue,
      );
      expect(result.isValid, isFalse);
    });

    test('an unknown persisted type loads as unsupported', () {
      final CircuitNode node = CircuitNode.fromJson(<String, Object?>{
        'id': 'x',
        'type': 'quantum_gate',
        'x': 10.0,
        'y': 20.0,
        'label': 'Q',
      });
      expect(node.type, ComponentType.unknown);
    });
  });
}
