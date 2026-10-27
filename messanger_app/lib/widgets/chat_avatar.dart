import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, this.avatarUrl, required this.fallbackName});

  final String? avatarUrl;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;
    return CircleAvatar(
      backgroundImage: hasImage
          ? CachedNetworkImageProvider('${dotenv.env['BASE_URL']}/$avatarUrl')
          : null,
      child: hasImage
          ? null
          : Text(
              (fallbackName.isNotEmpty ? fallbackName[0] : '?').toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
    );
  }
}
