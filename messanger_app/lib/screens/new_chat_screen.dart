import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/empty_state_hint.dart';
import '../widgets/error_dialog.dart';

import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Chat> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length <= 3) {
      setState(() {
        _results = [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final users = await ChatService.fetchChats(query);
      if (!mounted) return;
      setState(() {
        _results = users;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorDialog.show(
        context,
        'Не удалось выполнить поиск. Проверьте соединение и попробуйте ещё раз.',
        details: e,
      );
    }
  }

  void _openChat(Chat user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatScreen(userId: user.userId)),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый чат'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '@логин',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Очистить',
                        onPressed: _searchController.clear,
                      )
                    : null,
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
      body: _buildBody(t),
    );
  }

  Widget _buildBody(AppTokens t) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: t.secondary));
    }
    if (!_hasSearched) {
      return EmptyStateHint(
        icon: Icons.person_search,
        title: 'Кого ищем?',
        message:
            'Начните вводить логин — мы найдём пользователя '
            'и предложим начать диалог.',
      );
    }
    if (_results.isEmpty) {
      return EmptyStateHint(
        icon: Icons.person_off_outlined,
        title: 'Никого не нашлось',
        message:
            'Проверьте написание имени или логина. Возможно, пользователя '
            'ещё нет в системе.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 76, color: t.divider),
      itemBuilder: (context, index) {
        final user = _results[index];
        final displayName = user.userName;
        return Semantics(
          button: true,
          label: 'Написать $displayName',
          child: ListTile(
            leading: ChatAvatar(
              avatarUrl: user.avatarUrl,
              fallbackName: displayName,
            ),
            title: Text(displayName, style: TextStyle(color: t.textPrimary)),
            /*subtitle: Text(
              '@${user.login}',
              style: TextStyle(color: t.textSecondary),
            ),*/
            onTap: () => _openChat(user),
          ),
        );
      },
    );
  }
}
