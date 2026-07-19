import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uphone_client/shared/models/chat.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.messages.length}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isDownloading ? null : _downloadImage,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareImage,
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.messages.length,
        builder: (context, index) {
          final msg = widget.messages[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(msg.fileUrl),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }

  Future<void> _downloadImage() async {
    final url = widget.messages[_currentIndex].fileUrl;
    if (url.isEmpty) return;

    setState(() => _isDownloading = true);
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final bytes = response.data;
      if (bytes == null) throw Exception('Empty response');

      if (kIsWeb) {
        // On web, trigger download via anchor (simplified — use share as fallback)
        await Share.shareXFiles([XFile.fromData(Uint8List.fromList(bytes), name: 'image.jpg', mimeType: 'image/jpeg')]);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final filename = url.split('/').last;
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to ${file.path}')),
          );
        }
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

  Future<void> _shareImage() async {
    final url = widget.messages[_currentIndex].fileUrl;
    if (url.isEmpty) return;

    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final bytes = response.data;
      if (bytes == null) throw Exception('Empty response');

      final filename = url.split('/').last;
      final xfile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: filename,
        mimeType: 'image/${filename.split('.').last}',
      );
      await Share.shareXFiles([xfile]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }
}
