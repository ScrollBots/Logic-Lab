import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/logic_lab_theme.dart';
import '../application/circuit_editor_controller.dart';
import '../domain/circuit_geometry.dart';
import '../domain/circuit_models.dart';
import '../domain/component_spec.dart';
import '../domain/circuit_validator.dart';

class CircuitCanvasController {
  _CircuitCanvasState? _state;

  void resetView() => _state?._fitToCircuit(animated: true);

  void zoomIn() => _state?._zoomBy(1.18);

  void zoomOut() => _state?._zoomBy(1 / 1.18);

  /// Returns the center of the current viewport in circuit coordinates, so a
  /// newly added component appears where the user is looking.
  CanvasPoint? visibleCenter() => _state?._visibleCenter();
}

class CircuitCanvas extends StatefulWidget {
  const CircuitCanvas({
    super.key,
    required this.editor,
    required this.canvasController,
    this.showGrid = true,
  });

  final CircuitEditorController editor;
  final CircuitCanvasController canvasController;
  final bool showGrid;

  @override
  State<CircuitCanvas> createState() => _CircuitCanvasState();
}

class _CircuitCanvasState extends State<CircuitCanvas> {
  final TransformationController _transform = TransformationController();
  Size _viewport = Size.zero;
  bool _didInitialFit = false;

  CircuitEditorController get editor => widget.editor;

  @override
  void initState() {
    super.initState();
    widget.canvasController._state = this;
  }

