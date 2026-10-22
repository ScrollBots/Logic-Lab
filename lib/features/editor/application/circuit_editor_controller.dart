import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/id_generator.dart';
import '../../../features/projects/domain/circuit_project.dart';
import '../domain/circuit_geometry.dart';
import '../domain/circuit_models.dart';
import '../domain/circuit_validator.dart';
import '../domain/component_spec.dart';

enum SaveStatus { saved, unsaved, saving, error }

enum EditorFeedbackTone { info, success, error }

class EditorFeedback {
  const EditorFeedback(this.message, this.tone);

  final String message;
  final EditorFeedbackTone tone;
}

class _EditorSnapshot {
  const _EditorSnapshot({
    required this.graph,
    required this.selectedNodeId,
    required this.selectedWireId,
  });

  final CircuitGraph graph;
  final String? selectedNodeId;
  final String? selectedWireId;
}

/// Interactive editor state and undo/redo. Autosave is debounced and always
/// saves a complete immutable graph snapshot. The screen owns UI-only concerns
/// such as the viewport transform.
class CircuitEditorController extends ChangeNotifier {
  CircuitEditorController({
    required CircuitProject project,
    required Future<CircuitProject> Function(CircuitProject, CircuitGraph)
    onSave,
  }) : _project = project,
       _graph = project.graph,
       _onSave = onSave {
    _simulator = CircuitSimulator(_graph);
    _report = _simulator.evaluate();
  }

  final Future<CircuitProject> Function(CircuitProject, CircuitGraph) _onSave;

  static const int _historyLimit = 60;
  static const Duration autosaveDelay = Duration(milliseconds: 900);

  CircuitProject _project;
  CircuitGraph _graph;
  late CircuitSimulator _simulator;
  late SimulationResult _report;
  String? _selectedNodeId;
  String? _selectedWireId;
  String? _pendingSourceId;
  final Set<String> _multiSelectedNodeIds = <String>{};
  int _pendingSourcePort = 0;
  String? _draggingNodeId;
  bool _draggingMoved = false;
  bool _running = false;
  bool _gridSnapEnabled = true;
  Timer? _clockTimer;
  EditorFeedback? _feedback;

  final List<_EditorSnapshot> _undo = <_EditorSnapshot>[];
  final List<_EditorSnapshot> _redo = <_EditorSnapshot>[];

  SaveStatus _saveStatus = SaveStatus.saved;
  String? _saveError;
  DateTime? _lastSavedAt;
  Timer? _autosaveTimer;
  Future<void>? _activeSave;
  bool _dirty = false;
  int _revision = 0;
  bool _disposed = false;

  CircuitProject get project => _project;
  CircuitGraph get graph => _graph;
  SimulationResult get report => _report;
  String get name => _project.name;
  String? get selectedNodeId => _selectedNodeId;
  String? get selectedWireId => _selectedWireId;
  String? get pendingSourceId => _pendingSourceId;

  /// Output port that is currently picked up for a new connection.
  int get pendingSourcePort => _pendingSourcePort;
  EditorFeedback? get feedback => _feedback;
  SaveStatus get saveStatus => _saveStatus;
  String? get saveError => _saveError;
  DateTime? get lastSavedAt => _lastSavedAt;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get dirty => _dirty;
  bool get isSaving => _saveStatus == SaveStatus.saving;
  bool get hasPendingConnection => _pendingSourceId != null;

  /// True when the automatic clock is running.
  bool get isRunning => _running;

  /// Grid snapping keeps components on a tidy 8 px lattice.
  bool get gridSnapEnabled => _gridSnapEnabled;

  void setGridSnapEnabled(bool enabled) {
    if (_gridSnapEnabled == enabled) {
      return;
    }
    _gridSnapEnabled = enabled;
    _notify();
  }

  /// True when the circuit contains latches, flip-flops or counters.
  bool get hasSequentialParts => _graph.hasSequentialParts;

  /// Current level of the clock generator.
  bool get clockLevel => _simulator.clockLevel;

