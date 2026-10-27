import 'semantic_version.dart';

/// One published release, as read from the GitHub releases API.
///
/// Only the data needed to describe an update is kept. Every URL that leaves
/// the app is validated first: the update prompt may open a web page or an
/// installer download, so it must never be possible to point the user at an
/// arbitrary host, even if a response were ever tampered with.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.tagName,
    required this.title,
    required this.notes,
    required this.pageUri,
    this.downloadUri,
    this.publishedAt,
    this.assetName,
    this.assetSize,
  });

  final SemanticVersion version;
  final String tagName;
  final String title;

  /// Release notes as plain Markdown, exactly as written for the release.
  final String notes;

  /// The release page on GitHub.
  final Uri pageUri;

  /// The installer asset (`.apk`) when the release publishes one.
  final Uri? downloadUri;

  final DateTime? publishedAt;
  final String? assetName;

  /// Installer size in bytes, when the release reports it.
  final int? assetSize;

  /// Hosts that are allowed to serve the installer or the release page.
  ///
  /// `github.com` serves the release page, and the asset CDN hosts serve the
  /// APK. Nothing else is ever opened from the update prompt.
  static const Set<String> allowedHosts = <String>{
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
    'github-production-release-asset-2e65be.s3.amazonaws.com',
  };

  static bool isTrustedUri(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }
    if (allowedHosts.contains(uri.host)) {
      return true;
    }
    // GitHub serves release assets from a few `*.githubusercontent.com`
    // hosts; the suffix check keeps those working without allowing an
    // arbitrary subdomain of a look-alike domain.
    return uri.host.endsWith('.githubusercontent.com');
  }

  /// What the download button opens: the installer when the release has one,
  /// otherwise the release page (so the user can still reach the file).
  Uri get downloadTarget => downloadUri ?? pageUri;

  bool isNewerThan(SemanticVersion current) => version > current;

  /// Parses a payload of `GET /repos/{owner}/{repo}/releases/latest`.
  ///
  /// Returns `null` for drafts, pre-releases, malformed payloads and
  /// untrusted URLs instead of throwing, because a broken response must never
  /// be able to break the app.
  static AppRelease? fromGitHubJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    if (raw['draft'] == true || raw['prerelease'] == true) {
      return null;
    }
    final SemanticVersion? version = SemanticVersion.tryParse(
      raw['tag_name'] is String ? raw['tag_name'] as String : null,
    );
    if (version == null || version.isPreRelease) {
      return null;
    }
    final Uri? pageUri = _trustedUri(raw['html_url']);
    if (pageUri == null) {
      return null;
    }

    Uri? downloadUri;
    String? assetName;
    int? assetSize;
    final Object? assets = raw['assets'];
    if (assets is List) {
      final List<Map<Object?, Object?>> apks = <Map<Object?, Object?>>[];
      for (final Object? asset in assets) {
        if (asset is! Map) {
          continue;
        }
        final Object? name = asset['name'];
        if (name is String && name.toLowerCase().endsWith('.apk')) {
          apks.add(asset);
        }
      }
      // Prefer the universal build when a release happens to publish several
      // APKs; otherwise the first installer wins.
      final Map<Object?, Object?>? chosen =
          apks.where((Map<Object?, Object?> asset) {
            final Object? name = asset['name'];
            return name is String && name.toLowerCase().contains('universal');
          }).firstOrNull ??
          apks.firstOrNull;
      if (chosen != null) {
        downloadUri = _trustedUri(chosen['browser_download_url']);
        final Object? name = chosen['name'];
        assetName = name is String ? name : null;
        final Object? size = chosen['size'];
        assetSize = size is num && size > 0 ? size.toInt() : null;
      }
    }

    final Object? published = raw['published_at'];
    return AppRelease(
      version: version,
      tagName: raw['tag_name'] as String,
      title: raw['name'] is String && (raw['name'] as String).trim().isNotEmpty
          ? (raw['name'] as String).trim()
          : 'Logic Lab $version',
      notes: raw['body'] is String ? raw['body'] as String : '',
      pageUri: pageUri,
      downloadUri: downloadUri,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
      assetName: assetName,
      assetSize: assetSize,
    );
  }

  static Uri? _trustedUri(Object? value) {
    if (value is! String) {
      return null;
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || !isTrustedUri(uri)) {
      return null;
    }
    return uri;
  }
}
