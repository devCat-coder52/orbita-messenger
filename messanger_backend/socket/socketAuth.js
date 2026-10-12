const jwt = require('jsonwebtoken');

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
  io.use((socket, next) => {
    const token = extractToken(socket.handshake);

    if (!token) {
      return next(new Error('UNAUTHORIZED: токен доступа отсутствует'));
    }

    try {
      const verified = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = Number(verified.userId);

      if (!Number.isInteger(socket.userId) || socket.userId <= 0) {
        return next(new Error('UNAUTHORIZED: некорректный userId в токене'));
      }

      next();
    } catch (err) {
      next(new Error('UNAUTHORIZED: недействительный или просроченный токен'));
    }
  });
}

module.exports = { socketAuthMiddleware, extractToken };