import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Компактная панель эмодзи под полем ввода.
///
/// Намеренно без внешнего пакета: `emoji_keyboard_flutter` — это полноэкранная
/// клавиатура со своей анимацией и фокусом, она конфликтует с полем ввода.
/// Здесь достаточно сетки частых эмодзи, которая вставляет символ в текст.
class EmojiPicker extends StatelessWidget {
  const EmojiPicker({super.key, required this.onEmoji});

  final ValueChanged<String> onEmoji;

  static const List<String> _emojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
    '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
    '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
    '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏',
    '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣',
    '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠',
    '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨',
    '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥',
    '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧',
    '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
    '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑',
    '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻',
    '👍', '👎', '👌', '🤌', '🤏', '✌️', '🤞', '🤟',
    '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '👋',
    '🤚', '🖐️', '✋', '🖖', '👏', '🙌', '🤝', '🙏',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘',
    '🔥', '✨', '⭐', '🌟', '💫', '💥', '💯', '🎉',
    '🎊', '🎁', '🏆', '🥇', '⚡', '☀️', '🌙', '☕',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return Container(
      height: 248,
      color: t.surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: _emojis.length,
        itemBuilder: (context, index) {
          final emoji = _emojis[index];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onEmoji(emoji),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }
}
