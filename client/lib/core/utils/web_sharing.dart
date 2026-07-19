import 'web_sharing_native.dart'
    if (dart.library.js_interop) 'web_sharing_web.dart';

Future<bool> shareUrl(String url) => shareUrlImpl(url);
