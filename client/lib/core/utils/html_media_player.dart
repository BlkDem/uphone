import 'package:flutter/widgets.dart';
import 'html_media_player_native.dart'
    if (dart.library.js_interop) 'html_media_player_web.dart';

Widget buildVideoPlayer(String url, {double height = 200}) =>
    buildVideoPlayerImpl(url, height: height);

Widget buildAudioPlayer(String url) => buildAudioPlayerImpl(url);
