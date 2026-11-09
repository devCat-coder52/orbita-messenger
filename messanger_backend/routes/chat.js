const express = require('express');
const router = express.Router();
const { getChats, getMessages, getUserInfo, createChat, deleteChat, togglePin, toggleMute } = require('../controllers/chatController');

router.get('/all', getChats);
router.get('/:chatId/messages', getMessages);
router.get('/:chatId/info', getUserInfo);
router.post('/create', createChat);
router.post('/delete', deleteChat);
router.post('/toggle-pin', togglePin);
router.post('/toggle-mute', toggleMute);

module.exports = router;
