const logger = require('../utils/logger');

const errorHandler = (err, req, res, next) => {
  logger.error('Error occurred:', {
    message: err.message,
    stack: err.stack,
    url: req.originalUrl,
    method: req.method,
    userId: req.userId || 'anonymous',
  });

  let statusCode = err.statusCode || err.status || 500;
  let message = err.message || 'Внутренняя ошибка сервера';
  let errorDetails = null;

  if (err.name === 'ValidationError' || err.code === '23505') {
    statusCode = 400;
    message = 'Ошибка валидации данных';
    errorDetails = err.details || err.detail;
  }

  if (err.name === 'UnauthorizedError' || err.message === 'jwt malformed' || err.message?.includes('jwt')) {
    statusCode = 401;
    message = 'Неавторизованный доступ';
  }

  if (err.statusCode === 404 || err.message?.includes('not found')) {
    statusCode = 404;
    message = 'Ресурс не найден';
  }

  return res.status(statusCode).json({
    success: false,
    error: message,
    ...(errorDetails && { details: errorDetails }),
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};

module.exports = errorHandler;
