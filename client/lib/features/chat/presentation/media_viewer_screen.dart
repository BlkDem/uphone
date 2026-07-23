import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uphone_client/shared/models/chat.dart';
import 'package:uphone_client/core/config/app_settings.dart';
import 'package:uphone_client/core/utils/web_sharing.dart' as web_sharing;
import 'package:uphone_client/core/utils/download_helper.dart';
import 'package:uphone_client/core/utils/html_media_player.dart';

class MediaViewerScreen extends StatefulWidget {
  final List<ChatMessage> messages;
  final int initialIndex;
  final String chatId;

  const MediaViewerScreen({
    super.key,
    required this.messages,
    required this.initialIndex,
    required this.chatId,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;
  bool _isSlideshow = false;
  Timer? _slideshowTimer;
  bool _showControls = true;

  bool get _isVideo =>
      widget.messages[_currentIndex].type == 'video' &&
      widget.messages[_currentIndex].fileUrl.isNotEmpty;

  bool get _isImage =>
      widget.messages[_currentIndex].type == 'image' &&
      widget.messages[_currentIndex].fileUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startSlideshow() {
    if (!AppSettings.instance.slideshowAutoplay) return;
    setState(() => _isSlideshow = true);
    _scheduleNext();
  }

  void _stopSlideshow() {
    _slideshowTimer?.cancel();
    setState(() => _isSlideshow = false);
  }

  void _scheduleNext() {
    _slideshowTimer?.cancel();
    if (!_isSlideshow) return;

    final msg = widget.messages[_currentIndex];
    final isVideo = msg.type == 'video' && msg.fileUrl.isNotEmpty;

    if (isVideo) {
      // For videos, we wait for them to finish playing
      // The video player will call _onVideoFinished when done
      return;
    }

    final duration = Duration(seconds: AppSettings.instance.slideshowIntervalSeconds);
    _slideshowTimer = Timer(duration, _advanceSlideshow);
  }

  void _advanceSlideshow() {
    if (!_isSlideshow) return;
    if (_currentIndex < widget.messages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _stopSlideshow();
    }
  }

  void _onVideoFinished() {
    if (_isSlideshow) {
      _advanceSlideshow();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Main content
            PageView.builder(
              controller: _pageController,
              itemCount: widget.messages.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                if (_isSlideshow) _scheduleNext();
              },
              itemBuilder: (context, index) {
                final msg = widget.messages[index];
                if (msg.type == 'video' && msg.fileUrl.isNotEmpty) {
                  return _VideoPage(
                    message: msg,
                    isCurrentPage: index == _currentIndex,
                    onVideoFinished: _onVideoFinished,
                  );
                }
                return _ImagePage(message: msg);
              },
            ),

            // Top bar
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      title: Text(
                        '${_currentIndex + 1} / ${widget.messages.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      actions: [
                        // Slideshow button
                        IconButton(
                          icon: Icon(
                            _isSlideshow ? Icons.pause_circle : Icons.play_circle,
                            color: _isSlideshow ? Colors.amber : Colors.white,
                          ),
                          onPressed: _isSlideshow ? _stopSlideshow : _startSlideshow,
                          tooltip: _isSlideshow ? 'Stop slideshow' : 'Start slideshow',
                        ),
                        IconButton(
                          icon: const Icon(Icons.download, color: Colors.white),
                          onPressed: _isDownloading ? null : _downloadFile,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: _shareFile,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom bar with sender info
            if (_showControls && widget.messages[_currentIndex].sender != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.messages[_currentIndex].sender!.displayName.isNotEmpty
                                ? widget.messages[_currentIndex].sender!.displayName
                                : widget.messages[_currentIndex].sender!.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatDate(widget.messages[_currentIndex].createdAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Navigation arrows
            if (_showControls && _currentIndex > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavButton(
                    icon: Icons.chevron_left,
                    onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              ),
            if (_showControls && _currentIndex < widget.messages.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavButton(
                    icon: Icons.chevron_right,
                    onPressed: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              ),

            // Slideshow indicator
            if (_isSlideshow)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.slideshow, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _isVideo
                              ? 'Playing video...'
                              : 'Next in ${AppSettings.instance.slideshowIntervalSeconds}s',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadFile() async {
    final url = widget.messages[_currentIndex].fileUrl;
    if (url.isEmpty) return;

    setState(() => _isDownloading = true);
    try {
      await DownloadHelper.downloadFile(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareFile() async {
    final url = widget.messages[_currentIndex].fileUrl;
    if (url.isEmpty) return;

    try {
      if (kIsWeb) {
        final shared = await web_sharing.shareUrl(url);
        if (!shared) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
        }
      } else {
        await Share.shareUri(Uri.parse(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }
}

class _ImagePage extends StatelessWidget {
  final ChatMessage message;

  const _ImagePage({required this.message});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: message.fileUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final ChatMessage message;
  final bool isCurrentPage;
  final VoidCallback? onVideoFinished;

  const _VideoPage({
    required this.message,
    required this.isCurrentPage,
    this.onVideoFinished,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrentPage) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: buildVideoPlayer(widget.message.fileUrl),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
