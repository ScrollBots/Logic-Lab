import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Named visual palettes. The palette seed drives the Material 3 color scheme;
/// semantic circuit colors stay stable unless the user overrides them.
@immutable
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.seed,
  });

  final String id;
  final String name;
  final String description;
  final Color seed;

  static const List<AppPalette> values = <AppPalette>[
    AppPalette(
      id: 'engineering_blue',
      name: 'آبی مهندسی',
      description: 'پیش‌فرض؛ آرام و دقیق',
      seed: Color(0xFF1F5FCC),
    ),
    AppPalette(
      id: 'emerald',
      name: 'زمردی',
      description: 'برای جلسات طولانی',
      seed: Color(0xFF0A7D68),
    ),
    AppPalette(
      id: 'violet',
      name: 'بنفش آزمایشگاه',
      description: 'مدرن و متمایز',
      seed: Color(0xFF6750C8),
    ),
    AppPalette(
      id: 'amber',
      name: 'کهربایی',
      description: 'گرم و پرانرژی',
      seed: Color(0xFFA85D13),
    ),
    AppPalette(
      id: 'graphite',
      name: 'گرافیتی',
      description: 'خنثی و حرفه‌ای',
      seed: Color(0xFF475569),
    ),
  ];

  static AppPalette byId(String id) {
    return values.firstWhere(
      (AppPalette palette) => palette.id == id,
      orElse: () => values.first,
    );
  }
}

/// Semantic colors used by circuit surfaces and messages. These live in a
/// theme extension so every screen paints signals consistently.
@immutable
class LogicLabColors extends ThemeExtension<LogicLabColors> {
  const LogicLabColors({
    required this.highSignal,
    required this.lowSignal,
    required this.unknownSignal,
    required this.success,
    required this.warning,
    required this.danger,
    required this.canvas,
    required this.canvasGrid,
    required this.canvasBorder,
    required this.technicalBackground,
  });

  final Color highSignal;
  final Color lowSignal;
  final Color unknownSignal;
  final Color success;
  final Color warning;
  final Color danger;
  final Color canvas;
  final Color canvasGrid;
  final Color canvasBorder;
  final Color technicalBackground;

  static LogicLabColors of(BuildContext context) {
    final LogicLabColors? extension =
        Theme.of(context).extension<LogicLabColors>();
    return extension ?? fallback;
  }

  /// Fallback colours for contexts that do not use the app theme (for
  /// example isolated widget tests or a custom embedder).
  static const LogicLabColors fallback = LogicLabColors(
    highSignal: Color(0xFF1D9B72),
    lowSignal: Color(0xFF6D7B8E),
    unknownSignal: Color(0xFF8793A6),
    success: Color(0xFF087A55),
    warning: Color(0xFF99600A),
    danger: Color(0xFFB42318),
    canvas: Color(0xFFFBFCFE),
    canvasGrid: Color(0xFFE8EDF5),
    canvasBorder: Color(0xFFE1E6EF),
    technicalBackground: Color(0xFFF1F4F9),
  );

  @override
  LogicLabColors copyWith({
    Color? highSignal,
    Color? lowSignal,
    Color? unknownSignal,
    Color? success,
    Color? warning,
    Color? danger,
    Color? canvas,
    Color? canvasGrid,
    Color? canvasBorder,
    Color? technicalBackground,
  }) {
    return LogicLabColors(
      highSignal: highSignal ?? this.highSignal,
      lowSignal: lowSignal ?? this.lowSignal,
      unknownSignal: unknownSignal ?? this.unknownSignal,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      canvas: canvas ?? this.canvas,
      canvasGrid: canvasGrid ?? this.canvasGrid,
      canvasBorder: canvasBorder ?? this.canvasBorder,
      technicalBackground: technicalBackground ?? this.technicalBackground,
    );
  }

  @override
  LogicLabColors lerp(ThemeExtension<LogicLabColors>? other, double t) {
    if (other is! LogicLabColors) {
      return this;
    }
    return LogicLabColors(
      highSignal: Color.lerp(highSignal, other.highSignal, t)!,
      lowSignal: Color.lerp(lowSignal, other.lowSignal, t)!,
      unknownSignal: Color.lerp(unknownSignal, other.unknownSignal, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      canvasGrid: Color.lerp(canvasGrid, other.canvasGrid, t)!,
      canvasBorder: Color.lerp(canvasBorder, other.canvasBorder, t)!,
      technicalBackground:
          Color.lerp(technicalBackground, other.technicalBackground, t)!,
    );
  }
}

@immutable
class LogicLabTheme {
  const LogicLabTheme._();

