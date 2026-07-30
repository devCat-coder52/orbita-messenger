const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chat');
const profileRoutes = require('./routes/profile');
const userRoutes = require('./routes/users');
const Message = require('./models/Message');
const authenticateToken = require('./middleware/auth');
const admin = require('firebase-admin');
const fs = require('fs');
const serviceAccount = require('./serviceAccountKey.json');
const pool = require('./db');
const { getMessaging } = require('firebase-admin/messaging');
const multer = require('multer');

admin.initializeApp({
  credential: admin.cert(serviceAccount)
});

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
    credentials: true,
  }
});

const storage = multer.diskStorage({
  destination: './uploads/messages/',
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1E9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/auth', authRoutes);
app.use('/api/chat', authenticateToken, chatRoutes);
app.use('/api/users', authenticateToken, userRoutes);
app.use('/api/profile', profileRoutes);

io.use((socket, next) => {
  next();
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('user_connected', async (userId) => {
    socket.userId = userId;
    console.log('User', userId, 'онлайн');
    await pool.query('UPDATE users SET is_online = true, last_seen = NOW() WHERE id = $1', [userId]);
    const chats = await pool.query('SELECT chat_id FROM user_chats WHERE user_id = $1', [userId]);
    for (const row of chats.rows) {
      io.to(row.chat_id.toString()).emit('user_status_changed', { userId, status: 'online', last_seen: new Date().toISOString() });
    }
  });

  socket.on('disconnect', async () => {
    const userId = socket.userId;
    console.log('User', userId, 'оффлайн');
    if (userId) {
      await pool.query('UPDATE users SET is_online = false, last_seen = NOW() WHERE id = $1', [userId]);
      const chats = await pool.query('SELECT chat_id FROM user_chats WHERE user_id = $1', [userId]);
      for (const row of chats.rows) {
        io.to(row.chat_id.toString()).emit('user_status_changed', { 
          userId, status: 'offline', last_seen: new Date().toISOString() 
        });
      }
    }
  });

  // 2. КОМНАТЫ ЧАТОВ
  socket.on('join_chat', (chatId) => {
    socket.join(chatId.toString());
    console.log(`User ${socket.userId} joined chat ${chatId}`);
  });

  // 3. СООБЩЕНИЯ
  socket.on('send_message', async (data) => {
    const { chat_id, user_name, content, created_at } = data;
    const sender_id = socket.userId;
    
    try {
      const message = await Message.add({ chat_id, sender_id, content, createdAt: created_at });
      
      io.to(chat_id.toString()).emit('receive_message', message);

      const participants = await pool.query(
        'SELECT user_id FROM user_chats WHERE chat_id = $1 AND user_id != $2', 
        [chat_id, sender_id]
      );
      
      for (const p of participants.rows) {
        const socketsInRoom = await io.in(chat_id.toString()).fetchSockets();
        const isInRoom = socketsInRoom.some(s => s.userId === p.user_id);
        
        if (!isInRoom) {
          await sendPushNotification(p.user_id, chat_id, user_name, content);
        }
      }
    } catch (err) { console.error(err); }
  });

  // 4. ПРОЧТЕНИЕ
  socket.on('mark_as_read', async ({ chat_id, user_id }) => {
    await Message.read({ chat_id, user_id });
    io.to(chat_id.toString()).emit('message_status_updated', { chat_id, updated_by: user_id });
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});

const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

async function sendPushNotification(userId, chatId, senderName, body, imageUrl = null) {
  try {
    const userResult = await pool.query('SELECT fcm_token FROM users WHERE id = $1', [userId]);
    const token = userResult.rows[0]?.fcm_token;

    if (!token) {
      console.log(`Токен для пользователя ${userId} не найден`);
      return;
    }

    const message = {
      notification: {
        title: senderName,
        body: imageUrl ? '[Фотография]' : body,
      },
      data: {
        chat_id: chatId.toString(),
        sender_name: senderName,
        image_url: imageUrl || '', 
      },
      token: token,
      android: {
        priority: 'high',
        notification: {
          image: imageUrl, 
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            'mutable-content': 1,
          },
        },
      },
    };

    const response = await getMessaging().send(message);
    console.log('Успешно отправлено уведомление:', response);
    
  } catch (error) {
    console.error('Ошибка отправки уведомления:', error);
  }
}

const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Только изображения разрешены'), false);
  }
}

const upload = multer({ 
  storage, 
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }
})

app.post('/api/users/update-fcm-token', async (req, res) => {
  const { user_id, fcm_token } = req.body;
  
  try {
    await pool.query(
      'UPDATE users SET fcm_token = $1 WHERE id = $2',
      [fcm_token, user_id]
    );
    res.status(200).json({ message: 'Token updated' });
  } catch (error) {
    console.error('Error updating FCM token:', error);
    res.status(500).json({ error: 'Failed to update token' });
  }
});

app.post('/api/chat/:chatId/image', authenticateToken, upload.single('image'), async (req, res) => {
  const chatId = req.params.chatId;
  const senderId = req.userId;
  const createdAt = req.body.created_at;
  
  if (!req.file) {
    return res.status(400).json({ error: 'Файл не загружен' });
  }

  try {
    const imageUrl = `/uploads/messages/${req.file.filename}`;
    
    const message = await Message.add({
      chat_id: chatId,
      sender_id: senderId,
      content: '',
      image_url: imageUrl,
      createdAt: createdAt
    });

    io.to(chatId.toString()).emit('receive_message', message);

    const participants = await pool.query(
        'SELECT user_id FROM user_chats WHERE chat_id = $1 AND user_id != $2', 
        [chatId, senderId]
      );
      
    for (const p of participants.rows) {
      const socketsInRoom = await io.in(chatId.toString()).fetchSockets();
      const isInRoom = socketsInRoom.some(s => s.userId === p.user_id);
        
      if (!isInRoom) {
        await sendPushNotification(
          p.user_id, 
          chatId, 
          'Инкогнито', 
          '[Фотография]', 
          imageUrl
        );
      }
    }
    res.status(201).json(message);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Ошибка сохранения сообщения' });
  }
});