const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const pool = require('../db');
const { api, startServer, teardown, registerUser } = require('./helpers/env');

const PORT = 4109;

before(() => startServer(PORT));
after(() => teardown());

test('в списке чатов отдаётся статус последнего сообщения', async () => {
  const alice = await registerUser('sa');
  const bob = await registerUser('sb');

  const created = await api('POST', '/api/chat/create', {
    token: alice.token,
    body: { user_id: bob.id },
  });
  assert.equal(created.status, 201);
  const chatId = created.json.chat_id;

  await pool.query(
    `INSERT INTO messages (chat_id, sender_id, content, status, time_create)
     VALUES ($1, $2, 'привет', 'sent', $3)`,
    [chatId, alice.id, Date.now()]
  );

  const beforeRead = await api('GET', '/api/chat/all', { token: alice.token });
  const chatBefore = beforeRead.json.find((c) => c.chat_id === chatId);
  assert.equal(chatBefore.message_status, 'sent');

  await pool.query("UPDATE messages SET status = 'read' WHERE chat_id = $1", [
    chatId,
  ]);

  const afterRead = await api('GET', '/api/chat/all', { token: alice.token });
  const chatAfter = afterRead.json.find((c) => c.chat_id === chatId);
  assert.equal(chatAfter.message_status, 'read');
});

test('у прочитанного сообщения счётчик непрочитанных нулевой', async () => {
  const alice = await registerUser('sc');
  const bob = await registerUser('sd');

  const created = await api('POST', '/api/chat/create', {
    token: alice.token,
    body: { user_id: bob.id },
  });
  const chatId = created.json.chat_id;

  await pool.query(
    `INSERT INTO messages (chat_id, sender_id, content, status, time_create)
     VALUES ($1, $2, 'привет', 'read', $3)`,
    [chatId, bob.id, Date.now()]
  );

  const list = await api('GET', '/api/chat/all', { token: alice.token });
  const chat = list.json.find((c) => c.chat_id === chatId);
  assert.equal(chat.unread_count, 0);
  assert.equal(chat.message_status, 'read');
});
