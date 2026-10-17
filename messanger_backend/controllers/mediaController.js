const Message = require('../models/Message');
const pool = require('../db');
const { getIO } = require('../socket/socketHandler');
const { sendPushNotification } = require('../socket/socketService');
const asyncHandler = require('../utils/asyncHandler');
const { SOCKET_EVENTS } = require('../config/constants');

async function deliverMessage({ chatId, senderId, timeCreate, fields, notification }) {
  const io = getIO();

  const message = await Message.add({
    chat_id: chatId,
    sender_id: senderId,
    content: '',
    source_user_id: null,
    time_create: timeCreate,
    ...fields,
  });

  io.to(chatId.toString()).emit(SOCKET_EVENTS.MESSAGE_ADDED, message);

  const participants = await pool.query(
    'SELECT user_id FROM user_chats WHERE chat_id = $1 AND user_id != $2',
    [chatId, senderId]
  );

  const socketsInRoom = await io.in(chatId.toString()).fetchSockets();

  for (const participant of participants.rows) {
    const isOnline = socketsInRoom.some((socket) => socket.userId === participant.user_id);
    if (!isOnline) {
      await sendPushNotification(
        participant.user_id,
        chatId,
        notification.senderName,
        notification.body,
        notification.imageUrl ?? null
      );
    }
  }

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
  const imageUrl = `/uploads/messages/${req.file.filename}`;

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
  const fileUrl = `/uploads/files/${req.file.filename}`;
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
  const voiceUrl = `/uploads/voices/${req.file.filename}`;
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