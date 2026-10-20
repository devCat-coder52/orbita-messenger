const chatService = require('../services/chatService');
const logger = require('../utils/logger');
const asyncHandler = require('../utils/asyncHandler');
const { deleteMediaFiles } = require('../services/mediaService');

exports.getChats = asyncHandler(async (req, res) => {
  const queryString = req.query.query;
  const myId = req.userId;

  const chats = await chatService.getUserChats(myId, queryString);
  logger.info('Get chats', { userId: myId });
  return res.status(200).json(chats);
});

exports.getMessages = asyncHandler(async (req, res) => {
  const { chatId } = req.params;
  const myId = req.userId;
  const limit = parseInt(req.query.limit, 10) || 50;
  const offset = parseInt(req.query.offset, 10) || 0;

  const messages = await chatService.getMessages(chatId, myId, limit, offset);
  logger.info('Get messages', { chatId, userId: myId });
  return res.status(200).json(messages);
});

exports.getUserInfo = asyncHandler(async (req, res) => {
  const { chatId } = req.params;
  const myId = req.userId;

  const info = await chatService.getChatUserInfo(chatId, myId);
  logger.info('Get chat info:', { chatId, userId: myId });
  return res.status(200).json(info);
});

exports.createChat = asyncHandler(async (req, res) => {
  const { user_id } = req.body;
  const myId = req.userId;

  const chatId = await chatService.createChat(user_id, myId);
  logger.info('Chat created:', { chatId, createdUserId: myId, userId: user_id });
  return res.status(201).json({ chat_id: chatId });
});

exports.deleteChat = asyncHandler(async (req, res) => {
  const { chat_id } = req.body;
  const myId = req.userId;

  const media = await chatService.deleteAllMessages(chat_id);
  const chatId = await chatService.deleteChat(chat_id, myId);
  if (media.length > 0) {
    await deleteMediaFiles(media);
  }
  logger.info('Chat deleted:', { chatId, deletedUserId: myId });
  return res.status(200).json({ success: true });
});

exports.togglePin = asyncHandler(async (req, res) => {
  const { chat_id } = req.body;
  const myId = req.userId;

  const chat = await chatService.togglePinChat(chat_id, myId);
  logger.info('Chat pin toggled:', { chatId: chat_id, userId: myId, isPinned: chat.is_pinned });
  return res.status(200).json({ success: true });
});