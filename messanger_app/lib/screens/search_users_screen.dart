import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';
import '../models/user.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import '../widgets/error_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SearchChatsScreen extends StatefulWidget {
  const SearchChatsScreen({super.key});
  @override
  SearchChatsScreenState createState() => SearchChatsScreenState();
}

class SearchChatsScreenState extends State<SearchChatsScreen> {
  List<Chat> chats = [];
  List<User> allUsers = [];
  List<User> usersWithChats = [];
  List<User> usersWithoutChats = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _updateFilteredLists(String query) async {
    try {
      final fetchedChats = await ChatService.fetchChats(query);
      final myPrivateKey = await KeyStorageService.getPrivateKey();
      for (var chat in fetchedChats) {
        if (chat.messageText != null) {
          String content = chat.messageText!;
          if (chat.messageIsEncrypted == true && myPrivateKey != null) {
            try {
              content = CryptoService.decryptMessage(content, myPrivateKey);
            } catch (e) {
              content = '[Ошибка чтения]';
            }
          }
          chat.messageText = content;
        }
      }
      setState(() {
        chats = fetchedChats;
      });
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, 'SearchUserScreen: Ошибка загрузки: $e');
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 3) {
      _updateFilteredLists(_searchController.text);
    } else {
      setState(() {
        chats.length = 0;
      });
    }
  }

  void _openOrCreateChat(Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userId: chat.userId,
          userName: chat.userName,
          userAvatar: chat.avatarUrl,
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
      body: chats.isEmpty
          ? Center(
              child: Text(
                'Нет подходящих чатов',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                Chat chat = chats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: chat.avatarUrl != null
                        ? NetworkImage(
                            '${dotenv.env['BASE_URL']}/${chat.avatarUrl!}',
                          )
                        : null,
                    child: chat.avatarUrl == null
                        ? Text(chat.userName[0].toUpperCase())
                        : null,
                  ),
                  title: Text(
                    chat.userName,
                    style: TextStyle(
                      fontWeight: chat.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.messageText ?? "Написать сообщение...",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: chat.unreadCount > 0
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (chat.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => _openOrCreateChat(chat),
                );
              },
            ),
    );
  }
}
