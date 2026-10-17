const socketIo = require('socket.io');
const Message = require('../models/Message');
const pool = require('../db');
const logger = require('../utils/logger');
const { socketAuthMiddleware } = require('./socketAuth');
const { sendPushNotification } = require('./socketService');
const {
  SOCKET_EVENTS,
  SOCKET_MSG_RATE_LIMIT,
  SOCKET_RATE_WINDOW_MS,
  SOCKET_TYPING_RATE_LIMIT,
  MESSAGE_MAX_LENGTH,
} = require('../config/constants');

let io;

function createRateLimiter(limit, windowMs) {
  const buckets = new WeakMap();
  return function allow(socket) {
    const now = Date.now();
    let hits = buckets.get(socket);
    if (!hits) {
      hits = [];
      buckets.set(socket, hits);
    }
    while (hits.length && now - hits[0] > windowMs) hits.shift();
    if (hits.length >= limit) return false;
    hits.push(now);
    return true;
  };
}

function toRoom(chatId) {
  const id = Number(chatId);
  if (!Number.isInteger(id) || id <= 0) return null;
  return id.toString();
}

async function getUserChatIds(userId) {
  const res = await pool.query(
    'SELECT chat_id FROM user_chats WHERE user_id = $1',
    [userId]
  );
  return res.rows.map((r) => r.chat_id.toString());
}

async function isMemberOfChat(userId, chatId) {
  const res = await pool.query(
    'SELECT 1 FROM user_chats WHERE user_id = $1 AND chat_id = $2',
    [userId, chatId]
  );
  return res.rowCount > 0;
}

async function hasOtherActiveSockets(userId, exceptSocketId) {
  try {
    const sockets = await io.in(`user_${userId}`).fetchSockets();
    return sockets.some((s) => s.id !== exceptSocketId);
  } catch {
    return false;
  }
}

async function isActivelyViewingChat(userId, room) {
  try {
    const userSockets = await io.in(`user_${userId}`).fetchSockets();
    if (!userSockets.some((s) => s.rooms.has(room))) return false;
    const roomSockets = await io.in(room).fetchSockets();
    return roomSockets.some((s) => s.userId === userId && !s.disconnected);
  } catch {
    return false;
  }
}

function initSocketIO(server, allowedOrigins) {
  io = socketIo(server, {
    cors: {
      origin: (origin, callback) => {
        if (!origin || allowedOrigins.includes(origin)) {
          callback(null, true);
        } else {
          logger.warn('Socket blocked by CORS', { origin });
          callback(new Error('Not allowed by CORS'));
        }
      },
      methods: ['GET', 'POST'],
      credentials: true,
    },
    pingInterval: 25000,
    pingTimeout: 20000,
    connectionStateRecovery: {}, // восстановление сессий после обрывов связи
    maxHttpBufferSize: 1e6,
  });

  socketAuthMiddleware(io);

  io.on('connection', (socket) => handleConnection(socket));
  io.on('error', (err) => logger.error('Socket.IO server error', { error: err }));
  
  return io;
}

const messageLimiter = createRateLimiter(SOCKET_MSG_RATE_LIMIT, SOCKET_RATE_WINDOW_MS);
const typingLimiter = createRateLimiter(SOCKET_TYPING_RATE_LIMIT, SOCKET_RATE_WINDOW_MS);

function handleConnection(socket) {
  logger.info(`Client connected: ${socket.id}, user: ${socket.userId}`);

  socket.join(`user_${socket.userId}`);

  getUserChatIds(socket.userId)
    .then((chatIds) => {
      for (const room of chatIds) socket.join(room);
      broadcastStatus(socket.userId, 'online');
    })
    .catch((error) =>
      logger.error('Ошибка автовступления в чаты', { error, userId: socket.userId })
    );

  socket.on('disconnect', () => handleDisconnect(socket));
  socket.on('error', (error) =>
    logger.error('Socket error', { error, socketId: socket.id, userId: socket.userId })
  );
  socket.on('join_chat', (chatId) => handleJoinChat(socket, chatId));
  socket.on('leave_chat', (chatId) => handleLeaveChat(socket, chatId));
  socket.on('send_message', (data, cb) => handleSendMessage(socket, data, cb));
  socket.on('edit_message', (data, cb) => handleEditMessage(socket, data, cb));
  socket.on('delete_message', (data, cb) => handleDeleteMessage(socket, data, cb));
  socket.on('mark_as_read', (data, cb) => handleMarkAsRead(socket, data, cb));
  socket.on('typing', (data) => handleTyping(socket, data));
}

async function broadcastStatus(userId, status) {
  try {
    await pool.query(
      'UPDATE users SET is_online = $2, last_seen = NOW() WHERE id = $1',
      [userId, status === 'online']
    );
    const chats = await getUserChatIds(userId);
    const payload = { userId, status, last_seen: new Date().toISOString() };
    for (const room of chats) {
      io.to(room).emit('user_status_changed', payload);
    }
  } catch (error) {
    logger.error('Ошибка смены статуса', { error, userId, status });
  }
}

