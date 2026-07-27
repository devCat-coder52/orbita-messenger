const pool = require('../db');

const Message = {
  add: async ({ chat_id, sender_id, content, createdAt }) => {
    const query = 'INSERT INTO messages (chat_id, sender_id, content, created_at) VALUES ($1, $2, $3, $4) RETURNING *';
    const result = await pool.query(query, [chat_id, sender_id, content, createdAt]);
    return result.rows[0];
  },

  read: async({ chat_id, user_id }) => {
    await pool.query(
      'UPDATE messages SET status = $1 WHERE chat_id = $2 AND sender_id != $3 AND status != $1',
      ['read', chat_id, user_id]
    );
  },

  getByChatId: async (chatId) => {
    const query = `
      SELECT m.*, u.login AS sender_login
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.chat_id = $1
      ORDER BY m.created_at ASC
    `;
    const result = await pool.query(query, [chatId]);
    return result.rows;
  },
};

module.exports = Message;