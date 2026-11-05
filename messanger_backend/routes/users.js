const express = require('express');
const router = express.Router();
const User = require('../models/User');
const logger = require('../utils/logger');
const asyncHandler = require('../utils/asyncHandler');
const validateId = require('../middleware/validateId');

router.get('/:userId', validateId('userId'), asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.userId);
  if (!user) {
    const error = new Error('Пользователь не найден');
    error.statusCode = 404;
    throw error;
  }
  res.status(200).json(user);
}));

router.get('/:userId/public-key', validateId('userId'), asyncHandler(async (req, res) => {
  const key = await User.getPublicKey(req.params.userId);
  res.status(200).json({ public_key: key });
}));

router.post('/public-key', asyncHandler(async (req, res) => {
  const publicKey = req.body.public_key;
  if (typeof publicKey !== 'string' || publicKey.length < 16 || publicKey.length > 4096) {
    const error = new Error('Некорректный публичный ключ');
    error.statusCode = 400;
    throw error;
  }

  await User.updatePublicKey(req.userId, publicKey);
  logger.info('Публичный ключ обновлен', { userId: req.userId });
  res.status(200).json({ success: true });
}));

router.post('/update-fcm-token', asyncHandler(async (req, res) => {
  const { fcm_token: fcmToken } = req.body;
  if (typeof fcmToken !== 'string' || fcmToken.length > 4096) {
    const error = new Error('Некорректный токен');
    error.statusCode = 400;
    throw error;
  }

  await User.updateFCMtoken(req.userId, fcmToken);
  logger.info('FCM token updated', { userId: req.userId });
  res.status(200).json({ message: 'Token updated' });
}));

module.exports = router;