  CircuitNode? get selectedNode {
    final String? id = _selectedNodeId;
    return id == null ? null : _graph.nodeById(id);
  }

  CircuitWire? get selectedWire {
    final String? id = _selectedWireId;
    if (id == null) {
      return null;
    }
    for (final CircuitWire wire in _graph.wires) {
      if (wire.id == id) {
        return wire;
      }
    }
    return null;
  }

  bool get hasSelection => _selectedNodeId != null || _selectedWireId != null;

  void selectNode(String? nodeId) {
    _selectedNodeId = nodeId;
    _selectedWireId = null;
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _multiSelectedNodeIds.clear();
    _feedback = null;
    _notify();
  }

  /// Adds or removes a node from the multi selection. Long pressing a
  /// component starts a multi selection; every following tap adds to it.
  void toggleNodeSelection(String nodeId) {
    final CircuitNode? node = _graph.nodeById(nodeId);
    if (node == null) {
      return;
    }
    if (_multiSelectedNodeIds.remove(nodeId)) {
      _selectedNodeId = _multiSelectedNodeIds.isEmpty ? null : nodeId;
    } else {
      _multiSelectedNodeIds.add(nodeId);
      _selectedNodeId = nodeId;
    }
    _selectedWireId = null;
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _feedback = EditorFeedback(
      _multiSelectedNodeIds.length > 1
          ? '${_multiSelectedNodeIds.length} قطعه انتخاب شد؛ می‌توانید آن‌ها را جابه‌جا یا حذف کنید.'
          : 'یک قطعه انتخاب شد. برای انتخاب چند قطعه، روی قطعه‌های دیگر ضربه بزنید.',
      EditorFeedbackTone.info,
    );
    _notify();
  }

  /// Ids of every selected component.
  Set<String> get selectedNodeIds =>
      Set<String>.unmodifiable(_multiSelectedNodeIds);

  bool get hasMultiSelection => _multiSelectedNodeIds.length > 1;

  void clearMultiSelection() {
    if (_multiSelectedNodeIds.isEmpty) {
      return;
    }
    _multiSelectedNodeIds.clear();
    _notify();
  }

  void selectWire(String? wireId) {
    _selectedWireId = wireId;
    _selectedNodeId = null;
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _feedback = null;
    _notify();
  }

  void clearSelection() {
    if (_selectedNodeId == null &&
        _selectedWireId == null &&
        _pendingSourceId == null) {
      return;
    }
    _selectedNodeId = null;
    _selectedWireId = null;
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _feedback = null;
    _notify();
  }

  void cancelPendingConnection() {
    if (_pendingSourceId == null) {
      return;
    }
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _feedback = const EditorFeedback('اتصال لغو شد.', EditorFeedbackTone.info);
    _notify();
  }

  CircuitNode addNode(ComponentType type, CanvasPoint position) {
    final ComponentSpec spec = ComponentLibrary.specOf(type);
    final CircuitNode node = CircuitNode(
      id: IdGenerator.next(
        type.isInput
            ? 'in'
            : type.isOutput
            ? 'out'
            : type.isClock
            ? 'clk'
            : 'g',
      ),
      type: type,
      position: _snapPosition(position),
      label: type.isInput ? _nextInputLabel() : spec.title,
      inputCount: spec.configurableInputs ? spec.minInputs : null,
    );
    _pushHistory();
    _graph = _graph.addNode(node);
    _selectedNodeId = node.id;
    _selectedWireId = null;
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _feedback = EditorFeedback(
      '${spec.title} به بوم اضافه شد.',
      EditorFeedbackTone.success,
    );
    _commitChange();
    return node;
  }

  String _nextInputLabel() {
    const String alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final Set<String> used =
        _graph.inputs
            .map((CircuitNode input) => input.label.toUpperCase())
            .toSet();
    for (int i = 0; i < alphabet.length; i++) {
      if (!used.contains(alphabet[i])) {
        return alphabet[i];
      }
    }
    return 'IN${_graph.inputs.length + 1}';
  }

