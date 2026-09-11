const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/auth');
const User = require('../models/User');
const Chat = require('../models/Chat');
const logger = require('../utils/logger');

router.get('/all', authenticateToken, async (req, res) => {
  try {
    const users = await User.getAll();
    res.status(201).json(users);
  } catch (error) {
    const message = 'Ошибка получения списка пользователей';
    logger.error(message, { error, userId: req.userId });
    res.status(500).json({ error: `${message}: ${error}` });
  }
});

router.get('/:userId', authenticateToken, async (req, res) => {
  const { userId } = req.params;
  try {
    const user = await User.findById(userId);
    if (user) {
      res.status(201).json(user);
    } else {
      res.status(404).json({ error: 'Пользователь не найден' });
    }
  } catch (error) {
    const message = 'Ошибка поиска пользователя по ID';
    logger.error(message, { error, userId: req.params.userId });
    res.status(500).json({ error: `${message}: ${error}` });
  }
});

router.get('/:userId/public-key', authenticateToken, async (req, res) => {
  try {
    const key = await User.getPublicKey(req.params.userId);
    res.status(201).json({ public_key: key });
  } catch (error) {
    const message = 'Ошибка получения публичного ключа';
    logger.error(message, { error, userId: req.params.userId });
    res.status(500).json({ error: `${message}: ${error}` });
  }
});

router.post('/public-key', authenticateToken, async (req, res) => {
  try {
    await User.updatePublicKey(req.userId, req.body.public_key);
    logger.info('Публичный код обновлен', { userId: req.userId });
    res.status(201).json({ success: true });
  } catch (error) {
    const message = 'Ошибка обновления публичного ключа';
    logger.error(message, { error, userId: req.userId });
    res.status(500).json({ error: `${message}: ${error}` });
  }
  await User.updatePublicKey(req.userId, req.body.public_key);
  res.json({ success: true });
});

router.post('/update-fcm-token', authenticateToken, async (req, res) => {
  const { fcm_token } = req.body;
  const userId = req.userId;

  try {
    await User.updateFcmToken
    await pool.query(
      'UPDATE users SET fcm_token = $1 WHERE id = $2',
      [fcm_token, userId]
    );
    logger.info('FCM token updated', { userId });
    res.status(200).json({ message: 'Token updated' });
  } catch (error) {
    logger.error('Error updating FCM token:', { error, userId });
    res.status(500).json({ error: 'Failed to update token' });
  }
});

module.exports = router;