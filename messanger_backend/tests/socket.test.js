const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { io } = require('socket.io-client');

const {
  api,
  startServer,
  teardown,
  registerUser,
  createChat,
  query,
} = require('./helpers/env');

const PORT = 4107;
const BASE = `http://127.0.0.1:${PORT}`;

const sockets = [];
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function connect(token) {
  return new Promise((resolve, reject) => {
    const socket = io(BASE, {
      transports: ['websocket'],
      auth: { token },
      reconnection: false,
      forceNew: true,
    });
    sockets.push(socket);

    const timer = setTimeout(() => reject(new Error('connect timeout')), 8000);
    socket.on('connect', () => {
      clearTimeout(timer);
      resolve(socket);
    });
    socket.on('connect_error', (error) => {
      clearTimeout(timer);
      reject(new Error(`connect_error: ${error.message}`));
    });
  });
}

function once(socket, event, predicate = () => true, timeout = 4000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off(event, handler);
      reject(new Error(`timeout waiting for ${event}`));
    }, timeout);

    function handler(data) {
      if (!predicate(data)) return;
      clearTimeout(timer);
      socket.off(event, handler);
      resolve(data);
    }

    socket.on(event, handler);
  });
}

function emitWithAck(socket, event, data) {
  return new Promise((resolve) => socket.emit(event, data, resolve));
}

before(() => startServer(PORT));
after(() => {
  for (const socket of sockets) socket.close();
  return teardown();
});

test('send_message доходит до собеседника и подтверждается', async () => {
  const alice = await registerUser('sa');
  const bob = await registerUser('sb');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  const bobSocket = await connect(bob.token);
  await sleep(400); // автовступление в комнаты после подключения

  const received = once(
    bobSocket,
    'message_added',
    (m) => Number(m.chat_id) === Number(chatId)
  );
  const ack = await emitWithAck(aliceSocket, 'send_message', {
    chat_id: chatId,
    content: 'привет',
    time_create: Date.now(),
  });

  assert.equal(ack.status, 'ok');
  const message = await received;
  assert.equal(message.content, 'привет');
  assert.equal(Number(message.chat_id), Number(chatId));
});

test('статус пользователя приходит с chat_id', async () => {
  const alice = await registerUser('sc');
  const bob = await registerUser('sd');
  const chatId = await createChat(alice, bob.id);

  const bobSocket = await connect(bob.token);
  await sleep(400);

  const statusPromise = once(
    bobSocket,
    'user_status_changed',
    (s) => Number(s.userId) === Number(alice.id)
  );
  const aliceSocket = await connect(alice.token);

  const status = await statusPromise;
  assert.equal(Number(status.chat_id), Number(chatId));
  assert.equal(status.status, 'online');
  assert.equal(status.last_seen, null, 'для онлайна last_seen не нужен');

  const offlinePromise = once(
    bobSocket,
    'user_status_changed',
    (s) => Number(s.userId) === Number(alice.id) && s.status === 'offline'
  );
  aliceSocket.disconnect();

  const offline = await offlinePromise;
  assert.equal(Number(offline.chat_id), Number(chatId));
  assert.ok(offline.last_seen, 'для офлайна last_seen должен быть заполнен');
});

test('токен из query больше не принимается', async () => {
  const alice = await registerUser('so');
  const socket = io(BASE, {
    transports: ['websocket'],
    query: { token: alice.token },
    reconnection: false,
    forceNew: true,
  });
  sockets.push(socket);

  const error = await new Promise((resolve) => {
    socket.on('connect_error', (err) => resolve(err));
    socket.on('connect', () => resolve(null));
    setTimeout(() => resolve(null), 4000);
  });

  assert.ok(error, 'подключение должно быть отклонено');
  assert.match(String(error.message ?? ''), /UNAUTHORIZED/);
});