  void beginNodeDrag(String nodeId) {
    final CircuitNode? node = _graph.nodeById(nodeId);
    if (node == null) {
      return;
    }
    _selectedNodeId = nodeId;
    _selectedWireId = null;
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _draggingNodeId = nodeId;
    _draggingMoved = false;
    _pushHistory();
    _feedback = null;
    _notify();
  }

  void dragSelected(CanvasPoint delta) {
    final String? id = _draggingNodeId;
    if (id == null) {
      return;
    }
    final CircuitNode? node = _graph.nodeById(id);
    if (node == null) {
      return;
    }
    _draggingMoved = true;
    final Set<String> moving = <String>{
      id,
      ..._multiSelectedNodeIds.where((String other) => other != id),
    };
    for (final String nodeId in moving) {
      final CircuitNode? current = _graph.nodeById(nodeId);
      if (current == null) {
        continue;
      }
      final CanvasPoint next = _snapPosition(
        current.position.translate(delta.x, delta.y),
      );
      _graph = _graph.updateNode(current.copyWith(position: next));
    }
    // Moving a component cannot change any signal, so the circuit is not
    // re-simulated while dragging. The result is refreshed once, when the
    // component is dropped. This keeps large circuits responsive.
    _dirty = true;
    _revision++;
    _saveStatus = SaveStatus.unsaved;
    _notify();
  }

  void endNodeDrag() {
    if (_draggingNodeId == null) {
      return;
    }
    _draggingNodeId = null;
    if (!_draggingMoved) {
      // The history entry was only speculative.
      if (_undo.isNotEmpty) {
        _undo.removeLast();
      }
      _notify();
      return;
    }
    // The component was dropped: refresh the simulation once.
    _recomputeReport();
    _scheduleAutosave();
    _notify();
  }

  void toggleInput(String nodeId) {
    final CircuitNode? node = _graph.nodeById(nodeId);
    if (node == null || !node.type.isInput) {
      return;
    }
    _pushHistory();
    _graph = _graph.updateNode(node.copyWith(inputValue: !node.inputValue));
    _selectedNodeId = node.id;
    _selectedWireId = null;
    _recomputeReport();
    _commitChange();
  }

  void setInputValue(String nodeId, bool value) {
    final CircuitNode? node = _graph.nodeById(nodeId);
    if (node == null || !node.type.isInput || node.inputValue == value) {
      return;
    }
    _pushHistory();
    _graph = _graph.updateNode(node.copyWith(inputValue: value));
    _recomputeReport();
    _commitChange();
  }

  void updateSelectedLabel(String label) {
    final CircuitNode? node = selectedNode;
    if (node == null) {
      return;
    }
    final String normalized =
        label.trim().isEmpty ? node.type.technicalName : label.trim();
    if (normalized == node.label) {
      return;
    }
    _pushHistory();
    _graph = _graph.updateNode(node.copyWith(label: normalized));
    _commitChange();
  }

  void updateInputCount(int count) {
    final CircuitNode? node = selectedNode;
    if (node == null || !node.type.isBinaryGate) {
      return;
    }
    final int normalized = count.clamp(2, 4);
    if (normalized == node.inputCount) {
      return;
    }
    _pushHistory();
    _graph = _graph.updateNode(node.copyWith(inputCount: normalized));
    if (normalized < node.inputCount) {
      _graph = _graph.copyWith(
        wires: _graph.wires
            .where(
              (CircuitWire wire) =>
                  wire.toNodeId != node.id || wire.toInputIndex < normalized,
            )
            .toList(growable: false),
      );
    }
    _recomputeReport();
    _commitChange();
  }

