const path = require('path');

const ONE_MB = 1024 * 1024;

module.exports = {
  UPLOADS_DIR: path.join(__dirname, '..', 'uploads'),
  MESSAGES_DIR: path.join(__dirname, '..', 'uploads', 'messages'),
  FILES_DIR: path.join(__dirname, '..', 'uploads', 'files'),
  VOICES_DIR: path.join(__dirname, '..', 'uploads', 'voices'),

  IMAGE_MAX_SIZE: 5 * ONE_MB,   // 5 МБ
  FILE_MAX_SIZE: 20 * ONE_MB,   // 20 МБ
  VOICE_MAX_SIZE: 10 * ONE_MB,  // 10 МБ

  RATE_LIMIT_WINDOW_MS: 15 * 60 * 1000,
  GENERAL_RATE_LIMIT_MAX: 500,
  AUTH_RATE_LIMIT_MAX: 10,

  VERIFY_CODE_TTL_SECONDS: 600,

  DEFAULT_ALLOWED_ORIGINS: ['http://localhost:3000'],
  JWT_SECRET: process.env.JWT_SECRET || 'your-local-dev-secret-key',

  SOCKET_MSG_RATE_LIMIT: 20,        // сообщений за окно
  SOCKET_RATE_WINDOW_MS: 10 * 1000, // окно 10 секунд
  SOCKET_TYPING_RATE_LIMIT: 15,     // событий "печатает" за окно
  MESSAGE_MAX_LENGTH: 4096,

  SOCKET_EVENTS: {
    MESSAGE_ADDED: 'message_added',
    MESSAGE_EDITED: 'message_edited',
    MESSAGE_DELETED: 'message_deleted',
    MESSAGE_STATUS_UPDATED: 'message_status_updated',
    USER_TYPING: 'user_typing',
  },
};