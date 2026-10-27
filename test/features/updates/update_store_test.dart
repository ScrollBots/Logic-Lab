import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/features/updates/data/update_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesUpdateStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('check time and postponed version survive a restart', () async {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final SharedPreferencesUpdateStore store = SharedPreferencesUpdateStore(
        preferences,
      );
      final DateTime checkedAt = DateTime(2026, 10, 24, 8, 30);
      await store.save(
        UpdateMemory(lastCheckAt: checkedAt, skippedVersion: '1.2.0'),
      );

      final UpdateMemory reloaded = await SharedPreferencesUpdateStore(
        await SharedPreferences.getInstance(),
      ).load();

      expect(reloaded.lastCheckAt, checkedAt);
      expect(reloaded.skippedVersion, '1.2.0');
    });

    test('an empty store reads as "never checked"', () async {
      final UpdateMemory memory = await SharedPreferencesUpdateStore(
        await SharedPreferences.getInstance(),
      ).load();

      expect(memory.lastCheckAt, isNull);
      expect(memory.skippedVersion, isNull);
    });

    test('a corrupted value falls back to "never checked"', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'logic_lab.updates.v1': 'this-is-not-json',
      });
      final UpdateMemory memory = await SharedPreferencesUpdateStore(
        await SharedPreferences.getInstance(),
      ).load();

      expect(memory.lastCheckAt, isNull);
      expect(memory.skippedVersion, isNull);
    });

    test('a value with the wrong shape is ignored field by field', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'logic_lab.updates.v1': '{"lastCheckAt": 42, "skippedVersion": 7}',
      });
      final UpdateMemory memory = await SharedPreferencesUpdateStore(
        await SharedPreferences.getInstance(),
      ).load();

      expect(memory.lastCheckAt, isNull);
      expect(memory.skippedVersion, isNull);
    });
  });

  group('UpdateMemory', () {
    test('copyWith keeps values and can clear the postponed version', () {
      final UpdateMemory memory = UpdateMemory(
        lastCheckAt: DateTime(2026, 1, 1),
        skippedVersion: '1.2.0',
      );

      expect(
        memory.copyWith(lastCheckAt: DateTime(2026, 2, 2)).skippedVersion,
        '1.2.0',
      );
      final UpdateMemory cleared = memory.copyWith(clearSkipped: true);
      expect(cleared.skippedVersion, isNull);
      expect(cleared.lastCheckAt, DateTime(2026, 1, 1));
    });
  });
}