  /// Applies all editable properties of one node as a single undoable action.
  void updateNodeProperties(
    String nodeId, {
    required String label,
    int? inputCount,
    bool? inputValue,
  }) {
    final CircuitNode? node = _graph.nodeById(nodeId);
    if (node == null) {
      return;
    }
    final String normalizedLabel =
        label.trim().isEmpty ? node.type.technicalName : label.trim();
    final int normalizedCount =
        node.type.isBinaryGate
            ? (inputCount ?? node.inputCount).clamp(2, 4)
            : node.inputCount;
    final bool normalizedValue =
        node.type.isInput ? (inputValue ?? node.inputValue) : node.inputValue;
    if (normalizedLabel == node.label &&
        normalizedCount == node.inputCount &&
        normalizedValue == node.inputValue) {
      return;
    }
    _pushHistory();
    _graph = _graph.updateNode(
      node.copyWith(
        label: normalizedLabel,
        inputCount: normalizedCount,
        inputValue: normalizedValue,
      ),
    );
    if (normalizedCount < node.inputCount) {
      _graph = _graph.copyWith(
        wires: _graph.wires
            .where(
              (CircuitWire wire) =>
                  wire.toNodeId != node.id ||
                  wire.toInputIndex < normalizedCount,
            )
            .toList(growable: false),
      );
    }
    _recomputeReport();
    _feedback = const EditorFeedback(
      'تنظیمات قطعه به‌روز شد.',
      EditorFeedbackTone.success,
    );
    _commitChange();
  }

  bool canStartConnectionFrom(String nodeId, [int port = 0]) {
    final CircuitNode? node = _graph.nodeById(nodeId);
    if (node == null) {
      return false;
    }
    return node.type.producesSignal && port < node.outputCount;
  }

  void tapOutputPort(String nodeId, [int port = 0]) {
    if (!canStartConnectionFrom(nodeId, port)) {
      return;
    }
    if (_pendingSourceId == nodeId && _pendingSourcePort == port) {
      _pendingSourceId = null;
      _pendingSourcePort = 0;
      _pendingSourcePort = 0;
      _feedback = const EditorFeedback(
        'انتخاب خروجی لغو شد.',
        EditorFeedbackTone.info,
      );
    } else {
      _pendingSourceId = nodeId;
      _pendingSourcePort = port;
      _selectedNodeId = nodeId;
      _selectedWireId = null;
      _feedback = const EditorFeedback(
        'حالا پایه ورودی مقصد را انتخاب کنید. پایه‌های قابل اتصال برجسته شده‌اند.',
        EditorFeedbackTone.info,
      );
    }
    _notify();
  }

  void tapInputPort(String nodeId, int inputIndex) {
    if (_pendingSourceId == null) {
      _feedback = const EditorFeedback(
        'ابتدا پایه خروجی یک قطعه را انتخاب کنید، سپس ورودی مقصد را بزنید.',
        EditorFeedbackTone.info,
      );
      _notify();
      return;
    }
    final CircuitNode? target = _graph.nodeById(nodeId);
    if (target == null) {
      return;
    }
    final ConnectionCheck check = CircuitValidator.canConnect(
      graph: _graph,
      fromNodeId: _pendingSourceId!,
      toNodeId: nodeId,
      toInputIndex: inputIndex,
      fromPortIndex: _pendingSourcePort,
    );
    if (!check.allowed) {
      _feedback = EditorFeedback(check.message, EditorFeedbackTone.error);
      _notify();
      return;
    }
    _pushHistory();
    final CircuitWire wire = CircuitWire(
      id: IdGenerator.next('w'),
      fromNodeId: _pendingSourceId!,
      toNodeId: nodeId,
      toInputIndex: inputIndex,
      fromPortIndex: _pendingSourcePort,
    );
    _graph = _graph.addWire(wire);
    _recomputeReport();
    _selectedWireId = wire.id;
    _selectedNodeId = null;
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _pendingSourcePort = 0;
    _feedback = const EditorFeedback(
      'اتصال با موفقیت ساخته شد.',
      EditorFeedbackTone.success,
    );
    _commitChange();
  }

