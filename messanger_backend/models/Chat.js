const pool = require('../db');

const Chat = {
  create: async ({ name, creator_id }) => {
    const query = 'INSERT INTO chats (name, creator_id) VALUES ($1, $2) RETURNING id';
    const result = await pool.query(query, [name, creator_id]);
    return result.rows[0].id;
  },

  delete: async (chatId) => {
    await pool.query('DELETE FROM messages WHERE chat_id = $1', [chatId]);
    await pool.query('DELETE FROM user_chats WHERE chat_id = $1', [chatId]);
    const result = await pool.query('DELETE FROM chats WHERE id = $1 RETURNING id', [chatId]);
    return result.rows[0].id;
  },

  find: async (userId1, userId2) => {
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

  pin: async (chatId, userId) => {
    const query = 'UPDATE user_chats SET is_pinned = NOT is_pinned WHERE chat_id = $1 and user_id = $2 RETURNING is_pinned';
    const result = await pool.query(query, [chatId, userId]);
    return result.rows[0];
  },

  checkAccess: async (chatId, userId) => {
    const query = `
      SELECT c.id
        FROM chats c
        JOIN user_chats uc ON c.id = uc.chat_id
       WHERE c.id = $1 AND uc.user_id = $2; 
    `;
    const result = await pool.query(query, [chatId, userId]);
    return result.rows[0];
  },

  getUserChats: async (userId, queryString) => {
      const textUserChats = queryString ? 'LEFT JOIN user_chats cu' : 'JOIN user_chats cu';
      const query = `
        SELECT c.id as chat_id,
             u.id as user_id,
             COALESCE(ui.nick_name, u.login) as user_name,
             ui.avatar_url,
             u.is_online,
             COALESCE((SELECT is_pinned FROM user_chats cuu WHERE cuu.chat_id = c.id AND cuu.user_id = $1), false) as is_pinned,
             m.time_create as message_time,
             m.sender_id as message_sender,
	           m.content as message_text,
             m.is_encrypted as message_is_encrypted,
             CASE WHEN m.image_url IS NOT NULL THEN 'media' ELSE 'text' END as message_type,
             COALESCE(unread.unread_count, 0) as unread_count
          FROM users u
          JOIN user_info ui ON u.id = ui.user_id
          ${textUserChats} ON u.id = cu.user_id AND cu.user_id != $1 AND cu.chat_id IN 
            (SELECT cuu.chat_id FROM user_chats cuu WHERE cuu.user_id = $1)
          LEFT JOIN chats c ON c.id = cu.chat_id
          LEFT JOIN (
            SELECT DISTINCT ON (chat_id) *
              FROM messages
              ORDER BY chat_id, time_create DESC
            ) m ON c.id = m.chat_id
          LEFT JOIN (
            SELECT chat_id, COUNT(*)::integer as unread_count
              FROM messages
              WHERE sender_id != $1 AND status != 'read'
              GROUP BY chat_id
            ) unread ON c.id = unread.chat_id
        WHERE u.id != $1
          AND ($2::text IS NULL OR u.login like concat('%', $2::text, '%'))
        ORDER BY (SELECT is_pinned FROM user_chats cuu WHERE cuu.chat_id = c.id AND cuu.user_id = $1) DESC, m.time_create DESC NULLS LAST`;
    const result = await pool.query(query, [userId, queryString]);
    return result.rows;
  },

  addUserToChat: async (chatId, userId) => {
    const query = 'INSERT INTO user_chats (chat_id, user_id) VALUES ($1, $2)';
    await pool.query(query, [chatId, userId]);
  },
};

module.exports = Chat;