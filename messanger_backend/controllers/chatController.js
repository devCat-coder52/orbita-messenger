const Chat = require('../models/Chat');
const Message = require('../models/Message');
const User = require('../models/User')

exports.getChats = async (req, res) => {
  try {
    const chats = await Chat.getUserChats(req.userId);
    res.json(chats);
  } catch (error) {
    console.error('Get chats error:', error);
    res.status(500).json({ error: 'Ошибка получения списка чатов' });
  }
};

exports.getMessages = async (req, res) => {
  const { chatId } = req.params;
  const myId = req.userId;
  const limit = parseInt(req.query.limit) || 50;
  const offset = parseInt(req.query.offset) || 0;
  try {
    const {messages, hasMore} = await Message.getByChatId(chatId, myId, limit, offset);
    res.json({messages, hasMore});
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Ошибка получения сообщений' });
  }
};

exports.getUserInfo = async (req, res) => {
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
    console.error('Get chat info error:', error);
    res.status(500).json({ error: 'Ошибка получения информации о чате' });
  }
};