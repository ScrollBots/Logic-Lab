import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('theme mode, palette and toggles survive a restart', () async {
      final SettingsController controller = await SettingsController.load(
        await SharedPreferencesSettingsStore.create(),
      );
      controller.setThemeMode(ThemeMode.dark);
      controller.setPalette('emerald');
      controller.setHapticsEnabled(false);
      controller.setAnimationsEnabled(false);
      controller.setSignalColors(high: const Color(0xFF123456));
      await controller.flush();

      final SettingsController reloaded = await SettingsController.load(
        await SharedPreferencesSettingsStore.create(),
      );
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.value.paletteId, 'emerald');
      expect(reloaded.value.hapticsEnabled, isFalse);
      expect(reloaded.value.animationsEnabled, isFalse);
      expect(reloaded.value.highSignalValue, 0xFF123456);
    });

    test('a custom accent colour is persisted and can be cleared', () async {
      final SettingsController controller = await SettingsController.load(
        await SharedPreferencesSettingsStore.create(),
      );
      controller.setCustomAccent(const Color(0xFF00AA55));
      await controller.flush();
      expect(controller.value.customAccent, const Color(0xFF00AA55));

      final SettingsController reloaded = await SettingsController.load(
        await SharedPreferencesSettingsStore.create(),
      );
      expect(reloaded.value.customAccent, const Color(0xFF00AA55));

      reloaded.clearCustomAccent();
      await reloaded.flush();
      final SettingsController again = await SettingsController.load(
        await SharedPreferencesSettingsStore.create(),
      );
      expect(again.value.customAccent, isNull);
      expect(again.value.paletteId, 'engineering_blue');
    });

    test('a corrupted preference file falls back to the defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'logic_lab.settings.v1': 'this-is-not-json',
      });
      final SettingsController controller = await SettingsController.load(
        await SharedPreferencesSettingsStore.create(),
      );
      expect(controller.themeMode, ThemeMode.system);
      expect(controller.value.paletteId, 'engineering_blue');
    });
  });
}
