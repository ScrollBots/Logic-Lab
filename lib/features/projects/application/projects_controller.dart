import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/localization/persian_format.dart';
import '../../../core/utils/id_generator.dart';
import '../../../features/editor/domain/circuit_models.dart';
import '../data/project_repository.dart';
import '../domain/circuit_project.dart';

enum ProjectSort { recentlyUpdated, recentlyCreated, name }

class ProjectsController extends ChangeNotifier {
  ProjectsController(this._repository);

  final ProjectRepository _repository;

  List<CircuitProject> _projects = <CircuitProject>[];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _lastOperationError;
  bool _disposed = false;

  List<CircuitProject> get projects =>
      List<CircuitProject>.unmodifiable(_projects);
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get loadError => _loadError;
  String? get lastOperationError => _lastOperationError;
  int get count => _projects.length;
  bool get isEmpty => _projects.isEmpty;

  CircuitProject? get mostRecent => _projects.isEmpty ? null : _projects.first;

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    _notify();
    try {
      _projects = await _repository.loadAll();
      _sortInMemory();
    } catch (error) {
      _loadError = 'ذخیره‌گاه محلی بارگذاری نشد: $error';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> refresh() => load();

  Future<CircuitProject> createNew({
    CircuitGraph? graph,
    String? name,
    ComponentType? quickGate,
  }) async {
    final CircuitGraph circuit =
        graph ??
        (quickGate == null
            ? ProjectTemplate.blank()
            : ProjectTemplate.quickGateCircuit(quickGate));
    final DateTime now = DateTime.now();
    final CircuitProject project = CircuitProject(
      id: IdGenerator.next('p'),
      name:
          name?.trim().isNotEmpty == true
              ? name!.trim()
              : _suggestName('مدار جدید'),
      createdAt: now,
      updatedAt: now,
      graph: circuit,
    );
    await _saveInternal(project);
    return project;
  }

  Future<CircuitProject> saveGraph(
    CircuitProject project,
    CircuitGraph graph, {
    String? name,
  }) async {
    final CircuitProject updated = project.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : project.name,
      graph: graph,
      updatedAt: DateTime.now(),
    );
    await _saveInternal(updated);
    return updated;
  }

  Future<CircuitProject> saveProject(CircuitProject project) async {
    final CircuitProject updated = project.copyWith(
      name: project.name.trim().isEmpty ? 'مدار بدون نام' : project.name.trim(),
      updatedAt: DateTime.now(),
    );
    await _saveInternal(updated);
    return updated;
  }

  Future<CircuitProject> renameProject(String id, String name) async {
    final CircuitProject? current = byId(id);
    if (current == null) {
      throw StateError('پروژه پیدا نشد.');
    }
    final String normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FormatException('نام پروژه نمی‌تواند خالی باشد.');
    }
    if (normalized.length > 80) {
      throw const FormatException('نام پروژه نباید بیش از ۸۰ نویسه باشد.');
    }
    final CircuitProject updated = current.copyWith(
      name: normalized,
      updatedAt: DateTime.now(),
    );
    await _saveInternal(updated);
    return updated;
  }

  Future<CircuitProject> duplicateProject(String id) async {
    final CircuitProject? current = byId(id);
    if (current == null) {
      throw StateError('پروژه پیدا نشد.');
    }
    final DateTime now = DateTime.now();
    final CircuitProject copy = current.copyWith(
      id: IdGenerator.next('p'),
      name: _suggestName('${current.name} — کپی'),
      createdAt: now,
      updatedAt: now,
    );
    await _saveInternal(copy);
    return copy;
  }

  Future<void> deleteProject(String id) async {
    _beginOperation();
    try {
      await _repository.delete(id);
      _projects = _projects.where((CircuitProject p) => p.id != id).toList();
      _lastOperationError = null;
    } catch (error) {
      _lastOperationError = 'حذف پروژه انجام نشد: $error';
      rethrow;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<void> importProject(CircuitProject project) async {
    final CircuitProject imported = project.copyWith(
      id: IdGenerator.next('p'),
      name: _suggestName(project.name),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _saveInternal(imported);
  }

  Future<void> replaceAll(List<CircuitProject> projects) async {
    _beginOperation();
    try {
      await _repository.replaceAll(projects);
      _projects = List<CircuitProject>.from(projects);
      _sortInMemory();
      _lastOperationError = null;
    } catch (error) {
      _lastOperationError = 'بازیابی پروژه‌ها انجام نشد: $error';
      rethrow;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<void> deleteAllProjects() async {
    _beginOperation();
    try {
      await _repository.deleteAll();
      _projects = <CircuitProject>[];
      _lastOperationError = null;
    } catch (error) {
      _lastOperationError = 'حذف پروژه‌ها انجام نشد: $error';
      rethrow;
    } finally {
      _saving = false;
      _notify();
    }
  }

  CircuitProject? byId(String id) {
    for (final CircuitProject project in _projects) {
      if (project.id == id) {
        return project;
      }
    }
    return null;
  }

  List<CircuitProject> search(
    String query, {
    ProjectSort sort = ProjectSort.recentlyUpdated,
  }) {
    final String normalized = query.trim().toLowerCase();
    final List<CircuitProject> filtered =
        _projects
            .where(
              (CircuitProject project) =>
                  normalized.isEmpty ||
                  project.name.toLowerCase().contains(normalized),
            )
            .toList();
    _sort(filtered, sort);
    return filtered;
  }

  void _sortInMemory() => _sort(_projects, ProjectSort.recentlyUpdated);

  void _sort(List<CircuitProject> list, ProjectSort sort) {
    switch (sort) {
      case ProjectSort.recentlyUpdated:
        list.sort(
          (CircuitProject a, CircuitProject b) =>
              b.updatedAt.compareTo(a.updatedAt),
        );
      case ProjectSort.recentlyCreated:
        list.sort(
          (CircuitProject a, CircuitProject b) =>
              b.createdAt.compareTo(a.createdAt),
        );
      case ProjectSort.name:
        list.sort(
          (CircuitProject a, CircuitProject b) => a.name.compareTo(b.name),
        );
    }
  }

  String _suggestName(String base) {
    final String normalized = base.trim();
    if (!_projects.any((CircuitProject p) => p.name == normalized)) {
      return normalized;
    }
    int index = 2;
    while (_projects.any(
      (CircuitProject p) =>
          p.name == '$normalized ${PersianFormat.digits(index)}',
    )) {
      index++;
    }
    return '$normalized ${PersianFormat.digits(index)}';
  }

  Future<void> _saveInternal(CircuitProject project) async {
    _beginOperation();
    try {
      await _repository.upsert(project);
      _projects = <CircuitProject>[
        project,
        ..._projects.where((CircuitProject p) => p.id != project.id),
      ];
      _sortInMemory();
      _lastOperationError = null;
    } catch (error) {
      _lastOperationError = 'ذخیره پروژه انجام نشد: $error';
      rethrow;
    } finally {
      _saving = false;
      _notify();
    }
  }

  void _beginOperation() {
    _saving = true;
    _lastOperationError = null;
    _notify();
  }

  void clearOperationError() {
    if (_lastOperationError == null) {
      return;
    }
    _lastOperationError = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
