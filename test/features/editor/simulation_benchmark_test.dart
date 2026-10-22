import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/domain/circuit_simulator.dart';

/// Builds a chain of `count` inverters fed by one input, plus a probe.
CircuitGraph _chain(int count) {
  final List<CircuitNode> nodes = <CircuitNode>[];
  final List<CircuitWire> wires = <CircuitWire>[];
  nodes.add(
    CircuitNode(
      id: 'in',
      type: ComponentType.inputPin,
      position: const CanvasPoint(0, 0),
      label: 'IN',
    ),
  );
  String previous = 'in';
  for (int i = 0; i < count; i++) {
    final String id = 'n$i';
    nodes.add(
      CircuitNode(
        id: id,
        type: ComponentType.notGate,
        position: CanvasPoint(100.0 + i * 60, 0),
        label: 'N$i',
      ),
    );
    wires.add(
      CircuitWire(
        id: 'w$i',
        fromNodeId: previous,
        toNodeId: id,
        toInputIndex: 0,
      ),
    );
    previous = id;
  }
  nodes.add(
    CircuitNode(
      id: 'out',
      type: ComponentType.outputPin,
      position: CanvasPoint(100.0 + count * 60, 0),
      label: 'OUT',
    ),
  );
  wires.add(
    CircuitWire(
      id: 'wo',
      fromNodeId: previous,
      toNodeId: 'out',
      toInputIndex: 0,
    ),
  );
  return CircuitGraph(nodes: nodes, wires: wires);
}

/// Builds a circuit with `count` independent flip-flops that share one clock.
CircuitGraph _parallelFlipFlops(int count) {
  final List<CircuitNode> nodes = <CircuitNode>[];
  final List<CircuitWire> wires = <CircuitWire>[];
  nodes.add(
    CircuitNode(
      id: 'clk',
      type: ComponentType.clockSource,
      position: const CanvasPoint(0, 0),
      label: 'CLK',
    ),
  );
  nodes.add(
    CircuitNode(
      id: 'd',
      type: ComponentType.inputPin,
      position: const CanvasPoint(0, 120),
      label: 'D',
      inputValue: true,
    ),
  );
  for (int i = 0; i < count; i++) {
    final String id = 'ff$i';
    nodes.add(
      CircuitNode(
        id: id,
        type: ComponentType.dFlipFlop,
        position: CanvasPoint(200.0 + (i % 10) * 90, (i ~/ 10) * 120.0),
        label: 'FF$i',
      ),
    );
    wires.add(
      CircuitWire(id: 'wd$i', fromNodeId: 'd', toNodeId: id, toInputIndex: 0),
    );
    wires.add(
      CircuitWire(id: 'wc$i', fromNodeId: 'clk', toNodeId: id, toInputIndex: 1),
    );
  }
  return CircuitGraph(nodes: nodes, wires: wires);
}

void main() {
  group('Simulation performance', () {
    test('a chain of gates scales roughly linearly', () {
      // Reference numbers (debug VM, warm): 10 gates ~0.24 ms, 50 ~0.45 ms,
      // 100 ~0.60 ms, 200 ~1.3 ms per evaluation.
      final List<double> measurements = <double>[];
      for (final int size in <int>[10, 50, 100, 200]) {
        final CircuitSimulator simulator = CircuitSimulator(_chain(size));
        simulator.evaluate();
        const int runs = 20;
        final Stopwatch watch = Stopwatch()..start();
        for (int i = 0; i < runs; i++) {
          simulator.evaluate();
        }
        watch.stop();
        final double micros = watch.elapsedMicroseconds / runs;
        measurements.add(micros);
        // ignore: avoid_print
        print(
          'BENCH chain=$size nodes=${size + 2} ${micros.toStringAsFixed(1)} us/evaluation',
        );
      }
      // A lookup that scans the node list would make this quadratic; the
      // limit below is far above the measured value but catches such a
      // regression immediately.
      expect(measurements.last, lessThan(20000));
      // The growth from 10 to 200 nodes must stay clearly sub-quadratic.
      final double growth = measurements.last / measurements.first;
      expect(growth, lessThan(30));
    });

    test('many flip-flops stay cheap to evaluate', () {
      final CircuitSimulator simulator = CircuitSimulator(
        _parallelFlipFlops(50),
      );
      simulator.evaluate();
      const int runs = 20;
      final Stopwatch watch = Stopwatch()..start();
      for (int i = 0; i < runs; i++) {
        simulator.stepClock();
      }
      watch.stop();
      final double micros = watch.elapsedMicroseconds / runs;
      // ignore: avoid_print
      print(
        'BENCH 50 flip-flops: ${micros.toStringAsFixed(1)} us per clock cycle',
      );
      expect(micros, lessThan(20000));
    });
  });
}
