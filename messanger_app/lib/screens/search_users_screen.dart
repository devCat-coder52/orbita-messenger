import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import 'chat_screen.dart';
import '../widgets/error_dialog.dart';

class SearchChatsScreen extends StatefulWidget {
  const SearchChatsScreen({super.key});
  @override
  SearchChatsScreenState createState() => SearchChatsScreenState();
}

class SearchChatsScreenState extends State<SearchChatsScreen> {
  List<Map<String, dynamic>> chats = [];
  List<User> allUsers = [];
  List<User> usersWithChats = [];
  List<User> usersWithoutChats = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadInitialData() async {
    try {
      final fetchedChats = await ChatService.fetchChats();
      final fetchedUsers = await UserService.getAllUsers();

      setState(() {
        chats = fetchedChats;
        allUsers = fetchedUsers;
      });

      _updateFilteredLists('');
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, 'SearchUserScreen: Ошибка загрузки: $e');
    }
  }

  void _updateFilteredLists(String query) {
    if (query.length < 3) {
      setState(() {
        usersWithChats = [];
        usersWithoutChats = [];
      });
      return;
    }

    final lowerQuery = query.toLowerCase();

    // Пользователи, с которыми уже есть чат (падение)
    usersWithChats = allUsers.where((u) {
      final hasChat = chats.any((c) => c['user_id'] == u.id);
      return hasChat && u.login.toLowerCase().contains(lowerQuery);
    }).toList();

    // Пользователи, с которыми нет чата (только полное совпадение)
    usersWithoutChats = allUsers.where((u) {
      final hasChat = chats.any((c) => c['user_id'] == u.id);
      return !hasChat &&
          u.login.toLowerCase() == lowerQuery; // полное совпадение
    }).toList();

    setState(() {});
  }

  void _onSearchChanged() {
    _updateFilteredLists(_searchController.text);
  }

  void _openOrCreateChat(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userId: user.id,
          userName: user.name ?? user.login,
          userAvatar: user.avatarUrl,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Поиск чатов'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.0),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
              ),
            ),
          ),
        ),
      ),
      body: usersWithChats.isEmpty && usersWithoutChats.isEmpty
          ? Center(child: Text('Нет подходящих чатов'))
          : ListView(
              children: [
                if (usersWithChats.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'С кем уже есть чат',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  ...usersWithChats.map(
                    (user) => ListTile(
                      leading: CircleAvatar(child: Text(user.login[0])),
                      title: Text(user.login),
                      onTap: () => _openOrCreateChat(user),
                    ),
                  ),
                ],
                if (usersWithoutChats.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'С кем нет чата',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  ...usersWithoutChats.map(
                    (user) => ListTile(
                      leading: CircleAvatar(child: Text(user.login[0])),
                      title: Text(user.login),
                      subtitle: Text('Новый чат'),
                      onTap: () => _openOrCreateChat(user),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
