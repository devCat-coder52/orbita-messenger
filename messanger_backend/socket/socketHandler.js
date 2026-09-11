const socketIo = require('socket.io');
const Message = require('../models/Message');
const pool = require('../db');
const logger = require('../utils/logger');

let io;

function initSocketIO(server, allowedOrigins) {
  io = socketIo(server, {
    cors: {
      origin: function(origin, callback) {
        if (!origin || allowedOrigins.includes(origin)) {
          callback(null, true);
        } else {
          console.log('Blocked by CORS:', origin);
          callback(new Error('Not allowed by CORS'));
        }
      },
      methods: ['GET', 'POST'],
      credentials: true,
    }
  });

  setupSocketMiddleware();
  registerSocketEvents();

  return io;
}

function setupSocketMiddleware() {
  io.use((socket, next) => {
    next();
  });
}

function registerSocketEvents() {
  io.on('connection', (socket) => {
    handleConnection(socket);
  });
}

function handleConnection(socket) {
  logger.info(`Client connected: ${socket.id}`);

  socket.on('user_connected', async (userId) => {
    await handleUserConnected(socket, userId);
  });

  socket.on('disconnect', async () => {
    await handleDisconnect(socket);
  });

  socket.on('join_chat', (chatId) => {
    handleJoinChat(socket, chatId);
  });

  socket.on('leave_chat', (chatId) => {
    handleLeaveChat(socket, chatId);
  });

  socket.on('send_message', async (data) => {
    await handleSendMessage(socket, data);
  });

  socket.on('edit_message', async ({ message_id, content }) => {
    await handleEditMessage(socket, message_id, content);
  });

  socket.on('delete_message', async ({ message_id, chat_id, user_id }) => {
    await handleDeleteMessage(socket, message_id, chat_id, user_id);
  });

  socket.on('mark_as_read', async ({ chat_id, user_id }) => {
    await handleMarkAsRead(socket, chat_id, user_id);
  });

  socket.on('typing', async (data) => {
    await handleTyping(socket, data);
  });
}

async function handleUserConnected(socket, userId) {
  try {
    socket.userId = userId;
    logger.info(`User ${userId} онлайн`);

    await pool.query(
      'UPDATE users SET is_online = true, last_seen = NOW() WHERE id = $1',
      [userId]
    );

    const chats = await pool.query(
      'SELECT chat_id FROM user_chats WHERE user_id = $1',
      [userId]
    );

    for (const row of chats.rows) {
      socket.join(row.chat_id.toString());
      io.to(row.chat_id.toString()).emit('user_status_changed', {
        userId,
        status: 'online',
        last_seen: new Date().toISOString()
      });
    }
  } catch (error) {
    logger.error('Ошибка при подключении пользователя:', { error, userId });
  }
}

async function handleDisconnect(socket) {
  try {
    const userId = socket.userId;
    logger.info(`User ${userId} оффлайн`);

    if (userId) {
      await pool.query(
        'UPDATE users SET is_online = false, last_seen = NOW() WHERE id = $1',
        [userId]
      );

      const chats = await pool.query(
        'SELECT chat_id FROM user_chats WHERE user_id = $1',
        [userId]
      );

      for (const row of chats.rows) {
        io.to(row.chat_id.toString()).emit('user_status_changed', {
          userId,
          status: 'offline',
          last_seen: new Date().toISOString()
        });
      }
    }
  } catch (error) {
    logger.error('Ошибка при отключении пользователя:', { error, userId: socket.userId });
  }
}

function handleJoinChat(socket, chatId) {
  socket.join(chatId.toString());
  logger.info(`User ${socket.userId} joined chat ${chatId}`);
}

function handleLeaveChat(socket, chatId) {
  socket.leave(chatId.toString());
  logger.info(`User ${socket.userId} left chat ${chatId}`);
}

async function handleSendMessage(socket, data) {
  const { chat_id, user_name, content, time_create } = data;
  const sender_id = socket.userId;

  try {
    const message = await Message.add({ chat_id, sender_id, content, time_create });

    io.to(chat_id.toString()).emit('receive_message', message);

    const participants = await pool.query(
      'SELECT user_id FROM user_chats WHERE chat_id = $1 AND user_id != $2',
      [chat_id, sender_id]
    );

    for (const p of participants.rows) {
      const socketsInRoom = await io.in(chat_id.toString()).fetchSockets();
      const isInRoom = socketsInRoom.some(s => s.userId === p.user_id);

      if (!isInRoom) {
        const { sendPushNotification } = await import('./socketService.js');
        await sendPushNotification(p.user_id, chat_id, user_name, content);
      }
    }
  } catch (error) {
    logger.error('Ошибка отправки сообщения:', { error, chat_id, sender_id });
  }
}

async function handleEditMessage(socket, message_id, content) {
  try {
    const updatedMessage = await Message.update({ message_id, content });
    if (updatedMessage) {
      io.emit('message_edited', updatedMessage);
    }
  } catch (error) {
    logger.error('Ошибка редактирования сообщения:', { error, message_id });
  }
}

async function handleDeleteMessage(socket, message_id, chat_id, user_id) {
  try {
    await Message.delete({ message_id, user_id });
    if (!user_id) {
      io.to(chat_id.toString()).emit('message_deleted', {
        message_id,
        chat_id
      });
    }
  } catch (error) {
    logger.error('Ошибка удаления сообщения:', { error, message_id, chat_id });
  }
}

async function handleMarkAsRead(socket, chat_id, user_id) {
  try {
    await Message.read({ chat_id, user_id });
    io.to(chat_id.toString()).emit('message_status_updated', { chat_id, updated_by: user_id });
  } catch (error) {
    logger.error('Ошибка отметки прочитанных:', { error, chat_id, user_id });
  }
}

async function handleTyping(socket, data) {
  const { chat_id, user_name, is_typing } = data;
  try {
    socket.to(chat_id.toString()).emit('user_typing', {
      chat_id,
      user_name,
      is_typing,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Ошибка статуса набора текста:', { error, chat_id });
  }
}

function getIO() {
  if (!io) {
    throw new Error('Socket.IO не инициализирован. Вызовите initSocketIO() первым.');
  }
  return io;
}

module.exports = {
  initSocketIO,
  getIO
};
