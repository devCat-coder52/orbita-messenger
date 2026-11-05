const Chat = require('../models/Chat');

/**
 * Проверяет доступ к чату ДО multer.
 *
 * Раньше цепочка была `multer -> контроллер -> Chat.checkAccess`, то есть файл
 * уже лежал на диске, когда выяснялось, что пользователь не участник чата:
 * любой авторизованный мог заливать файлы в чужой чат и забивать диск.
 */
async function requireChatAccess(req, res, next) {
  try {
    if (!req.userId) {
      return res.status(401).json({ success: false, error: 'Access denied' });
    }

    const chatId = Number(req.params.chatId);
    if (!Number.isInteger(chatId) || chatId <= 0) {
      return res.status(400).json({ success: false, error: 'Некорректный chat_id' });
    }

    const access = await Chat.checkAccess(chatId, req.userId);
    if (!access) {
      return res.status(403).json({ success: false, error: 'Чат недоступен' });
    }

    req.chatId = chatId;
    return next();
  } catch (error) {
    return next(error);
  }
}

module.exports = requireChatAccess;
