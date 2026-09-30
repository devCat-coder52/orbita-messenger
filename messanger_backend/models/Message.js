const pool = require('../db');

const Message = {
  add: async ({ chat_id, sender_id, content, reply_msg_id, source_user_id, time_create, image_url }) => {
    const query = 'INSERT INTO messages (chat_id, sender_id, content, reply_to_message_id, source_user_id, time_create, image_url, is_encrypted) VALUES ($1, $2, $3, $4, $5, $6, $7, true) RETURNING *';
    const result = await pool.query(query, [chat_id, sender_id, content, reply_msg_id, source_user_id, time_create, image_url]);
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
    const result = await pool.query(
      `SELECT m.*, false as is_selected,
        CASE WHEN m.source_user_id IS NOT NULL THEN
          json_build_object(
            'id', m.source_user_id,
            'name', COALESCE(ui.nick_name, u.login),
            'avatar_url', ui.avatar_url
          )
        END AS forward,
        CASE WHEN m.sender_id IS NOT NULL THEN
          json_build_object(
            'id', m.sender_id,
            'name', COALESCE(ui1.nick_name, u1.login),
            'avatar_url', ui1.avatar_url
          )
        END AS sender,
        CASE WHEN m.reply_to_message_id IS NOT NULL THEN
          json_build_object(
            'id', mr.id,
            'sender', json_build_object(
              'id', mr.sender_id,
              'name', COALESCE(ui2.nick_name, u2.login),
              'avatar_url', ui2.avatar_url
            ),
            'content', mr.content,
            'image_url', mr.image_url
          )
        END AS reply
        FROM messages m
        LEFT JOIN users u ON m.source_user_id = u.id 
        LEFT JOIN user_info ui ON u.id = ui.user_id
        LEFT JOIN users u1 ON m.sender_id = u1.id 
        LEFT JOIN user_info ui1 ON u1.id = ui1.user_id
        LEFT JOIN messages mr ON m.reply_to_message_id = mr.id
        LEFT JOIN users u2 ON mr.sender_id = u2.id 
        LEFT JOIN user_info ui2 ON u2.id = ui2.user_id
       WHERE m.chat_id = $1
         AND (m.del_for_user_id IS NULL OR m.del_for_user_id != $2)
       ORDER BY m.time_create DESC 
       LIMIT $3 OFFSET $4`,
      [chatId, myId, limit, offset]
    );
    const messages = [...result.rows].reverse();
    const hasMore = result.rows.length === limit;

    return { messages, hasMore };
  },
};

module.exports = Message;