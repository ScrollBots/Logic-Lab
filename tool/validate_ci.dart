// Validates the GitHub Actions workflows of this repository.
//
// The script parses every workflow in `.github/workflows`, makes sure the
// mandatory keys exist and verifies that every local file a workflow refers
// to is really part of the repository. It is executed by the `CI` workflow
// itself, so a broken workflow fails fast instead of surprising the next
// release.
//
// Usage:
//   dart run tool/validate_ci.dart

import 'dart:io';

import 'package:yaml/yaml.dart';

const String workflowDirectory = '.github/workflows';

int _errors = 0;

void _fail(String message) {
  _errors++;
  stderr.writeln('ERROR: $message');
}

void main() {
  final Directory directory = Directory(workflowDirectory);
  if (!directory.existsSync()) {
    stderr.writeln('No $workflowDirectory directory found.');
    exit(66);
  }

  final List<File> workflows =
      directory
          .listSync()
          .whereType<File>()
          .where(
            (File file) =>
                file.path.endsWith('.yml') || file.path.endsWith('.yaml'),
          )
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  if (workflows.isEmpty) {
    stderr.writeln('No workflows found.');
    exit(66);
  }

  for (final File workflow in workflows) {
    final String name = workflow.path;
    stdout.writeln('Checking $name');

    final YamlMap document;
    try {
      document = loadYaml(workflow.readAsStringSync()) as YamlMap;
    } on Object catch (error) {
      _fail('$name is not valid YAML: $error');
      continue;
    }

    if (document['name'] == null) {
      _fail('$name has no "name"');
    }
    if (document['run-name'] is! String) {
      _fail('$name has no descriptive "run-name"');
    }
    final Object? triggers = document['on'] ?? document[true];
    if (triggers == null) {
      _fail('$name has no "on" trigger');
    }
    if (document['jobs'] is! YamlMap) {
      _fail('$name has no "jobs"');
      continue;
    }

    final YamlMap jobs = document['jobs'] as YamlMap;
    for (final MapEntry<dynamic, dynamic> job in jobs.entries) {
      final Object? steps = (job.value as YamlMap)['steps'];
      if (steps is! List) {
        _fail('$name / job "${job.key}" has no steps');
        continue;
      }
      for (final Object? step in steps) {
        if (step is! YamlMap) {
          continue;
        }
        if (step['name'] is! String) {
          _fail('$name / job "${job.key}" has an unnamed step');
        }
        if (step['continue-on-error'] != null &&
            step['continue-on-error'] != false) {
          _fail('$name / job "${job.key}" must not hide failed steps');
        }
        final Object? run = step['run'];
        if (run is! String) {
          continue;
        }
        for (final RegExpMatch match in RegExp(
          r'tool/[A-Za-z0-9_./-]+',
        ).allMatches(run)) {
          final String path = match.group(0)!;
          if (!File(path).existsSync()) {
            _fail('$name / job "${job.key}" refers to a missing file: $path');
          }
        }
        if (run.contains('secrets.')) {
          final Object? secretNames = step['env'];
          if (secretNames is! YamlMap) {
            _fail(
              '$name / job "${job.key}" uses secrets without declaring them in env',
            );
          }
        }
      }
    }

    final String filename = workflow.uri.pathSegments.last;
    if (filename == 'ci.yml' || filename == 'release.yml') {
      final String buildJob = filename == 'ci.yml' ? 'build' : 'release';
      final Object? build = jobs[buildJob];
      if (jobs['quality'] is! YamlMap ||
          build is! YamlMap ||
          build['needs'] != 'quality' ||
          build['if'] != null) {
        _fail('$name must gate Android builds on the quality job');
      }
    }
    if (filename == 'release.yml') {
      final Object? release = jobs['release'];
      final Object? steps = release is YamlMap ? release['steps'] : null;
      final bool hasReleaseBody =
          steps is List &&
          steps.whereType<YamlMap>().any((YamlMap step) {
            final Object? action = step['uses'];
            final Object? inputs = step['with'];
            return action is String &&
                action.startsWith('softprops/action-gh-release@') &&
                inputs is YamlMap &&
                inputs['body_path'] is String &&
                (inputs['body_path'] as String).trim().isNotEmpty;
          });
      if (!hasReleaseBody) {
        _fail('$name must publish version-specific release notes');
      }
    }
  }

  _validateDependabot();
  if (_errors > 0) {
    stderr.writeln('$_errors problem(s) found.');
    exit(1);
  }
  stdout.writeln('Workflow configuration and Dependabot groups are valid.');
}

void _validateDependabot() {
  const String path = '.github/dependabot.yml';
  const List<String> allowedTypes = <String>['major', 'minor', 'patch'];
  final YamlMap document;
  try {
    document = loadYaml(File(path).readAsStringSync()) as YamlMap;
  } on Object catch (error) {
    _fail('$path is not valid YAML: $error');
    return;
  }
  final Object? updates = document['updates'];
  if (updates is! List) {
    _fail('$path has no update configuration');
    return;
  }
  for (final YamlMap update in updates.whereType<YamlMap>()) {
    final Object? groups = update['groups'];
    if (groups is! YamlMap) {
      continue;
    }
    for (final MapEntry<dynamic, dynamic> group in groups.entries) {
      final Object? configuration = group.value;
      final Object? types = configuration is YamlMap
          ? configuration['update-types']
          : null;
      if (types != null &&
          (types is! List ||
              types.any((Object? type) => !allowedTypes.contains(type)))) {
        _fail('$path / group "${group.key}" has invalid update-types');
      }
    }
  }
}
