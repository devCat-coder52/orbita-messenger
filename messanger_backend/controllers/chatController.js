const chatService = require('../services/chatService');
const logger = require('../utils/logger');
const asyncHandler = require('../utils/asyncHandler');
const { deleteMediaFiles } = require('../services/mediaService');
const { getIO } = require('../socket/socketHandler');
const { SOCKET_EVENTS } = require('../config/constants');

exports.getChats = asyncHandler(async (req, res) => {
  const queryString = req.query.query;
  const myId = req.userId;

  const chats = await chatService.getUserChats(myId, queryString);
  logger.debug('Get chats', { userId: myId });
  return res.status(200).json(chats);
});

exports.getMessages = asyncHandler(async (req, res) => {
  const { chatId } = req.params;
  const myId = req.userId;
  const limit = parseInt(req.query.limit, 10) || 50;
  const offset = parseInt(req.query.offset, 10) || 0;

  const messages = await chatService.getMessages(chatId, myId, limit, offset);
  logger.debug('Get messages', { chatId, userId: myId });
  return res.status(200).json(messages);
});

exports.getUserInfo = asyncHandler(async (req, res) => {
  const { chatId } = req.params;
  const myId = req.userId;

  const info = await chatService.getChatUserInfo(chatId, myId);
  logger.debug('Get chat info:', { chatId, userId: myId });
  return res.status(200).json(info);
});

exports.createChat = asyncHandler(async (req, res) => {
  const { user_id } = req.body;
  const myId = req.userId;

  const chatId = await chatService.createChat(user_id, myId);
  logger.debug('Chat created:', { chatId, createdUserId: myId, userId: user_id });

  try {
    const io = getIO();
    const room = String(chatId);
    // Оба собеседника должны сразу получать события нового чата,
    // даже если он создан уже после их подключения.
    io.in(`user_${user_id}`).socketsJoin(room);
    io.in(`user_${myId}`).socketsJoin(room);
    io.to(`user_${user_id}`)
      .to(`user_${myId}`)
      .emit(SOCKET_EVENTS.CHAT_CREATED, { chat_id: chatId, created_by: myId });
  } catch (error) {
    logger.warn('Не удалось разослать chat_created', { error, chatId });
  }

  return res.status(201).json({ chat_id: chatId });
});

exports.deleteChat = asyncHandler(async (req, res) => {
  const { chat_id } = req.body;
  const myId = req.userId;

  const { media, memberIds } = await chatService.deleteChatForEveryone(
    chat_id,
    myId
  );

  if (media.length > 0) {
    await deleteMediaFiles(media);
  }
  logger.debug('Chat deleted for everyone:', { chatId: chat_id, userId: myId });

  try {
    const io = getIO();
    const room = String(chat_id);

    // Чат исчезает у обоих участников: событие — в комнату чата и в личные
    // комнаты всех участников (включая их другие устройства).
    let target = io.to(room);
    for (const memberId of memberIds) {
      target = target.to(`user_${memberId}`);
    }
    target.emit(SOCKET_EVENTS.CHAT_DELETED, {
      chat_id,
      deleted_by: myId,
    });

    io.in(room).socketsLeave(room);
  } catch (error) {
    logger.warn('Не удалось разослать chat_deleted', {
      error,
      chatId: chat_id,
    });
  }

  return res.status(200).json({ success: true });
});

exports.togglePin = asyncHandler(async (req, res) => {
  const { chat_id } = req.body;
  const myId = req.userId;

  const chat = await chatService.togglePinChat(chat_id, myId);
  logger.debug('Chat pin toggled:', { chatId: chat_id, userId: myId, isPinned: chat.is_pinned });
  return res.status(200).json({ success: true });
});

exports.toggleMute = asyncHandler(async (req, res) => {
  const { chat_id } = req.body;
  const myId = req.userId;

  const chat = await chatService.toggleMuteChat(chat_id, myId);
  logger.debug('Chat mute toggled:', { chatId: chat_id, userId: myId, isMuted: chat.is_muted });
  return res.status(200).json({ success: true, is_muted: chat.is_muted });
});