import 'package:flutter/material.dart';

import '../domain/circuit_geometry.dart';
import '../domain/circuit_models.dart';

/// Lightweight, read-only preview of a circuit used in project lists and the
/// home dashboard. It draws from the real graph, so the preview always matches
/// the stored project.
class CircuitPreview extends StatelessWidget {
  const CircuitPreview({super.key, required this.graph, this.padding = 10});

  final CircuitGraph graph;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CustomPaint(
      painter: _CircuitPreviewPainter(
        graph: graph,
        background: theme.colorScheme.surfaceContainerLow,
        border: theme.colorScheme.outlineVariant,
        wire: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        node: theme.colorScheme.primary.withValues(alpha: 0.75),
        nodeFill: theme.colorScheme.surfaceContainerLowest,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CircuitPreviewPainter extends CustomPainter {
  const _CircuitPreviewPainter({
    required this.graph,
    required this.background,
    required this.border,
    required this.wire,
    required this.node,
    required this.nodeFill,
  });

  final CircuitGraph graph;
  final Color background;
  final Color border;
  final Color wire;
  final Color node;
  final Color nodeFill;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas.drawRRect(frame, Paint()..color = background);
    canvas.drawRRect(
      frame,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (graph.nodes.isEmpty) {
      final TextPainter painter = TextPainter(
        text: const TextSpan(
          text: 'مدار خالی',
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          (size.width - painter.width) / 2,
          (size.height - painter.height) / 2,
        ),
      );
      return;
    }

    final CanvasRect bounds = CircuitGeometry.boundsOf(graph.nodes);
    final double scaleX = (size.width - 16) / mathMax(1, bounds.width);
    final double scaleY = (size.height - 16) / mathMax(1, bounds.height);
    final double scale = scaleX < scaleY ? scaleX : scaleY;
    final double offsetX =
        (size.width - bounds.width * scale) / 2 - bounds.left * scale;
    final double offsetY =
        (size.height - bounds.height * scale) / 2 - bounds.top * scale;

    Offset map(CanvasPoint point) =>
        Offset(point.x * scale + offsetX, point.y * scale + offsetY);

    final Paint wirePaint =
        Paint()
          ..color = wire
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;

    for (final CircuitWire circuitWire in graph.wires) {
      final CircuitNode? source = graph.nodeById(circuitWire.fromNodeId);
      final CircuitNode? target = graph.nodeById(circuitWire.toNodeId);
      if (source == null || target == null) {
        continue;
      }
      final CanvasPoint? start = CircuitGeometry.portPosition(
        source,
        CircuitPin.output(source.id, circuitWire.fromPortIndex),
      );
      final CanvasPoint? end = CircuitGeometry.portPosition(
        target,
        CircuitPin.input(target.id, circuitWire.toInputIndex),
      );
      if (start == null || end == null) {
        continue;
      }
      final List<CanvasPoint> controls = CircuitGeometry.wireControlPoints(
        start,
        end,
      );
      final Path path =
          Path()
            ..moveTo(map(start).dx, map(start).dy)
            ..cubicTo(
              map(controls[1]).dx,
              map(controls[1]).dy,
              map(controls[2]).dx,
              map(controls[2]).dy,
              map(end).dx,
              map(end).dy,
            );
      canvas.drawPath(path, wirePaint);
    }

    for (final CircuitNode circuitNode in graph.nodes) {
      final CanvasRect nodeBounds = CircuitGeometry.nodeBounds(circuitNode);
      final Rect rect = Rect.fromLTWH(
        nodeBounds.left * scale + offsetX,
        nodeBounds.top * scale + offsetY,
        nodeBounds.width * scale,
        nodeBounds.height * scale,
      );
      final RRect rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.width * 0.18),
      );
      canvas.drawRRect(rrect, Paint()..color = nodeFill);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = node
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final CanvasPoint? output = CircuitGeometry.portPosition(
        circuitNode,
        CircuitPin.output(circuitNode.id, 0),
      );
      if (output != null) {
        canvas.drawCircle(map(output), 2.2, Paint()..color = node);
      }
    }
  }

  static double mathMax(double a, double b) => a > b ? a : b;

  @override
  bool shouldRepaint(covariant _CircuitPreviewPainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.background != background ||
        oldDelegate.node != node;
  }
}