test('mark_as_read подтверждает прочтение отправителю', async () => {
  const alice = await registerUser('se');
  const bob = await registerUser('sf');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  const bobSocket = await connect(bob.token);
  await sleep(400);

  await emitWithAck(aliceSocket, 'send_message', {
    chat_id: chatId,
    content: 'прочти',
    time_create: Date.now(),
  });

  const readEvent = once(
    aliceSocket,
    'message_status_updated',
    (e) => Number(e.chat_id) === Number(chatId)
  );
  const ack = await emitWithAck(bobSocket, 'mark_as_read', { chat_id: chatId });

  assert.equal(ack.status, 'ok');
  const event = await readEvent;
  assert.equal(Number(event.updated_by), Number(bob.id));
});

test('чужое сообщение нельзя отредактировать', async () => {
  const alice = await registerUser('sg');
  const bob = await registerUser('sh');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  const bobSocket = await connect(bob.token);
  await sleep(400);

  const sent = await emitWithAck(aliceSocket, 'send_message', {
    chat_id: chatId,
    content: 'оригинал',
    time_create: Date.now(),
  });

  const ack = await emitWithAck(bobSocket, 'edit_message', {
    message_id: sent.message_id,
    content: 'подмена',
  });

  assert.equal(ack.status, 'error');
  assert.equal(ack.error, 'FORBIDDEN');
});

test('enter_chat не мешает доставке сообщений', async () => {
  const alice = await registerUser('si');
  const bob = await registerUser('sj');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  const bobSocket = await connect(bob.token);
  await sleep(400);

  bobSocket.emit('enter_chat', chatId);
  await sleep(100);

  const received = once(
    bobSocket,
    'message_added',
    (m) => Number(m.chat_id) === Number(chatId)
  );
  const ack = await emitWithAck(aliceSocket, 'send_message', {
    chat_id: chatId,
    content: 'после enter',
    time_create: Date.now(),
  });

  assert.equal(ack.status, 'ok');
  const message = await received;
  assert.equal(message.content, 'после enter');
});

test('повторное «удалить у себя» не удаляет сообщение у собеседника', async () => {
  const alice = await registerUser('sk');
  const bob = await registerUser('sl');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  const bobSocket = await connect(bob.token);
  await sleep(400);

  const sent = await emitWithAck(aliceSocket, 'send_message', {
    chat_id: chatId,
    content: 'секрет',
    time_create: Date.now(),
  });
  const messageId = sent.message_id;

  const deleteLocally = (socket) =>
    emitWithAck(socket, 'delete_message', {
      message_id: messageId,
      chat_id: chatId,
      is_local: true,
    });

  assert.equal((await deleteLocally(bobSocket)).status, 'ok');
  assert.equal((await deleteLocally(bobSocket)).status, 'ok');

  const stillThere = await query('SELECT id FROM messages WHERE id = $1', [
    messageId,
  ]);
  assert.equal(stillThere.rowCount, 1, 'сообщение должно остаться в базе');

  // Автор тоже скрыл сообщение — вот теперь строка удаляется.
  assert.equal((await deleteLocally(aliceSocket)).status, 'ok');
  const gone = await query('SELECT id FROM messages WHERE id = $1', [messageId]);
  assert.equal(gone.rowCount, 0);
});

test('внешние ссылки в вложениях отклоняются', async () => {
  const alice = await registerUser('sm');
  const bob = await registerUser('sn');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  await sleep(300);

  const bad = await emitWithAck(aliceSocket, 'send_message', {
    chat_id: chatId,
    content: '',
    image_url: 'http://evil.example/track.png',
    time_create: Date.now(),
  });
  assert.equal(bad.status, 'error');
  assert.equal(bad.error, 'INVALID_ATTACHMENT');

  const good = await emitWithAck(aliceSocket, 'send_message', {
    chat_id: chatId,
    content: '',
    image_url: '/uploads/messages/images/1-2.jpg',
    time_create: Date.now(),
  });
  assert.equal(good.status, 'ok');
});

