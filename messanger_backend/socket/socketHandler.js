const socketIo = require('socket.io');
const Message = require('../models/Message');
const pool = require('../db');
const logger = require('../utils/logger');
const { socketAuthMiddleware } = require('./socketAuth');
const {
  createRateLimiter,
  selectPushRecipients,
  isAllowedAttachmentUrl,
  buildPushBody,
} = require('./socketUtils');
const { sendPushNotification } = require('./socketService');
const { deleteMediaFiles } = require('../services/mediaService');
const {
  SOCKET_EVENTS,
  SOCKET_MSG_RATE_LIMIT,
  SOCKET_RATE_WINDOW_MS,
  SOCKET_TYPING_RATE_LIMIT,
  MESSAGE_MAX_LENGTH,
} = require('../config/constants');

let io;


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

/**
 * Смотрит ли человек именно в этот чат прямо сейчас.
 *
 * Вступление в комнату чата значит только «получаю события списка»: клиент
 * состоит во всех своих чатах с момента подключения. Поэтому «открыт экран»
 * отмечается отдельно — событиями enter_chat/exit_chat.
 */
async function isActivelyViewingChat(userId, room) {
  try {
    const userSockets = await io.in(`user_${Number(userId)}`).fetchSockets();
    return userSockets.some(
      (s) => String(s.data?.viewingChatId ?? '') === String(room)
    );
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
    // Короткий обрыв: Socket.IO сам восстанавливает комнаты и досылает
    // пропущенные пакеты, клиенту не нужно проходить handshake заново.
    connectionStateRecovery: {
      maxDisconnectionDuration: 2 * 60 * 1000,
      skipMiddlewares: false,
    },
    maxHttpBufferSize: 1e6,
  });

  socketAuthMiddleware(io);

  io.on('connection', (socket) => handleConnection(socket));
  io.on('error', (err) => logger.error('Socket.IO server error', { error: err }));
  
  return io;
}

const messageLimiter = createRateLimiter(SOCKET_MSG_RATE_LIMIT, SOCKET_RATE_WINDOW_MS);
const typingLimiter = createRateLimiter(SOCKET_TYPING_RATE_LIMIT, SOCKET_RATE_WINDOW_MS);
// Общий лимит на служебные события: правка, удаление, прочтение, вступление.
const actionLimiter = createRateLimiter(60, SOCKET_RATE_WINDOW_MS);

function handleConnection(socket) {
  // После восстановления сессии мидлварь может не выполняться:
  // поднимаем пользователя из socket.data, куда его кладёт авторизация.
  if (socket.userId == null && socket.data?.userId != null) {
    socket.userId = socket.data.userId;
  }

  logger.debug(`Client connected: ${socket.id}, user: ${socket.userId}`);

  socket.join(`user_${socket.userId}`);
  socket.data.viewingChatId = null;

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
  socket.on('enter_chat', (chatId) => handleEnterChat(socket, chatId));
  socket.on('exit_chat', (chatId) => handleExitChat(socket, chatId));
}

