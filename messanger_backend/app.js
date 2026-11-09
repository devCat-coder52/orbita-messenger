const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');

const logger = require('./utils/logger');
const config = require('./config/env');
const { RATE_LIMIT_WINDOW_MS, GENERAL_RATE_LIMIT_MAX } = require('./config/constants');

function applyGlobalMiddleware(app) {
  // За Caddy/nginx Express обязан доверять X-Forwarded-For ближайшего прокси:
  // иначе rate-limit видит IP контейнера, все клиенты делят один счётчик,
  // а express-rate-limit ругается на неожиданный X-Forwarded-For.
  const trustProxyHops = Number(process.env.TRUST_PROXY_HOPS ?? 1);
  if (Number.isFinite(trustProxyHops) && trustProxyHops > 0) {
    app.set('trust proxy', trustProxyHops);
  }

  app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
  }));

  app.use(morgan('combined', {
    stream: { write: (message) => logger.debug(message.trim()) },
  }));

  const allowedOrigins = config.allowedOrigins;

  app.use(cors({
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        logger.warn('Blocked by CORS', { origin });
        callback(new Error('Not allowed by CORS'));
      }
    },
    credentials: true,
  }));

  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  const generalLimiter = rateLimit({
    windowMs: RATE_LIMIT_WINDOW_MS,
    max: GENERAL_RATE_LIMIT_MAX,
    message: { error: 'Слишком много запросов, попробуйте позже' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  app.use('/api', generalLimiter);

  const inlineMediaExtensions = new Set([
    '.jpg', '.jpeg', '.png', '.webp', '.gif',
    '.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wav', '.amr',
  ]);

  app.use('/uploads', express.static(path.join(__dirname, 'uploads'), {
    index: false,
    dotfiles: 'deny',
    setHeaders(res, filePath) {
      const extension = path.extname(filePath).toLowerCase();
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('Cache-Control', 'private, max-age=86400');
      if (!inlineMediaExtensions.has(extension)) {
        res.setHeader('Content-Disposition', 'attachment');
      }
    },
  }));

  return allowedOrigins;
}

function initFirebase() {
  const admin = require('firebase-admin');
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');

  if (config.firebaseProjectId && fs.existsSync(keyPath)) {
    admin.initializeApp({
      credential: admin.cert(JSON.parse(fs.readFileSync(keyPath, 'utf8'))),
    });
    logger.info('Firebase initialized');
  } else {
    logger.info('Firebase not configured (local development mode)');
  }
}

module.exports = { applyGlobalMiddleware, initFirebase };