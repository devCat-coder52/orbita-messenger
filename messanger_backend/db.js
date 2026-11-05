const { Pool } = require('pg');
const config = require('./config/env');
const logger = require('./utils/logger');

const pool = new Pool({
  host: config.db.host,
  port: config.db.port,
  database: config.db.database,
  user: config.db.user,
  password: config.db.password,
  connectionTimeoutMillis: 5000,
  idleTimeoutMillis: 30000,
});

pool.on('error', (error) => {
  logger.error('Неожиданная ошибка простаивающего клиента PostgreSQL', {
    error: error.message,
    stack: error.stack,
  });
});

module.exports = pool;
