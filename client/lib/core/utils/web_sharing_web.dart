import 'package:web/web.dart' as web;

Future<bool> shareUrlImpl(String url) async {
  try {
    final nav = web.window.navigator;
    final data = web.ShareData(url: url, title: 'Shared image');
    if (nav.canShare(data)) {
      nav.share(data);
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}
