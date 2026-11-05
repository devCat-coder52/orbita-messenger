const Chat = require('../models/Chat');
const Message = require('../models/Message');
const User = require('../models/User');
const pool = require('../db');

class ChatService {

  async getUserChats(userId, searchQuery = '') {
    const chats = await Chat.getUserChats(userId, searchQuery);
    return chats;
  }

  async getMessages(chatId, userId, limit = 50, offset = 0) {
    const id = Number(chatId);
    if (!Number.isInteger(id) || id <= 0) {
      const error = new Error('Некорректный chat_id');
      error.statusCode = 400;
      throw error;
    }

    const access = await Chat.checkAccess(id, userId);
    if (!access) {
      const error = new Error('Чат недоступен');
      error.statusCode = 403;
      throw error;
    }

    const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
    const safeOffset = Math.max(Number(offset) || 0, 0);

    const result = await Message.getByChatId(id, userId, safeLimit, safeOffset);
    return result;
  }

  async getChatUserInfo(chatId, userId) {
    const id = Number(chatId);
    if (!Number.isInteger(id) || id <= 0) {
      const error = new Error('Некорректный chat_id');
      error.statusCode = 400;
      throw error;
    }

    const access = await Chat.checkAccess(id, userId);
    if (!access) {
      const error = new Error('Чат недоступен');
      error.statusCode = 403;
      throw error;
    }

    const users = await User.findByChat(id, userId);

    if (users.length === 0) {
      const error = new Error('Пользователь не обнаружен в чате!');
      error.statusCode = 404;
      throw error;
    }

    return users[0];
  }

  async createChat(userId, myId) {
    const targetId = Number(userId);
    const meId = Number(myId);

    if (!Number.isInteger(targetId) || targetId <= 0) {
      const error = new Error('Отсутствует user_id');
      error.statusCode = 400;
      throw error;
    }
    if (targetId === meId) {
      const error = new Error('Нельзя создать чат с самим собой');
      error.statusCode = 400;
      throw error;
    }
    const targetUser = await User.findById(targetId);
    if (!targetUser) {
      const error = new Error('Пользователь не найден');
      error.statusCode = 404;
      throw error;
    }

    const existingChat = await Chat.find(meId, targetId);
    if (existingChat) {
      return existingChat.id;
    }

    const chatId = await Chat.create({ name: '', creator_id: meId });
    await Chat.addUserToChat(chatId, meId);
    await Chat.addUserToChat(chatId, targetId);

    return chatId;
  }

  async leaveChat(chatId, userId) {
    const id = Number(chatId);
    const uid = Number(userId);

    if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(uid) || uid <= 0) {
      const error = new Error('Некорректные данные');
      error.statusCode = 400;
      throw error;
    }

    const chat = await Chat.checkAccess(id, uid);
    if (!chat) {
      const error = new Error('Чат недоступен или уже удален');
      error.statusCode = 403;
      throw error;
    }

    const orphanedRes = await pool.query(
      `DELETE FROM messages
        WHERE chat_id = $1
          AND del_for_user_id = $2
        RETURNING image_url, file_url, voice_url`,
      [id, uid]
    );

    await pool.query(
      'DELETE FROM user_chats WHERE chat_id = $1 AND user_id = $2',
      [id, uid]
    );

    const remainingRes = await pool.query(
      'SELECT 1 FROM user_chats WHERE chat_id = $1 LIMIT 1',
      [id]
    );
    let mediaUrls = [];
    if (remainingRes.rowCount === 0) {
      const deletedMsgs = await Chat.deleteAllMessages(id);
      await pool.query('DELETE FROM chats WHERE id = $1', [id]);
      mediaUrls = [...orphanedRes.rows, ...deletedMsgs];
    } else {
      mediaUrls = orphanedRes.rows;
    }

    if (mediaUrls.length > 0) {
      const urls = {
        image: mediaUrls.map((m) => m.image_url).filter(Boolean),
        file: mediaUrls.map((m) => m.file_url).filter(Boolean),
        voice: mediaUrls.map((m) => m.voice_url).filter(Boolean),
      };
      return Message.checkMedia(urls);
    }
    return [];
  }

  async togglePinChat(chatId, userId) {
    const id = Number(chatId);
    const uid = Number(userId);

    if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(uid) || uid <= 0) {
      const error = new Error('Некорректные данные');
      error.statusCode = 400;
      throw error;
    }

    const pinnedChat = await Chat.pin(id, uid);
    if (!pinnedChat) {
      const error = new Error('Чат недоступен или уже удален');
      error.statusCode = 403;
      throw error;
    }
    return pinnedChat;
  }
}

module.exports = new ChatService();