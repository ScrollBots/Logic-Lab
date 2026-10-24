import 'dart:math' as math;

/// Semantic version used by the update checker.
///
/// Published tags follow `vMAJOR.MINOR.PATCH` with an optional pre-release
/// suffix (`v1.2.0-rc.1`). Build metadata (`+3`) is deliberately ignored:
/// every release build gets a fresh build number from CI, so comparing it
/// would report an "update" for the exact version the user already has.
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(
    this.major,
    this.minor,
    this.patch, [
    this.preRelease = const <String>[],
  ]);

  final int major;
  final int minor;
  final int patch;

  /// Dot separated pre-release identifiers, empty for a final release.
  final List<String> preRelease;

  static final RegExp _pattern = RegExp(
    r'^[vV]?(\d{1,9})\.(\d{1,9})\.(\d{1,9})'
    r'(?:-([0-9A-Za-z.-]{1,64}))?'
    r'(?:\+[0-9A-Za-z.-]{1,64})?$',
  );

  /// Parses `1.2.3`, `v1.2.3`, `1.2.3-rc.1` or `1.2.3+45`.
  ///
  /// Returns `null` for anything that is not a complete version; a partial
  /// version such as `1.2` is rejected instead of being guessed.
  static SemanticVersion? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final RegExpMatch? match = _pattern.firstMatch(raw.trim());
    if (match == null) {
      return null;
    }
    final int? major = int.tryParse(match.group(1)!);
    final int? minor = int.tryParse(match.group(2)!);
    final int? patch = int.tryParse(match.group(3)!);
    if (major == null || minor == null || patch == null) {
      return null;
    }
    final String? suffix = match.group(4);
    return SemanticVersion(
      major,
      minor,
      patch,
      suffix == null || suffix.isEmpty ? const <String>[] : suffix.split('.'),
    );
  }

  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    if (patch != other.patch) {
      return patch.compareTo(other.patch);
    }
    // A pre-release sorts before the final release of the same version.
    if (preRelease.isEmpty && other.preRelease.isEmpty) {
      return 0;
    }
    if (preRelease.isEmpty) {
      return 1;
    }
    if (other.preRelease.isEmpty) {
      return -1;
    }
    final int length = math.min(preRelease.length, other.preRelease.length);
    for (int i = 0; i < length; i++) {
      final int comparison = _compareIdentifier(
        preRelease[i],
        other.preRelease[i],
      );
      if (comparison != 0) {
        return comparison;
      }
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  static int _compareIdentifier(String a, String b) {
    final int? numericA = int.tryParse(a);
    final int? numericB = int.tryParse(b);
    if (numericA != null && numericB != null) {
      return numericA.compareTo(numericB);
    }
    // Numeric identifiers have lower precedence than alphanumeric ones.
    if (numericA != null) {
      return -1;
    }
    if (numericB != null) {
      return 1;
    }
    return a.compareTo(b);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) {
    return other is SemanticVersion &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch &&
        _sameIdentifiers(other.preRelease, preRelease);
  }

  static bool _sameIdentifiers(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() {
    final String core = '$major.$minor.$patch';
    return preRelease.isEmpty ? core : '$core-${preRelease.join('.')}';
  }
}
