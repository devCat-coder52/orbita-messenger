const express = require('express');
const http = require('http');
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

require('dotenv').config();

initFirebase();

const app = express();
const allowedOrigins = applyGlobalMiddleware(app);
const server = http.createServer(app);

initSocketIO(server, allowedOrigins);

app.use('/api/auth', authRoutes);
app.use('/api/chat', authenticateToken, chatRoutes);
app.use('/api/chat', authenticateToken, mediaRoutes);
app.use('/api/users', authenticateToken, userRoutes);
app.use('/api/profile', authenticateToken, profileRoutes);

app.use((req, res, next) => {
  const error = new Error('Маршрут не найден');
  error.statusCode = 404;
  next(error);
});

app.use(errorHandler);

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  logger.info(`Server running on port ${PORT}`);
});

module.exports = { app, server };