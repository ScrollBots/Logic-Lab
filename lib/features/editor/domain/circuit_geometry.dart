import 'dart:math' as math;

import 'circuit_models.dart';
import 'component_spec.dart';

class CircuitGeometry {
  const CircuitGeometry._();

  static const double nodeWidth = 112;
  static const double nodeHeight = 88;
  static const double moduleWidth = 148;
  static const double portRadius = 5;
  static const double portHitRadius = 22;
  static const double inputPortGap = 24;
  static const double outputPortGap = 22;
  static const double selectionPadding = 7;
  static const double canvasWidth = 1800;
  static const double canvasHeight = 1200;
  static const double gridSize = 24;

  static CanvasPoint nodeCenter(CircuitNode node) => node.position;

  /// Width of the drawn body. Compound modules are wider so their port
  /// labels fit.
  static double widthOf(CircuitNode node) {
    final ComponentSpec spec = ComponentLibrary.specOf(node.type);
    if (spec.kind == ComponentKind.module ||
        spec.kind == ComponentKind.sequential) {
      return moduleWidth;
    }
    return nodeWidth;
  }

  /// Height of the drawn body, derived from the number of ports.
  static double heightOf(CircuitNode node) {
    final ComponentSpec spec = ComponentLibrary.specOf(node.type);
    final int ports = math.max(node.inputCount, node.outputCount);
    if (spec.kind == ComponentKind.module ||
        spec.kind == ComponentKind.sequential) {
      return math.max(72.0, 46.0 + ports * 20.0);
    }
    // A gate with more than four inputs needs a taller body so that every
    // port stays on the outline instead of floating past its corners.
    if (spec.kind == ComponentKind.gate && node.inputCount > 4) {
      return math.max(nodeHeight, (node.inputCount - 1) * inputPortGap + 24);
    }
    return nodeHeight;
  }

  static double inputPortY(CircuitNode node, int index) {
    final int count = math.max(1, node.inputCount);
    return node.position.y + (index - (count - 1) / 2) * inputPortGap;
  }

  static double outputPortY(CircuitNode node, int index) {
    final int count = math.max(1, node.outputCount);
    return node.position.y + (index - (count - 1) / 2) * outputPortGap;
  }

  static CanvasPoint? portPosition(CircuitNode node, CircuitPin pin) {
    if (pin.isInput) {
      if (!node.type.acceptsInputs ||
          pin.index < 0 ||
          pin.index >= node.inputCount) {
        return null;
      }
      return CanvasPoint(
        node.position.x - widthOf(node) / 2,
        inputPortY(node, pin.index),
      );
    }
    if (!node.type.producesSignal ||
        pin.index < 0 ||
        pin.index >= node.outputCount) {
      return null;
    }
    return CanvasPoint(
      node.position.x + widthOf(node) / 2,
      outputPortY(node, pin.index),
    );
  }

  static CanvasRect nodeBounds(CircuitNode node) {
    final double width = widthOf(node);
    final double height = heightOf(node);
    return CanvasRect(
      node.position.x - width / 2,
      node.position.y - height / 2,
      width,
      height,
    );
  }

  static CircuitPin? portAt(
    CircuitGraph graph,
    CanvasPoint point, {
    double radius = portHitRadius,
    bool inputOnly = false,
    bool outputOnly = false,
  }) {
    CircuitPin? closest;
    double closestDistance = radius;
    for (final CircuitNode node in graph.nodes.reversed) {
      final Iterable<CircuitPin> pins = <CircuitPin>[
        if (!inputOnly && node.type.producesSignal)
          for (int i = 0; i < node.outputCount; i++)
            CircuitPin.output(node.id, i),
        if (!outputOnly && node.type.acceptsInputs)
          for (int i = 0; i < node.inputCount; i++)
            CircuitPin.input(node.id, i),
      ];
      for (final CircuitPin pin in pins) {
        final CanvasPoint? position = portPosition(node, pin);
        if (position == null) {
          continue;
        }
        final double distance = position.distanceTo(point);
        if (distance <= radius &&
            (closest == null || distance < closestDistance)) {
          closest = pin;
          closestDistance = distance;
        }
      }
    }
    return closest;
  }

  static CircuitNode? nodeAt(CircuitGraph graph, CanvasPoint point) {
    for (final CircuitNode node in graph.nodes.reversed) {
      if (nodeBounds(node).inflate(4).contains(point)) {
        return node;
      }
    }
    return null;
  }