  void duplicateSelected() {
    final CircuitNode? node = selectedNode;
    if (node == null) {
      return;
    }
    final CircuitNode copy = CircuitNode(
      id: IdGenerator.next(
        node.type.isInput
            ? 'in'
            : node.type.isOutput
            ? 'out'
            : 'g',
      ),
      type: node.type,
      position: _snapPosition(node.position.translate(34, 34)),
      label: node.label,
      inputValue: node.inputValue,
      inputCount: node.inputCount,
    );
    _pushHistory();
    _graph = _graph.addNode(copy);
    _selectedNodeId = copy.id;
    _selectedWireId = null;
    _feedback = const EditorFeedback(
      'قطعه تکثیر شد. اتصال‌های آن به‌صورت جداگانه ساخته می‌شوند.',
      EditorFeedbackTone.success,
    );
    _commitChange();
  }

  void deleteSelected() {
    if (_multiSelectedNodeIds.isNotEmpty) {
      final List<String> ids = _multiSelectedNodeIds.toList(growable: false);
      _pushHistory();
      CircuitGraph next = _graph;
      for (final String nodeId in ids) {
        next = next.removeNode(nodeId);
      }
      _graph = next;
      _multiSelectedNodeIds.clear();
      _selectedNodeId = null;
      _pendingSourceId = null;
      _pendingSourcePort = 0;
      _recomputeReport();
      _feedback = EditorFeedback(
        '${ids.length} قطعه و سیم‌های متصل حذف شد.',
        EditorFeedbackTone.info,
      );
      _commitChange();
      return;
    }
    if (_selectedNodeId != null) {
      final String nodeId = _selectedNodeId!;
      final CircuitNode? node = _graph.nodeById(nodeId);
      if (node == null) {
        return;
      }
      _pushHistory();
      _graph = _graph.removeNode(nodeId);
      _selectedNodeId = null;
      _pendingSourceId = null;
      _pendingSourcePort = 0;
      _recomputeReport();
      _feedback = EditorFeedback(
        '«${node.label}» و سیم‌های متصل حذف شد.',
        EditorFeedbackTone.info,
      );
      _commitChange();
      return;
    }
    if (_selectedWireId != null) {
      final String wireId = _selectedWireId!;
      _pushHistory();
      _graph = _graph.removeWire(wireId);
      _selectedWireId = null;
      _recomputeReport();
      _feedback = const EditorFeedback('سیم حذف شد.', EditorFeedbackTone.info);
      _commitChange();
    }
  }

  void undo() {
    if (_undo.isEmpty) {
      return;
    }
    final _EditorSnapshot previous = _undo.removeLast();
    _redo.add(_snapshot());
    _restore(previous);
    _feedback = const EditorFeedback(
      'آخرین تغییر برگشت داده شد.',
      EditorFeedbackTone.info,
    );
    _dirty = true;
    _revision++;
    _recomputeReport();
    _saveStatus = SaveStatus.unsaved;
    _scheduleAutosave();
    _notify();
  }

  void redo() {
    if (_redo.isEmpty) {
      return;
    }
    final _EditorSnapshot next = _redo.removeLast();
    _undo.add(_snapshot());
    _restore(next);
    _feedback = const EditorFeedback(
      'تغییر برگشت‌داده‌شده دوباره اعمال شد.',
      EditorFeedbackTone.info,
    );
    _dirty = true;
    _revision++;
    _recomputeReport();
    _saveStatus = SaveStatus.unsaved;
    _scheduleAutosave();
    _notify();
  }

  void rename(String newName) {
    final String normalized = newName.trim();
    if (normalized.isEmpty || normalized == _project.name) {
      return;
    }
    _project = _project.copyWith(name: normalized);
    _markDirty(schedule: true);
  }

  void clearFeedback() {
    if (_feedback == null) {
      return;
    }
    _feedback = null;
    _notify();
  }

  void _restore(_EditorSnapshot snapshot) {
    _graph = snapshot.graph;
    _selectedNodeId = snapshot.selectedNodeId;
    _selectedWireId = snapshot.selectedWireId;
    _pendingSourceId = null;
    _pendingSourcePort = 0;
    _draggingNodeId = null;
  }

