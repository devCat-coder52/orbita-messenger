const Chat = require('../models/Chat');
const Message = require('../models/Message');
const User = require('../models/User');
const logger = require('../utils/logger');

class ChatService {

  async getUserChats(userId, searchQuery = '') {
    const chats = await Chat.getUserChats(userId, searchQuery);
    return chats;
  }

  async getMessages(chatId, userId, limit = 50, offset = 0) {
    const result = await Message.getByChatId(chatId, userId, limit, offset);
    return result;
  }

  async getChatUserInfo(chatId, userId) {
    const users = await User.findByChat(chatId, userId);

    if (users.length === 0) {
      const error = new Error('Пользователь не обнаружен в чате!');
      error.statusCode = 404;
      throw error;
    }

    return users[0];
  }

  async createChat(userId, myId) {
    if (!userId) {
      const error = new Error('Отсутствует user_id');
      error.statusCode = 400;
      throw error;
    }
    if (userId === myId) {
      const error = new Error('Нельзя создать чат с самим собой');
      error.statusCode = 400;
      throw error;
    }
    const targetUser = await User.findById(userId);
    if (!targetUser) {
      const error = new Error('Пользователь не найден');
      error.statusCode = 404;
      throw error;
    }

    const existingChat = await Chat.findPrivateChat(myId, userId);
    if (existingChat) {
      return existingChat.id;
    }
      
    const chatId = await Chat.create({ name: '', creator_id: myId });
    await Chat.addUserToChat(chatId, myId);
    await Chat.addUserToChat(chatId, userId);
        
    return chatId;
  }
}

module.exports = new ChatService();