const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'messenger_db',
  password: 'test',
  port: 5432,
});

module.exports = pool;