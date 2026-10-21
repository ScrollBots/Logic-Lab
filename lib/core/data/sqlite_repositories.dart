import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/editor/domain/circuit_models.dart';
import '../../features/learn/data/learning_progress_repository.dart';
import '../../features/projects/data/project_repository.dart';
import '../../features/projects/domain/circuit_project.dart';

class LogicLabDatabase {
  LogicLabDatabase._(this.database);

  final Database database;

  static const String fileName = 'logic_lab.db';
  static const int version = 1;

  static Future<LogicLabDatabase> open() async {
    final String directory = await getDatabasesPath();
    final String path = p.join(directory, fileName);
    final Database database = await openDatabase(
      path,
      version: version,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            circuit_json TEXT NOT NULL,
            schema_version INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX projects_updated_idx ON projects(updated_at DESC)',
        );
        await db.execute('''
          CREATE TABLE learning_progress (
            item_id TEXT PRIMARY KEY,
            completed INTEGER NOT NULL DEFAULT 0,
            best_score INTEGER NOT NULL DEFAULT 0,
            attempts INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    return LogicLabDatabase._(database);
  }

  Future<void> close() => database.close();
}

class SqliteProjectRepository implements ProjectRepository {
  SqliteProjectRepository(this._database);

  final LogicLabDatabase _database;

  Database get _db => _database.database;

  @override
  Future<List<CircuitProject>> loadAll() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'projects',
      orderBy: 'updated_at DESC',
    );
    final List<CircuitProject> projects = <CircuitProject>[];
    for (final Map<String, Object?> row in rows) {
      try {
        final Object? circuit = jsonDecode(row['circuit_json']! as String);
        projects.add(
          CircuitProject(
            id: row['id']! as String,
            name: row['name']! as String,
            createdAt: DateTime.parse(row['created_at']! as String).toLocal(),
            updatedAt: DateTime.parse(row['updated_at']! as String).toLocal(),
            graph: _graphFromJson(circuit),
          ),
        );
      } catch (error) {
        // One malformed row must not make every saved project unusable. Keep
        // the row in place for diagnostics, skip it in the UI, and report the
        // issue in debug logs. Imported files receive explicit validation.
        debugPrint('Skipping malformed project row ${row['id']}: $error');
      }
    }
    return projects;
  }

  CircuitGraph _graphFromJson(Object? value) {
    return CircuitGraph.fromJson(value);
  }

  @override
  Future<void> upsert(CircuitProject project) async {
    final Map<String, Object?> row = _toRow(project);
    await _db.insert(
      'projects',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete('projects', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<void> deleteAll() async {
    await _db.delete('projects');
  }

  @override
  Future<void> replaceAll(List<CircuitProject> projects) async {
    await _db.transaction((Transaction txn) async {
      await txn.delete('projects');
      final Batch batch = txn.batch();
      for (final CircuitProject project in projects) {
        batch.insert('projects', _toRow(project));
      }
      await batch.commit(noResult: true);
    });
  }

  Map<String, Object?> _toRow(CircuitProject project) => <String, Object?>{
    'id': project.id,
    'name': project.name,
    'created_at': project.createdAt.toUtc().toIso8601String(),
    'updated_at': project.updatedAt.toUtc().toIso8601String(),
    'circuit_json': jsonEncode(project.graph.toJson()),
    'schema_version': CircuitProject.schemaVersion,
  };
}

class SqliteLearningProgressRepository implements LearningProgressRepository {
  SqliteLearningProgressRepository(this._database);

  final LogicLabDatabase _database;

  Database get _db => _database.database;

  @override
  Future<List<LearningProgress>> loadAll() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'learning_progress',
    );
    return rows
        .map(
          (Map<String, Object?> row) => LearningProgress(
            itemId: row['item_id']! as String,
            completed: (row['completed']! as int) == 1,
            bestScore: row['best_score']! as int,
            attempts: row['attempts']! as int,
            updatedAt: DateTime.parse(row['updated_at']! as String).toLocal(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> upsert(LearningProgress progress) async {
    await _db.insert('learning_progress', <String, Object?>{
      'item_id': progress.itemId,
      'completed': progress.completed ? 1 : 0,
      'best_score': progress.bestScore,
      'attempts': progress.attempts,
      'updated_at': progress.updatedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteAll() async {
    await _db.delete('learning_progress');
  }

  @override
  Future<void> replaceAll(List<LearningProgress> items) async {
    await _db.transaction((Transaction txn) async {
      await txn.delete('learning_progress');
      final Batch batch = txn.batch();
      for (final LearningProgress item in items) {
        batch.insert('learning_progress', <String, Object?>{
          'item_id': item.itemId,
          'completed': item.completed ? 1 : 0,
          'best_score': item.bestScore,
          'attempts': item.attempts,
          'updated_at': item.updatedAt.toUtc().toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
    });
  }
}
