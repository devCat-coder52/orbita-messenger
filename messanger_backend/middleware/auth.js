const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../config/constants');
const User = require('../models/User');

const authenticateToken = async (req, res, next) => {
  const header = req.header('Authorization') || '';
  const [scheme, rawToken] = header.split(' ');

  if (scheme !== 'Bearer' || !rawToken) {
    return res.status(401).json({ success: false, error: 'Access denied' });
  }

  try {
    const verified = jwt.verify(rawToken, JWT_SECRET);
    const userId = Number(verified.userId);

    if (!Number.isInteger(userId) || userId <= 0) {
      return res.status(401).json({ success: false, error: 'Invalid token' });
    }

    const tokenVersion = await User.getTokenVersion(userId);
    if (tokenVersion === null) {
      return res.status(401).json({ success: false, error: 'Invalid token' });
    }
    if ((Number(verified.v) || 0) !== tokenVersion) {
      return res.status(401).json({
        success: false,
        error: 'Сессия устарела, войдите заново',
      });
    }

    req.userId = userId;
    return next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Invalid token' });
  }
};

module.exports = authenticateToken;
