/// Single source of truth for the user-facing application identity.
///
/// The values mirror `pubspec.yaml` (`version: 1.0.0+1`). A unit test reads
/// `pubspec.yaml` and fails if the two ever drift apart, so the About screen,
/// the splash screen and the Android manifest can never disagree.
class AppInfo {
  const AppInfo._();

  /// Primary brand name (also the Android launcher label).
  static const String appName = 'Logic Lab';

  /// Persian subtitle shown beneath the brand name on the splash and About
  /// surfaces.
  static const String appSubtitle = 'آزمایشگاه منطق';

  /// Dot separated semantic version, exactly as published.
  static const String version = '1.0.0';

  /// Build number, kept separate from the user-facing version.
  static const String buildNumber = '1';

  /// The version string shown to the user. Never localised: the dot separator
  /// must stay a real `.` and never become `٫` or `/`.
  static const String versionDisplay = version;

  /// Full version including the build number, e.g. `1.0.0+1`.
  static const String fullVersion = '$version+$buildNumber';

  /// Footer line of the About screen.
  ///
  /// The line mixes a Latin name, a Persian year and a separator, so the
  /// About screen renders it with an explicit LTR direction to keep the parts
  /// in the order they are written.
  static const String copyright =
      'Logic Lab - ۱۴۰۵ | ساخته شده برای یادگیری مدارهای منطقی';
}
