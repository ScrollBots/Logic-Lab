import 'package:flutter/material.dart';

import '../../features/editor/domain/circuit_models.dart';

/// Compact schematic symbol for gates, used in trays, learning cards, and
/// quick-start actions. Symbols always render left-to-right as in technical
/// notation, even inside the RTL interface.
class GateSymbol extends StatelessWidget {
  const GateSymbol({
    super.key,
    required this.type,
    this.size = 38,
    this.color,
    this.strokeWidth = 1.8,
  });

  final ComponentType type;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: type.persianName,
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _GateSymbolPainter(
          type: type,
          color: color ?? Theme.of(context).colorScheme.onSurface,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _GateSymbolPainter extends CustomPainter {
  _GateSymbolPainter({
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

  final ComponentType type;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final double left = size.width * 0.14;
    final double right = size.width * 0.78;
    final double top = size.height * 0.25;
    final double bottom = size.height * 0.75;
    final double mid = size.height * 0.5;
    final bool bubble =
        type == ComponentType.nandGate ||
        type == ComponentType.norGate ||
        type == ComponentType.xnorGate;
    final double gateRight = bubble ? right - size.width * 0.06 : right;

    if (type == ComponentType.notGate) {
      final Path triangle =
          Path()
            ..moveTo(left, top)
            ..lineTo(left, bottom)
            ..lineTo(gateRight, mid)
            ..close();
      canvas.drawPath(triangle, stroke);
      final double bubbleCenter = gateRight + size.width * 0.06;
      if (bubble) {
        canvas.drawCircle(
          Offset(bubbleCenter, mid),
          size.width * 0.055,
          stroke,
        );
      }
    } else {
      Path shape;
      if (type == ComponentType.andGate || type == ComponentType.nandGate) {
        shape =
            Path()
              ..moveTo(left, top)
              ..lineTo(size.width * 0.42, top)
              ..cubicTo(
                gateRight + 2,
                top,
                gateRight + 1,
                mid - 2,
                gateRight,
                mid,
              )
              ..cubicTo(
                gateRight + 1,
                mid + 2,
                gateRight + 2,
                bottom,
                size.width * 0.42,
                bottom,
              )
              ..lineTo(left, bottom)
              ..close();
      } else {
        final bool xor =
            type == ComponentType.xorGate || type == ComponentType.xnorGate;
        shape =
            Path()
              ..moveTo(left + (xor ? 3 : 0), top)
              ..quadraticBezierTo(size.width * 0.62, top + 2, gateRight, mid)
              ..quadraticBezierTo(
                size.width * 0.62,
                bottom - 2,
                left + (xor ? 3 : 0),
                bottom,
              )
              ..quadraticBezierTo(
                size.width * 0.35,
                mid,
                left + (xor ? 3 : 0),
                top,
              )
              ..close();
        if (xor) {
          final Path extra =
              Path()
                ..moveTo(left - 3, top)
                ..quadraticBezierTo(size.width * 0.26, mid, left - 3, bottom);
          canvas.drawPath(extra, stroke);
        }
      }
      canvas.drawPath(shape, stroke);
      if (bubble) {
        canvas.drawCircle(
          Offset(gateRight + size.width * 0.06, mid),
          size.width * 0.05,
          stroke,
        );
      }
    }

    canvas.drawLine(
      Offset(0, size.height * 0.38),
      Offset(left, size.height * 0.38),
      stroke,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(left, size.height * 0.62),
      stroke,
    );
    final double outStart = bubble ? right + size.width * 0.01 : right;
    canvas.drawLine(Offset(outStart, mid), Offset(size.width, mid), stroke);
  }

  @override
  bool shouldRepaint(covariant _GateSymbolPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class ComponentTypeLabel extends StatelessWidget {
  const ComponentTypeLabel({super.key, required this.type});

  final ComponentType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GateSymbol(type: type, size: 22, strokeWidth: 1.4),
        const SizedBox(width: 7),
        Text(
          type.technicalName,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}
