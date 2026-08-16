const express = require('express');
const router = express.Router();
const { getChats, getMessages, getUserInfo } = require('../controllers/chatController');
const authenticateToken = require('../middleware/auth');

router.get('/', authenticateToken, getChats);
router.get('/:chatId/messages', authenticateToken, getMessages);
router.get('/:chatId/info',authenticateToken, getUserInfo);

module.exports = router;