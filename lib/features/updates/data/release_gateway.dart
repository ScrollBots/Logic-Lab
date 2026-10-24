import '../domain/app_release.dart';
import 'release_gateway_stub.dart'
    if (dart.library.io) 'release_gateway_io.dart'
    as platform;

/// Why a check did not produce a release.
enum ReleaseFailure { offline, timeout, rateLimited, badResponse, unsupported }

/// The public endpoint the update check reads.
///
/// Unauthenticated, read-only and scoped to a single public repository: the
/// request carries no user data and needs no token.
const String defaultReleaseEndpoint =
    'https://api.github.com/repos/ScrollBots/Logic-Lab/releases/latest';

class ReleaseGatewayException implements Exception {
  const ReleaseGatewayException(this.failure);

  final ReleaseFailure failure;

  @override
  String toString() => 'ReleaseGatewayException(${failure.name})';
}

/// Reads the latest published release.
///
/// Implementations must never throw for a merely missing release (for example
/// a repository without any release yet) and must never return anything that
/// is not a final, trusted release.
abstract class ReleaseGateway {
  Future<AppRelease?> latest();
}

/// Creates the gateway for the running platform.
///
/// Android (and every other `dart:io` target) talks to the GitHub API; the
/// web preview gets a gateway that reports "nothing to do" instead of issuing
/// a cross-origin request.
ReleaseGateway createReleaseGateway() =>
    platform.createPlatformReleaseGateway();
