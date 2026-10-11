import 'package:flutter/material.dart';
import '../../models/message.dart';

class ChatSearchController {
  ChatSearchController({
    required this.scrollController,
    required this.messages,
  });

  final ScrollController scrollController;
  final List<Message> Function() messages;

  final TextEditingController textController = TextEditingController();

  bool isActive = false;
  String query = '';
  List<int> results = [];
  int currentIndex = -1;

  static const double _approxItemHeight = 80.0;

  void toggle() {
    isActive = !isActive;
    if (!isActive) reset();
  }

  void reset() {
    query = '';
    results = [];
    currentIndex = -1;
    textController.clear();
  }

  void performSearch(String newQuery) {
    query = newQuery;
    results = [];
    currentIndex = -1;

    if (query.isEmpty) return;

    final lowerQuery = query.toLowerCase();
    final list = messages();
    for (int i = 0; i < list.length; i++) {
      if (list[i].content.toLowerCase().contains(lowerQuery)) {
        results.add(i);
      }
    }

    if (results.isNotEmpty) {
      currentIndex = results.length - 1;
      _scheduleScrollTo(results[currentIndex]);
    }
  }

  void navigate(int direction) {
    if (results.isEmpty) return;

    currentIndex += direction;
    if (currentIndex < 0) {
      currentIndex = results.length - 1;
    } else if (currentIndex >= results.length) {
      currentIndex = 0;
    }

    _scheduleScrollTo(results[currentIndex]);
  }

  void dispose() => textController.dispose();

  void _scheduleScrollTo(int messageIndex) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scrollToIndex(messageIndex),
    );
  }

  void scrollToIndex(int messageIndex) {
    if (!scrollController.hasClients) return;
    final reversedIndex = messages().length - 1 - messageIndex;
    final target = (reversedIndex * _approxItemHeight).clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );
    scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