async function broadcastStatus(userId, status) {
  try {
    // last_seen имеет смысл только для офлайна: пока человек в сети,
    // «был(а) недавно» не должно сдвигаться на текущий момент.
    if (status === 'online') {
      await pool.query('UPDATE users SET is_online = TRUE WHERE id = $1', [userId]);
    } else {
      await pool.query(
        'UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = $1',
        [userId]
      );
    }

    // Кто скрыл «в сети», не должен светиться и в событиях статуса.
    const privacy = await pool.query(
      'SELECT show_online FROM users WHERE id = $1',
      [userId]
    );
    if (privacy.rows[0]?.show_online === false) return;

    const chats = await getUserChatIds(userId);
    const lastSeen = status === 'online' ? null : new Date().toISOString();
    for (const room of chats) {
      io.to(room).emit('user_status_changed', {
        userId,
        status,
        last_seen: lastSeen,
        chat_id: Number(room),
      });
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
    logger.debug(`User ${userId} disconnected (socket ${socket.id})`);
  } catch (error) {
    logger.error('Ошибка при отключении пользователя', { error, userId });
  }
}

async function handleJoinChat(socket, chatId) {
  const room = toRoom(chatId);
  if (!room) return;
  if (!actionLimiter(socket)) return;
  if (!(await isMemberOfChat(socket.userId, room))) {
    logger.warn('join_chat denied: not a member', { userId: socket.userId, chatId });
    return;
  }
  socket.join(room);
  logger.debug(`User ${socket.userId} joined chat ${chatId}`);
}

async function handleLeaveChat(socket, chatId) {
  const room = toRoom(chatId);
  if (!room) return;
  socket.leave(room);
  if (String(socket.data.viewingChatId ?? '') === room) {
    socket.data.viewingChatId = null;
  }
  logger.debug(`User ${socket.userId} left chat ${chatId}`);
}

/** Клиент открыл экран чата: с этого момента push по нему не нужен. */
async function handleEnterChat(socket, chatId) {
  const room = toRoom(chatId);
  if (!room) return;
  if (!(await isMemberOfChat(socket.userId, room))) {
    logger.warn('enter_chat denied: not a member', {
      userId: socket.userId,
      chatId,
    });
    return;
  }
  socket.join(room);
  socket.data.viewingChatId = room;
}

/** Клиент закрыл экран чата: снова можно присылать push. */
function handleExitChat(socket, chatId) {
  const room = toRoom(chatId);
  if (!room) return;
  if (String(socket.data.viewingChatId ?? '') === room) {
    socket.data.viewingChatId = null;
  }
}

async function handleSendMessage(socket, data, ack) {
  // Ответ клиенту должен уйти ровно один раз: раньше сбой в блоке push
  // отправлял второй ack с ошибкой уже после успешного.
  let responded = false;
  const done = (payload) => {
    if (responded) return;
    responded = true;
    if (typeof ack === 'function') ack(payload);
  };

  try {
    if (!messageLimiter(socket)) {
      return done({ status: 'error', error: 'TOO_MANY_MESSAGES' });
    }

    const {
      chat_id, content, is_encrypted, reply, forward,
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

    // Чат с сервисным аккаунтом (id < 1) только для чтения.
    const partner = await pool.query(
      'SELECT user_id FROM user_chats WHERE chat_id = $1 AND user_id != $2 LIMIT 1',
      [chat_id, sender_id]
    );
    if (partner.rows[0] && Number(partner.rows[0].user_id) < 1) {
      return done({ status: 'error', error: 'SERVICE_CHAT' });
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

    // Ссылки на вложения принимаем только свои: внешняя ссылка — это трекинг
    // получателя, а произвольный путь — чужой файл.
    for (const [field, url] of [
      ['image_url', image_url],
      ['file_url', file_url],
      ['voice_url', voice_url],
    ]) {
      if (!isAllowedAttachmentUrl(field, url)) {
        return done({ status: 'error', error: 'INVALID_ATTACHMENT' });
      }
    }
    
    let replyMessageId = null;
    if (reply && reply.id != null) {
      replyMessageId = Number(reply.id);
      const replyRes = Number.isInteger(replyMessageId) && replyMessageId > 0
        ? await pool.query('SELECT chat_id FROM messages WHERE id = $1', [replyMessageId])
        : null;
      if (!replyRes || replyRes.rowCount === 0 || String(replyRes.rows[0].chat_id) !== room) {
        return done({ status: 'error', error: 'INVALID_REPLY' });
      }
    }

    let sourceUserId = null;
    let forwardPayload = null;
    if (forward && forward.id != null) {
      sourceUserId = Number(forward.id);
      const userRes = Number.isInteger(sourceUserId) && sourceUserId > 0
        ? await pool.query(
            `SELECT u.id, COALESCE(ui.nick_name, u.login) AS name, ui.avatar_url
               FROM users u LEFT JOIN user_info ui ON ui.user_id = u.id
              WHERE u.id = $1`,
            [sourceUserId]
          )
        : null;
      if (!userRes || userRes.rowCount === 0) {
        return done({ status: 'error', error: 'INVALID_FORWARD' });
      }

      // Подпись «переслано от» берём из БД: клиент может прислать
      // любые name/avatar_url, и получатель увидит подделку.
      forwardPayload = {
        id: sourceUserId,
        name: userRes.rows[0].name,
        avatar_url: userRes.rows[0].avatar_url ?? null,
      };
    }

    if (Number.isInteger(time_create)) {
      const existingRes = await pool.query(
        'SELECT * FROM messages WHERE chat_id = $1 AND sender_id = $2 AND time_create = $3 LIMIT 1',
        [Number(room), sender_id, time_create]
      );
      if (existingRes.rowCount > 0) {
        logger.warn('Duplicate send_message ignored', {
          sender_id,
          chat_id,
          time_create,
          existing_message_id: existingRes.rows[0].id,
        });
        return done({
          status: 'ok',
          message_id: existingRes.rows[0].id,
          time_create: existingRes.rows[0].time_create,
          duplicate: true,
        });
      }
    }

    const message = await Message.add({
      chat_id: Number(room),
      sender_id,
      content: text,
      is_encrypted: !!is_encrypted,
      reply_msg_id: replyMessageId,
      source_user_id: sourceUserId,
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
    message.forward = forwardPayload;

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
          WHERE mr.id = $1 AND mr.chat_id = $2`,
        [message.reply_to_message_id, Number(room)]
      );
      message.reply = replyRes.rows[0]?.reply ?? null;
    } else {
      message.reply = null;
    }

    io.to(room).emit(SOCKET_EVENTS.MESSAGE_ADDED, message);
    done({ status: 'ok', message_id: message.id, time_create: message.time_create });

    try {
      const participants = await pool.query(
      'SELECT user_id, is_muted FROM user_chats WHERE chat_id = $1 AND user_id != $2',
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

    const pushes = selectPushRecipients(participants.rows, viewers)
      .map((p) =>
        sendPushNotification(
          p.user_id,
          chat_id,
          message.sender?.name,
          buildPushBody({
            text,
            is_encrypted: !!is_encrypted,
            voice_url,
            image_url,
            file_url,
            file_name,
          }),
          image_url || null,
          message.sender?.avatar_url || null
        ).catch((e) => logger.error('Push failed', { error: e, userId: p.user_id }))
      );
      await Promise.allSettled(pushes);
    } catch (pushError) {
      logger.error('Не удалось разослать push', {
        error: pushError,
        chat_id,
      });
    }
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
    if (!actionLimiter(socket)) {
      return done({ status: 'error', error: 'TOO_MANY_EVENTS' });
    }

    const { message_id, content } = data || {};
    const text = typeof content === 'string' ? content.trim() : '';
    if (!text || text.length > MESSAGE_MAX_LENGTH) {
      return done({ status: 'error', error: 'INVALID_CONTENT' });
    }

    const msgRes = await pool.query('SELECT * FROM messages WHERE id = $1', [message_id]);
    const original = msgRes.rows[0];
    if (!original) return done({ status: 'error', error: 'MESSAGE_NOT_FOUND' });
    if (original.is_system) {
      return done({ status: 'error', error: 'SYSTEM_MESSAGE' });
    }
    if (!(await isMemberOfChat(socket.userId, original.chat_id.toString()))) {
      return done({ status: 'error', error: 'FORBIDDEN' });
    }
    if (Number(original.sender_id) !== socket.userId) {
      logger.warn('edit_message denied: not an author', {
        userId: socket.userId,
        message_id,
      });
      return done({ status: 'error', error: 'FORBIDDEN' });
    }
    // Фото, файлы и голосовые не редактируются: у них нет текста,
    // который можно заменить.
    if (original.image_url || original.file_url || original.voice_url) {
      logger.warn('edit_message denied: not a text message', {
        userId: socket.userId,
        message_id,
      });
      return done({ status: 'error', error: 'NOT_TEXT_MESSAGE' });
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
    if (!actionLimiter(socket)) {
      return done({ status: 'error', error: 'TOO_MANY_EVENTS' });
    }

    const { message_id, chat_id, is_local } = data || {};

    const msgRes = await pool.query('SELECT * FROM messages WHERE id = $1', [message_id]);
    const original = msgRes.rows[0];
    if (!original) return done({ status: 'error', error: 'MESSAGE_NOT_FOUND' });

    // Комнату берём из самого сообщения: иначе, зная id, можно трогать
    // сообщения чужих чатов, прикрываясь своим chat_id.
    const room = toRoom(original.chat_id);
    if (!room) return done({ status: 'error', error: 'INVALID_CHAT_ID' });
    if (chat_id != null && String(chat_id) !== room) {
      return done({ status: 'error', error: 'INVALID_CHAT_ID' });
    }
    if (!(await isMemberOfChat(socket.userId, room))) {
      return done({ status: 'error', error: 'FORBIDDEN' });
    }
    const sender_id = Number(original.sender_id);
    // «Удалить для всех» доступно только автору. Чужое сообщение
    // удаляется только у себя, даже если клиент прислал is_local = false.
    const deleteForEveryone = !is_local && sender_id === socket.userId;
    const row = await Message.delete({
      message_id,
      user_id: deleteForEveryone ? null : socket.userId,
    });
    if (row) {
      const mediaUrl = row.image_url || row.file_url || row.voice_url;
      if (mediaUrl) {
        const mediaUrls = {
          image: row.image_url ? [row.image_url] : null,
          file: row.file_url ? [row.file_url] : null,
          voice: row.voice_url ? [row.voice_url] : null
        }
        const deletedMedia = await Message.checkMedia(mediaUrls);
        await deleteMediaFiles(deletedMedia);
      }
    }

    if (deleteForEveryone) {
      io.to(room).emit(SOCKET_EVENTS.MESSAGE_DELETED, {
        message_id,
        chat_id,
        sender_id,
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
    if (!actionLimiter(socket)) {
      return done({ status: 'error', error: 'TOO_MANY_EVENTS' });
    }

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
  isActivelyViewingChat,
  // Экспортируются для тестов.
  selectPushRecipients,
  createRateLimiter,
};
