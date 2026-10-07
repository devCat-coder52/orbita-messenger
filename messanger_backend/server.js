const express = require('express');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const morgan = require('morgan');
const http = require('http');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chat');
const profileRoutes = require('./routes/profile');
const userRoutes = require('./routes/users');
const authenticateToken = require('./middleware/auth');
const errorHandler = require('./middleware/errorHandler');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const logger = require('./utils/logger');
const Message = require('./models/Message');
const { initSocketIO, getIO } = require('./socket/socketHandler');
const { sendPushNotification } = require('./socket/socketService');
const pool = require('./db');
require('dotenv').config();

if (process.env.FIREBASE_PROJECT_ID && fs.existsSync('./serviceAccountKey.json')) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.cert(serviceAccount)
  });
  console.log('Firebase initialized');
} else {
  console.log('Firebase not configured (local development mode)');
}

const app = express();
const server = http.createServer(app);

app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
}));

app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) }
}));

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['http://localhost:3000', 'http://192.168.0.6:3000'];

initSocketIO(server, allowedOrigins);

const uploadsDir = path.join(__dirname, 'uploads');
const messagesDir = path.join(uploadsDir, 'messages');
const filesDir = path.join(uploadsDir, 'files');
const voicesDir = path.join(uploadsDir, 'voices');

if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}
if (!fs.existsSync(messagesDir)) {
  fs.mkdirSync(messagesDir, { recursive: true });
}
if (!fs.existsSync(filesDir)) {
  fs.mkdirSync(filesDir, { recursive: true });
}
if (!fs.existsSync(voicesDir)) {
  fs.mkdirSync(voicesDir, { recursive: true });
}

const diskStorageOptions = (dir) => ({
  destination: (req, file, cb) => {
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1E9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

const storage = multer.diskStorage(diskStorageOptions(messagesDir));

app.use(cors({
  origin: function(origin, callback) {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      console.log('Blocked by CORS:', origin);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500,
  message: { error: 'Слишком много запросов, попробуйте позже' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api', generalLimiter);
app.use('/api/auth', authRoutes);
app.use('/api/chat', authenticateToken, chatRoutes);
app.use('/api/users', authenticateToken, userRoutes);
app.use('/api/profile', authenticateToken, profileRoutes);
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const io = getIO();

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  logger.info(`Server running on port ${PORT}`);
});

app.use(errorHandler);

const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Только изображения разрешены'), false);
  }
}

const anyFileFilter = (req, file, cb) => cb(null, true);

const voiceFilter = (req, file, cb) => {
  const allowedVoiceTypes = [
    'audio/mp4',
    'audio/mpeg4',
    'audio/x-m4a',
    'audio/aac',
    'audio/mp4a-latm',
    'audio/webm',
    'audio/ogg',
    'audio/opus',
    'audio/wav',
    'audio/x-wav',
    'audio/amr',
    'audio/3gpp',
  ];
  const ext = path.extname(file.originalname || '').toLowerCase();
  const allowedExt = ['.m4a', '.aac', '.webm', '.ogg', '.opus', '.wav', '.amr', '.mp3'];
  if (file.mimetype.startsWith('audio/') ||
      allowedVoiceTypes.includes(file.mimetype) ||
      allowedExt.includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error('Разрешены только аудиофайлы'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 } // 5 МБ
})

const fileUpload = multer({
  storage: multer.diskStorage(diskStorageOptions(filesDir)),
  fileFilter: anyFileFilter,
  limits: { fileSize: 20 * 1024 * 1024 } // 20 МБ
})

const voiceUpload = multer({
  storage: multer.diskStorage(diskStorageOptions(voicesDir)),
  fileFilter: voiceFilter,
  limits: { fileSize: 10 * 1024 * 1024 } // 10 МБ
})

app.post('/api/chat/:chatId/image', authenticateToken, upload.single('image'), async (req, res) => {
  const chatId = req.params.chatId;
  const senderId = req.userId;
  const timeCreate = req.body.time_create;

  if (!req.file) {
    return res.status(400).json({ error: 'Файл не загружен' });
  }

  try {
    const imageUrl = `/uploads/messages/${req.file.filename}`;

    const message = await Message.add({
      chat_id: chatId,
      sender_id: senderId,
      content: '',
      source_user_id: null,
      image_url: imageUrl,
      time_create: timeCreate
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
    logger.error('Ошибка сохранения сообщения с изображением:', { error, chatId, senderId });
    res.status(500).json({ error: `Ошибка сохранения сообщения: ${error}` });
  }
});

app.post('/api/chat/:chatId/file', authenticateToken, fileUpload.single('file'), async (req, res) => {
  const chatId = req.params.chatId;
  const senderId = req.userId;
  const timeCreate = req.body.time_create;

  if (!req.file) {
    return res.status(400).json({ error: 'Файл не загружен' });
  }

  try {
    const fileUrl = `/uploads/files/${req.file.filename}`;
    const fileName = req.body.file_name || req.file.originalname;
    const fileSize = req.file.size;

    const message = await Message.add({
      chat_id: chatId,
      sender_id: senderId,
      content: '',
      source_user_id: null,
      file_url: fileUrl,
      file_name: fileName,
      file_size: fileSize,
      time_create: timeCreate
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
          `[Файл] ${fileName}`
        );
      }
    }
    res.status(201).json(message);
  } catch (error) {
    logger.error('Ошибка сохранения сообщения с файлом:', { error, chatId, senderId });
    res.status(500).json({ error: `Ошибка сохранения сообщения: ${error}` });
  }
});

app.post('/api/chat/:chatId/voice', authenticateToken, voiceUpload.single('voice'), async (req, res) => {
  const chatId = req.params.chatId;
  const senderId = req.userId;
  const timeCreate = req.body.time_create;
  const duration = parseInt(req.body.duration) || 0;

  if (!req.file) {
    return res.status(400).json({ error: 'Файл не загружен' });
  }

  try {
    const voiceUrl = `/uploads/voices/${req.file.filename}`;

    const message = await Message.add({
      chat_id: chatId,
      sender_id: senderId,
      content: '',
      source_user_id: null,
      voice_url: voiceUrl,
      voice_duration: duration,
      time_create: timeCreate
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
          '[Голосовое сообщение]'
        );
      }
    }
    res.status(201).json(message);
  } catch (error) {
    logger.error('Ошибка сохранения голосового сообщения:', { error, chatId, senderId });
    res.status(500).json({ error: `Ошибка сохранения сообщения: ${error}` });
  }
});

app.use((req, res, next) => {
  const error = new Error('Маршрут не найден');
  error.statusCode = 404;
  next(error);
});