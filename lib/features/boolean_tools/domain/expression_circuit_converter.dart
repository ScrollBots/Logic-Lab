import '../../../core/utils/id_generator.dart';
import '../../../features/editor/domain/circuit_models.dart';
import 'boolean_expression.dart';

class ExpressionConversionException implements Exception {
  const ExpressionConversionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Converts a parsed Boolean expression into a real editable circuit. The
/// generated graph deliberately contains ordinary gates and wires; no hidden
/// evaluation shortcut is used by the editor or simulator.
class ExpressionCircuitConverter {
  const ExpressionCircuitConverter._();

  static const int _inputX = 100;
  static const int _levelGap = 200;
  static const int _inputGap = 150;

  static CircuitGraph toCircuit(BoolExpr expression) {
    final List<String> variables = expression.collectVariables().toList()
      ..sort();
    if (variables.isEmpty) {
      throw const ExpressionConversionException(
        'عبارت‌های ثابت (بدون متغیر) به مدار تبدیل نمی‌شوند؛ عبارت باید حداقل یک متغیر داشته باشد.',
      );
    }
    if (variables.length > 8) {
      throw const ExpressionConversionException(
        'تبدیل بیش از ۸ متغیر به مدار پشتیبانی نمی‌شود.',
      );
    }

    final int depth = _depth(expression);
    final Map<String, CircuitNode> inputs = <String, CircuitNode>{};
    for (int i = 0; i < variables.length; i++) {
      final String name = variables[i];
      inputs[name] = CircuitNode(
        id: IdGenerator.next('in'),
        type: ComponentType.inputPin,
        position: CanvasPoint(
          _inputX.toDouble(),
          120 + i * _inputGap.toDouble(),
        ),
        label: name,
        inputValue: false,
      );
    }

    final List<CircuitNode> nodes = <CircuitNode>[...inputs.values];
    final List<CircuitWire> wires = <CircuitWire>[];

    _Built build(BoolExpr node, int depthFromRoot) {
      if (node is BoolVariable) {
        return _Built(inputs[node.name]!.id, inputs[node.name]!.position.y);
      }
      if (node is BoolConstant) {
        throw const ExpressionConversionException(
          'تبدیل عبارت شامل ثابت ۰ یا ۱ به مدار پشتیبانی نمی‌شود؛ از متغیرها استفاده کنید.',
        );
      }

      final double x = _inputX + (depth - depthFromRoot) * _levelGap.toDouble();
      if (node is BoolNot) {
        final _Built child = build(node.operand, depthFromRoot + 1);
        final CircuitNode gate = CircuitNode(
          id: IdGenerator.next('g'),
          type: ComponentType.notGate,
          position: CanvasPoint(x, child.y),
          label: 'NOT',
          inputCount: 1,
        );
        nodes.add(gate);
        wires.add(
          CircuitWire(
            id: IdGenerator.next('w'),
            fromNodeId: child.nodeId,
            toNodeId: gate.id,
            toInputIndex: 0,
          ),
        );
        return _Built(gate.id, child.y);
      }
      if (node is BoolBinary) {
        final _Built left = build(node.left, depthFromRoot + 1);
        final _Built right = build(node.right, depthFromRoot + 1);
        final ComponentType type = switch (node.operator) {
          BooleanOperator.and => ComponentType.andGate,
          BooleanOperator.or => ComponentType.orGate,
          BooleanOperator.xor => ComponentType.xorGate,
        };
        final double y = (left.y + right.y) / 2;
        final CircuitNode gate = CircuitNode(
          id: IdGenerator.next('g'),
          type: type,
          position: CanvasPoint(x, y),
          label: type.technicalName,
          inputCount: 2,
        );
        nodes.add(gate);
        wires
          ..add(
            CircuitWire(
              id: IdGenerator.next('w'),
              fromNodeId: left.nodeId,
              toNodeId: gate.id,
              toInputIndex: 0,
            ),
          )
          ..add(
            CircuitWire(
              id: IdGenerator.next('w'),
              fromNodeId: right.nodeId,
              toNodeId: gate.id,
              toInputIndex: 1,
            ),
          );
        return _Built(gate.id, y);
      }
      throw const ExpressionConversionException('گره عبارت پشتیبانی نمی‌شود.');
    }

    final _Built root = build(expression, 0);

    // Separate gates sharing a column vertically when their computed centers
    // are too close. This keeps generated circuits readable without changing
    // connectivity.
    final Map<double, List<CircuitNode>> columns =
        <double, List<CircuitNode>>{};
    for (final CircuitNode node in nodes) {
      if (node.type.isGate) {
        columns.putIfAbsent(node.position.x, () => <CircuitNode>[]).add(node);
      }
    }
    final List<CircuitNode> adjusted = List<CircuitNode>.from(nodes);
    for (final List<CircuitNode> column in columns.values) {
      column.sort(
        (CircuitNode a, CircuitNode b) => a.position.y.compareTo(b.position.y),
      );
      double minimum = double.negativeInfinity;
      for (final CircuitNode node in column) {
        double y = node.position.y;
        if (y < minimum + 112) {
          y = minimum + 112;
        }
        minimum = y;
        final int index = adjusted.indexWhere(
          (CircuitNode n) => n.id == node.id,
        );
        adjusted[index] = node.copyWith(
          position: CanvasPoint(node.position.x, y),
        );
      }
    }

    final CircuitNode adjustedRoot = adjusted.firstWhere(
      (CircuitNode node) => node.id == root.nodeId,
    );
    final double maxX = adjusted.fold<double>(
      0,
      (double current, CircuitNode node) =>
          node.position.x > current ? node.position.x : current,
    );
    final CircuitNode output = CircuitNode(
      id: IdGenerator.next('out'),
      type: ComponentType.outputPin,
      position: CanvasPoint(maxX + _levelGap, adjustedRoot.position.y),
      label: 'Y',
      inputCount: 1,
    );
    adjusted.add(output);
    wires.add(
      CircuitWire(
        id: IdGenerator.next('w'),
        fromNodeId: root.nodeId,
        toNodeId: output.id,
        toInputIndex: 0,
      ),
    );

    return CircuitGraph(nodes: adjusted, wires: wires);
  }

  static int _depth(BoolExpr expression) {
    if (expression is BoolNot) {
      return 1 + _depth(expression.operand);
    }
    if (expression is BoolBinary) {
      final int left = _depth(expression.left);
      final int right = _depth(expression.right);
      return 1 + (left > right ? left : right);
    }
    return 0;
  }
}

class _Built {
  const _Built(this.nodeId, this.y);

  final String nodeId;
  final double y;
}
