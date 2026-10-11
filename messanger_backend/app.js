const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');

const logger = require('./utils/logger');
const { DEFAULT_ALLOWED_ORIGINS, RATE_LIMIT_WINDOW_MS, GENERAL_RATE_LIMIT_MAX } = require('./config/constants');

function applyGlobalMiddleware(app) {
  app.use(helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
  }));

  app.use(morgan('combined', {
    stream: { write: (message) => logger.info(message.trim()) },
  }));

  const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : DEFAULT_ALLOWED_ORIGINS;

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
  app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

  return allowedOrigins;
}

function initFirebase() {
  const admin = require('firebase-admin');
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');

  if (process.env.FIREBASE_PROJECT_ID && fs.existsSync(keyPath)) {
    admin.initializeApp({
      credential: admin.cert(JSON.parse(fs.readFileSync(keyPath, 'utf8'))),
    });
    logger.info('Firebase initialized');
  } else {
    logger.info('Firebase not configured (local development mode)');
  }
}

module.exports = { applyGlobalMiddleware, initFirebase };