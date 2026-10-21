import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/data/app_repositories.dart';
import '../core/data/bootstrap_repositories.dart';
import '../features/learn/application/learning_controller.dart';
import '../features/projects/application/projects_controller.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app.dart';

/// Application bootstrap.
///
/// The branded splash is shown while the local database, the stored projects
/// and the learning progress are opened. If anything fails the user sees a
/// readable error instead of a blank screen.
class LogicLabBootstrap extends StatefulWidget {
  const LogicLabBootstrap({super.key});

  @override
  State<LogicLabBootstrap> createState() => _LogicLabBootstrapState();
}

class _LogicLabBootstrapState extends State<LogicLabBootstrap> {
  SettingsController? _settings;
  ProjectsController? _projects;
  LearningController? _learning;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final SettingsController settings = await SettingsController.load(
        await SharedPreferencesSettingsStore.create(),
      );
      final AppRepositories repositories = await createAppRepositories();
      final ProjectsController projects = ProjectsController(
        repositories.projects,
      );
      final LearningController learning = LearningController(
        repositories.progress,
      );
      await Future.wait<void>(<Future<void>>[projects.load(), learning.load()]);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _projects = projects;
        _learning = learning;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'برنامه نتوانست داده‌های محلی را باز کند: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController? settings = _settings;
    if (settings != null && _projects != null && _learning != null) {
      return LogicLabApp(
        settings: settings,
        projects: _projects!,
        learning: _learning!,
      );
    }

    // The splash uses the default palette until the saved preferences load.
    final SettingsController fallback =
        settings ??
        SettingsController(MemorySettingsStore(), const AppSettings());
    return MaterialApp(
      title: 'Logic Lab',
      debugShowCheckedModeBanner: false,
      theme: LogicLabApp.buildTheme(fallback, Brightness.light),
      darkTheme: LogicLabApp.buildTheme(fallback, Brightness.dark),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const <Locale>[Locale('fa', 'IR')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashScreen(error: _loading ? null : _error),
    );
  }
}