test('чужое сообщение удаляется только у себя', async () => {
  const alice = await registerUser('td');
  const bob = await registerUser('te');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  const bobSocket = await connect(bob.token);
  await sleep(300);

  await emitWithAck(aliceSocket, 'send_message', {
    chat_id: chatId,
    content: 'чужое сообщение',
    time_create: Date.now(),
  });

  const row = await query(
    'SELECT id FROM messages WHERE chat_id = $1 ORDER BY time_create DESC LIMIT 1',
    [chatId]
  );
  const messageId = row.rows[0].id;

  const del = await emitWithAck(bobSocket, 'delete_message', {
    message_id: messageId,
    chat_id: chatId,
    is_local: false,
  });
  assert.equal(del.status, 'ok');

  const after = await query(
    'SELECT del_for_user_id, sender_id FROM messages WHERE id = $1',
    [messageId]
  );
  assert.equal(after.rows.length, 1, 'строка не должна исчезнуть физически');
  assert.equal(Number(after.rows[0].del_for_user_id), Number(bob.id));
  assert.equal(Number(after.rows[0].sender_id), Number(alice.id));
});
test('удаление сообщения из чужого чата отклоняется', async () => {
  const alice = await registerUser('cm1');
  const bob = await registerUser('cm2');
  const charlie = await registerUser('cm3');
  const chatA = await createChat(alice, bob.id);
  const chatB = await createChat(bob, charlie.id);

  const bobSocket = await connect(bob.token);
  const sent = await emitWithAck(bobSocket, 'send_message', {
    chat_id: chatB,
    content: 'сообщение в другом чате',
    is_encrypted: false,
    time_create: Date.now(),
  });
  assert.equal(sent.status, 'ok');
  const messageId = sent.message_id;

  const aliceSocket = await connect(alice.token);
  const denied = await emitWithAck(aliceSocket, 'delete_message', {
    message_id: messageId,
    chat_id: chatA,
    is_local: false,
  });

  assert.notEqual(denied.status, 'ok', 'чужой чат должен быть отклонён');
  const still = await query('SELECT id FROM messages WHERE id = $1', [messageId]);
  assert.equal(still.rowCount, 1, 'сообщение чужого чата не должно удаляться');
});
test('нетекстовое сообщение нельзя отредактировать', async () => {
  const alice = await registerUser('tf');
  const bob = await registerUser('tg');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  await sleep(300);

  const inserted = await query(
    `INSERT INTO messages (chat_id, sender_id, content, image_url, status, time_create)
     VALUES ($1, $2, '', 'uploads/test.jpg', 'sent', $3) RETURNING id`,
    [chatId, alice.id, Date.now()]
  );
  const messageId = inserted.rows[0].id;

  const edit = await emitWithAck(aliceSocket, 'edit_message', {
    message_id: messageId,
    content: 'новый текст',
  });

  assert.equal(edit.status, 'error');
  assert.equal(edit.error, 'NOT_TEXT_MESSAGE');
});
test('отключение сокета отправляет собеседнику статус offline', async () => {
  const alice = await registerUser('ua');
  const bob = await registerUser('ub');
  await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  const bobSocket = await connect(bob.token);
  await sleep(400);

  const offline = once(
    bobSocket,
    'user_status_changed',
    (e) => Number(e.userId) === Number(alice.id) && e.status === 'offline'
  );

  aliceSocket.disconnect();

  const event = await offline;
  assert.equal(event.status, 'offline');
});
test('создание чата приходит собеседнику по сокету', async () => {
  const alice = await registerUser('va');
  const bob = await registerUser('vb');

  const bobSocket = await connect(bob.token);
  await sleep(300);

  const created = once(bobSocket, 'chat_created', (e) => e.chat_id != null);

  const response = await api('POST', '/api/chat/create', {
    token: alice.token,
    body: { user_id: bob.id },
  });
  assert.equal(response.status, 201);

  const event = await created;
  assert.equal(Number(event.chat_id), Number(response.json.chat_id));
});

