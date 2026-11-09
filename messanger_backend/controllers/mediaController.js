const Message = require('../models/Message');
const pool = require('../db');
const logger = require('../utils/logger');
const { getIO, isActivelyViewingChat } = require('../socket/socketHandler');
const { selectPushRecipients } = require('../socket/socketUtils');
const { sendPushNotification } = require('../socket/socketService');
const asyncHandler = require('../utils/asyncHandler');
const { SOCKET_EVENTS } = require('../config/constants');
const Chat = require('../models/Chat');

async function deliverMessage({ chatId, senderId, timeCreate, fields, notification }) {
  const io = getIO();

  const room = Number(chatId);
  if (!Number.isInteger(room) || room <= 0) {
    const error = new Error('Некорректный chat_id');
    error.statusCode = 400;
    throw error;
  }
  const access = await Chat.checkAccess(room, senderId);
  if (!access) {
    const error = new Error('Чат недоступен');
    error.statusCode = 403;
    throw error;
  }

  const parsedTime = Number(timeCreate);
  const safeTime =
    Number.isInteger(parsedTime) && parsedTime > 0 ? parsedTime : Date.now();

  const message = await Message.add({
    chat_id: room,
    sender_id: senderId,
    content: '',
    source_user_id: null,
    time_create: safeTime,
    ...fields,
  });

  const senderRes = await pool.query(
    `SELECT u.id, COALESCE(ui.nick_name, u.login) AS name, ui.avatar_url
        FROM users u LEFT JOIN user_info ui ON ui.user_id = u.id
      WHERE u.id = $1`,
    [senderId]
  );

  message.sender = senderRes.rows[0];

  io.to(room.toString()).emit(SOCKET_EVENTS.MESSAGE_ADDED, message);

  const participants = await pool.query(
    'SELECT user_id, is_muted FROM user_chats WHERE chat_id = $1 AND user_id != $2',
    [room, senderId]
  );

  const viewers = new Set();
  for (const participant of participants.rows) {
    if (await isActivelyViewingChat(participant.user_id, room.toString())) {
      viewers.add(participant.user_id);
    }
  }

  const pushes = selectPushRecipients(participants.rows, viewers)
    .map((participant) =>
      sendPushNotification(
        participant.user_id,
        room,
        message.sender?.name || notification.senderName || 'Orbita',
        notification.body,
        notification.imageUrl ?? null
      ).catch((error) =>
        logger.error('Push failed', { error: error.message, userId: participant.user_id })
      )
    );

  await Promise.allSettled(pushes);

  return message;
}

const requireFile = (req) => {
  if (!req.file) {
    const error = new Error('Файл не загружен');
    error.statusCode = 400;
    throw error;
  }
};

exports.sendImage = asyncHandler(async (req, res) => {
  requireFile(req);
  const { chatId } = req.params;
  const senderId = req.userId;
  const imageUrl = `/uploads/messages/images/${req.file.filename}`;

  const message = await deliverMessage({
    chatId,
    senderId,
    timeCreate: req.body.time_create,
    fields: { image_url: imageUrl },
    notification: { senderName: 'Инкогнито', body: '[Фотография]', imageUrl },
  });

  res.status(201).json(message);
});

exports.sendFile = asyncHandler(async (req, res) => {
  requireFile(req);
  const { chatId } = req.params;
  const senderId = req.userId;
  const fileUrl = `/uploads/messages/files/${req.file.filename}`;
  const fileName = req.body.file_name || req.file.originalname;

  const message = await deliverMessage({
    chatId,
    senderId,
    timeCreate: req.body.time_create,
    fields: { file_url: fileUrl, file_name: fileName, file_size: req.file.size },
    notification: { senderName: 'Инкогнито', body: `[Файл] ${fileName}` },
  });

  res.status(201).json(message);
});

exports.sendVoice = asyncHandler(async (req, res) => {
  requireFile(req);
  const { chatId } = req.params;
  const senderId = req.userId;
  const voiceUrl = `/uploads/messages/voices/${req.file.filename}`;
  const duration = parseInt(req.body.duration, 10) || 0;

  const message = await deliverMessage({
    chatId,
    senderId,
    timeCreate: req.body.time_create,
    fields: { voice_url: voiceUrl, voice_duration: duration },
    notification: { senderName: 'Инкогнито', body: '[Голосовое сообщение]' },
  });

  res.status(201).json(message);
});