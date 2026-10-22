import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/logic_lab_theme.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.paletteId = 'engineering_blue',
    this.customAccent,
    this.hapticsEnabled = true,
    this.animationsEnabled = true,
    this.highSignalValue = 0xFF1D9B72,
    this.lowSignalValue = 0xFF6D7B8E,
    this.localeCode = 'fa',
  });

  final ThemeMode themeMode;
  final String paletteId;
  final Color? customAccent;
  final bool hapticsEnabled;
  final bool animationsEnabled;
  final int highSignalValue;
  final int lowSignalValue;

  /// Only Persian is shipped today, but the locale is stored as data so more
  /// locales can be added without changing settings or persistence.
  final String localeCode;

  AppPalette get palette => AppPalette.byId(paletteId);
  Color get effectiveSeed => customAccent ?? palette.seed;
  Color get highSignal => Color(highSignalValue);
  Color get lowSignal => Color(lowSignalValue);

  Duration get shortMotion =>
      animationsEnabled ? const Duration(milliseconds: 180) : Duration.zero;
  Duration get motion =>
      animationsEnabled ? const Duration(milliseconds: 260) : Duration.zero;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? paletteId,
    Color? customAccent,
    bool clearCustomAccent = false,
    bool? hapticsEnabled,
    bool? animationsEnabled,
    int? highSignalValue,
    int? lowSignalValue,
    String? localeCode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      paletteId: paletteId ?? this.paletteId,
      customAccent:
          clearCustomAccent ? null : (customAccent ?? this.customAccent),
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      highSignalValue: highSignalValue ?? this.highSignalValue,
      lowSignalValue: lowSignalValue ?? this.lowSignalValue,
      localeCode: localeCode ?? this.localeCode,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'themeMode': themeMode.name,
      'paletteId': paletteId,
      'customAccent': customAccent?.toARGB32(),
      'hapticsEnabled': hapticsEnabled,
      'animationsEnabled': animationsEnabled,
      'highSignalValue': highSignalValue,
      'lowSignalValue': lowSignalValue,
      'localeCode': localeCode,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    ThemeMode mode;
    switch (json['themeMode']) {
      case 'light':
        mode = ThemeMode.light;
      case 'dark':
        mode = ThemeMode.dark;
      default:
        mode = ThemeMode.system;
    }
    const AppSettings defaults = AppSettings();
    final int? accent = _readColor(json['customAccent']);
    return AppSettings(
      themeMode: mode,
      paletteId: AppPalette.byId(_readString(json['paletteId'], '')).id,
      customAccent: accent == null ? null : Color(accent),
      hapticsEnabled: _readBool(json['hapticsEnabled'], true),
      animationsEnabled: _readBool(json['animationsEnabled'], true),
      highSignalValue:
          _readColor(json['highSignalValue']) ?? defaults.highSignalValue,
      lowSignalValue:
          _readColor(json['lowSignalValue']) ?? defaults.lowSignalValue,
      localeCode: _readString(json['localeCode'], 'fa'),
    );
  }
}

String _readString(Object? value, String fallback) =>
    value is String ? value : fallback;

bool _readBool(Object? value, bool fallback) =>
    value is bool ? value : fallback;

int? _readColor(Object? value) {
  if (value is! int || value < 0 || value > 0xFFFFFFFF) {
    return null;
  }
  return value;
}

abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class SharedPreferencesSettingsStore implements SettingsStore {
  SharedPreferencesSettingsStore(this._preferences);

  static const String _key = 'logic_lab.settings.v1';
  final SharedPreferences _preferences;

  static Future<SharedPreferencesSettingsStore> create() async {
    return SharedPreferencesSettingsStore(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  Future<AppSettings> load() async {
    final String? raw = _preferences.getString(_key);
    if (raw == null) {
      return const AppSettings();
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } catch (error) {
      // A malformed preference must never prevent the app from opening; this
      // also covers valid JSON whose values have the wrong types.
      debugPrint('Could not read the saved settings: $error');
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _preferences.setString(_key, jsonEncode(settings.toJson()));
  }
}

/// In-memory store used by widget tests and the web preview build.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController(this._store, AppSettings initial) : _settings = initial;

  final SettingsStore _store;
  AppSettings _settings;
  Future<void> _writeQueue = Future<void>.value();
  bool _disposed = false;

  AppSettings get value => _settings;

  ThemeMode get themeMode => _settings.themeMode;
  AppPalette get palette => _settings.palette;
  Color get seedColor => _settings.effectiveSeed;
  bool get hapticsEnabled => _settings.hapticsEnabled;
  bool get animationsEnabled => _settings.animationsEnabled;

  static Future<SettingsController> load(SettingsStore store) async {
    return SettingsController(store, await store.load());
  }

  void setThemeMode(ThemeMode mode) {
    _update(_settings.copyWith(themeMode: mode));
  }

  void setPalette(String paletteId) {
    _update(_settings.copyWith(paletteId: paletteId, clearCustomAccent: true));
  }

  void setCustomAccent(Color color) {
    _update(_settings.copyWith(customAccent: color));
  }

  void clearCustomAccent() {
    _update(_settings.copyWith(clearCustomAccent: true));
  }

  void setHapticsEnabled(bool enabled) {
    _update(_settings.copyWith(hapticsEnabled: enabled));
  }

  void setAnimationsEnabled(bool enabled) {
    _update(_settings.copyWith(animationsEnabled: enabled));
  }

  void setSignalColors({Color? high, Color? low}) {
    _update(
      _settings.copyWith(
        highSignalValue: high?.toARGB32(),
        lowSignalValue: low?.toARGB32(),
      ),
    );
  }

  void resetAppearance() {
    _update(
      _settings.copyWith(
        themeMode: ThemeMode.system,
        paletteId: 'engineering_blue',
        clearCustomAccent: true,
      ),
    );
  }

  void replaceSettings(AppSettings settings) {
    _update(settings);
  }

  void _update(AppSettings next) {
    if (next == _settings) {
      return;
    }
    _settings = next;
    if (!_disposed) {
      notifyListeners();
    }
    _writeQueue = _writeQueue.then((_) => _store.save(next));
  }

  /// Ensures pending preference writes are finished (used before backup and
  /// by tests).
  Future<void> flush() => _writeQueue;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppHaptics {
  const AppHaptics._();

  static void selection(bool enabled) {
    if (enabled) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  static void impact(bool enabled) {
    if (enabled) {
      unawaited(HapticFeedback.lightImpact());
    }
  }
}
