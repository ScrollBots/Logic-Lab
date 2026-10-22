import 'circuit_models.dart';
import 'circuit_simulator.dart';
import 'component_spec.dart';

export 'circuit_simulator.dart';

/// Connection rules for the editor.
///
/// The rules are shared by the editor (which refuses illegal gestures) and by
/// the simulator (which reports illegal wires that arrive through a project
/// file).
class ConnectionCheck {
  const ConnectionCheck({
    required this.allowed,
    required this.message,
    this.code,
  });

  final bool allowed;
  final String message;
  final CircuitProblemCode? code;

  static const ConnectionCheck ok = ConnectionCheck(
    allowed: true,
    message: 'اتصال معتبر است.',
  );
}

class CircuitValidator {
  const CircuitValidator._();

  /// Evaluates a circuit without any sequential state. For circuits with
  /// latches or flip-flops use [CircuitSimulator] directly so that the state
  /// can be stepped with a clock.
  static SimulationResult simulate(CircuitGraph graph) {
    return CircuitSimulator(graph).evaluate();
  }

  /// Checks whether a new wire would be legal.
  static ConnectionCheck canConnect({
    required CircuitGraph graph,
    required String fromNodeId,
    required String toNodeId,
    required int toInputIndex,
    int fromPortIndex = 0,
  }) {
    final CircuitNode? from = graph.nodeById(fromNodeId);
    final CircuitNode? to = graph.nodeById(toNodeId);
    if (from == null || to == null) {
      return const ConnectionCheck(
        allowed: false,
        message: 'یکی از قطعه‌های متصل پیدا نشد.',
        code: CircuitProblemCode.malformedWire,
      );
    }
    if (from.type.isOutput) {
      return const ConnectionCheck(
        allowed: false,
        message: 'پایه خروجی قطعه «خروجی» سیگنال تولید نمی‌کند.',
        code: CircuitProblemCode.sourceIsOutput,
      );
    }
    if (to.type.isInput) {
      return const ConnectionCheck(
        allowed: false,
        message:
            'ورودی‌ها سیگنال نمی‌پذیرند؛ از پایه خروجی آن‌ها استفاده کنید.',
        code: CircuitProblemCode.targetIsInput,
      );
    }
    if (to.type.isClock) {
      return const ConnectionCheck(
        allowed: false,
        message: 'پایه کلاک فقط توسط مولد کلاک تغذیه می‌شود.',
        code: CircuitProblemCode.targetIsInput,
      );
    }
    if (from.id == to.id) {
      return const ConnectionCheck(
        allowed: false,
        message: 'یک قطعه نمی‌تواند به خودش متصل شود.',
        code: CircuitProblemCode.cycle,
      );
    }
    if (fromPortIndex < 0 || fromPortIndex >= from.outputCount) {
      return const ConnectionCheck(
        allowed: false,
        message: 'شماره پایه خروجی معتبر نیست.',
        code: CircuitProblemCode.invalidPort,
      );
    }
    if (toInputIndex < 0 || toInputIndex >= to.inputCount) {
      return const ConnectionCheck(
        allowed: false,
        message: 'شماره پایه ورودی معتبر نیست.',
        code: CircuitProblemCode.invalidPort,
      );
    }
    final bool portTaken = graph.wires.any(
      (CircuitWire wire) =>
          wire.toNodeId == toNodeId && wire.toInputIndex == toInputIndex,
    );
    if (portTaken) {
      return const ConnectionCheck(
        allowed: false,
        message: 'این پایه قبلاً به یک سیگنال متصل شده است.',
        code: CircuitProblemCode.duplicateInputConnection,
      );
    }
    if (_wouldCreateCombinationalCycle(graph, fromNodeId, toNodeId)) {
      return const ConnectionCheck(
        allowed: false,
        message:
            'این اتصال یک چرخهٔ ترکیبی می‌سازد و مجاز نیست. '
            'بازخورد از راه یک فلیپ‌فلپ یا قفل مجاز است.',
        code: CircuitProblemCode.cycle,
      );
    }
    return ConnectionCheck.ok;
  }

  /// Detects a *combinational* cycle for the connection that is about to be
  /// created.
  ///
  /// A loop that runs through a stateful component (a flip-flop, a latch, a
  /// register) is valid sequential feedback and must stay possible: the state
  /// element breaks the combinational loop. The check therefore ignores every
  /// path that leaves a stateful component.
  static bool _wouldCreateCombinationalCycle(
    CircuitGraph graph,
    String fromNodeId,
    String toNodeId,
  ) {
    // Adding source -> target creates a cycle if target already reaches source
    // without passing through a stateful component.
    final Map<String, List<String>> adjacency = <String, List<String>>{};
    for (final CircuitWire wire in graph.wires) {
      adjacency
          .putIfAbsent(wire.fromNodeId, () => <String>[])
          .add(wire.toNodeId);
    }
    final List<String> stack = <String>[toNodeId];
    final Set<String> seen = <String>{};
    while (stack.isNotEmpty) {
      final String current = stack.removeLast();
      if (current == fromNodeId) {
        return true;
      }
      if (!seen.add(current)) {
        continue;
      }
      final CircuitNode? node = graph.nodeById(current);
      if (node != null && ComponentLibrary.specOf(node.type).isStateful) {
        // The loop is broken by a stateful element: this is sequential
        // feedback, not a combinational cycle.
        continue;
      }
      stack.addAll(adjacency[current] ?? const <String>[]);
    }
    return false;
  }

  /// Gate truth functions exposed independently for exhaustive unit testing.
  /// NAND/NOR/XNOR are derived and XOR is true for an odd number of HIGHs.
  static bool evaluateGate(ComponentType type, List<bool> inputs) {
    if (inputs.isEmpty) {
      throw ArgumentError('هر دروازه حداقل به یک ورودی نیاز دارد.');
    }
    final ComponentSpec spec = ComponentLibrary.specOf(type);
    final List<LogicSignal> signals = inputs
        .map(LogicSignal.fromBool)
        .toList(growable: false);
    final List<LogicSignal> result = spec.evaluator!(
      signals,
      const ComponentState(),
    );
    return result.first == LogicSignal.high;
  }
}
