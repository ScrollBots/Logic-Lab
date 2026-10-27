import '../domain/circuit_project.dart';

abstract class ProjectRepository {
  Future<List<CircuitProject>> loadAll();

  Future<void> upsert(CircuitProject project);

  Future<void> delete(String id);

  Future<void> deleteAll();

  Future<void> replaceAll(List<CircuitProject> projects);
}

/// Deterministic in-memory implementation for tests and web preview builds.
/// Production Android builds use [SqliteProjectRepository].
class MemoryProjectRepository implements ProjectRepository {
  MemoryProjectRepository([
    Iterable<CircuitProject> initial = const <CircuitProject>[],
  ]) : _projects = <String, CircuitProject>{
         for (final CircuitProject project in initial) project.id: project,
       };

  final Map<String, CircuitProject> _projects;

  @override
  Future<List<CircuitProject>> loadAll() async {
    final List<CircuitProject> projects = _projects.values.toList()
      ..sort(
        (CircuitProject a, CircuitProject b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );
    return projects;
  }

  @override
  Future<void> upsert(CircuitProject project) async {
    _projects[project.id] = project;
  }

  @override
  Future<void> delete(String id) async {
    _projects.remove(id);
  }

  @override
  Future<void> deleteAll() async {
    _projects.clear();
  }

  @override
  Future<void> replaceAll(List<CircuitProject> projects) async {
    _projects
      ..clear()
      ..addEntries(
        projects.map(
          (CircuitProject project) =>
              MapEntry<String, CircuitProject>(project.id, project),
        ),
      );
  }
}
