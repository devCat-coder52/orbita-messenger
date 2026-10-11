const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/auth');
const User = require('../models/User');
const logger = require('../utils/logger');
const asyncHandler = require('../utils/asyncHandler');

router.get('/all', asyncHandler(async (req, res) => {
  const users = await User.getAll();
  res.status(200).json(users);
}));

router.get('/:userId', asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.userId);
  if (!user) {
    const error = new Error('Пользователь не найден');
    error.statusCode = 404;
    throw error;
  }
  res.status(200).json(user);
}));

router.get('/:userId/public-key', asyncHandler(async (req, res) => {
  const key = await User.getPublicKey(req.params.userId);
  res.status(200).json({ public_key: key });
}));

router.post('/public-key', asyncHandler(async (req, res) => {
  await User.updatePublicKey(req.userId, req.body.public_key);
  logger.info('Публичный ключ обновлен', { userId: req.userId });
  res.status(200).json({ success: true });
}));

router.post('/update-fcm-token', asyncHandler(async (req, res) => {
  const { fcm_token } = req.body;
  await User.updateFCMtoken(req.userId, fcm_token);
  logger.info('FCM token updated', { userId: req.userId });
  res.status(200).json({ message: 'Token updated' });
}));

module.exports = router;