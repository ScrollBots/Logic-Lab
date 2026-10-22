import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';

import '../../support/circuit_test_support.dart';

void main() {
  group('The result describes exactly one simulation step', () {
    test('every wire carries the signal of its driver to its target', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode a = builder.add(
        ComponentType.inputPin,
        label: 'A',
        value: true,
      );
      final CircuitNode b = builder.add(ComponentType.inputPin, label: 'B');
      final CircuitNode gate = builder.add(ComponentType.andGate);
      final CircuitNode inverter = builder.add(ComponentType.notGate);
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Y',
      );
      builder.connect(a, gate, toPort: 0);
      builder.connect(b, gate, toPort: 1);
      builder.connect(gate, inverter, toPort: 0);
      builder.connect(inverter, flipFlop, toPort: 0);
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, probe, toPort: 0, fromPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.stepClock();
      final SimulationResult result = simulator.result;

      for (final CircuitWire wire in simulator.currentGraph.wires) {
        final LogicSignal driven = result.signalOf(
          wire.fromNodeId,
          wire.fromPortIndex,
        );
        final LogicSignal received = result.inputOf(
          wire.toNodeId,
          wire.toInputIndex,
        );
        expect(
          received,
          driven,
          reason:
              'wire ${wire.id} must carry the signal of '
              '${wire.fromNodeId} to ${wire.toNodeId}',
        );
      }
    });

    test('the reported clock level is the level of the clock source', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode clock = builder.add(ComponentType.clockSource);
      final CircuitNode flipFlop = builder.add(ComponentType.dFlipFlop);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Q',
      );
      builder.connect(clock, flipFlop, toPort: 1);
      builder.connect(flipFlop, probe, toPort: 0, fromPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      simulator.evaluate();
      expect(simulator.result.clockLevel, isFalse);
      expect(simulator.result.signalOf(clock.id), LogicSignal.low);

      simulator.setClockLevel(true);
      expect(simulator.result.clockLevel, isTrue);
      expect(simulator.result.signalOf(clock.id), LogicSignal.high);
    });

    test('every evaluated node has an output and every output is known', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode a = builder.add(ComponentType.inputPin, label: 'A');
      final CircuitNode gate = builder.add(ComponentType.andGate);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Y',
      );
      builder.connect(a, gate, toPort: 0);
      builder.connect(gate, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      final SimulationResult result = simulator.evaluate();
      for (final String id in result.evaluatedNodeIds) {
        expect(
          result.outputSignals.containsKey(id),
          isTrue,
          reason: 'node $id was evaluated but has no output',
        );
      }
      expect(result.evaluatedNodeIds, contains(gate.id));
      expect(result.evaluatedNodeIds, contains(probe.id));
    });

    test('a problem never refers to a node that does not exist', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode gate = builder.add(ComponentType.andGate);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Y',
      );
      builder.connect(gate, probe, toPort: 0);

      final CircuitSimulator simulator = CircuitSimulator(builder.build());
      final SimulationResult result = simulator.evaluate();
      expect(result.problems, isNotEmpty);
      for (final CircuitProblem problem in result.problems) {
        if (problem.nodeId == null) {
          continue;
        }
        expect(
          simulator.currentGraph.nodeById(problem.nodeId!),
          isNotNull,
          reason: 'problem ${problem.code.name} points at a missing node',
        );
      }
    });

    test('the same graph always produces the same signals', () {
      final CircuitBuilder builder = CircuitBuilder();
      final CircuitNode a = builder.add(
        ComponentType.inputPin,
        label: 'A',
        value: true,
      );
      final CircuitNode gate = builder.add(ComponentType.xorGate);
      final CircuitNode probe = builder.add(
        ComponentType.outputPin,
        label: 'Y',
      );
      builder.connect(a, gate, toPort: 0);
      builder.connect(gate, probe, toPort: 0);

      final CircuitGraph graph = builder.build();
      final LogicSignal first = CircuitSimulator(
        graph,
      ).evaluate().signalOf(probe.id);
      final LogicSignal second = CircuitSimulator(
        graph,
      ).evaluate().signalOf(probe.id);
      expect(second, first);
    });
  });
}
