const pool = require('../db');
const logger = require('../utils/logger');
const admin = require('firebase-admin');
const { getMessaging } = require('firebase-admin/messaging');

/**
 * Отправка push-уведомления пользователю
 * @param {number} userId - ID пользователя
 * @param {number} chatId - ID чата
 * @param {string} senderName - Имя отправителя
 * @param {string} body - Текст сообщения
 * @param {string|null} imageUrl - URL изображения (опционально)
 */

async function sendPushNotification(userId, chatId, senderName, body, imageUrl = null) {
  try {
    const userResult = await pool.query(
      'SELECT fcm_token FROM users WHERE id = $1',
      [userId]
    );
    const token = userResult.rows[0]?.fcm_token;

    if (!token) {
      logger.info(`Токен для пользователя ${userId} не найден`);
      return;
    }

    const message = {
      notification: {
        title: senderName,
        body: imageUrl ? 'Фотография' : body,
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
    logger.info('Успешно отправлено уведомление', { response, userId });

  } catch (error) {
    logger.error('Ошибка отправки уведомления', { error, userId });
  }
}

module.exports = {
  sendPushNotification
};
