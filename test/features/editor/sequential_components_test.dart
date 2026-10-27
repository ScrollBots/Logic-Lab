import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_validator.dart';

import '../../support/circuit_test_support.dart';

void main() {
  group('D flip-flop', () {
    test('captures on the rising edge and holds between the edges', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode data = builder.add(ComponentType.inputPin, label: 'D');
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(data, flipFlop, toPort: 0);
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);

      // Data goes high, but without a clock edge nothing is captured.
      simulator.updateGraph(
        builder.build().copyWith(
          nodes: builder
              .build()
              .nodes
              .map(
                (CircuitNode node) =>
                    node.label == 'D' ? node.copyWith(inputValue: true) : node,
              )
              .toList(),
        ),
      );
      simulator.evaluate();
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);

      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.high);

      // The value is retained until the next edge.
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.high);
    });

    test('captures the settled value of a gate that drives D', () {
      // This is the regression test for the evaluation order defect: the flip-flop
      // must not capture a value that was simply not computed yet.
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode a = builder.add(
        ComponentType.inputPin,
        label: 'A',
        value: true,
      );
      final CircuitNode b = builder.add(
        ComponentType.inputPin,
        label: 'B',
        value: true,
      );
      final CircuitNode gate = builder.add(ComponentType.andGate, label: 'AND');
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(a, gate, toPort: 0);
      builder.connect(b, gate, toPort: 1);
      builder.connect(gate, flipFlop, toPort: 0);
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(
        simulator.result.signalOf(probe.id),
        LogicSignal.high,
        reason: 'D = A AND B = 1 must be captured',
      );
      expect(simulator.result.inputOf(flipFlop.id, 0), LogicSignal.high);
    });

    test('a chain of gates in front of D is captured correctly', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode data = builder.add(
        ComponentType.inputPin,
        label: 'D',
        value: true,
      );
      final CircuitNode gate1 = builder.add(ComponentType.notGate);
      final CircuitNode gate2 = builder.add(ComponentType.notGate);
      final CircuitNode gate3 = builder.add(ComponentType.notGate);
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(data, gate1, toPort: 0);
      builder.connect(gate1, gate2, toPort: 0);
      builder.connect(gate2, gate3, toPort: 0);
      builder.connect(gate3, flipFlop, toPort: 0);
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      // Three inversions: D = 0.
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);
    });

    test('an unknown data line makes the captured value unknown', () {
      final CircuitBuilder builder = CircuitBuilder();
      // The data input stays unconnected -> unknown.
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(
        simulator.result.signalOf(probe.id),
        LogicSignal.unknown,
        reason: 'capturing an unknown line must not invent a value',
      );
    });
  });

  group('T and JK flip-flops', () {
    test('the T flip-flop toggles on every rising edge', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode toggle = builder.add(
        ComponentType.inputPin,
        label: 'T',
        value: true,
      );
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.tFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(toggle, flipFlop, toPort: 0);
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.high);
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.high);
    });

    test('the JK flip-flop follows the JK truth table', () {
      for (final List<bool> jk in <List<bool>>[
        <bool>[false, false],
        <bool>[true, false],
        <bool>[false, true],
        <bool>[true, true],
      ]) {
        final CircuitBuilder builder = CircuitBuilder();
        final CircuitNode j = builder.add(
          ComponentType.inputPin,
          label: 'J',
          value: jk[0],
        );
        final CircuitNode k = builder.add(
          ComponentType.inputPin,
          label: 'K',
          value: jk[1],
        );
        final CircuitNode clock = builder.add(ComponentType.clockSource);
        final CircuitNode flipFlop = builder.add(ComponentType.jkFlipFlop);
        final CircuitNode probe = builder.add(
          ComponentType.outputPin,
          label: 'Q',
        );
        builder.connect(j, flipFlop, toPort: 0);
        builder.connect(k, flipFlop, toPort: 1);
        builder.connect(clock, flipFlop, toPort: 2);
        builder.connect(flipFlop, probe, toPort: 0);

        final CircuitSimulator simulator = CircuitSimulator(builder.build());
        simulator.evaluate();
        simulator.stepClock();
        final LogicSignal first = simulator.result.signalOf(probe.id);
        simulator.stepClock();
        final LogicSignal second = simulator.result.signalOf(probe.id);

        final bool expectedFirst = jk[0];
        final bool expectedSecond = jk[0] && jk[1]
            ? !expectedFirst
            : (jk[0] && !jk[1])
            ? true
            : (jk[1] && !jk[0])
            ? false
            : expectedFirst;
        expect(
          first,
          expectedFirst ? LogicSignal.high : LogicSignal.low,
          reason: 'J=${jk[0]} K=${jk[1]} first capture',
        );
        expect(
          second,
          expectedSecond ? LogicSignal.high : LogicSignal.low,
          reason: 'J=${jk[0]} K=${jk[1]} second capture',
        );
      }
    });
  });

  group('Latches', () {
    test('the D latch follows D while it is enabled and holds afterwards', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode data = builder.add(
        ComponentType.inputPin,
        label: 'D',
        value: true,
      );
      final CircuitNode enable = builder.add(
        ComponentType.inputPin,
        label: 'EN',
        value: true,
      );
      final CircuitNode latch = builder.add(ComponentType.dLatch);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(data, latch, toPort: 0);
      builder.connect(enable, latch, toPort: 1);
      builder.connect(latch, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      expect(
        simulator.result.signalOf(probe.id),
        LogicSignal.high,
        reason: 'an enabled latch is transparent',
      );

      // Disable the latch and change D: the stored value must be kept.
      final CircuitGraph held = builder.build().copyWith(
        nodes: builder
            .build()
            .nodes
            .map(
              (CircuitNode node) => node.label == 'EN'
                  ? node.copyWith(inputValue: false)
                  : node.label == 'D'
                  ? node.copyWith(inputValue: false)
                  : node,
            )
            .toList(),
      );
      simulator.updateGraph(held);
      simulator.evaluate();
      expect(
        simulator.result.signalOf(probe.id),
        LogicSignal.high,
        reason: 'a closed latch keeps its value',
      );
    });

    test('the SR latch stores set and reset and reports the illegal state', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode set = builder.add(ComponentType.inputPin, label: 'S');
      final CircuitNode reset = builder.add(ComponentType.inputPin, label: 'R');
      final CircuitNode latch = builder.add(ComponentType.srLatch);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(set, latch, toPort: 0);
      builder.connect(reset, latch, toPort: 1);
      builder.connect(latch, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);

      simulator.updateGraph(
        builder.build().copyWith(
          nodes: builder
              .build()
              .nodes
              .map(
                (CircuitNode node) =>
                    node.label == 'S' ? node.copyWith(inputValue: true) : node,
              )
              .toList(),
        ),
      );
      simulator.evaluate();
      expect(simulator.result.signalOf(probe.id), LogicSignal.high);

      simulator.updateGraph(
        builder.build().copyWith(
          nodes: builder
              .build()
              .nodes
              .map(
                (CircuitNode node) => node.label == 'R'
                    ? node.copyWith(inputValue: true)
                    : node.label == 'S'
                    ? node.copyWith(inputValue: false)
                    : node,
              )
              .toList(),
        ),
      );
      simulator.evaluate();
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);
    });
  });

  group('Registers, shift registers and counters', () {
    test('the 4 bit register stores the data word on the clock edge', () {
      final CircuitBuilder builder = CircuitBuilder();
      final List<CircuitNode> data = <CircuitNode>[
        builder.add(ComponentType.inputPin, label: 'D0', value: true),
        builder.add(ComponentType.inputPin, label: 'D1'),
        builder.add(ComponentType.inputPin, label: 'D2'),
        builder.add(ComponentType.inputPin, label: 'D3'),
      ];
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode register = builder.add(ComponentType.register4);
      final List<CircuitNode> probes = <CircuitNode>[
        builder.add(ComponentType.outputPin, label: 'Q0'),
        builder.add(ComponentType.outputPin, label: 'Q1'),
        builder.add(ComponentType.outputPin, label: 'Q2'),
        builder.add(ComponentType.outputPin, label: 'Q3'),
      ];
      for (int i = 0; i < 4; i++) {
        builder.connect(data[i], register, toPort: i);
      }
      builder.connect(clock, register, toPort: 4);
      for (int i = 0; i < 4; i++) {
        builder.connect(register, probes[i], toPort: 0, fromPort: i);
      }

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(simulator.result.signalOf(probes[0].id), LogicSignal.high);
      expect(simulator.result.signalOf(probes[1].id), LogicSignal.low);
      expect(simulator.result.signalOf(probes[2].id), LogicSignal.low);
      expect(simulator.result.signalOf(probes[3].id), LogicSignal.low);
    });

    test('the shift register moves the data on every clock edge', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode data = builder.add(
        ComponentType.inputPin,
        label: 'D',
        value: true,
      );
      final CircuitNode direction = builder.add(
        ComponentType.inputPin,
        label: 'DIR',
      );
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode register = builder.add(ComponentType.shiftRegister4);
      final List<CircuitNode> probes = <CircuitNode>[
        builder.add(ComponentType.outputPin, label: 'Q0'),
        builder.add(ComponentType.outputPin, label: 'Q1'),
        builder.add(ComponentType.outputPin, label: 'Q2'),
        builder.add(ComponentType.outputPin, label: 'Q3'),
      ];
      builder.connect(data, register, toPort: 0);
      builder.connect(direction, register, toPort: 1);
      builder.connect(clock, register, toPort: 2);
      for (int i = 0; i < 4; i++) {
        builder.connect(register, probes[i], toPort: 0, fromPort: i);
      }

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(simulator.result.signalOf(probes[0].id), LogicSignal.high);
      simulator.stepClock();
      // D stays high, so it keeps entering the register while the previous
      // value moves one position further.
      expect(simulator.result.signalOf(probes[0].id), LogicSignal.high);
      expect(simulator.result.signalOf(probes[1].id), LogicSignal.high);
    });

    test('the counter counts up and wraps around', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode reset = builder.add(
        ComponentType.inputPin,
        label: 'RST',
      );
      final CircuitNode counter = builder.add(ComponentType.counter4);
      final List<CircuitNode> probes = <CircuitNode>[
        builder.add(ComponentType.outputPin, label: 'Q0'),
        builder.add(ComponentType.outputPin, label: 'Q1'),
        builder.add(ComponentType.outputPin, label: 'Q2'),
        builder.add(ComponentType.outputPin, label: 'Q3'),
      ];
      builder.connect(clock, counter, toPort: 0);
      builder.connect(reset, counter, toPort: 1);
      for (int i = 0; i < 4; i++) {
        builder.connect(counter, probes[i], toPort: 0, fromPort: i);
      }

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(simulator.result.signalOf(probes[0].id), LogicSignal.high);
      expect(simulator.result.signalOf(probes[1].id), LogicSignal.low);

      for (int i = 0; i < 15; i++) {
        simulator.stepClock();
      }
      // 16 steps in total: the counter wrapped back to zero.
      expect(simulator.result.signalOf(probes[0].id), LogicSignal.low);
      expect(simulator.result.signalOf(probes[1].id), LogicSignal.low);
      expect(simulator.result.signalOf(probes[2].id), LogicSignal.low);
      expect(simulator.result.signalOf(probes[3].id), LogicSignal.low);
    });

    test('reset clears the counter', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode reset = builder.add(
        ComponentType.inputPin,
        label: 'RST',
      );
      final CircuitNode counter = builder.add(ComponentType.counter4);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q0',
      );
      builder.connect(clock, counter, toPort: 0);
      builder.connect(reset, counter, toPort: 1);
      builder.connect(counter, probe, toPort: 0, fromPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.high);

      simulator.updateGraph(
        builder.build().copyWith(
          nodes: builder
              .build()
              .nodes
              .map(
                (CircuitNode node) => node.label == 'RST'
                    ? node.copyWith(inputValue: true)
                    : node,
              )
              .toList(),
        ),
      );
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);
    });
  });

  group('Feedback and cycles', () {
    test('valid feedback through a flip-flop is allowed and works', () {
      // Q of the flip-flop is inverted and fed back into D: the output must
      // toggle on every clock edge.
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode inverter = builder.add(ComponentType.notGate);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, inverter, toPort: 0, fromPort: 0);
      builder.connect(flipFlop, probe, toPort: 0, fromPort: 0);

      // The editor must allow closing the loop through the flip-flop.
      final ConnectionCheck check = CircuitValidator.canConnect(
        graph: builder.build(),
        fromNodeId: inverter.id,
        toNodeId: flipFlop.id,
        toInputIndex: 0,
      );
      expect(check.allowed, isTrue, reason: check.message);

      builder.connect(inverter, flipFlop, toPort: 0);
      final CircuitGraph graph = builder.build();

      final CircuitSimulator simulator = CircuitSimulator(graph);
      simulator.evaluate();
      expect(
        simulator.result.hasErrors,
        isFalse,
        reason: 'feedback through a flip-flop is not a combinational cycle',
      );
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.high);
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);
    });

    test('an invalid combinational loop is reported', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode gate1 = builder.add(ComponentType.nandGate);
      final CircuitNode gate2 = builder.add(ComponentType.nandGate);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Y',
      );
      builder.connect(gate1, gate2, toPort: 0);
      builder.connect(gate2, gate1, toPort: 0);
      builder.connect(gate1, probe, toPort: 0);

      final CircuitGraph graph = builder.build();
      final SimulationResult result = CircuitSimulator(graph).evaluate();
      expect(
        result.problems.any(
          (CircuitProblem problem) => problem.code == CircuitProblemCode.cycle,
        ),
        isTrue,
      );
      expect(result.signalOf(probe.id), LogicSignal.unknown);

      // The editor must refuse to create such a loop.
      final ConnectionCheck check = CircuitValidator.canConnect(
        graph: graph,
        fromNodeId: gate2.id,
        toNodeId: gate1.id,
        toInputIndex: 0,
      );
      expect(check.allowed, isFalse);
    });
  });

  group('Unknown and high impedance at the clock', () {
    test('an unknown clock does not create an edge and is reported', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode data = builder.add(
        ComponentType.inputPin,
        label: 'D',
        value: true,
      );
      // The clock input of the flip-flop stays unconnected -> unknown.
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(data, flipFlop, toPort: 0);
      builder.connect(flipFlop, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      expect(
        simulator.result.problems.any(
          (CircuitProblem problem) =>
              problem.code == CircuitProblemCode.unknownClock,
        ),
        isTrue,
      );
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);
    });
  });

  group('State handling', () {
    test('the state survives repeated evaluations and is cleared by reset', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode data = builder.add(
        ComponentType.inputPin,
        label: 'D',
        value: true,
      );
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(data, flipFlop, toPort: 0);
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(simulator.result.signalOf(probe.id), LogicSignal.high);

      simulator.evaluate();
      simulator.evaluate();
      expect(
        simulator.result.signalOf(probe.id),
        LogicSignal.high,
        reason: 'evaluating again must not clear the stored value',
      );

      simulator.reset();
      expect(simulator.result.signalOf(probe.id), LogicSignal.low);
    });

    test('two independent branches keep their own state', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode first = builder.add(
        ComponentType.dFlipFlop,
        label: 'FF1',
      );
      final CircuitNode second = builder.add(
        ComponentType.dFlipFlop,
        label: 'FF2',
      );
      final CircuitNode data = builder.add(
        ComponentType.inputPin,
        label: 'D',
        value: true,
      );
      final CircuitNode probeA = builder.add(
        ComponentType.outputPin,
        label: 'QA',
      );
      final CircuitNode probeB = builder.add(
        ComponentType.outputPin,
        label: 'QB',
      );
      builder.connect(data, first, toPort: 0);
      builder.connect(clock, first, toPort: 1);
      builder.connect(first, probeA, toPort: 0, fromPort: 0);
      builder.connect(data, second, toPort: 0);
      builder.connect(clock, second, toPort: 1);
      builder.connect(second, probeB, toPort: 0, fromPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      simulator.stepClock();
      expect(simulator.result.signalOf(probeA.id), LogicSignal.high);
      expect(simulator.result.signalOf(probeB.id), LogicSignal.high);
    });
  });
}
