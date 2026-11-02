const redis = require('redis');
const logger = require('../utils/logger');

const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
  return_buffers: false,
});

redisClient.on('error', (err) => logger.error('Redis Client Error', { error: err.message }));
redisClient.on('connect', () => logger.info('Connected to Redis'));
redisClient.on('end', () => logger.warn('Redis connection closed'));

module.exports = redisClient;