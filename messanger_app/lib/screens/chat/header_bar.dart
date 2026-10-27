import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../profile_screen.dart';
import '../../models/member.dart';
import '../../utils/app_colors.dart';
import '../../widgets/typing_dots.dart';

class ChatBarHeaderWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final Member? user;
  final String? chatStatus;
  final int selectedCount;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onCancelPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onForwardPressed;
  final VoidCallback? onBackPressed;
  final GlobalKey? menuButtonKey;

  const ChatBarHeaderWidget({
    super.key,
    this.user,
    this.chatStatus,
    this.selectedCount = 0,
    this.onMenuPressed,
    this.menuButtonKey,
    this.onCancelPressed,
    this.onDeletePressed,
    this.onForwardPressed,
    this.onBackPressed,
  });

  Widget _buildStatusLine() {
    final isTyping = chatStatus == 'печатает...';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      child: isTyping
          ? Row(
              key: const ValueKey('typing'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'печатает',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 6),
                const TypingDots(size: 4, color: Colors.white70),
              ],
            )
          : Text(
              chatStatus ?? '',
              key: ValueKey(chatStatus),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      leading: selectedCount > 0
          ? IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onCancelPressed,
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBackPressed,
            ),
      title: selectedCount > 0
          ? Text(
              'Выбрано: $selectedCount',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: user != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(userId: user!.id),
                        ),
                      );
                    }
                  : null,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: user != null && user!.avatarUrl != null
                        ? CachedNetworkImageProvider(
                            '${dotenv.env['BASE_URL']}/${user!.avatarUrl}',
                          )
                        : null,
                    backgroundColor: Colors.grey[600],
                    child: user != null && user!.avatarUrl == null
                        ? Text(
                            user!.name.isNotEmpty
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.name ?? 'Чат',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        _buildStatusLine(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: selectedCount > 0
          ? [
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: onForwardPressed,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: onDeletePressed,
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.more_vert),
                key: menuButtonKey,
                onPressed: onMenuPressed,
              ),
            ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
