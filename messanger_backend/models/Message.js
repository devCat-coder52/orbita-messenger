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

  getByChatId: async (chatId, limit, offset) => {
    const result = await pool.query(
      `SELECT * FROM messages 
       WHERE chat_id = $1 
       ORDER BY created_at DESC 
       LIMIT $2 OFFSET $3`,
      [chatId, limit, offset]
    );
    const messages = result.rows.reverse(); 
    const hasMore = result.rows.length === limit;

    return { messages, hasMore };
  },
};

module.exports = Message;