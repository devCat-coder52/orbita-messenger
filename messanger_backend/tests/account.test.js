const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  api,
  startServer,
  teardown,
  registerUser,
  createChat,
  query,
} = require('./helpers/env');

const PORT = 4103;

before(() => startServer(PORT));
after(() => teardown());

test('удаление аккаунта сохраняет историю чата', async () => {
  const alice = await registerUser('da');
  const bob = await registerUser('db');
  const chatId = await createChat(alice, bob.id);

  const inserted = await query(
    `INSERT INTO messages (chat_id, sender_id, content, time_create)
     VALUES ($1, $2, $3, $4)
     RETURNING id`,
    [chatId, alice.id, 'сообщение до удаления', Date.now()]
  );
  const messageId = inserted.rows[0].id;

  const deleted = await api('POST', '/api/profile/delete', { token: alice.token });
  assert.equal(deleted.status, 200);

  const user = await query('SELECT id FROM users WHERE id = $1', [alice.id]);
  assert.equal(user.rowCount, 0, 'пользователь должен быть удалён');

  const info = await query('SELECT user_id FROM user_info WHERE user_id = $1', [
    alice.id,
  ]);
  assert.equal(info.rowCount, 0, 'профиль должен удалиться каскадом');

  const message = await query(
    'SELECT sender_id, content FROM messages WHERE id = $1',
    [messageId]
  );
  assert.equal(message.rowCount, 1, 'история чата не должна исчезать');
  assert.equal(message.rows[0].sender_id, null, 'автор должен стать NULL');
  assert.equal(message.rows[0].content, 'сообщение до удаления');

  const history = await api('GET', `/api/chat/${chatId}/messages`, {
    token: bob.token,
  });
  assert.equal(history.status, 200);
  assert.equal(history.json.messages.length, 1);
});

test('удаление чата каскадно чистит участников и сообщения', async () => {
  const alice = await registerUser('xa');
  const bob = await registerUser('xb');
  const chatId = await createChat(alice, bob.id);

  await query(
    `INSERT INTO messages (chat_id, sender_id, content, time_create)
     VALUES ($1, $2, $3, $4)`,
    [chatId, bob.id, 'временное сообщение', Date.now()]
  );

  await query('DELETE FROM chats WHERE id = $1', [chatId]);

  const members = await query('SELECT 1 FROM user_chats WHERE chat_id = $1', [chatId]);
  const messages = await query('SELECT 1 FROM messages WHERE chat_id = $1', [chatId]);

  assert.equal(members.rowCount, 0);
  assert.equal(messages.rowCount, 0);
});

test('выход из чата не затрагивает сообщения других участников', async () => {
  const alice = await registerUser('la');
  const bob = await registerUser('lb');
  const chatId = await createChat(alice, bob.id);

  await query(
    `INSERT INTO messages (chat_id, sender_id, content, time_create, del_for_user_id)
     VALUES ($1, $2, $3, $4, $2)`,
    [chatId, bob.id, 'сообщение боба', Date.now()]
  );
  await query(
    `INSERT INTO messages (chat_id, sender_id, content, time_create)
     VALUES ($1, $2, $3, $4)`,
    [chatId, bob.id, 'обычное сообщение', Date.now() + 1]
  );

  const left = await api('POST', '/api/chat/delete', {
    token: alice.token,
    body: { chat_id: chatId },
  });
  assert.equal(left.status, 200);

  const remaining = await query('SELECT content FROM messages WHERE chat_id = $1', [
    chatId,
  ]);
  assert.equal(remaining.rowCount, 2);
});
