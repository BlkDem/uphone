import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadHelper {
  static Future<void> downloadFile(String url, {String? filename}) async {
    if (url.isEmpty) return;

    if (kIsWeb) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
      return;
    }

    final name = filename ?? url.split('/').last;
    final dio = Dio();
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null) throw Exception('Empty response');

    final ext = name.contains('.') ? name.split('.').last : 'bin';
    await FileSaver.instance.saveFile(
      name: name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_'),
      bytes: Uint8List.fromList(bytes),
      fileExtension: ext,
    );
  }
}
