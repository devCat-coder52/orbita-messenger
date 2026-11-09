/**
 * Общая обвязка интеграционных тестов.
 *
 * Тесты работают против настоящих PostgreSQL и Redis и поднимают сервер
 * отдельным процессом на своём порту. Все данные помечаются префиксом
 * `zztest` и удаляются в after().
 */
const path = require('path');
const { spawn } = require('child_process');
const { Pool } = require('pg');
const redis = require('redis');

const backendDir = path.join(__dirname, '..', '..');
const config = require(path.join(backendDir, 'config/env'));

const LOGIN_PREFIX = 'zztest';
const PASSWORD = 'secret123';
const CODE = '123456';

let serverProcess = null;
let baseUrl = null;
let pool = null;
let redisClient = null;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function startServer(port) {
  if (serverProcess) return;

  baseUrl = `http://127.0.0.1:${port}`;
  serverProcess = spawn(process.execPath, ['server.js'], {
    cwd: backendDir,
    env: {
      ...process.env,
      PORT: String(port),
      NODE_ENV: 'test',
      // Тесты создают десятки пользователей с одного IP.
      AUTH_RATE_LIMIT_MAX: '300',
    },
    stdio: 'ignore',
  });

  for (let attempt = 0; attempt < 80; attempt += 1) {
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) return;
    } catch (_) {
      /* сервер ещё поднимается */
    }
    await sleep(250);
  }

  throw new Error('Сервер не поднялся за отведённое время');
}

async function stopServer() {
  if (!serverProcess) return;
  serverProcess.kill();
  serverProcess = null;
  await sleep(300);
}

function getPool() {
  if (!pool) {
    pool = new Pool({
      host: config.db.host,
      port: config.db.port,
      database: config.db.database,
      user: config.db.user,
      password: config.db.password,
    });
  }
  return pool;
}

function getRedis() {
  if (!redisClient) {
    redisClient = redis.createClient({ url: config.redisUrl });
    redisClient.on('error', () => {});
  }
  return redisClient;
}

const query = (text, params) => getPool().query(text, params);

function setVerificationCode(email, code = CODE) {
  return new Promise((resolve, reject) => {
    getRedis().setex(`verify_code:${email}`, 600, code, (err) =>
      err ? reject(err) : resolve()
    );
  });
}

async function api(method, route, { token, body } = {}) {
  const headers = {};
  if (token) headers.authorization = `Bearer ${token}`;
  if (body) headers['content-type'] = 'application/json';

  const response = await fetch(`${baseUrl}${route}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch (_) {
    /* ответ не JSON */
  }
  return { status: response.status, json, text, headers: response.headers };
}

function uniqueLogin(suffix = '') {
  const time = Date.now().toString(36);
  const random = Math.random().toString(36).slice(2, 5);
  return `${LOGIN_PREFIX}${suffix}_${time}_${random}`.slice(0, 25);
}

async function registerUser(suffix = '') {
  const login = uniqueLogin(suffix);
  const email = `${login}@example.com`;

  await setVerificationCode(email, CODE);

  const result = await api('POST', '/api/auth/register', {
    body: { login, email, password: PASSWORD, code: CODE },
  });

  if (result.status !== 201) {
    throw new Error(`Не удалось зарегистрировать ${login}: ${result.text}`);
  }

  return {
    id: result.json.user.id,
    login,
    email,
    password: PASSWORD,
    token: result.json.token,
  };
}

async function createChat(asUser, withUserId) {
  const result = await api('POST', '/api/chat/create', {
    token: asUser.token,
    body: { user_id: withUserId },
  });
  if (result.status !== 201) {
    throw new Error(`Не удалось создать чат: ${result.text}`);
  }
  return result.json.chat_id;
}

async function cleanupTestData() {
  const client = getPool();
  await client.query(
    `DELETE FROM chats
      WHERE creator_id IN (SELECT id FROM users WHERE login LIKE $1)`,
    [`${LOGIN_PREFIX}%`]
  );
  await client.query('DELETE FROM users WHERE login LIKE $1', [`${LOGIN_PREFIX}%`]);
}

async function teardown() {
  try {
    await cleanupTestData();
  } finally {
    await stopServer();
    if (pool) {
      await pool.end();
      pool = null;
    }
    if (redisClient) {
      redisClient.quit();
      redisClient = null;
    }
  }
}

module.exports = {
  CODE,
  PASSWORD,
  LOGIN_PREFIX,
  api,
  startServer,
  stopServer,
  teardown,
  query,
  registerUser,
  createChat,
  setVerificationCode,
};
