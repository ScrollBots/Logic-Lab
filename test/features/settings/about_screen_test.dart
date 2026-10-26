import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/core/app_info.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:logic_lab/features/settings/presentation/settings_screen.dart';
import 'package:logic_lab/features/updates/application/update_controller.dart';
import 'package:logic_lab/features/updates/data/no_release_gateway.dart';
import 'package:logic_lab/features/updates/data/update_store.dart';
import 'package:logic_lab/features/updates/domain/semantic_version.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

Future<Widget> _buildSettings({
  SettingsController? settings,
  UpdateController? updates,
}) async {
  final SettingsController settingsController =
      settings ??
      SettingsController(MemorySettingsStore(), const AppSettings());
  final UpdateController updateController =
      updates ??
      UpdateController(
        store: MemoryUpdateStore(),
        gateway: const NoReleaseGateway(),
        currentVersion: SemanticVersion.tryParse(AppInfo.version),
      );
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<SettingsController>.value(
        value: settingsController,
      ),
      ChangeNotifierProvider<UpdateController>.value(value: updateController),
    ],
    child: const MaterialApp(
      locale: Locale('fa', 'IR'),
      supportedLocales: <Locale>[Locale('fa', 'IR')],
      localizationsDelegates: <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SettingsScreen(),
    ),
  );
}

Future<void> _scrollToAbout(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('about-section')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToUpdates(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('updates-section')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the About screen shows the semantic version', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildSettings());
    await tester.pumpAndSettle();
    await _scrollToAbout(tester);

    expect(find.byKey(const Key('about-version')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('about-version')),
        matching: find.text(AppInfo.versionDisplay),
      ),
      findsOneWidget,
    );
    expect(find.text('نسخه'), findsOneWidget);
  });

  testWidgets('the About screen does not show the internal build number', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildSettings());
    await tester.pumpAndSettle();
    await _scrollToAbout(tester);

    // The build number stays in the packaging metadata, but it must not be
    // part of the user facing About screen.
    expect(find.text('شماره ساخت'), findsNothing);
    expect(find.text(AppInfo.buildNumber), findsNothing);
    expect(find.text(AppInfo.fullVersion), findsNothing);
  });

  testWidgets('the About footer uses the exact bilingual text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildSettings());
    await tester.pumpAndSettle();
    await _scrollToAbout(tester);

    const String expected =
        'Logic Lab - ۱۴۰۵ | ساخته شده برای یادگیری مدارهای منطقی';
    expect(AppInfo.copyright, expected);
    expect(find.byKey(const Key('about-footer')), findsOneWidget);
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('the footer keeps its parts in the written order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildSettings());
    await tester.pumpAndSettle();
    await _scrollToAbout(tester);

    // The line mixes a Latin name, a Persian year and a separator, so it is
    // rendered with an explicit LTR direction.
    final Directionality directionality = tester.widget<Directionality>(
      find
          .ancestor(
            of: find.byKey(const Key('about-footer')),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(directionality.textDirection, TextDirection.ltr);

    final Text footer = tester.widget<Text>(
      find.byKey(const Key('about-footer')),
    );
    final String footerText = footer.data ?? '';
    expect(footerText, AppInfo.copyright);
    expect(footerText.startsWith('Logic Lab - '), isTrue);
    expect(footerText.contains(' | '), isTrue);
  });

  testWidgets('the About text mentions no data is sent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildSettings());
    await tester.pumpAndSettle();
    await _scrollToAbout(tester);

    expect(find.textContaining('هیچ دادهٔ شخصی جمع‌آوری'), findsWidgets);
  });
}
