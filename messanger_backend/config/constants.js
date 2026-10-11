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

  SOCKET_EVENTS: {
    RECEIVE_MESSAGE: 'receive_message',
    MESSAGE_EDITED: 'message_edited',
    MESSAGE_DELETED: 'message_deleted',
    MESSAGE_STATUS_UPDATED: 'message_status_updated',
    USER_TYPING: 'user_typing',
    USER_STATUS_CHANGED: 'user_status_changed',
  },
};