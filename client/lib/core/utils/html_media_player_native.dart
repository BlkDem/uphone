import 'package:flutter/material.dart';

Widget buildVideoPlayerImpl(String url, {double height = 200}) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam, size: 32),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {},
            child: const Text('Tap to play in browser'),
          ),
        ],
      ),
    ),
  );
}

Widget buildAudioPlayerImpl(String url) {
  return Container(
    height: 48,
    decoration: BoxDecoration(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic, size: 20),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {},
            child: const Text('Tap to play in browser'),
          ),
        ],
      ),
    ),
  );
}
