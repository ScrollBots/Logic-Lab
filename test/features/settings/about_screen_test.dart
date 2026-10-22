import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logic_lab/core/app_info.dart';
import 'package:logic_lab/features/settings/application/settings_controller.dart';
import 'package:logic_lab/features/settings/presentation/settings_screen.dart';
import 'package:provider/provider.dart';

Future<Widget> _buildSettings() async {
  final SettingsController settings = SettingsController(
    MemorySettingsStore(),
    const AppSettings(),
  );
  return ChangeNotifierProvider<SettingsController>.value(
    value: settings,
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

void main() {
  testWidgets('the About screen shows the semantic version', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(await _buildSettings());
    await tester.pumpAndSettle();
    await _scrollToAbout(tester);

    expect(find.byKey(const Key('about-version')), findsOneWidget);
    expect(find.text(AppInfo.versionDisplay), findsOneWidget);
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
}
