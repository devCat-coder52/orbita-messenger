import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'search_users_screen.dart';
import 'profile_screen.dart';
import '../services/socket_service.dart';
import '../widgets/error_dialog.dart';
import '../widgets/online_indicator.dart';
import '../utils/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> chats = [];
  int? myId;

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  void _onReceiveMessage(dynamic data) {
    _loadChats();
  }

  Future<void> _initializeHome() async {
    final id = await AuthService.getUserId();
    if (!mounted) return;
    setState(() => myId = id);

    await SocketService.connectIfNotConnected();
    if (myId != null) {
      SocketService.emit('user_connected', myId!);
    }
    _loadChats();

    SocketService.onReceiveMessage(_onReceiveMessage);
    SocketService.onMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.onUserStatusChanged(_onUserStatusChanged);
  }

  void _onUserStatusChanged(dynamic data) {
    log.i('HomeScreen: вызываем _onUserStatusChanged $data');
    final userId = data['userId'];
    final status = data['status'];

    setState(() {
      for (var chat in chats) {
        if (chat['user_id'] == userId) {
          chat['is_online'] = status == 'online' ? true : false;
          break;
          //chat['last_seen'] = data['last_seen'] ?? chat['last_seen'];
        }
      }
    });
  }

  void _onMessageStatusUpdated(dynamic data) {
    final chatId = data['chat_id'];

    /*setState(() {
      final index = chats.indexWhere((c) => c['id'] == chatId);
      if (index != -1) {
        chats[index]['last_message_status'] = data['status'];

        /*if (chats[index]['unread_count'] > 0 && data['updated_by'] != myId) {
          // Логика обновления unread_count зависит от твоей структуры БД
        }*/
      }
    });*/
  }

  void _loadChats() async {
    try {
      final fetchedChats = await ChatService.fetchChats();
      setState(() {
        chats = fetchedChats;
      });
    } catch (e) {
      if (!mounted) return;
      ErrorDialog.show(context, 'HomeScreen: Ошибка загрузки чатов: $e');
    }
  }

  void _logout() async {
    SocketService.disconnect;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    final dateTime = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}.${dateTime.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Чаты'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchChatsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadChats();
        },
        child: chats.isEmpty
            ? Center(child: Text('Нет доступных чатов'))
            : ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  var chat = chats[index];
                  return ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          backgroundImage: chat['avatar_url'] != null
                              ? NetworkImage(
                                  '${dotenv.env['BASE_URL']}/${chat["avatar_url"]}',
                                )
                              : null,
                          child:
                              (chat['avatar_url'] == null ||
                                  chat['avatar_url']!.isEmpty)
                              ? Text(
                                  (chat['user_name'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: OnlineIndicator(
                            isOnline: chat['is_online'] == true,
                          ),
                        ),
                      ],
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // выравнивание по краям
                      children: [
                        Text(chat['user_name'] ?? chat['login']),
                        Text(
                          _formatTime(chat['last_message_time']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            (chat['last_message_sender_id'] == myId
                                    ? 'Вы: '
                                    : '') +
                                (chat['last_message_content'] ??
                                    'Нет сообщений'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        if (chat['unread_count'] != null &&
                            chat['unread_count']! > 0)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                chat['unread_count'].toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(chatId: chat['id']!),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  @override
  void dispose() {
    SocketService.offReceiveMessage(_onReceiveMessage);
    SocketService.offMessageStatusUpdated(_onMessageStatusUpdated);
    SocketService.offUserStatusChanged(_onUserStatusChanged);
    super.dispose();
  }
}
