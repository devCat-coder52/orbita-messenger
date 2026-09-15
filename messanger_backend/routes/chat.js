const express = require('express');
const router = express.Router();
const { getChats, getMessages, getUserInfo, createChat, deleteChat, togglePin } = require('../controllers/chatController');
const authenticateToken = require('../middleware/auth');

router.get('/all', authenticateToken, getChats);
router.get('/:chatId/messages', authenticateToken, getMessages);
router.get('/:chatId/info',authenticateToken, getUserInfo);
router.post('/create', authenticateToken, createChat);
router.post('/delete', authenticateToken, deleteChat);
router.post('/toggle-pin', authenticateToken, togglePin);

module.exports = router;