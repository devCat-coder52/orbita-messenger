import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/app_config.dart';
import '../../models/message.dart';
import '../../models/member.dart';
import '../../services/auth_service.dart';
import '../photo_viewer_screen.dart';

typedef PickedFileResult = ({Message tempMessage, File file});

class ChatMediaHandler {
  const ChatMediaHandler();

  Future<PickedFileResult?> pickImage({
    required Member sender,
    double? maxWidth = 1200,
    double? maxHeight = 1200,
    int imageQuality = 85,
  }) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (picked == null) return null;

    final file = File(picked.path);
    final tempMessage = Message(
      sender: sender,
      imageUrl: 'temp:${picked.path}',
      timeCreate: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.sending,
      isTemp: true,
    );
    return (tempMessage: tempMessage, file: file);
  }

  Future<PickedFileResult?> pickFile({
    required Member sender,
    int maxSize = 20 * 1024 * 1024,
    void Function(String message)? onError,
  }) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final picked = result?.files.first;
    final path = picked?.path;
    if (picked == null || path == null) return null;

    final file = File(path);
    if (await file.length() > maxSize) {
      onError?.call('Файл больше ${maxSize ~/ (1024 * 1024)} МБ');
      return null;
    }

    final tempMessage = Message(
      sender: sender,
      fileUrl: 'temp:$path',
      fileName: picked.name,
      fileSize: picked.size,
      timeCreate: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.sending,
      isTemp: true,
    );
    return (tempMessage: tempMessage, file: file);
  }

  Future<String?> downloadAndOpenFile(
    String relativeUrl,
    String fileName,
  ) async {
    try {
      final uri = _resolveMediaUri(relativeUrl);
      if (uri == null) {
        return 'Некорректная ссылка на файл';
      }

      final dir = await getApplicationDocumentsDirectory();
      final name = _safeFileName(
        fileName.isNotEmpty ? fileName : uri.pathSegments.last,
      );
      final savePath = '${dir.path}/downloads/$name';
      final file = File(savePath);
      await file.parent.create(recursive: true);

      final exists = await file.exists();
      if (!exists || await file.length() == 0) {
        await HttpService.client.download(
          uri.toString(),
          savePath,
          options: Options(receiveTimeout: const Duration(minutes: 2)),
        );
      }

      final openResult = await OpenFilex.open(savePath);
      if (openResult.type != ResultType.done) {
        return 'Не удалось открыть файл: ${openResult.message}';
      }
      return null;
    } catch (e) {
      return 'Ошибка скачивания файла: $e';
    }
  }

  Uri? _resolveMediaUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.startsWith('temp:')) return null;

    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;

    final base = AppConfig.baseUrlApi;
    if (base.isEmpty) return null;
    final baseUri = Uri.tryParse(base);
    if (baseUri == null) return null;

    return baseUri.resolve(value);
  }

  String _safeFileName(String raw) {
    final base = raw.split(RegExp(r'[\\/]')).last.trim();
    final cleaned = base.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
    return cleaned.length > 120
        ? cleaned.substring(cleaned.length - 120)
        : cleaned;
  }

  void openImageViewer(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PhotoViewerScreen(imageUrl: imageUrl),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}
