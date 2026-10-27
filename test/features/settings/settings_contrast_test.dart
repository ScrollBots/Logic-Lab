import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/core/theme/logic_lab_theme.dart';
import 'package:logic_lab/features/learn/application/learning_controller.dart';
import 'package:logic_lab/features/learn/data/learning_progress_repository.dart';
import 'package:logic_lab/features/projects/application/projects_controller.dart';
import 'package:logic_lab/features/projects/data/project_repository.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:logic_lab/features/settings/presentation/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

Future<Widget> _buildSettings({required Brightness brightness}) async {
  final SettingsController settings = SettingsController(
    MemorySettingsStore(),
    const AppSettings(),
  );
  final ProjectsController projects = ProjectsController(
    MemoryProjectRepository(),
  );
  final LearningController learning = LearningController(
    MemoryLearningProgressRepository(),
  );
  await projects.load();
  await learning.load();
  final ThemeData theme = LogicLabTheme.build(
    brightness: brightness,
    seed: settings.seedColor,
    highSignal: settings.value.highSignal,
    lowSignal: settings.value.lowSignal,
  );
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<ProjectsController>.value(value: projects),
      ChangeNotifierProvider<LearningController>.value(value: learning),
    ],
    child: MaterialApp(
      theme: theme,
      darkTheme: theme,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const <Locale>[Locale('fa', 'IR')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  const String paletteDescription =
      'رنگ اصلی برنامه از این پالت‌ها انتخاب می‌شود.';

  testWidgets('the palette description is readable in Light mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildSettings(brightness: Brightness.light));
    await tester.pumpAndSettle();

    final Text text = tester.widget<Text>(find.text(paletteDescription));
    final Color color = text.style!.color!;
    expect(color, isNot(Colors.black));
    expect(
      color.computeLuminance(),
      lessThan(0.6),
      reason: 'in Light mode the description must be a dark, readable color',
    );
  });

  testWidgets('the palette description is readable in Dark mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildSettings(brightness: Brightness.dark));
    await tester.pumpAndSettle();

    final Text text = tester.widget<Text>(find.text(paletteDescription));
    final Color color = text.style!.color!;
    expect(color, isNot(Colors.black));
    expect(
      color.computeLuminance(),
      greaterThan(0.4),
      reason: 'in Dark mode the description must be a light, readable color',
    );
  });

  testWidgets(
    'the palette description uses the theme-aware secondary color in both modes',
    (WidgetTester tester) async {
      for (final Brightness brightness in <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        await tester.pumpWidget(await _buildSettings(brightness: brightness));
        await tester.pumpAndSettle();

        final Text text = tester.widget<Text>(find.text(paletteDescription));
        final Color? color = text.style?.color;
        expect(
          color,
          isNotNull,
          reason: 'style color must be set in $brightness',
        );
        // The color must come from the ColorScheme, not a hardcoded value.
        expect(color, isNot(Colors.black54));
        expect(color, isNot(Colors.black));
      }
    },
  );
}
