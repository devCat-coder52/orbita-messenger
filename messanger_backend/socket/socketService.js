const pool = require('../db');
const config = require('../config/env');
const logger = require('../utils/logger');
const { getMessaging } = require('firebase-admin/messaging');

/**
 * Абсолютный URL для FCM: сервер хранит относительные пути вида
 * /uploads/messages/images/..., а push-сервис умеет загружать только полные.
 * Если PUBLIC_BASE_URL не задан, картинку в уведомление не добавляем.
 */
function absoluteMediaUrl(relativeUrl) {
  if (!relativeUrl) return null;
  if (/^https?:\/\//i.test(relativeUrl)) return relativeUrl;
  if (!config.publicBaseUrl) return null;
  return `${config.publicBaseUrl}${relativeUrl.startsWith('/') ? '' : '/'}${relativeUrl}`;
}

/**
 * Отправка push-уведомления пользователю
 * @param {number} userId - ID пользователя
 * @param {number} chatId - ID чата
 * @param {string} senderName - Имя отправителя
 * @param {string} body - Текст сообщения
 * @param {string|null} imageUrl - URL изображения (опционально)
 */

async function sendPushNotification(
  userId,
  chatId,
  senderName,
  body,
  imageUrl = null,
  avatarUrl = null
) {
  try {
    const userResult = await pool.query(
      'SELECT fcm_token FROM users WHERE id = $1',
      [userId]
    );
    const token = userResult.rows[0]?.fcm_token;

    if (!token) {
      logger.debug(`Токен для пользователя ${userId} не найден`);
      return;
    }

    const image = absoluteMediaUrl(imageUrl);
    const avatar = absoluteMediaUrl(avatarUrl);

    const message = {
      notification: {
        title: senderName,
        body: imageUrl ? 'Фотография' : body,
      },
      data: {
        chat_id: String(chatId),
        sender_name: senderName,
        image_url: image || '',
        // Аватар отправителя: клиент может использовать его для
        // уведомления в стиле Telegram (крупная иконка).
        sender_avatar_url: avatar || '',
      },
      token: token,
      android: {
        priority: 'high',
        collapseKey: `chat_${chatId}`,
        notification: {
          tag: `chat_${chatId}`,
          // Фото сообщения — как большая картинка; если фото нет,
          // показываем аватар отправителя.
          ...((image || avatar) ? { image: image || avatar } : {}),
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            'mutable-content': 1,
            'thread-id': `chat_${chatId}`,
          },
        },
      },
    };

    const response = await getMessaging().send(message);
    logger.debug('Успешно отправлено уведомление', { userId });
  } catch (error) {
    if (isUnregisteredTokenError(error)) {
      await clearFcmToken(userId);
      return;
    }

    logger.error('Ошибка отправки уведомления', {
      error: error.message,
      userId,
    });
  }
}

function isUnregisteredTokenError(error) {
  const code = error?.code || error?.errorInfo?.code || '';
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/invalid-argument'
  );
}

async function clearFcmToken(userId) {
  try {
    await pool.query('UPDATE users SET fcm_token = NULL WHERE id = $1', [userId]);
    logger.warn('FCM-токен устарел и удалён', { userId });
  } catch (error) {
    logger.error('Не удалось очистить FCM-токен', {
      error: error.message,
      userId,
    });
  }
}

module.exports = {
  sendPushNotification,
  absoluteMediaUrl,
};
