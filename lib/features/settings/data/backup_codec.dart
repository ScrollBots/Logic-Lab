import 'dart:convert';

import '../../learn/data/learning_progress_repository.dart';
import '../../projects/domain/circuit_project.dart';

/// Versioned backup envelope. The payload is portable JSON with no absolute
/// paths and can be restored on any installation of the app.
class BackupPayload {
  const BackupPayload({
    required this.projects,
    required this.progress,
    this.settings,
  });

  final List<CircuitProject> projects;
  final List<LearningProgress> progress;
  final Map<String, Object?>? settings;
}

class BackupCodec {
  const BackupCodec._();

  static const String formatId = 'logic-lab-backup';
  static const int formatVersion = 1;

  static BackupPayload? decode(String source) {
    Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    if (raw['format'] != formatId) {
      return null;
    }
    final Object? version = raw['version'];
    if (version is! num ||
        !version.isFinite ||
        version.toInt() > formatVersion) {
      return null;
    }
    final Object? rawProjects = raw['projects'];
    if (rawProjects is! List) {
      return null;
    }
    final List<CircuitProject> projects = <CircuitProject>[];
    for (final Object? item in rawProjects) {
      try {
        final CircuitProject project = CircuitProject.fromJson(item);
        ProjectCodec.validateCircuit(project.graph);
        projects.add(project);
      } catch (_) {
        // Skip broken rows instead of aborting the whole restore.
        continue;
      }
    }

    final List<LearningProgress> progress = <LearningProgress>[];
    final Object? rawProgress = raw['learningProgress'];
    if (rawProgress is List) {
      for (final Object? item in rawProgress) {
        if (item is! Map) {
          continue;
        }
        final Object? id = item['itemId'];
        final Object? updatedAt = item['updatedAt'];
        if (id is! String || id.trim().isEmpty || updatedAt is! String) {
          continue;
        }
        progress.add(
          LearningProgress(
            itemId: id,
            completed: _readBool(item['completed']),
            bestScore: _readCount(item['bestScore']),
            attempts: _readCount(item['attempts']),
            updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
          ),
        );
      }
    }

    final Object? rawSettings = raw['settings'];
    return BackupPayload(
      projects: projects,
      progress: progress,
      settings: rawSettings is Map<String, Object?> ? rawSettings : null,
    );
  }

  static bool _readBool(Object? value) => value == true;

  static int _readCount(Object? value) {
    if (value is! num || !value.isFinite || value < 0) {
      return 0;
    }
    return value.toInt();
  }
}
