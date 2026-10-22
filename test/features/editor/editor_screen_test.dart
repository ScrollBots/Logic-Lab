import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/core/widgets/common.dart';
import 'package:logic_lab/features/editor/domain/circuit_models.dart';
import 'package:logic_lab/features/editor/presentation/circuit_editor_screen.dart';
import 'package:logic_lab/features/projects/application/projects_controller.dart';
import 'package:logic_lab/features/projects/data/project_repository.dart';
import 'package:logic_lab/features/projects/domain/circuit_project.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:provider/provider.dart';

CircuitProject _counterProject() {
  final CircuitNode clock = CircuitNode(
    id: 'clk',
    type: ComponentType.clockSource,
    position: const CanvasPoint(120, 260),
    label: 'CLK',
  );
  final CircuitNode reset = CircuitNode(
    id: 'rst',
    type: ComponentType.inputPin,
    position: const CanvasPoint(120, 380),
    label: 'RST',
  );
  final CircuitNode counter = CircuitNode(
    id: 'cnt',
    type: ComponentType.counter4,
    position: const CanvasPoint(340, 300),
    label: 'CNT4',
  );
  final CircuitNode probe = CircuitNode(
    id: 'q0',
    type: ComponentType.outputPin,
    position: const CanvasPoint(580, 280),
    label: 'Q0',
  );
  return CircuitProject(
    id: 'p1',
    name: 'شمارنده آزمایشی',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    graph: CircuitGraph(
      nodes: <CircuitNode>[clock, reset, counter, probe],
      wires: <CircuitWire>[
        CircuitWire(
          id: 'w1',
          fromNodeId: 'clk',
          toNodeId: 'cnt',
          toInputIndex: 0,
        ),
        CircuitWire(
          id: 'w2',
          fromNodeId: 'rst',
          toNodeId: 'cnt',
          toInputIndex: 1,
        ),
        CircuitWire(
          id: 'w3',
          fromNodeId: 'cnt',
          toNodeId: 'q0',
          toInputIndex: 0,
          fromPortIndex: 0,
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('the editor shows the simulation controls and the clock level', (
    WidgetTester tester,
  ) async {
    final ProjectsController projects = ProjectsController(
      MemoryProjectRepository(),
    );
    await tester.pumpWidget(
      _wrap(
        CircuitEditorScreen(
          project: _counterProject(),
          projectsController: projects,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مدار معتبر است'), findsOneWidget);
    expect(find.text('CLK=0'), findsOneWidget);
    expect(find.byTooltip('یک پالس کلاک'), findsOneWidget);
    expect(find.byTooltip('اجرای کلاک خودکار'), findsOneWidget);
    expect(find.byTooltip('بازنشانی وضعیت ترتیبی'), findsOneWidget);
  });

  testWidgets('stepping the clock advances the counter in the editor', (
    WidgetTester tester,
  ) async {
    final ProjectsController projects = ProjectsController(
      MemoryProjectRepository(),
    );
    await tester.pumpWidget(
      _wrap(
        CircuitEditorScreen(
          project: _counterProject(),
          projectsController: projects,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The counter starts at zero.
    expect(find.text('CLK=0'), findsOneWidget);

    await tester.tap(find.byTooltip('یک پالس کلاک'));
    await tester.pumpAndSettle();

    // After one rising edge the least significant output is high.
    expect(find.text('CLK=0'), findsOneWidget);
    final SignalPill pill = tester.widget<SignalPill>(
      find.ancestor(of: find.text('Q0'), matching: find.byType(SignalPill)),
    );
    expect(pill.value, isTrue);
  });

  for (final Size size in <Size>[const Size(320, 640), const Size(640, 320)]) {
    testWidgets('editor controls stay usable at $size', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final ProjectsController projects = ProjectsController(
        MemoryProjectRepository(),
      );
      await tester.pumpWidget(
        _wrap(
          CircuitEditorScreen(
            project: _counterProject(),
            projectsController: projects,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
      expect(
        find.ancestor(
          of: find.text('قطعه'),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.text('مدار معتبر است')).width,
        greaterThanOrEqualTo(180),
      );
      expect(
        tester.getRect(find.byType(SignalPill)).top,
        greaterThanOrEqualTo(
          tester
              .getRect(
                find.text(
                  'خروجی‌ها با هر تغییر ورودی بلافاصله محاسبه می‌شوند.',
                ),
              )
              .bottom,
        ),
      );
      for (final String tooltip in <String>[
        'اجرای کلاک خودکار',
        'یک پالس کلاک',
        'بازنشانی وضعیت ترتیبی',
        'جزئیات وضعیت',
      ]) {
        expect(find.byTooltip(tooltip).hitTestable(), findsOneWidget);
      }
      expect(find.text('افزودن قطعه').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('پنهان کردن شبکه'));
      await tester.tap(find.text('پنهان کردن شبکه'));
      await tester.pumpAndSettle();
      expect(find.text('نمایش شبکه'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final bool enabled in <bool>[true, false]) {
    testWidgets('simulation and add haptics respect enabled=$enabled', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final ProjectsController projects = ProjectsController(
        MemoryProjectRepository(),
      );
      await tester.pumpWidget(
        _wrap(
          CircuitEditorScreen(
            project: _counterProject(),
            projectsController: projects,
          ),
          settings: AppSettings(
            hapticsEnabled: enabled,
            animationsEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      haptics.clear();

      await tester.tap(find.byTooltip('اجرای کلاک خودکار'));
      await tester.pump();
      expect(haptics.length, enabled ? 1 : 0);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(haptics.length, enabled ? 1 : 0);
      await tester.tap(find.byTooltip('توقف کلاک خودکار'));
      await tester.pump();
      expect(haptics.length, enabled ? 2 : 0);
      await tester.tap(find.byTooltip('یک پالس کلاک'));
      await tester.pump();
      expect(haptics.length, enabled ? 3 : 0);
      await tester.tap(find.byTooltip('بازنشانی وضعیت ترتیبی'));
      await tester.pumpAndSettle();
      expect(haptics.length, enabled ? 4 : 0);

      haptics.clear();
      await tester.tap(find.text('افزودن قطعه'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      await tester.tap(find.text('ورودی'));
      await tester.pumpAndSettle();
      expect(haptics.length, enabled ? 1 : 0);
      if (enabled) {
        expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');
      }
      expect(find.text('ورودی به بوم اضافه شد.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final (bool enabled, bool reduced) in <(bool, bool)>[
    (true, false),
    (false, false),
    (true, true),
  ]) {
    testWidgets('feedback motion respects enabled=$enabled reduced=$reduced', (
      WidgetTester tester,
    ) async {
      final ProjectsController projects = ProjectsController(
        MemoryProjectRepository(),
      );
      await tester.pumpWidget(
        _wrap(
          CircuitEditorScreen(
            project: _counterProject(),
            projectsController: projects,
          ),
          settings: AppSettings(animationsEnabled: enabled),
          disableAnimations: reduced,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('افزودن قطعه'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ورودی'));
      await tester.pumpAndSettle();

      final AnimatedSwitcher switcher = tester.widget(
        find.ancestor(
          of: find.text('ورودی به بوم اضافه شد.'),
          matching: find.byType(AnimatedSwitcher),
        ),
      );
      expect(
        switcher.duration,
        enabled && !reduced ? const Duration(milliseconds: 220) : Duration.zero,
      );
      await tester.tap(find.byTooltip('بستن پیام'));
      await tester.pumpAndSettle();
      expect(find.text('ورودی به بوم اضافه شد.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}

Widget _wrap(
  Widget child, {
  AppSettings settings = const AppSettings(animationsEnabled: false),
  bool disableAnimations = false,
}) {
  return ChangeNotifierProvider<SettingsController>(
    create: (_) => SettingsController(MemorySettingsStore(), settings),
    child: MaterialApp(
      builder:
          (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
      home: child,
    ),
  );
}
