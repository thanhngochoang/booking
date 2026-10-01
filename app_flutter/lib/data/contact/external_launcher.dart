import 'package:url_launcher/url_launcher.dart';

/// Port over "open this URL in another app", so tests never touch the OS.
abstract class ExternalLauncher {
  Future<bool> canOpen(Uri uri);
  Future<bool> open(Uri uri);
}

class UrlLauncherExternalLauncher implements ExternalLauncher {
  const UrlLauncherExternalLauncher();

  @override
  Future<bool> canOpen(Uri uri) => canLaunchUrl(uri);

  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

class FakeExternalLauncher implements ExternalLauncher {
  FakeExternalLauncher({
    this.unsupportedSchemes = const {},
    this.failOpen = false,
  });

  /// Schemes this "device" cannot handle (e.g. `tel` on a tablet).
  final Set<String> unsupportedSchemes;
  final bool failOpen;

  /// URLs that were opened, in order.
  final opened = <Uri>[];

  @override
  Future<bool> canOpen(Uri uri) async =>
      !unsupportedSchemes.contains(uri.scheme);

  @override
  Future<bool> open(Uri uri) async {
    if (failOpen || unsupportedSchemes.contains(uri.scheme)) return false;
    opened.add(uri);
    return true;
  }
}
