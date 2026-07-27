const pool = require('../db');

const User = {
  create: async ({ login, email, password }) => {
    const query = 'INSERT INTO users (login, email, password) VALUES ($1, $2, $3) RETURNING id, login, email';
    const result = await pool.query(query, [login, email, password]);
    return result.rows[0];
  },

  findById: async (id) => {
    const query = 'SELECT id, login, name, email, avatar_url, is_online, last_seen FROM users WHERE id = $1';
    const result = await pool.query(query, [id]);
    return result.rows[0];
  },

  findByEmail: async (email) => {
    const query = 'SELECT * FROM users WHERE email = $1';
    const result = await pool.query(query, [email]);
    return result.rows[0];
  },

  findByLogin: async (login) => {
    const query = 'SELECT * FROM users WHERE login = $1';
    const result = await pool.query(query, [login]);
    return result.rows[0];
  },

  findByChat: async (chatId, myId) => {
    const query = `
      SELECT u.id, u.name, u.login, u.avatar_url, u.is_online, u.last_seen
      FROM user_chats cu 
      JOIN users u ON u.id = cu.user_id 
      WHERE cu.chat_id = $1 AND cu.user_id != $2
    `;
    const result = await pool.query(query, [chatId, myId]);
    return result.rows;
  },

  getAll: async () => {
    const query = 'SELECT id, login, email FROM users';
    const result = await pool.query(query);
    return result.rows;
  },

  updateProfileData: async ({ userId, name, avatarUrl }) => {
    const setClause = [];
    const values = [];
    let paramCount = 1;

    if (name !== undefined) {
      setClause.push(`name = $${paramCount}`);
      values.push(name);
      paramCount++;
    }

    if (avatarUrl !== undefined) {
      setClause.push(`avatar_url = $${paramCount}`);
      values.push(avatarUrl);
      paramCount++;
    }

    if (setClause.length === 0) {
      return await pool.query('SELECT * FROM users WHERE id = $1', [userId]).then(res => res.rows[0]);
    }
    
    values.push(userId);
    const query = `UPDATE users SET ${setClause.join(', ')} WHERE id = $${paramCount} RETURNING *`;
    const result = await pool.query(query, values);
    return result.rows[0];
  },

  getProfileData: async (userId) => {
    const query = 'SELECT login, name, email, avatar_url FROM users WHERE id = $1';
    const result = await pool.query(query, [userId]);
    return result.rows[0];
  },
};

module.exports = User;