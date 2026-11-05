const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../config/constants');
const User = require('../models/User');

function extractToken(handshake) {
  const { auth = {}, headers = {}, query = {} } = handshake;

  if (typeof auth.token === 'string' && auth.token) return auth.token;

  const header = headers.authorization || headers.Authorization;
  if (typeof header === 'string' && header.startsWith('Bearer ')) {
    return header.slice(7);
  }

  if (typeof query.token === 'string' && query.token) return query.token;

  return null;
}

function socketAuthMiddleware(io) {
  io.use(async (socket, next) => {
    const token = extractToken(socket.handshake);

    if (!token) {
      return next(new Error('UNAUTHORIZED: токен доступа отсутствует'));
    }

    try {
      const verified = jwt.verify(token, JWT_SECRET);
      const userId = Number(verified.userId);

      if (!Number.isInteger(userId) || userId <= 0) {
        return next(new Error('UNAUTHORIZED: некорректный userId в токене'));
      }

      const tokenVersion = await User.getTokenVersion(userId);
      if (tokenVersion === null || (Number(verified.v) || 0) !== tokenVersion) {
        return next(new Error('UNAUTHORIZED: сессия устарела, войдите заново'));
      }

      socket.userId = userId;
      return next();
    } catch (err) {
      return next(new Error('UNAUTHORIZED: недействительный или просроченный токен'));
    }
  });
}

module.exports = { socketAuthMiddleware, extractToken };