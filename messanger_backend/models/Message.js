const pool = require('../db');

const Message = {
  add: async ({ chat_id, sender_id, content, createdAt, image_url }) => {
    const query = 'INSERT INTO messages (chat_id, sender_id, content, created_at, image_url) VALUES ($1, $2, $3, $4, $5) RETURNING *';
    const result = await pool.query(query, [chat_id, sender_id, content, createdAt, image_url]);
    return result.rows[0];
  },

  update: async ({ message_id, content }) => {
    const query = 'UPDATE messages SET content = $2, is_edited = TRUE WHERE id = $1 RETURNING *';
    const result = await pool.query(query, [message_id, content]);
    return result.rows[0];
  },

  delete: async({ message_id, user_id }) => {
    if (!user_id) {
      await pool.query('DELETE FROM messages WHERE id = $1 RETURNING *', [message_id]);
    } else {
      const query = 'SELECT del_for_user_id FROM messages WHERE id = $1';
      const result = await pool.query(query, [message_id]);
      if (result.rows[0].del_for_user_id) {
        await pool.query('DELETE FROM messages WHERE id = $1 RETURNING *', [message_id]);
      } else {
        await pool.query(
          'UPDATE messages SET del_for_user_id = $2 WHERE id = $1',
          [message_id, user_id]
        );
      }
    }
  },

  read: async({ chat_id, user_id }) => {
    await pool.query(
      'UPDATE messages SET status = $1 WHERE chat_id = $2 AND sender_id != $3 AND status != $1',
      ['read', chat_id, user_id]
    );
  },

  getByChatId: async (chatId, myId, limit, offset) => {
    console.log(chatId, myId, limit, offset)
    const result = await pool.query(
      `SELECT * FROM messages 
       WHERE chat_id = $1
         AND (del_for_user_id IS NULL OR del_for_user_id != $2)
       ORDER BY created_at DESC 
       LIMIT $3 OFFSET $4`,
      [chatId, myId, limit, offset]
    );
    const messages = [...result.rows].reverse(); 
    const hasMore = result.rows.length === limit;

    return { messages, hasMore };
  },
};

module.exports = Message;