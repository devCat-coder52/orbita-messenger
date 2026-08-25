const pool = require('../db');

const Chat = {
  create: async ({ name, creator_id }) => {
    const query = 'INSERT INTO chats (name, creator_id) VALUES ($1, $2) RETURNING id';
    const result = await pool.query(query, [name, creator_id]);
    return result.rows[0].id;
  },

  getUserChats: async (userId, queryString) => {
      const textUserChats = queryString ? 'LEFT JOIN user_chats cu' : 'JOIN user_chats cu';
      const query = `
      SELECT c.id as chat_id,
             u.id as user_id,
             COALESCE(ui.nick_name, u.login) as user_name,
             ui.avatar_url,
             u.is_online,
             m.created_at as message_time,
             m.sender_id as message_sender,
	           m.content as message_text,
             COALESCE(unread.unread_count, 0) as unread_count
          FROM users u
          JOIN user_info ui ON u.id = ui.user_id
          ${textUserChats} ON u.id = cu.user_id AND cu.user_id != $1 AND cu.chat_id IN 
            (SELECT cuu.chat_id FROM user_chats cuu WHERE cuu.user_id = $1)
          LEFT JOIN chats c ON c.id = cu.chat_id
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
        WHERE u.id != $1
          AND ($2::text IS NULL OR u.login like concat('%', $2::text, '%'))
        ORDER BY m.created_at DESC NULLS LAST`;
    const result = await pool.query(query, [userId, queryString]);
    return result.rows;
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