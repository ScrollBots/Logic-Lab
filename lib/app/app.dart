import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/theme/logic_lab_theme.dart';
import '../features/learn/application/learning_controller.dart';
import '../features/projects/application/projects_controller.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/updates/application/update_controller.dart';
import '../features/updates/data/no_release_gateway.dart';
import '../features/updates/data/update_store.dart';
import '../features/updates/presentation/update_gate.dart';
import 'shell/app_shell.dart';

class LogicLabApp extends StatelessWidget {
  const LogicLabApp({
    super.key,
    required this.settings,
    required this.projects,
    required this.learning,
    this.updates,
  });

  final SettingsController settings;
  final ProjectsController projects;
  final LearningController learning;

  /// The update checker. Tests and previews that do not pass one get a
  /// controller whose gateway never reports a release, so no test ever
  /// touches the network.
  final UpdateController? updates;

  static final UpdateController _offlineUpdates = UpdateController(
    store: MemoryUpdateStore(),
    gateway: const NoReleaseGateway(),
  );

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
    final UpdateController updateController = updates ?? _offlineUpdates;
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<ProjectsController>.value(value: projects),
        ChangeNotifierProvider<LearningController>.value(value: learning),
        ChangeNotifierProvider<UpdateController>.value(value: updateController),
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
            home: UpdateGate(
              controller: updateController,
              autoCheck: settings.updatesEnabled,
              child: const AppShell(),
            ),
          );
        },
      ),
    );
  }
}
