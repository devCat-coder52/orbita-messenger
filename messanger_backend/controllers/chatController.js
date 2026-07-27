const Chat = require('../models/Chat');
const Message = require('../models/Message');

exports.getChats = async (req, res) => {
  try {
    const chats = await Chat.getUserChats(req.userId);
    res.json(chats);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getMessages = async (req, res) => {
  const { chatId } = req.params;
  try {
    const messages = await Message.getByChatId(chatId);
    res.json(messages);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};