async function handleDisconnect(socket) {
  const userId = socket.userId;
  if (!userId) return;

  try {
    const remaining = await hasOtherActiveSockets(userId, socket.id);
    if (!remaining) {
      await broadcastStatus(userId, 'offline');
    }
    logger.info(`User ${userId} disconnected (socket ${socket.id})`);
  } catch (error) {
    logger.error('Ошибка при отключении пользователя', { error, userId });
  }
}

async function handleJoinChat(socket, chatId) {
  const room = toRoom(chatId);
  if (!room) return;
  if (!(await isMemberOfChat(socket.userId, room))) {
    logger.warn('join_chat denied: not a member', { userId: socket.userId, chatId });
    return;
  }
  socket.join(room);
  logger.info(`User ${socket.userId} joined chat ${chatId}`);
}

async function handleLeaveChat(socket, chatId) {
  const room = toRoom(chatId);
  if (!room) return;
  socket.leave(room);
  logger.info(`User ${socket.userId} left chat ${chatId}`);
}

async function handleSendMessage(socket, data, ack) {
  const done = (payload) => {
    if (typeof ack === 'function') ack(payload);
  };

  try {
    if (!messageLimiter(socket)) {
      return done({ status: 'error', error: 'TOO_MANY_MESSAGES' });
    }

    const {
      chat_id, content, reply, forward,
      image_url, file_url, file_name, file_size,
      voice_url, voice_duration, time_create,
    } = data || {};

    const room = toRoom(chat_id);
    if (!room) return done({ status: 'error', error: 'INVALID_CHAT_ID' });

    const sender_id = socket.userId;

    if (!(await isMemberOfChat(sender_id, room))) {
      logger.warn('send_message denied: not a member', { sender_id, chat_id });
      return done({ status: 'error', error: 'NOT_A_MEMBER' });
    }

    const hasAttachment = !!(image_url || file_url || voice_url);
    const text = typeof content === 'string' ? content.trim() : '';
    if (!text && !hasAttachment) {
      return done({ status: 'error', error: 'EMPTY_MESSAGE' });
    }
    if (text.length > MESSAGE_MAX_LENGTH) {
      return done({ status: 'error', error: 'MESSAGE_TOO_LONG' });
    }
    if (file_name != null && String(file_name).length > 255) {
      return done({ status: 'error', error: 'INVALID_FILE_NAME' });
    }

    const message = await Message.add({
      chat_id,
      sender_id,
      content: text,
      reply_msg_id: reply?.id ?? null,
      source_user_id: forward?.id ?? null,
      time_create,
      image_url, file_url, file_name, file_size, voice_url, voice_duration,
    });

    const senderRes = await pool.query(
      `SELECT u.id, COALESCE(ui.nick_name, u.login) AS name, ui.avatar_url
         FROM users u LEFT JOIN user_info ui ON ui.user_id = u.id
        WHERE u.id = $1`,
      [sender_id]
    );
    message.sender = senderRes.rows[0];
    message.forward = forward ?? null;

    if (message.reply_to_message_id != null) {
      const replyRes = await pool.query(
        `SELECT json_build_object(
            'id', mr.id,
            'sender', json_build_object(
              'id', mr.sender_id,
              'name', COALESCE(ui2.nick_name, u2.login),
              'avatar_url', ui2.avatar_url
            ),
            'content', mr.content,
            'image_url', mr.image_url,
            'file_url', mr.file_url,
            'file_name', mr.file_name,
            'voice_url', mr.voice_url,
            'time_create', mr.time_create::text
          ) AS reply
          FROM messages mr
          JOIN users u2 ON u2.id = mr.sender_id
          LEFT JOIN user_info ui2 ON ui2.user_id = u2.id
          WHERE mr.id = $1`,
        [message.reply_to_message_id]
      );
      message.reply = replyRes.rows[0]?.reply ?? null;
    } else {
      message.reply = null;
    }

    io.to(room).emit(SOCKET_EVENTS.MESSAGE_ADDED, message);
    done({ status: 'ok', message_id: message.id, time_create: message.time_create });

    const participants = await pool.query(
      'SELECT user_id FROM user_chats WHERE chat_id = $1 AND user_id != $2',
      [chat_id, sender_id]
    );
    const viewStatuses = await Promise.all(
      participants.rows.map(async (p) => ({
        user_id: p.user_id,
        viewing: await isActivelyViewingChat(p.user_id, room),
      }))
    );
    const viewers = new Set(
      viewStatuses.filter((v) => v.viewing).map((v) => v.user_id)
    );

    const pushes = participants.rows
      .filter((p) => !viewers.has(p.user_id))
      .map((p) =>
        sendPushNotification(
          p.user_id,
          chat_id,
          message.sender?.name,
          text || (voice_url ? 'Голосовое сообщение' : ''),
          image_url || null
        ).catch((e) => logger.error('Push failed', { error: e, userId: p.user_id }))
      );
    await Promise.allSettled(pushes);
  } catch (error) {
    logger.error('Ошибка отправки сообщения', { error, data });
    done({ status: 'error', error: 'INTERNAL_ERROR' });
  }
}

