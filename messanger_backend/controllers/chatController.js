const chatService = require('../services/chatService');
const logger = require('../utils/logger');

exports.getChats = async (req, res) => {
  const queryString = req.query.query;
  const myId = req.userId;
  try {
    const chats = await chatService.getUserChats(myId, queryString);
    logger.info('Get chats', { userId: myId });
    return res.status(201).json(chats);
  } catch (error) {
    logger.error('Get chats error', { error, userId: myId });
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

exports.deleteChat = async (req, res) => {
  const { chat_id } = req.body;
  const myId = req.userId;

  try {
    const chatId = await chatService.deleteChat(chat_id, myId);
    logger.info('Chat deleted:', { chatId, deletedUserId: myId });
    return res.status(201).json({ success: true });
  } catch(error) {
    logger.error('Delete chats error:', { error, chatId: chat_id, myId });
    if (error.statusCode) {
      return res.status(error.statusCode).json({ error: `Ошибка удаления чатов: ${error.message}` });
    }
    return res.status(500).json({ error: `Ошибка удаления чатов: ${error}` });
  }
}

exports.togglePin = async (req, res) => {
  const { chat_id } = req.body;
  const myId = req.userId;

  try {
    const chat = await chatService.togglePinChat(chat_id, myId);
    logger.info('Chat pin toggled:', { chatId: chat_id, userId: myId, isPinned: chat.is_pinned });
    return res.status(201).json({ success: true });
  } catch (error) {
    logger.error('Toggle pin error:', { error, chatId: chat_id, myId });
    if (error.statusCode) {
      return res.status(error.statusCode).json({ error: `Ошибка закрепления чата: ${error.message}` });
    }
    return res.status(500).json({ error: `Ошибка закрепления чата: ${error}` });
  }
};