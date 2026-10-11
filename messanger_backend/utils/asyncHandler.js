const logger = require('./logger');

const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch((error) => {
    logger.error(error.message, { stack: error.stack, url: req.originalUrl });
    next(error);
  });
};

module.exports = asyncHandler;