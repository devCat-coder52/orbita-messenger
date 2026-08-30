const pool = require('../db');

const User = {
  create: async ({ login, email, password }) => {
    const query = 'INSERT INTO users (login, email, password) VALUES ($1, $2, $3) RETURNING id, login, email';
    const result = await pool.query(query, [login, email, password]);
    if (result.rows.length > 0) await pool.query('INSERT INTO user_info (user_id) VALUES ($1)', [result.rows[0].id]);
    return result.rows[0];
  },

  update: async ({ userId, name, avatarUrl, location, birth_date, bio, gender }) => {
    const setClause = [];
    const values = [];
    let paramCount = 1;

    if (name !== undefined) {
      setClause.push(`nick_name = $${paramCount}`);
      values.push(name.length > 0 ? name : null);
      paramCount++;
    }

    if (avatarUrl) {
      setClause.push(`avatar_url = $${paramCount}`);
      values.push(avatarUrl);
      paramCount++;
    }

    if (gender !== undefined) {
      let genderText;
      switch(gender) {
        case 'Мужской': 
          genderText = 'М'
          break
        case 'Женский': 
          genderText = 'Ж'
          break
        default: genderText = null
      }
      setClause.push(`gender = $${paramCount}`);
      values.push(genderText);
      paramCount++;
    }

    if (bio !== undefined) {
      setClause.push(`bio = $${paramCount}`);
      values.push(bio.length > 0 ? bio : null);
      paramCount++;
    }

    if (location !== undefined) {
      setClause.push(`location = $${paramCount}`);
      values.push(location.length > 0 ? location : null);
      paramCount++;
    }

    if (birth_date !== undefined) {
      setClause.push(`birth_date = $${paramCount}`);
      values.push(birth_date);
      paramCount++;
    }
    
    values.push(userId);
    const query = `UPDATE user_info SET ${setClause.join(', ')} WHERE user_id = $${paramCount} RETURNING *`;
    const result = await pool.query(query, values);
    return result.rows[0];
  },

  findById: async (id) => {
    const query = 'SELECT u.id, u.login, ui.nick_name as name, u.email, ui.avatar_url, u.is_online, u.last_seen FROM users u JOIN user_info ui ON u.id = ui.user_id WHERE id = $1';
    const result = await pool.query(query, [id]);
    return result.rows[0];
  },

  findByEmail: async (email) => {
    const query = 'SELECT id FROM users WHERE email = $1';
    const result = await pool.query(query, [email]);
    return result.rows[0];
  },

  findByLogin: async (login) => {
    const query = 'SELECT id, login, email, password FROM users WHERE login = $1';
    const result = await pool.query(query, [login]);
    return result.rows[0];
  },

  findByChat: async (chatId, myId) => {
    const query = `
      SELECT u.id, ui.nick_name, u.login, ui.avatar_url, u.is_online, u.last_seen
      FROM user_chats cu 
      JOIN users u ON u.id = cu.user_id
      JOIN user_info ui ON u.id = ui.user_id
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

  getProfileData: async (userId) => {
    const query = `SELECT 
      u.login, 
      ui.nick_name, 
      u.email, 
      ui.avatar_url, 
      ui.location, 
      ui.birth_date::text as birth_date, 
      bio, 
      u.email, 
      CASE 
        WHEN gender = 'М' THEN 'Мужской'
        WHEN gender = 'Ж' THEN 'Женский'
        ELSE 'Не указано' END as gender
      FROM users u JOIN user_info ui ON u.id = ui.user_id WHERE id = $1`;
    const result = await pool.query(query, [userId]);
    return result.rows[0];
  },
  
  getPublicKey: async (userId) => {
    const result = await pool.query('SELECT public_key FROM users WHERE id = $1', [userId]);
    return result.rows[0]?.public_key;
  },

  updatePublicKey: async (userId, publicKey) => {
    await pool.query('UPDATE users SET public_key = $1 WHERE id = $2', [publicKey, userId]);
  }
};

module.exports = User;