import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'package:web/web.dart' show HTMLVideoElement, HTMLAudioElement;

final Set<String> _registeredViews = {};

Widget buildVideoPlayerImpl(String url, {double height = 200}) {
  final viewId = 'video_player_${url.hashCode}';
  if (!_registeredViews.contains(viewId)) {
    _registeredViews.add(viewId);
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final video = web.document.createElement('video') as HTMLVideoElement;
      video.src = url;
      video.setAttribute('controls', '');
      video.setAttribute('style',
          'width:100%;height:100%;object-fit:contain;background:#000;border-radius:8px;');
      video.setAttribute('playsinline', '');
      return video;
    });
  }
  return SizedBox(
    height: height,
    child: HtmlElementView(viewType: viewId),
  );
}

Widget buildAudioPlayerImpl(String url) {
  final viewId = 'audio_player_${url.hashCode}';
  if (!_registeredViews.contains(viewId)) {
    _registeredViews.add(viewId);
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final audio = web.document.createElement('audio') as HTMLAudioElement;
      audio.src = url;
      audio.setAttribute('controls', '');
      audio.setAttribute('style',
          'width:100%;height:100%;');
      return audio;
    });
  }
  return SizedBox(
    height: 48,
    child: HtmlElementView(viewType: viewId),
  );
}
