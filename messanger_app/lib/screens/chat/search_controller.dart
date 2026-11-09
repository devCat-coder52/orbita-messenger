import 'package:flutter/material.dart';

import '../../models/message.dart';

/// Поиск по открытому чату.
///
/// Хранит идентификаторы найденных сообщений (а не индексы: список живёт
/// своей жизнью, индексы к моменту перехода устаревают) и просит экран
/// докрутить список к нужному сообщению.
class ChatSearchController {
  ChatSearchController({
    required this.messages,
    required this.onRevealMessage,
    this.onCacheFallback,
  });

  final List<Message> Function() messages;
  final void Function(int messageId) onRevealMessage;
  final Future<List<int>> Function(String query)? onCacheFallback;

  final TextEditingController textController = TextEditingController();

  bool isActive = false;
  bool isSearchingCache = false;
  String query = '';
  List<int> results = [];
  int _searchSeq = 0;
  int currentIndex = -1;

  void toggle() {
    isActive = !isActive;
    if (!isActive) reset();
  }

  void reset() {
    query = '';
    results = [];
    currentIndex = -1;
    isSearchingCache = false;
    textController.clear();
  }

  bool performSearch(
    String newQuery, {
    void Function(List<int> extraIndices)? applyExtra,
  }) {
    query = newQuery;
    results = [];
    currentIndex = -1;
    final seq = ++_searchSeq;

    if (query.isEmpty) {
      isSearchingCache = false;
      return true;
    }

    final lowerQuery = query.toLowerCase();
    final list = messages();
    for (final message in list) {
      final id = message.id;
      if (id != null && message.content.toLowerCase().contains(lowerQuery)) {
        results.add(id);
      }
    }

    if (results.isNotEmpty) {
      currentIndex = results.length - 1;
      _revealCurrent();
    }

    final fallback = onCacheFallback;
    if (fallback != null) {
      isSearchingCache = true;
      fallback(newQuery).then((extra) {
        if (seq != _searchSeq) return;
        isSearchingCache = false;
        if (extra.isEmpty) return;

        // Кэш возвращает индексы в текущем списке — переводим их в id.
        final extraIds = <int>[];
        for (final index in extra) {
          if (index < 0 || index >= list.length) continue;
          final id = list[index].id;
          if (id != null) extraIds.add(id);
        }
        if (extraIds.isEmpty) return;

        results = ({...results, ...extraIds}).toList()..sort();
        if (currentIndex == -1 && results.isNotEmpty) {
          currentIndex = results.length - 1;
          _revealCurrent();
        }
        applyExtra?.call(extra);
      });
    }
    return true;
  }

  void navigate(int direction) {
    if (results.isEmpty) return;

    currentIndex += direction;
    if (currentIndex < 0) {
      currentIndex = results.length - 1;
    } else if (currentIndex >= results.length) {
      currentIndex = 0;
    }

    _revealCurrent();
  }

  void dispose() => textController.dispose();

  void _revealCurrent() {
    if (currentIndex < 0 || currentIndex >= results.length) return;
    final messageId = results[currentIndex];
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => onRevealMessage(messageId),
    );
  }
}