  /// Cubic Bézier control points for an orthogonal-flow wire. Both endpoint
  /// directions point horizontally, making signals easy to follow in RTL UIs
  /// without mirroring the technical left-to-right signal flow.
  static List<CanvasPoint> wireControlPoints(
    CanvasPoint start,
    CanvasPoint end,
  ) {
    final double dx = (end.x - start.x).abs();
    final double reach = math.max(48, math.min(180, dx * 0.55));
    return <CanvasPoint>[
      start,
      CanvasPoint(start.x + reach, start.y),
      CanvasPoint(end.x - reach, end.y),
      end,
    ];
  }

  static CanvasPoint bezierPoint(List<CanvasPoint> controls, double t) {
    final double u = 1 - t;
    final double b0 = u * u * u;
    final double b1 = 3 * u * u * t;
    final double b2 = 3 * u * t * t;
    final double b3 = t * t * t;
    return CanvasPoint(
      b0 * controls[0].x +
          b1 * controls[1].x +
          b2 * controls[2].x +
          b3 * controls[3].x,
      b0 * controls[0].y +
          b1 * controls[1].y +
          b2 * controls[2].y +
          b3 * controls[3].y,
    );
  }

  static double distanceToWire(
    CanvasPoint point,
    CanvasPoint start,
    CanvasPoint end,
  ) {
    final List<CanvasPoint> controls = wireControlPoints(start, end);
    double minimum = double.infinity;
    CanvasPoint previous = start;
    const int segments = 24;
    for (int i = 1; i <= segments; i++) {
      final CanvasPoint current = bezierPoint(controls, i / segments);
      minimum = math.min(minimum, _distanceToSegment(point, previous, current));
      previous = current;
    }
    return minimum;
  }

  static String? wireAt(
    CircuitGraph graph,
    CanvasPoint point, {
    double radius = 12,
  }) {
    String? bestId;
    double bestDistance = radius;
    for (final CircuitWire wire in graph.wires.reversed) {
      final CircuitNode? source = graph.nodeById(wire.fromNodeId);
      final CircuitNode? target = graph.nodeById(wire.toNodeId);
      if (source == null || target == null) {
        continue;
      }
      final CanvasPoint? start = portPosition(
        source,
        CircuitPin.output(source.id, wire.fromPortIndex),
      );
      final CanvasPoint? end = portPosition(
        target,
        CircuitPin.input(target.id, wire.toInputIndex),
      );
      if (start == null || end == null) {
        continue;
      }
      final double distance = distanceToWire(point, start, end);
      if (distance <= bestDistance) {
        bestDistance = distance;
        bestId = wire.id;
      }
    }
    return bestId;
  }

  static CanvasRect boundsOf(Iterable<CircuitNode> nodes) {
    if (nodes.isEmpty) {
      return const CanvasRect(0, 0, 1200, 700);
    }
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    for (final CircuitNode node in nodes) {
      final CanvasRect bounds = nodeBounds(node);
      minX = math.min(minX, bounds.left);
      minY = math.min(minY, bounds.top);
      maxX = math.max(maxX, bounds.right);
      maxY = math.max(maxY, bounds.bottom);
    }
    return CanvasRect(minX, minY, maxX - minX, maxY - minY);
  }

  static double _distanceToSegment(
    CanvasPoint p,
    CanvasPoint a,
    CanvasPoint b,
  ) {
    final double dx = b.x - a.x;
    final double dy = b.y - a.y;
    if (dx == 0 && dy == 0) {
      return p.distanceTo(a);
    }
    final double t = (((p.x - a.x) * dx + (p.y - a.y) * dy) /
            (dx * dx + dy * dy))
        .clamp(0.0, 1.0);
    final CanvasPoint projection = CanvasPoint(a.x + t * dx, a.y + t * dy);
    return p.distanceTo(projection);
  }
}

class CircuitPin {
  const CircuitPin({
    required this.nodeId,
    required this.index,
    required this.isInput,
  });

  factory CircuitPin.input(String nodeId, int index) {
    return CircuitPin(nodeId: nodeId, index: index, isInput: true);
  }

  factory CircuitPin.output(String nodeId, int index) {
    return CircuitPin(nodeId: nodeId, index: index, isInput: false);
  }

  final String nodeId;
  final int index;
  final bool isInput;

  @override
  bool operator ==(Object other) {
    return other is CircuitPin &&
        other.nodeId == nodeId &&
        other.index == index &&
        other.isInput == isInput;
  }

  @override
  int get hashCode => Object.hash(nodeId, index, isInput);
}

class CanvasRect {
  const CanvasRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool contains(CanvasPoint point) {
    return point.x >= left &&
        point.x <= right &&
        point.y >= top &&
        point.y <= bottom;
  }

  CanvasRect inflate(double amount) {
    return CanvasRect(
      left - amount,
      top - amount,
      width + amount * 2,
      height + amount * 2,
    );
  }
}
