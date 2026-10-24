import '../domain/app_release.dart';
import 'release_gateway.dart';

/// A gateway that never reports a release and performs no I/O.
///
/// Used by the web preview, by widget tests and as a safe fallback when no
/// real gateway should be created. It keeps "no update" a successful, silent
/// outcome instead of an error.
class NoReleaseGateway implements ReleaseGateway {
  const NoReleaseGateway();

  @override
  Future<AppRelease?> latest() async => null;
}
