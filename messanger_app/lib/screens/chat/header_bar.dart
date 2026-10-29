import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../profile_screen.dart';
import '../../models/member.dart';
import '../../widgets/typing_dots.dart';

import '../../theme/app_theme.dart';

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

  Widget _buildStatusLine(BuildContext context) {
    final t = context.app;
    final isTyping = chatStatus == 'печатает...';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      child: isTyping
          ? Row(
              key: const ValueKey('typing'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'печатает',
                  style: TextStyle(fontSize: 12, color: t.textOnHeaderDim),
                ),
                const SizedBox(width: 6),
                TypingDots(size: 4, color: t.textOnHeaderDim),
              ],
            )
          : Text(
              chatStatus ?? '',
              key: ValueKey(chatStatus),
              style: TextStyle(fontSize: 12, color: t.textOnHeaderDim),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    return AppBar(
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: t.headerGradient,
          ),
        ),
      ),
      leading: selectedCount > 0
          ? IconButton(
              icon: Icon(Icons.close, color: t.textOnHeader),
              onPressed: onCancelPressed,
            )
          : IconButton(
              icon: Icon(Icons.arrow_back, color: t.textOnHeader),
              onPressed: onBackPressed,
            ),
      title: selectedCount > 0
          ? Text(
              'Выбрано: $selectedCount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: t.textOnHeader,
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
                    backgroundColor: t.surfaceVariant,
                    child: user != null && user!.avatarUrl == null
                        ? Text(
                            user!.name.isNotEmpty
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: t.textOnHeader),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: t.textOnHeader,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        _buildStatusLine(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      iconTheme: IconThemeData(color: t.textOnHeader),
      actions: selectedCount > 0
          ? [
              IconButton(
                tooltip: 'Переслать',
                icon: Icon(Icons.share, color: t.textOnHeader),
                onPressed: onForwardPressed,
              ),
              IconButton(
                tooltip: 'Удалить',
                icon: Icon(Icons.delete_outline, color: t.textOnHeader),
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
