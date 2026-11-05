const redis = require('redis');
const config = require('./env');
const logger = require('../utils/logger');

const redisClient = redis.createClient({
  url: config.redisUrl,
  return_buffers: false,
});

redisClient.on('error', (err) => logger.error('Redis Client Error', { error: err.message }));
redisClient.on('connect', () => logger.info('Connected to Redis'));
redisClient.on('end', () => logger.warn('Redis connection closed'));

module.exports = redisClient;
