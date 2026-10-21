import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/theme/logic_lab_theme.dart';
import '../features/learn/application/learning_controller.dart';
import '../features/projects/application/projects_controller.dart';
import '../features/settings/application/settings_controller.dart';
import 'shell/app_shell.dart';

class LogicLabApp extends StatelessWidget {
  const LogicLabApp({
    super.key,
    required this.settings,
    required this.projects,
    required this.learning,
  });

  final SettingsController settings;
  final ProjectsController projects;
  final LearningController learning;

  /// Builds the light/dark theme from the current settings. Shared with the
  /// bootstrap splash so both surfaces use the exact same design system.
  static ThemeData buildTheme(
    SettingsController settings,
    Brightness brightness,
  ) {
    return LogicLabTheme.build(
      brightness: brightness,
      seed: settings.seedColor,
      highSignal: settings.value.highSignal,
      lowSignal: settings.value.lowSignal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<ProjectsController>.value(value: projects),
        ChangeNotifierProvider<LearningController>.value(value: learning),
      ],
      child: Consumer<SettingsController>(
        builder: (
          BuildContext context,
          SettingsController settings,
          Widget? _,
        ) {
          return MaterialApp(
            title: 'Logic Lab',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: buildTheme(settings, Brightness.light),
            darkTheme: buildTheme(settings, Brightness.dark),
            locale: const Locale('fa', 'IR'),
            supportedLocales: const <Locale>[Locale('fa', 'IR')],
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (BuildContext context, Widget? child) {
              final MediaQueryData media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: media.textScaler.clamp(
                    minScaleFactor: 0.9,
                    maxScaleFactor: 1.4,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
