import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Полноэкранный просмотр аватара с зумом.
class AvatarViewerScreen extends StatelessWidget {
  const AvatarViewerScreen({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Padding(
              padding: EdgeInsets.all(48),
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
