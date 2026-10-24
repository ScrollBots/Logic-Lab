import 'package:url_launcher/url_launcher.dart';

import '../domain/app_release.dart';

/// Opens an external page for the update flow.
///
/// The download button deliberately opens the system browser instead of
/// installing silently: Android requires an explicit confirmation for any
/// package installation, and the app itself never downloads or runs code it
/// did not ship with.
class UpdateLauncher {
  const UpdateLauncher._();

  static Future<bool> open(Uri uri) async {
    // Defence in depth: the release parser already rejects untrusted hosts,
    // and the launcher rejects them again before handing a URI to Android.
    if (!AppRelease.isTrustedUri(uri)) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
