import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/app/app.dart';
import 'package:logic_lab/app/shell/app_navigation.dart';
import 'package:logic_lab/features/learn/application/learning_controller.dart';
import 'package:logic_lab/features/learn/data/learning_progress_repository.dart';
import 'package:logic_lab/features/learn/data/learning_state_repository.dart';
import 'package:logic_lab/features/learn/domain/curriculum.dart';
import 'package:logic_lab/features/learn/presentation/learn_screen.dart';
import 'package:logic_lab/features/learn/presentation/learning_session_screen.dart';
import 'package:logic_lab/features/projects/application/projects_controller.dart';
import 'package:logic_lab/features/projects/data/project_repository.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

Future<LearningController> _learning() async {
  final LearningController learning = LearningController(
    MemoryLearningProgressRepository(),
    stateRepository: MemoryLearningStateRepository(),
  );
  await learning.load();
  return learning;
}

Widget _home(LearningController learning, SettingsController settings) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<LearningController>.value(value: learning),
    ],
    child: MaterialApp(
      locale: const Locale('fa', 'IR'),
      supportedLocales: const <Locale>[Locale('fa', 'IR')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: LogicLabApp.buildTheme(settings, Brightness.light),
      home: const LearnScreen(),
    ),
  );
}

Widget _session(
  LearningController learning,
  SettingsController settings,
  String lessonId,
) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<LearningController>.value(value: learning),
    ],
    child: MaterialApp(
      locale: const Locale('fa', 'IR'),
      supportedLocales: const <Locale>[Locale('fa', 'IR')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: LogicLabApp.buildTheme(settings, Brightness.light),
      home: LearningSessionScreen(lesson: kLessonById[lessonId]!),
    ),
  );
}

void main() {
  testWidgets('the learning home fits a 360 px phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final SettingsController settings = await SettingsController.load(
      MemorySettingsStore(),
    );
    final LearningController learning = await _learning();

    await tester.pumpWidget(_home(learning, settings));
    await tester.pumpAndSettle();

    expect(find.text('ادامهٔ یادگیری'), findsOneWidget);
    expect(find.text('شروع درس'), findsOneWidget);
    expect(find.text('چطور یاد بگیریم؟'), findsOneWidget);

    final Finder start = find.text('شروع می‌کنم');
    await tester.scrollUntilVisible(
      start,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(learning.state.onboardingSeen, isTrue);
    expect(find.text('چطور یاد بگیریم؟'), findsNothing);

    // The unit map and practice entries live below the hero card; they must
    // still be reachable on a narrow screen.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    final Finder map = find.text('مسیر یادگیری');
    await tester.scrollUntilVisible(
      map,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(map, findsOneWidget);

    final Finder reference = find.text('مرجع گیت‌ها');
    await tester.scrollUntilVisible(
      reference,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(reference, findsOneWidget);
  });

  testWidgets('the first lesson runs end to end on a small phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final SettingsController settings = await SettingsController.load(
      MemorySettingsStore(),
    );
    final ProjectsController projects = ProjectsController(
      MemoryProjectRepository(),
    );
    await projects.load();
    final LearningController learning = await _learning();

    await tester.pumpWidget(
      LogicLabApp(settings: settings, projects: projects, learning: learning),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppDestination.learning.itemKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('شروع درس'));
    await tester.pumpAndSettle();

    // Two short concept steps.
    expect(find.text('فقط دو حالت'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    expect(find.text('کلیدها، ورودی و خروجی'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    // Predict the output of a buffer holding 1.
    expect(find.text('حدس بزنید'), findsOneWidget);
    final Finder one = find.text('۱');
    await tester.ensureVisible(one);
    await tester.tap(one);
    await tester.pump();
    await tester.tap(find.text('بررسی پاسخ'));
    await tester.pumpAndSettle();
    expect(find.text('درست است.'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    // Choose the gate that passes the signal unchanged.
    expect(find.text('قطعهٔ مناسب'), findsOneWidget);
    final Finder buffer = find.text('بافر');
    await tester.ensureVisible(buffer);
    await tester.tap(buffer);
    await tester.pump();
    await tester.tap(find.text('بررسی پاسخ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پایان درس'));
    await tester.pumpAndSettle();

    expect(find.text('درس کامل شد'), findsOneWidget);
    expect(find.textContaining('XP این جلسه'), findsOneWidget);
    expect(learning.isLessonCompleted('lesson_signals'), isTrue);
    expect(learning.xp, greaterThan(0));

    await tester.tap(find.text('بازگشت به مسیر'));
    await tester.pumpAndSettle();

    expect(find.text('ادامهٔ یادگیری'), findsOneWidget);
    expect(find.text('سیم‌کشی درست'), findsWidgets);
  });

  testWidgets('a sequential lesson steps through real latch states', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final SettingsController settings = await SettingsController.load(
      MemorySettingsStore(),
    );
    final LearningController learning = await _learning();

    await tester.pumpWidget(_session(learning, settings, 'lesson_latch'));
    await tester.pumpAndSettle();

    expect(find.text('حافظه با بازخورد'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    // EN stays 1 while D goes 1 -> 0: the latch is transparent.
    expect(find.text('دریچهٔ باز'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('1'), findsNWidgets(2));
    await tester.tap(find.text('1').at(0));
    await tester.tap(find.text('0').at(1));
    await tester.pump();
    await tester.tap(find.text('بررسی پاسخ'));
    await tester.pumpAndSettle();
    expect(find.text('ترتیب مقادیر درست است.'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    // The closed latch keeps the stored 1 while D changes.
    expect(find.text('بستن دریچه'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(3));
    await tester.tap(find.text('1').at(0));
    await tester.tap(find.text('1').at(1));
    await tester.tap(find.text('1').at(2));
    await tester.pump();
    await tester.tap(find.text('بررسی پاسخ'));
    await tester.pumpAndSettle();
    expect(find.text('ترتیب مقادیر درست است.'), findsOneWidget);
    await tester.tap(find.text('ادامه'));
    await tester.pumpAndSettle();

    expect(find.text('قاعدهٔ قفل'), findsOneWidget);
    final Finder choice = find.textContaining('EN=۱: Q از D پیروی می‌کند');
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pump();
    await tester.tap(find.text('بررسی پاسخ'));
    await tester.pumpAndSettle();
    expect(find.text('درست است.'), findsOneWidget);
    await tester.tap(find.text('پایان درس'));
    await tester.pumpAndSettle();

    expect(find.text('درس کامل شد'), findsOneWidget);
    expect(learning.isLessonCompleted('lesson_latch'), isTrue);
  });
}