  @override
  void didUpdateWidget(covariant CircuitCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasController != widget.canvasController) {
      oldWidget.canvasController._state = null;
      widget.canvasController._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.canvasController._state == this) {
      widget.canvasController._state = null;
    }
    _transform.dispose();
    super.dispose();
  }

  void _fitToCircuit({bool animated = false}) {
    if (_viewport.isEmpty) {
      return;
    }
    final CanvasRect bounds = CircuitGeometry.boundsOf(editor.graph.nodes);
    const double padding = 150;
    final double availableWidth = math.max(1, _viewport.width - 40);
    final double availableHeight = math.max(1, _viewport.height - 40);
    final double scale = math
        .min(
          1.05,
          math.min(
            availableWidth / math.max(1, bounds.width + padding * 2),
            availableHeight / math.max(1, bounds.height + padding * 2),
          ),
        )
        .clamp(0.28, 1.05);
    final double centerX = bounds.left + bounds.width / 2;
    final double centerY = bounds.top + bounds.height / 2;
    final double dx = _viewport.width / 2 - centerX * scale;
    final double dy = _viewport.height / 2 - centerY * scale;
    final Matrix4 target =
        Matrix4.identity()
          ..translate(dx, dy)
          ..scale(scale, scale);
    _transform.value = target;
  }

  void _zoomBy(double factor) {
    if (_viewport.isEmpty) {
      return;
    }
    final Offset center = Offset(_viewport.width / 2, _viewport.height / 2);
    final Matrix4 current = _transform.value;
    final double currentScale = current.getMaxScaleOnAxis();
    final double targetScale = (currentScale * factor).clamp(0.28, 2.6);
    final double actualFactor = targetScale / currentScale;
    final Matrix4 next =
        Matrix4.copy(current)
          ..translate(center.dx, center.dy)
          ..scale(actualFactor, actualFactor)
          ..translate(-center.dx, -center.dy);
    _transform.value = next;
  }

  CanvasPoint? _visibleCenter() {
    if (_viewport.isEmpty) {
      return null;
    }
    final Matrix4 inverse =
        Matrix4.tryInvert(_transform.value) ?? Matrix4.identity();
    final Offset center = MatrixUtils.transformPoint(
      inverse,
      Offset(_viewport.width / 2, _viewport.height / 2),
    );
    return CanvasPoint(center.dx, center.dy);
  }

  void _handleCanvasTap(TapUpDetails details) {
    final CanvasPoint point = CanvasPoint(
      details.localPosition.dx,
      details.localPosition.dy,
    );
    final CircuitPin? pin = CircuitGeometry.portAt(editor.graph, point);
    if (pin != null) {
      _handlePinTap(pin);
      return;
    }
    final String? wireId = CircuitGeometry.wireAt(editor.graph, point);
    if (wireId != null) {
      editor.selectWire(wireId);
      return;
    }
    final CircuitNode? node = CircuitGeometry.nodeAt(editor.graph, point);
    if (node != null) {
      if (node.type.isInput) {
        editor.toggleInput(node.id);
      } else {
        editor.selectNode(node.id);
      }
      return;
    }
    editor.clearSelection();
  }

  void _handlePinTap(CircuitPin pin) {
    if (pin.isInput) {
      editor.tapInputPort(pin.nodeId, pin.index);
    } else {
      editor.tapOutputPort(pin.nodeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size newViewport = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        if (newViewport != _viewport) {
          _viewport = newViewport;
          if (!_didInitialFit && !_viewport.isEmpty) {
            _didInitialFit = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _fitToCircuit();
              }
            });
          }
        }
        return AnimatedBuilder(
          animation: editor,
          builder: (BuildContext context, Widget? child) {
            final ThemeData theme = Theme.of(context);
            final LogicLabColors logicColors = LogicLabColors.of(context);
            return ClipRect(
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerLow,
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 0.28,
                  maxScale: 2.6,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(900),
                  constrained: false,
                  clipBehavior: Clip.none,
                  child: SizedBox(
                    width: CircuitGeometry.canvasWidth,
                    height: CircuitGeometry.canvasHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: _handleCanvasTap,
                            child: CustomPaint(
                              painter: CircuitPainter(
                                graph: editor.graph,
                                report: editor.report,
                                selectedNodeId: editor.selectedNodeId,
                                selectedWireId: editor.selectedWireId,
                                pendingSourceId: editor.pendingSourceId,
                                pendingSourcePort: editor.pendingSourcePort,
                                selectedNodeIds: editor.selectedNodeIds,
                                showGrid: widget.showGrid,
                                theme: theme,
                                colors: logicColors,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        for (final CircuitNode node in editor.graph.nodes)
                          ..._nodeOverlays(context, node),
                        for (final CircuitNode node in editor.graph.nodes)
                          ..._portOverlays(context, node, theme),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _nodeOverlays(BuildContext context, CircuitNode node) {
    final CanvasRect bounds = CircuitGeometry.nodeBounds(node);
    final bool isInput = node.type.isInput;
    final String semantics =
        isInput
            ? '${node.label}، ورودی، مقدار ${node.inputValue ? 'یک' : 'صفر'}؛ برای تغییر مقدار دو بار ضربه بزنید یا از دکمه استفاده کنید.'
            : '${node.label}، ${node.type.persianName}';
    return <Widget>[
      Positioned(
        left: bounds.left,
        top: bounds.top,
        width: bounds.width,
        height: bounds.height,
        child: Semantics(
          container: true,
          label: semantics,
          button: true,
          onTap: () {
            if (isInput) {
              editor.toggleInput(node.id);
            } else {
              editor.selectNode(node.id);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (isInput) {
                editor.toggleInput(node.id);
              } else if (editor.selectedNodeIds.contains(node.id)) {
                editor.toggleNodeSelection(node.id);
              } else {
                editor.selectNode(node.id);
              }
            },
            onLongPress: () => editor.toggleNodeSelection(node.id),
            onPanStart: (_) => editor.beginNodeDrag(node.id),
            onPanUpdate: (DragUpdateDetails details) {
              editor.dragSelected(
                CanvasPoint(details.delta.dx, details.delta.dy),
              );
            },
            onPanEnd: (_) => editor.endNodeDrag(),
            onPanCancel: editor.endNodeDrag,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ];
  }

  List<Widget> _portOverlays(
    BuildContext context,
    CircuitNode node,
    ThemeData theme,
  ) {
    final List<Widget> overlays = <Widget>[];
    if (node.type.producesSignal) {
      final ComponentSpec spec = ComponentLibrary.specOf(node.type);
      for (int port = 0; port < node.outputCount; port++) {
        final CanvasPoint position =
            CircuitGeometry.portPosition(
              node,
              CircuitPin.output(node.id, port),
            )!;
        final String portName =
            port < spec.outputLabels.length ? spec.outputLabels[port] : 'Y';
        overlays.add(
          _pinOverlay(
            context: context,
            node: node,
            position: position,
            label: 'پایه خروجی $portName از ${node.label}',
            onTap: () => editor.tapOutputPort(node.id, port),
          ),
        );
      }
    }
    if (node.type.acceptsInputs) {
      final ComponentSpec spec = ComponentLibrary.specOf(node.type);
      for (int i = 0; i < node.inputCount; i++) {
        final CanvasPoint position =
            CircuitGeometry.portPosition(node, CircuitPin.input(node.id, i))!;
        final String portName =
            i < spec.inputLabels.length ? spec.inputLabels[i] : 'IN${i + 1}';
        overlays.add(
          _pinOverlay(
            context: context,
            node: node,
            position: position,
            label: 'پایه ورودی $portName از ${node.label}',
            onTap: () => editor.tapInputPort(node.id, i),
          ),
        );
      }
    }
    return overlays;
  }

  Widget _pinOverlay({
    required BuildContext context,
    required CircuitNode node,
    required CanvasPoint position,
    required String label,
    required VoidCallback onTap,
  }) {
    const double hit = CircuitGeometry.portHitRadius * 2;
    return Positioned(
      left: position.x - CircuitGeometry.portHitRadius,
      top: position.y - CircuitGeometry.portHitRadius,
      width: hit,
      height: hit,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: label,
          onTap: onTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class CircuitPainter extends CustomPainter {
  CircuitPainter({
    required this.graph,
    required this.report,
    required this.selectedNodeId,
    required this.selectedWireId,
    required this.pendingSourceId,
    required this.pendingSourcePort,
    required this.selectedNodeIds,
    required this.showGrid,
    required this.theme,
    required this.colors,
  });

  final CircuitGraph graph;
  final SimulationResult report;
  final String? selectedNodeId;
  final String? selectedWireId;
  final String? pendingSourceId;
  final int pendingSourcePort;
  final Set<String> selectedNodeIds;
  final bool showGrid;
  final ThemeData theme;
  final LogicLabColors colors;

  static const Color _gateFillLight = Color(0xFFFFFFFF);
  static const Color _gateFillDark = Color(0xFF151E2B);

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintWires(canvas);
    for (final CircuitNode node in graph.nodes) {
      _paintNode(canvas, node);
    }
    if (pendingSourceId != null) {
      _paintPendingTargets(canvas);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    if (!showGrid) {
      return;
    }
    final Paint dot = Paint()..color = colors.canvasGrid;
    const double spacing = CircuitGeometry.gridSize;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        final bool major =
            (x / spacing).round() % 5 == 0 && (y / spacing).round() % 5 == 0;
        canvas.drawCircle(
          Offset(x, y),
          major ? 1.35 : 0.75,
          dot..color = colors.canvasGrid.withValues(alpha: major ? 0.9 : 0.55),
        );
      }
    }
  }

  void _paintWires(Canvas canvas) {
    // Junction dots make branching visible: a filled dot marks an output
    // that drives more than one net.
    final Map<String, int> fanOut = <String, int>{};
    for (final CircuitWire wire in graph.wires) {
      fanOut[wire.fromNodeId] = (fanOut[wire.fromNodeId] ?? 0) + 1;
    }
    for (final MapEntry<String, int> entry in fanOut.entries) {
      if (entry.value < 2) {
        continue;
      }
      final CircuitNode? source = graph.nodeById(entry.key);
      if (source == null) {
        continue;
      }
      for (int port = 0; port < source.outputCount; port++) {
        final bool drivesTwo = graph.wires.any(
          (CircuitWire wire) =>
              wire.fromNodeId == entry.key && wire.fromPortIndex == port,
        );
        if (!drivesTwo) {
          continue;
        }
        final CanvasPoint? point = CircuitGeometry.portPosition(
          source,
          CircuitPin.output(source.id, port),
        );
        if (point == null) {
          continue;
        }
        final bool hasBranch =
            graph.wires
                .where(
                  (CircuitWire wire) =>
                      wire.fromNodeId == entry.key &&
                      wire.fromPortIndex == port,
                )
                .length >
            1;
        if (!hasBranch) {
          continue;
        }
        canvas.drawCircle(
          Offset(point.x, point.y),
          7,
          Paint()..color = theme.colorScheme.surfaceContainerLowest,
        );
        canvas.drawCircle(
          Offset(point.x, point.y),
          5.4,
          Paint()..color = theme.colorScheme.primary,
        );
      }
    }

    for (final CircuitWire wire in graph.wires) {
      final CircuitNode? source = graph.nodeById(wire.fromNodeId);
      final CircuitNode? target = graph.nodeById(wire.toNodeId);
      if (source == null || target == null) {
        continue;
      }
      final CanvasPoint? start = CircuitGeometry.portPosition(
        source,
        CircuitPin.output(source.id, wire.fromPortIndex),
      );
      final CanvasPoint? end = CircuitGeometry.portPosition(
        target,
        CircuitPin.input(target.id, wire.toInputIndex),
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
            ..moveTo(start.x, start.y)
            ..cubicTo(
              controls[1].x,
              controls[1].y,
              controls[2].x,
              controls[2].y,
              end.x,
              end.y,
            );
      final LogicSignal signal = report.signalForWire(wire);
      final Color color = signalColor(signal);
      final bool selected = selectedWireId == wire.id;

      if (selected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = theme.colorScheme.primary.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11
            ..strokeCap = StrokeCap.round,
        );
      }
      if (signal == LogicSignal.unknown) {
        _drawDashedPath(
          canvas,
          path,
          Paint()
            ..color = color.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3 : 2.2
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3.3 : 2.2
            ..strokeCap = StrokeCap.round,
        );
      }
      // Small signal direction dots make fan-out less ambiguous.
      final CanvasPoint marker = CircuitGeometry.bezierPoint(controls, 0.52);
      canvas.drawCircle(
        Offset(marker.x, marker.y),
        selected ? 3.4 : 2.5,
        Paint()..color = color,
      );
    }
  }

  void _paintNode(Canvas canvas, CircuitNode node) {
    final CanvasRect nodeRect = CircuitGeometry.nodeBounds(node);
    final Rect bounds = Rect.fromLTWH(
      nodeRect.left,
      nodeRect.top,
      nodeRect.width,
      nodeRect.height,
    );
    final bool selected =
        selectedNodeId == node.id || selectedNodeIds.contains(node.id);
    final ComponentSpec spec = ComponentLibrary.specOf(node.type);
    final LogicSignal output = report.signalOf(node.id);

    // Restrained floating shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bounds.translate(0, 5),
        const Radius.circular(16),
      ),
      Paint()
        ..color = Colors.black.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.23 : 0.06,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );

    if (spec.kind == ComponentKind.module ||
        spec.kind == ComponentKind.sequential) {
      _paintModule(canvas, node, bounds, selected, spec);
    } else {
      switch (node.type) {
        case ComponentType.inputPin:
          _paintInputNode(canvas, node, bounds, selected, output);
        case ComponentType.outputPin:
          _paintOutputNode(canvas, node, bounds, selected, output);
        case ComponentType.clockSource:
          _paintClockNode(canvas, node, bounds, selected, output);
        default:
          _paintGate(canvas, node, bounds, selected, output);
      }
    }

    if (selected) {
      final RRect selection = RRect.fromRectAndRadius(
        bounds.inflate(CircuitGeometry.selectionPadding),
        const Radius.circular(22),
      );
      canvas.drawRRect(
        selection,
        Paint()
          ..color = theme.colorScheme.primary.withValues(alpha: 0.07)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        selection,
        Paint()
          ..color = theme.colorScheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
      for (final Offset corner in <Offset>[
        selection.outerRect.topLeft,
        selection.outerRect.topRight,
        selection.outerRect.bottomLeft,
        selection.outerRect.bottomRight,
      ]) {
        canvas.drawCircle(
          corner,
          2.6,
          Paint()..color = theme.colorScheme.primary,
        );
      }
    }
    _paintPorts(canvas, node);
  }

  /// Draws a compound module or a sequential element as a labelled block with
  /// named ports, the way professional schematics present them.
  void _paintModule(
    Canvas canvas,
    CircuitNode node,
    Rect bounds,
    bool selected,
    ComponentSpec spec,
  ) {
    final RRect body = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(12),
    );
    final bool isSequential = spec.kind == ComponentKind.sequential;
    final Color headerColor =
        isSequential ? theme.colorScheme.tertiary : theme.colorScheme.primary;
    canvas.drawRRect(
      body,
      Paint()
        ..color = theme.colorScheme.surfaceContainerLowest
        ..style = PaintingStyle.fill,
    );
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, 26),
      Paint()..color = headerColor.withValues(alpha: 0.14),
    );
    canvas.restore();
    canvas.drawRRect(
      body,
      Paint()
        ..color =
            selected ? theme.colorScheme.primary : theme.colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.6 : 1.1,
    );

    _drawText(
      canvas,
      node.label,
      Offset(bounds.left + 10, bounds.top + 7),
      width: bounds.width - 20,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: headerColor,
      maxLines: 1,
    );

    final List<LogicSignal> inputs =
        report.inputSignals[node.id] ?? const <LogicSignal>[];
    for (int port = 0; port < node.inputCount; port++) {
      final String label =
          port < spec.inputLabels.length
              ? spec.inputLabels[port]
              : 'IN${port + 1}';
      final double y = CircuitGeometry.inputPortY(node, port);
      _drawText(
        canvas,
        label,
        Offset(bounds.left + 10, y - 6),
        width: 46,
        fontSize: 8.5,
        color: theme.colorScheme.onSurfaceVariant,
      );
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.left + 8, y),
        Paint()
          ..color = theme.colorScheme.outline
          ..strokeWidth = 1,
      );
      final LogicSignal signal =
          port < inputs.length ? inputs[port] : LogicSignal.unknown;
      _drawTextInCircle(
        canvas,
        _signalGlyph(signal),
        Offset(bounds.right - 16, y),
        color: signalColor(signal),
        fontSize: 8,
      );
    }

    for (int port = 0; port < node.outputCount; port++) {
      final String label =
          port < spec.outputLabels.length ? spec.outputLabels[port] : 'Y';
      final double y = CircuitGeometry.outputPortY(node, port);
      _drawText(
        canvas,
        label,
        Offset(bounds.right - 56, y - 6),
        width: 42,
        fontSize: 8.5,
        color: theme.colorScheme.onSurfaceVariant,
        textAlign: TextAlign.right,
      );
      canvas.drawLine(
        Offset(bounds.right - 8, y),
        Offset(bounds.right, y),
        Paint()
          ..color = theme.colorScheme.outline
          ..strokeWidth = 1,
      );
      _drawTextInCircle(
        canvas,
        _signalGlyph(report.signalOf(node.id, port)),
        Offset(bounds.left + 16, y),
        color: signalColor(report.signalOf(node.id, port)),
        fontSize: 8,
      );
    }
  }

  void _paintClockNode(
    Canvas canvas,
    CircuitNode node,
    Rect bounds,
    bool selected,
    LogicSignal output,
  ) {
    final RRect body = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(14),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = theme.colorScheme.surfaceContainerLowest
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color =
            selected ? theme.colorScheme.primary : theme.colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 1,
    );
    _drawText(
      canvas,
      'CLK',
      Offset(bounds.left + 14, bounds.center.dy - 8),
      width: 60,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    _drawText(
      canvas,
      'KLAK',
      Offset(bounds.left + 14, bounds.center.dy + 6),
      width: 60,
      fontSize: 7.5,
      color: theme.colorScheme.onSurfaceVariant,
    );
    _drawTextInCircle(
      canvas,
      output == LogicSignal.high ? '1' : '0',
      Offset(bounds.right - 28, bounds.center.dy),
      color: signalColor(output),
      fontSize: 10,
    );
  }

  static String _signalGlyph(LogicSignal signal) {
    return switch (signal) {
      LogicSignal.high => '1',
      LogicSignal.low => '0',
      LogicSignal.unknown => '?',
      LogicSignal.highImpedance => 'Z',
    };
  }

  void _paintInputNode(
    Canvas canvas,
    CircuitNode node,
    Rect bounds,
    bool selected,
    LogicSignal output,
  ) {
    final RRect body = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(14),
    );
    final Color nodeSignalColor = signalColor(output);
    canvas.drawRRect(
      body,
      Paint()
        ..color = theme.colorScheme.surfaceContainerLowest
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color =
            selected ? theme.colorScheme.primary : theme.colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bounds.left + 10, bounds.top + 15, 3, bounds.height - 30),
        const Radius.circular(2),
      ),
      Paint()..color = nodeSignalColor,
    );
    _drawText(
      canvas,
      node.label,
      Offset(bounds.left + 24, bounds.center.dy - 17),
      width: bounds.width - 68,
      maxLines: 2,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    _drawText(
      canvas,
      'INPUT',
      Offset(bounds.left + 24, bounds.center.dy + 8),
      width: bounds.width - 68,
      fontSize: 7.5,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
    );
    final Offset badgeCenter = Offset(bounds.right - 30, bounds.center.dy);
    canvas.drawCircle(
      badgeCenter,
      15,
      Paint()..color = nodeSignalColor.withValues(alpha: 0.13),
    );
    canvas.drawCircle(
      badgeCenter,
      15,
      Paint()
        ..color = nodeSignalColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke,
    );
    _drawTextInCircle(
      canvas,
      output == LogicSignal.high ? '1' : '0',
      badgeCenter,
      color: nodeSignalColor,
      fontSize: 12,
    );
    _drawPortDot(
      canvas,
      CanvasPoint(bounds.right, bounds.center.dy),
      output,
      isOutput: true,
    );
  }

  void _paintOutputNode(
    Canvas canvas,
    CircuitNode node,
    Rect bounds,
    bool selected,
    LogicSignal input,
  ) {
    final RRect body = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(14),
    );
    final Color nodeSignalColor = signalColor(input);
    canvas.drawRRect(
      body,
      Paint()
        ..color = theme.colorScheme.surfaceContainerLowest
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color =
            selected ? theme.colorScheme.primary : theme.colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 1,
    );
    final Offset badgeCenter = Offset(bounds.left + 30, bounds.center.dy);
    canvas.drawCircle(
      badgeCenter,
      15,
      Paint()..color = nodeSignalColor.withValues(alpha: 0.13),
    );
    canvas.drawCircle(
      badgeCenter,
      15,
      Paint()
        ..color = nodeSignalColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke,
    );
    _drawTextInCircle(
      canvas,
      input == LogicSignal.high
          ? '1'
          : input == LogicSignal.low
          ? '0'
          : input == LogicSignal.highImpedance
          ? 'Z'
          : '؟',
      badgeCenter,
      color: nodeSignalColor,
      fontSize: input == LogicSignal.unknown ? 12 : 12,
    );
    _drawText(
      canvas,
      node.label,
      Offset(bounds.left + 54, bounds.center.dy - 17),
      width: bounds.width - 64,
      maxLines: 2,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    _drawText(
      canvas,
      'OUTPUT',
      Offset(bounds.left + 54, bounds.center.dy + 8),
      width: bounds.width - 64,
      fontSize: 7.5,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
    );
    _drawPortDot(
      canvas,
      CanvasPoint(bounds.left, bounds.center.dy),
      input,
      isOutput: false,
    );
  }

  void _paintGate(
    Canvas canvas,
    CircuitNode node,
    Rect bounds,
    bool selected,
    LogicSignal output,
  ) {
    final Color fill =
        theme.brightness == Brightness.dark ? _gateFillDark : _gateFillLight;
    final Color border =
        selected
            ? theme.colorScheme.primary
            : report.problems.any(
              (CircuitProblem problem) =>
                  problem.nodeId == node.id && problem.isError,
            )
            ? signalColor(LogicSignal.unknown)
            : theme.colorScheme.outline;
    final Paint fillPaint =
        Paint()
          ..color = fill
          ..style = PaintingStyle.fill;
    final Paint stroke =
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1.7 : 1.2
          ..strokeJoin = StrokeJoin.round;
    final double left = bounds.left + 18;
    final double right = bounds.right - 26;
    final double top = bounds.top + 15;
    final double bottom = bounds.bottom - 15;
    final double centerY = bounds.center.dy;
    final bool bubble =
        node.type == ComponentType.nandGate ||
        node.type == ComponentType.norGate ||
        node.type == ComponentType.xnorGate;
    final double bubbleRadius = 6;
    final double activeRight = bubble ? right - 2 : right;

    // Input and output stubs.
    for (int i = 0; i < node.inputCount; i++) {
      final double y = CircuitGeometry.inputPortY(node, i);
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(left + 2, y),
        Paint()
          ..color = border.withValues(alpha: 0.8)
          ..strokeWidth = 1.2,
      );
    }

    Path shape;
    switch (node.type) {
      case ComponentType.andGate:
      case ComponentType.nandGate:
        shape =
            Path()
              ..moveTo(left, top)
              ..lineTo(left + 30, top)
              ..cubicTo(
                right + 2,
                top,
                right + 19,
                centerY - 16,
                right,
                centerY,
              )
              ..cubicTo(
                right + 19,
                centerY + 16,
                right + 2,
                bottom,
                left + 30,
                bottom,
              )
              ..lineTo(left, bottom)
              ..close();
      case ComponentType.orGate:
      case ComponentType.norGate:
        shape =
            Path()
              ..moveTo(left, top)
              ..quadraticBezierTo(left + 53, top + 4, right, centerY)
              ..quadraticBezierTo(left + 53, bottom - 4, left, bottom)
              ..quadraticBezierTo(left + 26, centerY, left, top)
              ..close();
      case ComponentType.xorGate:
      case ComponentType.xnorGate:
        shape =
            Path()
              ..moveTo(left + 8, top)
              ..quadraticBezierTo(left + 58, top + 4, right, centerY)
              ..quadraticBezierTo(left + 58, bottom - 4, left + 8, bottom)
              ..quadraticBezierTo(left + 34, centerY, left + 8, top)
              ..close();
      case ComponentType.notGate:
        shape =
            Path()
              ..moveTo(left, top)
              ..lineTo(left, bottom)
              ..lineTo(activeRight, centerY)
              ..close();
      default:
        shape =
            Path()..addRRect(
              RRect.fromRectAndRadius(bounds, const Radius.circular(14)),
            );
    }
    canvas.drawPath(shape, fillPaint);
    canvas.drawPath(shape, stroke);

    if (node.type == ComponentType.xorGate ||
        node.type == ComponentType.xnorGate) {
      final Path extra =
          Path()
            ..moveTo(left - 3, top)
            ..quadraticBezierTo(left + 23, centerY, left - 3, bottom);
      canvas.drawPath(extra, stroke);
    }

    if (bubble) {
      final Offset outputCenter = Offset(right + bubbleRadius + 1, centerY);
      canvas.drawCircle(
        outputCenter,
        bubbleRadius,
        Paint()
          ..color = fill
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(outputCenter, bubbleRadius, stroke);
      canvas.drawLine(
        Offset(outputCenter.dx + bubbleRadius, centerY),
        Offset(bounds.right, centerY),
        Paint()
          ..color = border
          ..strokeWidth = 1.2,
      );
    } else {
      final double startX =
          node.type == ComponentType.notGate ? activeRight : right;
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(bounds.right, centerY),
        Paint()
          ..color = border
          ..strokeWidth = 1.2,
      );
    }

    final String typeLabel = switch (node.type) {
      ComponentType.andGate => 'AND',
      ComponentType.orGate => 'OR',
      ComponentType.notGate => 'NOT',
      ComponentType.nandGate => 'NAND',
      ComponentType.norGate => 'NOR',
      ComponentType.xorGate => 'XOR',
      ComponentType.xnorGate => 'XNOR',
      _ => node.type.technicalName,
    };
    final bool hasCustomLabel =
        node.label.toUpperCase() != typeLabel.toUpperCase();
    // The D-shaped gates (AND/NAND) carry their label slightly to the right so
    // that it sits inside the curved body instead of the flat input side.
    final double labelOffset =
        (node.type == ComponentType.andGate ||
                node.type == ComponentType.nandGate)
            ? 9
            : 0;
    if (hasCustomLabel) {
      _drawText(
        canvas,
        node.label,
        Offset(left + 12 + labelOffset, centerY - 14),
        width: math.max(10, right - left - 10 - labelOffset),
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
        textAlign: TextAlign.center,
      );
      _drawText(
        canvas,
        typeLabel,
        Offset(left + 8 + labelOffset, centerY + 2),
        width: math.max(10, right - left - 12 - labelOffset),
        fontSize: 8,
        color: theme.colorScheme.onSurfaceVariant,
        textAlign: TextAlign.center,
        letterSpacing: 0.5,
      );
    } else {
      _drawText(
        canvas,
        typeLabel,
        Offset(
          (node.type == ComponentType.notGate ? left + 8 : left + 4) +
              labelOffset,
          centerY - 7,
        ),
        width: math.max(10, right - left - 8 - labelOffset),
        fontSize: node.type == ComponentType.nandGate ? 8 : 9.5,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
        textAlign:
            node.type == ComponentType.notGate
                ? TextAlign.left
                : TextAlign.center,
        letterSpacing: 0.4,
      );
    }

    if (output == LogicSignal.unknown) {
      final Offset alert = Offset(bounds.right - 11, bounds.top + 11);
      canvas.drawCircle(
        alert,
        7,
        Paint()
          ..color = signalColor(LogicSignal.unknown).withValues(alpha: 0.16),
      );
      _drawTextInCircle(
        canvas,
        '!',
        alert,
        color: signalColor(LogicSignal.unknown),
        fontSize: 9,
      );
    }
  }

  void _paintPorts(Canvas canvas, CircuitNode node) {
    if (node.type.producesSignal) {
      for (int port = 0; port < node.outputCount; port++) {
        final CanvasPoint? position = CircuitGeometry.portPosition(
          node,
          CircuitPin.output(node.id, port),
        );
        if (position == null) {
          continue;
        }
        final bool pending =
            pendingSourceId == node.id && pendingSourcePort == port;
        _drawPortDot(
          canvas,
          position,
          report.signalOf(node.id, port),
          isOutput: true,
          highlighted: pending,
        );
      }
    }
    if (node.type.acceptsInputs) {
      final List<LogicSignal> signals =
          report.inputSignals[node.id] ?? const <LogicSignal>[];
      for (int i = 0; i < node.inputCount; i++) {
        final CanvasPoint? position = CircuitGeometry.portPosition(
          node,
          CircuitPin.input(node.id, i),
        );
        if (position == null) {
          continue;
        }
        final bool canTarget =
            pendingSourceId != null &&
            CircuitValidator.canConnect(
              graph: graph,
              fromNodeId: pendingSourceId!,
              toNodeId: node.id,
              toInputIndex: i,
              fromPortIndex: pendingSourcePort,
            ).allowed;
        _drawPortDot(
          canvas,
          position,
          i < signals.length ? signals[i] : LogicSignal.unknown,
          isOutput: false,
          highlighted: canTarget,
        );
      }
    }
  }

  void _paintPendingTargets(Canvas canvas) {
    final CircuitNode? source = graph.nodeById(pendingSourceId!);
    if (source == null) {
      return;
    }
    final CanvasPoint? start = CircuitGeometry.portPosition(
      source,
      CircuitPin.output(source.id, 0),
    );
    if (start == null) {
      return;
    }
    canvas.drawCircle(
      Offset(start.x, start.y),
      13,
      Paint()
        ..color = theme.colorScheme.primary.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(start.x, start.y),
      13,
      Paint()
        ..color = theme.colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _drawPortDot(
    Canvas canvas,
    CanvasPoint point,
    LogicSignal signal, {
    required bool isOutput,
    bool highlighted = false,
  }) {
    final Offset center = Offset(point.x, point.y);
    final bool unknown = signal == LogicSignal.unknown;
    final Color color = signalColor(signal);
    if (highlighted) {
      canvas.drawCircle(
        center,
        12,
        Paint()
          ..color = theme.colorScheme.primary.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        12,
        Paint()
          ..color = theme.colorScheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawCircle(
      center,
      CircuitGeometry.portRadius + 1.5,
      Paint()..color = theme.colorScheme.surfaceContainerLowest,
    );
    if (unknown && !isOutput) {
      canvas.drawCircle(
        center,
        CircuitGeometry.portRadius,
        Paint()
          ..color = colors.unknownSignal.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        CircuitGeometry.portRadius,
        Paint()
          ..color = colors.unknownSignal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    } else {
      canvas.drawCircle(
        center,
        CircuitGeometry.portRadius,
        Paint()..color = color.withValues(alpha: unknown ? 0.2 : 0.2),
      );
      canvas.drawCircle(
        center,
        CircuitGeometry.portRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7,
      );
      canvas.drawCircle(center, 2.2, Paint()..color = color);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double width,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    TextAlign textAlign = TextAlign.left,
    int maxLines = 1,
    double letterSpacing = 0,
  }) {
    final bool persian = _containsPersian(text);
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? theme.colorScheme.onSurface,
          fontFamily: persian ? 'Vazirmatn' : 'JetBrainsMono',
          fontSize: fontSize,
          height: 1.35,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: persian ? TextDirection.rtl : TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  void _drawTextInCircle(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    double fontSize = 11,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: text == '؟' ? 'Vazirmatn' : 'JetBrainsMono',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  static bool _containsPersian(String input) {
    for (final int code in input.runes) {
      if (code >= 0x0600 && code <= 0x06FF) {
        return true;
      }
    }
    return false;
  }

  Color signalColor(LogicSignal signal) => switch (signal) {
    LogicSignal.high => colors.highSignal,
    LogicSignal.low => colors.lowSignal,
    LogicSignal.unknown => colors.unknownSignal,
    LogicSignal.highImpedance => theme.colorScheme.outline,
  };

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      const double dash = 7;
      const double gap = 5;
      while (distance < metric.length) {
        final double end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CircuitPainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.report != report ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.selectedWireId != selectedWireId ||
        oldDelegate.pendingSourceId != pendingSourceId ||
        oldDelegate.colors != colors ||
        oldDelegate.theme.brightness != theme.brightness;
  }
}
