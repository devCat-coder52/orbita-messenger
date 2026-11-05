const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  require('dotenv').config({ path: envPath, quiet: true });
} else {
  require('dotenv').config({ quiet: true });
}

const isProduction = (process.env.NODE_ENV || 'development') === 'production';

function fail(message) {
  console.error(`[config] ${message}`);
  process.exit(1);
}

function readJwtSecret() {
  const secret = (process.env.JWT_SECRET || '').trim();

  if (secret.length >= 32) return secret;

  if (isProduction) {
    fail(
      'JWT_SECRET обязателен в production и должен быть не короче 32 символов. ' +
        'Сервер не запущен.'
    );
  }

  const generated = crypto.randomBytes(32).toString('hex');
  console.warn(
    '[config] JWT_SECRET не задан или слишком короткий — сгенерирован временный ' +
      'секрет. Все выданные ранее токены станут недействительными после ' +
      'перезапуска сервера. Задайте JWT_SECRET в .env.'
  );
  return generated;
}

function readOrigins() {
  const raw = (process.env.ALLOWED_ORIGINS || '').trim();
  if (!raw) return ['http://localhost:3000'];
  return raw
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

const config = {
  isProduction,
  port: Number(process.env.PORT) || 3000,
  clientUrl: process.env.CLIENT_URL || '',
  allowedOrigins: readOrigins(),

  jwtSecret: readJwtSecret(),

  db: {
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME || 'orbita',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
  },

  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  
  publicBaseUrl: (process.env.PUBLIC_BASE_URL || '').replace(/\/+$/, ''),

  smtp: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: Number(process.env.SMTP_PORT) || 587,
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    fromEmail: process.env.SMTP_FROM_EMAIL || process.env.SMTP_USER || '',
  },

  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || '',
};

if (isProduction) {
  const missing = ['DB_PASSWORD', 'SMTP_USER', 'SMTP_PASS'].filter(
    (name) => !(process.env[name] || '').trim()
  );
  if (missing.length > 0) {
    console.warn(`[config] не заданы переменные: ${missing.join(', ')}`);
  }
}

module.exports = config;
