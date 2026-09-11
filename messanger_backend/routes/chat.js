const express = require('express');
const router = express.Router();
const { getChats, getMessages, getUserInfo, createChat } = require('../controllers/chatController');
const authenticateToken = require('../middleware/auth');

router.get('/all', authenticateToken, getChats);
router.get('/:chatId/messages', authenticateToken, getMessages);
router.get('/:chatId/info',authenticateToken, getUserInfo);
router.post('/create', authenticateToken, createChat)

module.exports = router;