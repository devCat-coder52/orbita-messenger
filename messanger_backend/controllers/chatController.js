const Chat = require('../models/Chat');
const Message = require('../models/Message');

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
  const limit = parseInt(req.query.limit) || 50;
  const offset = parseInt(req.query.offset) || 0;
  try {
    const {messages, hasMore} = await Message.getByChatId(chatId, limit, offset);
    console.log(messages.length, hasMore);
    res.json({messages, hasMore});
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Ошибка получения сообщений' });
  }
};