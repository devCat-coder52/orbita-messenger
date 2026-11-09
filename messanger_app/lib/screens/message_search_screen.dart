import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../models/global_search_hit.dart';
import '../theme/app_theme.dart';
import '../utils/time_formatter.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/empty_state_hint.dart';
import 'chat_screen.dart';

class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({super.key});

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  static const int _minQueryLength = 2;
  static const Duration _debounce = Duration(milliseconds: 250);

  final TextEditingController _controller = TextEditingController();
  Timer? _timer;
  bool _isSearching = false;
  String _query = '';
  List<GlobalSearchHit> _results = const [];

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final query = value.trim();
    setState(() => _query = query);

    if (query.length < _minQueryLength) {
      setState(() => _results = const []);
      return;
    }
    _timer = Timer(_debounce, _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _query;
    setState(() => _isSearching = true);

    try {
      final hits = await ChatRepository.searchMessagesGlobal(query);
      if (!mounted || query != _query) return;
      setState(() => _results = hits);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openHit(GlobalSearchHit hit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(chatId: hit.chatId, initialMessageId: hit.messageId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск по сообщениям'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              style: TextStyle(color: t.textPrimary),
              cursorColor: t.secondary,
              decoration: InputDecoration(
                hintText: 'Что искать?',
                hintStyle: TextStyle(color: t.hint),
                prefixIcon: Icon(Icons.search, color: t.hint),
                isDense: true,
                filled: true,
                fillColor: t.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final t = context.app;

    if (_query.length < _minQueryLength) {
      return EmptyStateHint(
        icon: Icons.search,
        title: 'Поиск по переписке',
        message:
            'Введите минимум $_minQueryLength символа. Поиск идёт по сообщениям, '
            'которые уже загружены на это устройство.',
      );
    }

    if (_isSearching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return EmptyStateHint(
        icon: Icons.search_off,
        title: 'Ничего не найдено',
        message:
            'Попробуйте другой запрос. Совсем старые сообщения, которые ещё '
            'не загружались на телефон, в поиск не попадут.',
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: t.divider),
      itemBuilder: (context, index) {
        final hit = _results[index];
        return ListTile(
          leading: ChatAvatar(
            avatarUrl: hit.avatarUrl,
            fallbackName: hit.chatName,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  hit.chatName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                TimeFormatter.chatListTime(hit.createdAt),
                style: TextStyle(fontSize: 12, color: t.textSecondary),
              ),
            ],
          ),
          subtitle: _Snippet(content: hit.content, query: _query),
          onTap: () => _openHit(hit),
        );
      },
    );
  }
}

/// Строка результата с подсветкой совпадения.
class _Snippet extends StatelessWidget {
  const _Snippet({required this.content, required this.query});

  static const int _maxLength = 160;

  final String content;
  final String query;

  @override
  Widget build(BuildContext context) {
    final t = context.app;
    final normalized = content.replaceAll('\n', ' ');
    final quote = normalized.length > _maxLength
        ? '${normalized.substring(0, _maxLength)}…'
        : normalized;

    final lowerQuote = quote.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerQuote.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: quote.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: quote.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: quote.substring(index, index + query.length),
          style: TextStyle(color: t.secondary, fontWeight: FontWeight.w600),
        ),
      );
      start = index + query.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: t.textSecondary),
    );
  }
}
