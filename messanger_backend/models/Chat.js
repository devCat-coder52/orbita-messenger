const pool = require('../db');

const Chat = {
  create: async ({ name }) => {
    const query = 'INSERT INTO chats (name, creator_id) VALUES ($1, $2) RETURNING id';
    const result = await pool.query(query, [name, 1]);
    return result.rows[0].id;
  },

  getUserChats: async (userId) => {
    try {
      const query = `
          SELECT 
            c.id, 
            c.name, 
            c.created_at, 
            u.login,
            u.name as user_name, 
            u.avatar_url, 
            u.id as user_id,
            CASE WHEN m.image_url IS NOT NULL
              THEN concat('[Фотография] ', m.content)
                 ELSE m.content
            END as last_message_content,
            m.created_at as last_message_time,
            m.sender_id as last_message_sender_id,
            u.is_online,
            unread.unread_count
          FROM chats c
          JOIN user_chats cu ON c.id = cu.chat_id
          JOIN users u ON cu.user_id = u.id
          LEFT JOIN (
            SELECT DISTINCT ON (chat_id) *
            FROM messages
            ORDER BY chat_id, created_at DESC
          ) m ON c.id = m.chat_id
          LEFT JOIN (
            SELECT chat_id, COUNT(*)::integer as unread_count
            FROM messages
            WHERE sender_id != $1 AND status != 'read'
            GROUP BY chat_id
          ) unread ON c.id = unread.chat_id
          WHERE c.id IN (
            SELECT DISTINCT cu2.chat_id
            FROM user_chats cu2
            WHERE cu2.user_id = $1
          ) AND u.id != $1
          ORDER BY m.created_at DESC NULLS LAST
        `;
      const result = await pool.query(query, [userId]);
      return result.rows;
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  },

  findPrivateChat: async (userId1, userId2) => {
    const query = `
      SELECT c.id
      FROM chats c
      JOIN user_chats uc1 ON c.id = uc1.chat_id
      JOIN user_chats uc2 ON c.id = uc2.chat_id
      WHERE uc1.user_id = $1 AND uc2.user_id = $2
    `;
    const result = await pool.query(query, [userId1, userId2]);
    return result.rows[0] || null;
  },

  addUserToChat: async (chatId, userId) => {
    const query = 'INSERT INTO user_chats (chat_id, user_id) VALUES ($1, $2)';
    await pool.query(query, [chatId, userId]);
  },
};

module.exports = Chat;