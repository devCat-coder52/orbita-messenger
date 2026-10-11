import 'package:flutter/material.dart';

class ChatSearchBarWidget extends StatelessWidget {
  final TextEditingController searchController;
  final bool hasResults;
  final int currentIndex;
  final int totalResults;
  final Function(String) onChanged;
  final VoidCallback onBackPressed;
  final VoidCallback onNavigateUp;
  final VoidCallback onNavigateDown;

  const ChatSearchBarWidget({
    super.key,
    required this.searchController,
    this.hasResults = false,
    this.currentIndex = -1,
    this.totalResults = 0,
    required this.onChanged,
    required this.onBackPressed,
    required this.onNavigateUp,
    required this.onNavigateDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: onBackPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              autofocus: true,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Поиск сообщений...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIcon: hasResults
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${currentIndex + 1}/$totalResults',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_upward_outlined,
                              size: 20,
                            ),
                            onPressed: onNavigateUp,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_downward_outlined,
                              size: 20,
                            ),
                            onPressed: onNavigateDown,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