  static const double cardRadius = 20;
  static const double fieldRadius = 14;
  static const double smallRadius = 10;

  static ThemeData build({
    required Brightness brightness,
    required Color seed,
    required Color highSignal,
    required Color lowSignal,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme generated = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final Color background =
        isDark ? const Color(0xFF0A0E15) : const Color(0xFFF4F6FA);
    final Color surface =
        isDark ? const Color(0xFF111722) : const Color(0xFFFFFFFF);
    final Color surfaceLow =
        isDark ? const Color(0xFF0E141E) : const Color(0xFFF8FAFD);
    final Color surfaceHigh =
        isDark ? const Color(0xFF1A2230) : const Color(0xFFEDF1F7);
    final Color outline =
        isDark ? const Color(0xFF2A3545) : const Color(0xFFE1E6EF);
    final Color outlineStrong =
        isDark ? const Color(0xFF3B485B) : const Color(0xFFC7D0DE);
    final Color textPrimary =
        isDark ? const Color(0xFFF2F5FA) : const Color(0xFF111827);
    final Color textSecondary =
        isDark ? const Color(0xFFA4B0C2) : const Color(0xFF5C687B);

    final ColorScheme scheme = generated.copyWith(
      surface: background,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surfaceLow,
      surfaceContainer:
          isDark ? const Color(0xFF141C28) : const Color(0xFFF1F4F9),
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest:
          isDark ? const Color(0xFF222C3C) : const Color(0xFFE7ECF4),
      outline: outlineStrong,
      outlineVariant: outline,
      error: isDark ? const Color(0xFFFF8A87) : const Color(0xFFB42318),
      onError: isDark ? const Color(0xFF3B0705) : Colors.white,
    );

    final TextTheme base = Typography.material2021(
      platform: TargetPlatform.android,
      colorScheme: scheme,
    ).black.apply(
      fontFamily: 'Vazirmatn',
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final TextTheme textTheme = base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 34,
        height: 1.35,
        letterSpacing: 0,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        height: 1.35,
        letterSpacing: 0,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 1.4,
        letterSpacing: 0,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 21,
        height: 1.4,
        letterSpacing: 0,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.45,
        letterSpacing: 0,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 17,
        height: 1.5,
        letterSpacing: 0,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        height: 1.55,
        letterSpacing: 0,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        height: 1.5,
        letterSpacing: 0,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.8,
        letterSpacing: 0,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 13.5,
        height: 1.75,
        letterSpacing: 0,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.65,
        color: textSecondary,
        letterSpacing: 0,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
        letterSpacing: 0,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0,
      ),
    );

    final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
      side: BorderSide(color: outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Vazirmatn',
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: outlineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          iconSize: 21,
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLow,
        selectedColor: scheme.primary.withValues(alpha: 0.13),
        side: BorderSide(color: outline),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: outline),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outlineStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF243044) : const Color(0xFF1B2533),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor:
            isDark ? const Color(0xFF9EC5FF) : const Color(0xFFB8D4FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF253044) : const Color(0xFF1D2635),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 550),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : (isDark ? const Color(0xFF8D99AA) : Colors.white);
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : outlineStrong;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.12),
        circularTrackColor: scheme.primary.withValues(alpha: 0.12),
      ),
      extensions: <ThemeExtension<dynamic>>[
        LogicLabColors(
          highSignal:
              isDark && highSignal == const Color(0xFF1D9B72)
                  ? const Color(0xFF22C55E)
                  : highSignal,
          lowSignal:
              isDark && lowSignal == const Color(0xFF6D7B8E)
                  ? const Color(0xFF334155)
                  : lowSignal,
          unknownSignal:
              isDark ? const Color(0xFF8793A6) : const Color(0xFF7D8798),
          success: isDark ? const Color(0xFF4ADE9A) : const Color(0xFF087A55),
          warning: isDark ? const Color(0xFFF6C25B) : const Color(0xFF99600A),
          danger: isDark ? const Color(0xFFFF8A87) : const Color(0xFFB42318),
          canvas: isDark ? const Color(0xFF0F172A) : const Color(0xFFFBFCFE),
          canvasGrid:
              isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF5),
          canvasBorder: outline,
          technicalBackground:
              isDark ? const Color(0xFF0C121C) : const Color(0xFFF1F4F9),
        ),
      ],
    );
  }

  /// Technical values deliberately use an LTR monospace face. This keeps
  /// binary strings, symbols, and identifiers unambiguous inside the RTL UI.
  static TextStyle technical(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: 'JetBrainsMono',
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      letterSpacing: 0,
    );
  }
}