  _EditorSnapshot _snapshot() {
    return _EditorSnapshot(
      graph: _graph,
      selectedNodeId: _selectedNodeId,
      selectedWireId: _selectedWireId,
    );
  }

  void _pushHistory() {
    _undo.add(_snapshot());
    if (_undo.length > _historyLimit) {
      _undo.removeAt(0);
    }
    _redo.clear();
  }

  void _commitChange() {
    _recomputeReport();
    _dirty = true;
    _revision++;
    _saveStatus = SaveStatus.unsaved;
    _saveError = null;
    _scheduleAutosave();
    _notify();
  }

  void _markDirty({required bool schedule}) {
    _dirty = true;
    _revision++;
    _saveStatus = SaveStatus.unsaved;
    if (schedule) {
      _scheduleAutosave();
    }
    _notify();
  }

  void _recomputeReport() {
    _simulator.updateGraph(_graph);
    _report = _simulator.evaluate();
  }

  /// Advances the circuit by one complete clock cycle. Sequential elements
  /// capture their input on the rising edge.
  void stepClock() {
    _report = _simulator.stepClock();
    _notify();
  }

  /// Clears the state of every sequential element.
  void resetSimulation() {
    _simulator.reset();
    _report = _simulator.result;
    _notify();
  }

  /// Starts or stops the automatic clock.
  void setRunning(bool running) {
    if (running == _running) {
      return;
    }
    _running = running;
    _clockTimer?.cancel();
    _clockTimer = null;
    if (running) {
      _clockTimer = Timer.periodic(
        const Duration(milliseconds: 700),
        (Timer timer) => stepClock(),
      );
    }
    _notify();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, () {
      unawaited(saveNow());
    });
  }

  Future<void> saveNow() async {
    _autosaveTimer?.cancel();
    if (!_dirty || _disposed) {
      return;
    }
    if (_activeSave != null) {
      await _activeSave;
      if (_dirty) {
        return saveNow();
      }
      return;
    }
    final Future<void> task = _performSave();
    _activeSave = task;
    try {
      await task;
    } finally {
      if (identical(_activeSave, task)) {
        _activeSave = null;
      }
    }
  }

  Future<void> _performSave() async {
    if (!_dirty || _disposed) {
      return;
    }
    final int revisionAtStart = _revision;
    _saveStatus = SaveStatus.saving;
    _saveError = null;
    _notify();
    try {
      final CircuitProject saved = await _onSave(_project, _graph);
      _project = saved;
      _lastSavedAt = DateTime.now();
      if (revisionAtStart == _revision) {
        _dirty = false;
        _saveStatus = SaveStatus.saved;
      } else {
        _dirty = true;
        _saveStatus = SaveStatus.unsaved;
        _scheduleAutosave();
      }
    } catch (error) {
      _saveStatus = SaveStatus.error;
      _saveError = 'ذخیره خودکار انجام نشد. اتصال ذخیره‌گاه را بررسی کنید.';
      debugPrint('Autosave failed: $error');
    }
    _notify();
  }

  Future<void> flush() async {
    _autosaveTimer?.cancel();
    final Future<void>? active = _activeSave;
    if (active != null) {
      await active;
    }
    if (_dirty) {
      await saveNow();
    }
  }

  void applyNameFromPersistedProject(CircuitProject saved) {
    _project = saved;
    _notify();
  }

  CanvasPoint _snapPosition(CanvasPoint point) {
    final double x = _gridSnapEnabled ? (point.x / 8).round() * 8.0 : point.x;
    final double y = _gridSnapEnabled ? (point.y / 8).round() * 8.0 : point.y;
    return CanvasPoint(
      x.clamp(48, CircuitGeometry.canvasWidth - 48),
      y.clamp(48, CircuitGeometry.canvasHeight - 48),
    );
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autosaveTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }
}
