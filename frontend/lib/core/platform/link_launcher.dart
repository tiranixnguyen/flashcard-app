import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:url_launcher/url_launcher.dart";

part "link_launcher.g.dart";

/// Mở link bằng trình duyệt của máy. Bọc lại để widget test override được
/// (gọi thẳng `url_launcher` là đụng platform channel thật).
abstract class LinkLauncher {
  /// `false` = máy không mở được.
  Future<bool> open(Uri uri);
}

class UrlLauncherLinkLauncher implements LinkLauncher {
  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

@riverpod
LinkLauncher linkLauncher(Ref ref) => UrlLauncherLinkLauncher();
