import 'no_release_gateway.dart';
import 'release_gateway.dart';

/// Web preview builds do not check for updates: the preview is served from a
/// different origin and is not an installed Android application, so there is
/// nothing to install. The real gateway is used on every `dart:io` target.
ReleaseGateway createPlatformReleaseGateway() => const NoReleaseGateway();
