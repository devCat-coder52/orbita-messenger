const logger = require('../utils/logger');
const config = require('../config/env');

const errorHandler = (err, req, res, next) => {
  let statusCode = err.statusCode || err.status || 500;
  let message = err.message || 'Внутренняя ошибка сервера';
  let errorDetails = null;

  if (err.name === 'MulterError') {
    statusCode = 400;
    message = err.code === 'LIMIT_FILE_SIZE'
      ? 'Файл слишком большой'
      : 'Ошибка загрузки файла';
    errorDetails = err.code;
  } else if (err.name === 'ValidationError' || err.code === '23505') {
    statusCode = 400;
    message = 'Ошибка валидации данных';
    errorDetails = err.details || err.detail;
  } else if (
    err.name === 'UnauthorizedError' ||
    err.message === 'jwt malformed' ||
    err.message?.includes('jwt')
  ) {
    statusCode = 401;
    message = 'Неавторизованный доступ';
  } else if (err.statusCode === 404 || err.message?.includes('not found')) {
    statusCode = 404;
    message = 'Ресурс не найден';
  }

  const logPayload = {
    message: err.message,
    statusCode,
    url: req.originalUrl,
    method: req.method,
    userId: req.userId || 'anonymous',
  };
  
  if (statusCode >= 500) {
    logger.error('Error occurred:', { ...logPayload, stack: err.stack });
  } else {
    logger.warn('Request rejected:', logPayload);
  }

  return res.status(statusCode).json({
    success: false,
    error: message,
    ...(errorDetails && { details: errorDetails }),
    ...(!config.isProduction && { stack: err.stack }),
  });
};

module.exports = errorHandler;
