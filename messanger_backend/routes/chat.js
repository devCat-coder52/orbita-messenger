const express = require('express');
const router = express.Router();
const { getChats, getMessages } = require('../controllers/chatController');
const authenticateToken = require('../middleware/auth');

router.get('/', authenticateToken, getChats);
router.get('/:chatId/messages', authenticateToken, getMessages);

module.exports = router;