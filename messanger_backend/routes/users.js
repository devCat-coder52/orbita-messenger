const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/auth');
const User = require('../models/User');
const Chat = require('../models/Chat');

router.post('/create_chat', authenticateToken, async (req, res) => {
  const { user_id } = req.body;
  const myId = req.userId;

  try {
    const targetUser = await User.findById(user_id);
    if (!targetUser) {
      return res.status(404).json({ error: 'Пользователь не найден' });
    }

    const existingChat = await Chat.findPrivateChat(myId, user_id);
    if (existingChat) {
      return res.status(200).json({ chat_id: existingChat.id });
    }

    //Пока не будем заполнять имя чата, поскольку реализую только личные чаты
    //const chatName = `Чат с ${targetUser.login}`; 
    const chatId = await Chat.create({ name: '' /*chatName*/ });

    await Chat.addUserToChat(chatId, myId);
    await Chat.addUserToChat(chatId, user_id);

    res.status(201).json({ chat_id: chatId });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/all', authenticateToken, async (req, res) => {
  try {
    const users = await User.getAll();
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/api/chats/:chatId/info', authenticateToken, async (req, res) => {
  const { chatId } = req.params;
  const myId = req.userId;
  try {
    const users = await User.findByChat(chatId, myId);
    if (users.length > 0) {
      res.json(users[0]);
    } else {
      res.status(404).json({ error: 'Пользователь не обнаружен в чате!' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Ошибка сервера!' });
  }
});

router.get('/api/users/:userId', authenticateToken, async (req, res) => {
  const { userId } = req.params;
  try {
    const users = await User.findById(userId);
    if (users.length > 0) {
      res.json(users[0]);
    } else {
      res.status(404).json({ error: 'Пользователь не обнаружен в чате!' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Ошибка сервера!' });
  }
});

module.exports = router;