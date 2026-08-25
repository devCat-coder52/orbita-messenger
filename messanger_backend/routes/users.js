const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/auth');
const User = require('../models/User');
const Chat = require('../models/Chat');

router.post('/create_chat', authenticateToken, async (req, res) => {
  const { user_id } = req.body;
  const myId = req.userId;
  if (!user_id) {
    return res.status(400).json({ error: 'Отсутствует user_id' });
  }
  if (user_id === myId) {
    return res.status(400).json({ error: 'Нельзя создать чат с самим собой' });
  }
  try {
    const targetUser = await User.findById(user_id);
    if (!targetUser) {
      return res.status(404).json({ error: 'Пользователь не найден' });
    }

    const existingChat = await Chat.findPrivateChat(myId, user_id);
    if (existingChat) {
      return res.status(200).json({ chat_id: existingChat.id });
    }
    const chatId = await Chat.create({ name: '', creator_id: myId });

    await Chat.addUserToChat(chatId, myId);
    await Chat.addUserToChat(chatId, user_id);

    res.status(201).json({ chat_id: chatId });
  } catch (error) {
    console.error('Create chat error:', error);
    res.status(500).json({ error: 'Ошибка создания чата' });
  }
});

router.get('/all', authenticateToken, async (req, res) => {
  try {
    const users = await User.getAll();
    res.json(users);
  } catch (error) {
    console.error('Get all users error:', error);
    res.status(500).json({ error: 'Ошибка получения списка пользователей' });
  }
});

router.get('/:userId', authenticateToken, async (req, res) => {
  const { userId } = req.params;
  try {
    const user = await User.findById(userId);
    if (user) {
      res.json(user);
    } else {
      res.status(404).json({ error: 'Пользователь не найден' });
    }
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Ошибка получения пользователя' });
  }
});

module.exports = router;