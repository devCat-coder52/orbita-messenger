import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

class PhotoViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? fileName;

  const PhotoViewerScreen({super.key, required this.imageUrl, this.fileName});

  Future<void> _savePhoto(BuildContext context) async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'orbita_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tempDir.path}/$fileName';

      await dio.download(imageUrl, filePath);

      Directory? externalDir;
      if (Platform.isAndroid) {
        externalDir = Directory('/storage/emulated/0/DCIM/Orbita');
      } else if (Platform.isIOS) {
        externalDir = await getApplicationDocumentsDirectory();
      }

      if (externalDir != null && !await externalDir.exists()) {
        await externalDir.create(recursive: true);
      }

      if (externalDir != null) {
        final newPath = '${externalDir.path}/$fileName';
        await File(filePath).copy(newPath);

        if (Platform.isAndroid) {
          try {
            await Process.run('am', [
              'broadcast',
              '-a',
              'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
              '-d',
              'file://$newPath',
            ]);
          } catch (e) {
            log.e('Не удалось запустить MediaScanner: $e');
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Сохранено в DCIM/Orbita')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _savePhoto(context),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: imageUrl,
          child: PhotoView(
            imageProvider: NetworkImage(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }
}
