import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/error_dialog.dart';

class SearchMessagesScreen extends StatefulWidget {
  final int chatId;

  const SearchMessagesScreen({required this.chatId, super.key});
  @override
  SearchMessagesScreenState createState() => SearchMessagesScreenState();
}

class SearchMessagesScreenState extends State<SearchMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> allMessages = [];
  List<Map<String, dynamic>> filteredMessages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _searchController.addListener(_onSearchChanged);
  }

  void _loadMessages() async {
    try {
      final messages = await ChatService.fetchMessages(widget.chatId);
      setState(() {
        allMessages = messages;
        filteredMessages = allMessages;
      });
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(
        context,
        'SeacrhMessagesScreen: Ошибка загрузки сообщений: $e',
      );
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredMessages = allMessages
          .where((msg) => msg['content'].toLowerCase().contains(query))
          .toList();
    });
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
        title: Text('Поиск сообщений'),
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
      body: filteredMessages.isEmpty
          ? Center(child: Text('Нет подходящих сообщений'))
          : ListView.builder(
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                var msg = filteredMessages[index];
                return ListTile(
                  title: Text(msg['content']),
                  subtitle: Text(msg['sender_name'] ?? 'Неизвестный'),
                );
              },
            ),
    );
  }
}
