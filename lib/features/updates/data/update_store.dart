import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Everything the update checker has to remember between launches.
class UpdateMemory {
  const UpdateMemory({this.lastCheckAt, this.skippedVersion});

  /// When the last successful check finished. A failed check does not update
  /// it, so being offline never delays the next attempt by a day.
  final DateTime? lastCheckAt;

  /// The version the user explicitly postponed. It is not offered again, but
  /// a newer release is.
  final String? skippedVersion;

  UpdateMemory copyWith({
    DateTime? lastCheckAt,
    String? skippedVersion,
    bool clearSkipped = false,
  }) {
    return UpdateMemory(
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      skippedVersion: clearSkipped
          ? null
          : (skippedVersion ?? this.skippedVersion),
    );
  }
}

abstract class UpdateStore {
  Future<UpdateMemory> load();
  Future<void> save(UpdateMemory memory);
}

class SharedPreferencesUpdateStore implements UpdateStore {
  SharedPreferencesUpdateStore(this._preferences);

  static const String _key = 'logic_lab.updates.v1';

  final SharedPreferences _preferences;

  @override
  Future<UpdateMemory> load() async {
    final String? raw = _preferences.getString(_key);
    if (raw == null) {
      return const UpdateMemory();
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final Object? checkedAt = decoded['lastCheckAt'];
        final Object? skipped = decoded['skippedVersion'];
        return UpdateMemory(
          lastCheckAt: checkedAt is String
              ? DateTime.tryParse(checkedAt)
              : null,
          skippedVersion: skipped is String && skipped.isNotEmpty
              ? skipped
              : null,
        );
      }
    } on FormatException {
      // A malformed preference must never stop the app from opening.
    }
    return const UpdateMemory();
  }

  @override
  Future<void> save(UpdateMemory memory) async {
    await _preferences.setString(
      _key,
      jsonEncode(<String, Object?>{
        'lastCheckAt': memory.lastCheckAt?.toIso8601String(),
        'skippedVersion': memory.skippedVersion,
      }),
    );
  }
}

/// In-memory store used by widget tests and the web preview build.
class MemoryUpdateStore implements UpdateStore {
  MemoryUpdateStore([this._memory = const UpdateMemory()]);

  UpdateMemory _memory;

  @override
  Future<UpdateMemory> load() async => _memory;

  @override
  Future<void> save(UpdateMemory memory) async {
    _memory = memory;
  }
}
