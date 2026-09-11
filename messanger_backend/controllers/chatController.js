const chatService = require('../services/chatService');
const logger = require('../utils/logger');

exports.getChats = async (req, res) => {
  const queryString = req.query.query;
  try {
    const chats = await chatService.getUserChats(req.userId, queryString);
    logger.info('Get chats', { userId: req.userId });
    return res.status(201).json(chats);
  } catch (error) {
    logger.error('Get chats error', { error, userId: req.userId });
    return res.status(500).json({ error: `Ошибка получения чатов: ${error}` });
  }
};

exports.getMessages = async (req, res) => {
  const { chatId } = req.params;
  const myId = req.userId;
  const limit = parseInt(req.query.limit) || 50;
  const offset = parseInt(req.query.offset) || 0;
  try {
    const messages = await chatService.getMessages(chatId, myId, limit, offset);
    logger.info('Get messages', { chatId, userId: req.userId });
    return res.status(201).json(messages);
  } catch (error) {
    logger.error('Get messages error', { error, chatId, userId: req.userId });
    return res.status(500).json({ error: `Ошибка получения сообщений: ${error}` });
  }
};

exports.getUserInfo = async (req, res) => {
  const { chatId } = req.params;
  const myId = req.userId;

  try {
    const info = await chatService.getChatUserInfo(chatId, myId);
    logger.info('Get chat info:', { chatId, userId: req.userId });
    return res.status(201).json(info);
  } catch (error) {
    logger.error('Get chat info error:', { error, chatId, userId: req.userId });
    if (error.statusCode) {
      return res.status(error.statusCode).json({ error: `Ошибка получения информации о чате: ${error.message}` });
    }
    return res.status(500).json({ error: `Ошибка получения информации о чате: ${error}` });
  }
};

exports.createChat = async (req, res) => {
  const { user_id } = req.body;
  const myId = req.userId;

  try {
    const chatId = await chatService.createChat(user_id, myId);
    logger.info('Chat created:', { chatId, createdUserId: myId, userId: user_id });
    return res.status(201).json({ chat_id: chatId });
  } catch (error) {
    logger.error('Create chat error:', { error, createdUserId: myId, userId: user_id });
    if (error.statusCode) {
      return res.status(error.statusCode).json({ error: `Ошибка создания чата: ${error.message}` });
    }
    return res.status(500).json({ error: `Ошибка создания чата: ${error}` });

  }
}