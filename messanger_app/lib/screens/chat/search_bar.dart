import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ChatSearchBarWidget extends StatelessWidget {
  final TextEditingController searchController;
  final bool hasResults;
  final int currentIndex;
  final int totalResults;
  final bool isSearchingCache;
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
    this.isSearchingCache = false,
    required this.onChanged,
    required this.onBackPressed,
    required this.onNavigateUp,
    required this.onNavigateDown,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: t.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, size: 20, color: t.textPrimary),
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
              style: TextStyle(color: t.textPrimary),
              cursorColor: t.secondary,
              decoration: InputDecoration(
                hintText: 'Поиск сообщений...',
                hintStyle: TextStyle(color: t.hint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: t.surfaceVariant,
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
                              color: t.textSecondary,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_upward_outlined,
                              size: 20,
                              color: t.textSecondary,
                            ),
                            onPressed: onNavigateUp,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_downward_outlined,
                              size: 20,
                              color: t.textSecondary,
                            ),
                            onPressed: onNavigateDown,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : isSearchingCache
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.secondary,
                          ),
                        ),
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