test('удаление чата убирает его у обоих участников', async () => {
  const alice = await registerUser('vc');
  const bob = await registerUser('vd');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  const bobSocket = await connect(bob.token);
  await sleep(300);

  const aliceDeleted = once(
    aliceSocket,
    'chat_deleted',
    (e) => Number(e.chat_id) === Number(chatId)
  );
  const bobDeleted = once(
    bobSocket,
    'chat_deleted',
    (e) => Number(e.chat_id) === Number(chatId)
  );

  const response = await api('POST', '/api/chat/delete', {
    token: alice.token,
    body: { chat_id: chatId },
  });
  assert.equal(response.status, 200);

  await aliceDeleted;
  await bobDeleted;

  const aliceList = await api('GET', '/api/chat/all', { token: alice.token });
  const bobList = await api('GET', '/api/chat/all', { token: bob.token });
  assert.ok(!aliceList.json.some((c) => Number(c.chat_id) === Number(chatId)));
  assert.ok(!bobList.json.some((c) => Number(c.chat_id) === Number(chatId)));

  const rows = await query('SELECT 1 FROM chats WHERE id = $1', [chatId]);
  assert.equal(rows.rows.length, 0);
});
test('системное сообщение нельзя отредактировать', async () => {
  const alice = await registerUser('wa');
  const bob = await registerUser('wb');
  const chatId = await createChat(alice, bob.id);

  const aliceSocket = await connect(alice.token);
  await sleep(300);

  const inserted = await query(
    `INSERT INTO messages (chat_id, sender_id, content, time_create, is_system)
     VALUES ($1, $2, 'Чат создан', $3, TRUE) RETURNING id`,
    [chatId, alice.id, Date.now()]
  );

  const edit = await emitWithAck(aliceSocket, 'edit_message', {
    message_id: inserted.rows[0].id,
    content: 'новый текст',
  });

  assert.equal(edit.status, 'error');
  assert.equal(edit.error, 'SYSTEM_MESSAGE');
});

test('системное сообщение отдаётся с флагом is_system', async () => {
  const alice = await registerUser('wc');
  const bob = await registerUser('wd');
  const chatId = await createChat(alice, bob.id);

  const inserted = await query(
    `INSERT INTO messages (chat_id, sender_id, content, time_create, is_system)
     VALUES ($1, NULL, 'Чат создан', $2, TRUE) RETURNING id`,
    [chatId, Date.now()]
  );

  const response = await api('GET', `/api/chat/${chatId}/messages`, {
    token: alice.token,
  });
  assert.equal(response.status, 200);

  const message = response.json.messages.find(
    (m) => Number(m.id) === Number(inserted.rows[0].id)
  );
  assert.ok(message, 'системное сообщение должно быть в ответе');
  assert.equal(message.is_system, true);
});
test('при регистрации создаётся сервисный чат с приветствием', async () => {
  const alice = await registerUser('sv');

  const list = await api('GET', '/api/chat/all', { token: alice.token });
  const chat = list.json.find((c) => Number(c.user_id) === -1);
  assert.ok(chat, 'должен быть сервисный чат');
  assert.equal(chat.user_name, 'Orbita');
  assert.equal(chat.avatar_url, 'uploads/orbita.png');

  const messages = await api('GET', `/api/chat/${chat.chat_id}/messages`, {
    token: alice.token,
  });
  assert.equal(messages.status, 200);

  const system = messages.json.messages.find((m) => m.is_system === true);
  assert.ok(system, 'должно быть системное приветствие');
  assert.ok(String(system.content).includes('орбите'));
});

test('сервисный аккаунт доступен по id -1', async () => {
  const alice = await registerUser('sv');

  const user = await api('GET', '/api/users/-1', { token: alice.token });
  assert.equal(user.status, 200);
  assert.equal(user.json.name, 'Orbita');

  const profile = await api('GET', '/api/profile/-1', { token: alice.token });
  assert.equal(profile.status, 200);
  assert.equal(profile.json.name, 'Orbita');
  assert.equal(profile.json.email, undefined);
});
test('в сервисный чат нельзя написать', async () => {
  const alice = await registerUser('sw');

  const list = await api('GET', '/api/chat/all', { token: alice.token });
  const chat = list.json.find((c) => Number(c.user_id) === -1);

  const socket = await connect(alice.token);
  await sleep(300);

  const ack = await emitWithAck(socket, 'send_message', {
    chat_id: chat.chat_id,
    content: 'привет',
    time_create: Date.now(),
  });

  assert.equal(ack.status, 'error');
  assert.equal(ack.error, 'SERVICE_CHAT');
});