async function handleEditMessage(socket, data, ack) {
  const done = (payload) => {
    if (typeof ack === 'function') ack(payload);
  };

  try {
    const { message_id, content } = data || {};
    const text = typeof content === 'string' ? content.trim() : '';
    if (!text || text.length > MESSAGE_MAX_LENGTH) {
      return done({ status: 'error', error: 'INVALID_CONTENT' });
    }

    const msgRes = await pool.query('SELECT * FROM messages WHERE id = $1', [message_id]);
    const original = msgRes.rows[0];
    if (!original) return done({ status: 'error', error: 'MESSAGE_NOT_FOUND' });
    if (original.sender_id !== socket.userId) {
      logger.warn('edit_message denied: not an author', {
        userId: socket.userId,
        message_id,
      });
      return done({ status: 'error', error: 'FORBIDDEN' });
    }

    const updatedMessage = await Message.update({ message_id, content: text });
    if (!updatedMessage) return done({ status: 'error', error: 'UPDATE_FAILED' });

    io.to(original.chat_id.toString()).emit(SOCKET_EVENTS.MESSAGE_EDITED, updatedMessage);
    done({ status: 'ok' });
  } catch (error) {
    logger.error('Ошибка редактирования сообщения', { error, data });
    done({ status: 'error', error: 'INTERNAL_ERROR' });
  }
}

async function handleDeleteMessage(socket, data, ack) {
  const done = (payload) => {
    if (typeof ack === 'function') ack(payload);
  };

  try {
    const { message_id, chat_id, is_local } = data || {};
    const room = toRoom(chat_id);
    if (!room) return done({ status: 'error', error: 'INVALID_CHAT_ID' });

    const msgRes = await pool.query('SELECT * FROM messages WHERE id = $1', [message_id]);
    const original = msgRes.rows[0];
    if (!original) return done({ status: 'error', error: 'MESSAGE_NOT_FOUND' });
    if (!(await isMemberOfChat(socket.userId, room))) {
      return done({ status: 'error', error: 'FORBIDDEN' });
    }

    console.log(is_local);
    await Message.delete({ message_id, user_id: is_local ? socket.userId : null });

    if (is_local) {
      socket.emit(SOCKET_EVENTS.MESSAGE_DELETED, {
        message_id,
        chat_id,
        deleted_for_user_id: socket.userId,
      });
    } else {
      io.to(room).emit(SOCKET_EVENTS.MESSAGE_DELETED, {
        message_id,
        chat_id,
        deleted_for_user_id: null,
      });
    }
    done({ status: 'ok' });
  } catch (error) {
    logger.error('Ошибка удаления сообщения', { error, data });
    done({ status: 'error', error: 'INTERNAL_ERROR' });
  }
}

async function handleMarkAsRead(socket, data, ack) {
  const done = (payload) => {
    if (typeof ack === 'function') ack(payload);
  };

  try {
    const { chat_id } = data || {};
    const room = toRoom(chat_id);
    if (!room) return done({ status: 'error', error: 'INVALID_CHAT_ID' });
    if (!(await isMemberOfChat(socket.userId, room))) {
      return done({ status: 'error', error: 'FORBIDDEN' });
    }

    const updated = await Message.read({ chat_id, user_id: socket.userId });
    if (!updated) return done({ status: 'ok', changed: false });
    io.to(room).emit(SOCKET_EVENTS.MESSAGE_STATUS_UPDATED, {
      chat_id,
      updated_by: socket.userId,
    });
    done({ status: 'ok', changed: true });
  } catch (error) {
    logger.error('Ошибка отметки прочитанных', { error, data });
    done({ status: 'error', error: 'INTERNAL_ERROR' });
  }
}

function handleTyping(socket, data) {
  if (!typingLimiter(socket)) return;

  const { chat_id, is_typing } = data || {};
  const room = toRoom(chat_id);
  if (!room) return;
  if (!socket.rooms.has(room)) return;

  socket.to(room).emit(SOCKET_EVENTS.USER_TYPING, {
    chat_id,
    user_id: socket.userId,
    is_typing: !!is_typing,
    timestamp: new Date().toISOString(),
  });
}

function getIO() {
  if (!io) {
    throw new Error('Socket.IO не инициализирован. Вызовите initSocketIO() первым.');
  }
  return io;
}

module.exports = {
  initSocketIO,
  getIO,
};
