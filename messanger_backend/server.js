const config = require('./config/env');
const express = require('express');
const http = require('http');
const pool = require('./db');
const { applyGlobalMiddleware, initFirebase } = require('./app');
const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chat');
const mediaRoutes = require('./routes/media');
const profileRoutes = require('./routes/profile');
const userRoutes = require('./routes/users');
const authenticateToken = require('./middleware/auth');
const errorHandler = require('./middleware/errorHandler');
const logger = require('./utils/logger');
const { initSocketIO } = require('./socket/socketHandler');
const chatService = require('./services/chatService');

initFirebase();

const app = express();
const allowedOrigins = applyGlobalMiddleware(app);
const server = http.createServer(app);

const io = initSocketIO(server, allowedOrigins);

// Сервисный аккаунт и его аватар должны существовать до первой регистрации.
chatService.ensureServiceUser().catch((error) =>
  logger.warn('Не удалось подготовить сервисный аккаунт', { error })
);

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    return res.status(200).json({
      status: 'ok',
      uptime: Math.round(process.uptime()),
    });
  } catch (error) {
    logger.error('Health check failed', { error: error.message });
    return res.status(503).json({ status: 'degraded', db: 'down' });
  }
});

app.use('/api/auth', authRoutes);
app.use('/api/chat', authenticateToken, chatRoutes, mediaRoutes);
app.use('/api/users', authenticateToken, userRoutes);
app.use('/api/profile', authenticateToken, profileRoutes);

app.use((req, res, next) => {
  const error = new Error('Маршрут не найден');
  error.statusCode = 404;
  next(error);
});

app.use(errorHandler);

const PORT = config.port;
server.listen(PORT, '0.0.0.0', () => {
  logger.info(`Server running on port ${PORT}`);
});

let shuttingDown = false;

function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info(`Получен ${signal}, останавливаем сервер`);

  const forceExit = setTimeout(() => {
    logger.error('Корректная остановка не удалась, выходим принудительно');
    process.exit(1);
  }, 10000);
  forceExit.unref();

  io.close();
  server.close(async () => {
    try {
      await pool.end();
    } catch (error) {
      logger.warn('Ошибка при закрытии пула PostgreSQL', {
        error: error.message,
      });
    }
    clearTimeout(forceExit);
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

process.on('unhandledRejection', (reason) => {
  logger.error('unhandledRejection', {
    reason: reason instanceof Error ? reason.message : String(reason),
    stack: reason instanceof Error ? reason.stack : undefined,
  });
});

process.on('uncaughtException', (error) => {
  logger.error('uncaughtException', {
    error: error.message,
    stack: error.stack,
  });
  shutdown('uncaughtException');
});

module.exports = { app, server };
