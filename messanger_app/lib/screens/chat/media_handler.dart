import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/message.dart';
import '../../models/member.dart';
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
    required BuildContext context,
    int maxSize = 20 * 1024 * 1024,
  }) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final picked = result?.files.first;
    final path = picked?.path;
    if (picked == null || path == null || !context.mounted) return null;

    final file = File(path);
    if (await file.length() > maxSize) return null;

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
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/downloads/$fileName';
      final file = File(savePath);
      await file.parent.create(recursive: true);

      if (!await file.exists()) {
        await Dio().download(relativeUrl, savePath);
      }

      final openResult = await OpenFilex.open(savePath);
      if (openResult.message != 'done') {
        return 'Не удалось открыть файл: ${openResult.message}';
      }
      return null;
    } catch (e) {
      return 'Ошибка скачивания файла';
    }
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
