const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  api,
  startServer,
  teardown,
  registerUser,
  createChat,
} = require('./helpers/env');

const PORT = 4102;

before(() => startServer(PORT));
after(() => teardown());

test('чат создаётся один раз на пару пользователей', async () => {
  const alice = await registerUser('ca');
  const bob = await registerUser('cb');

  const first = await createChat(alice, bob.id);
  const second = await createChat(alice, bob.id);

  assert.equal(first, second);
});

test('нельзя создать чат с самим собой', async () => {
  const alice = await registerUser('self');

  const response = await api('POST', '/api/chat/create', {
    token: alice.token,
    body: { user_id: alice.id },
  });

  assert.equal(response.status, 400);
});

test('сообщения чата доступны только участникам', async () => {
  const alice = await registerUser('ma');
  const bob = await registerUser('mb');
  const stranger = await registerUser('mc');

  const chatId = await createChat(alice, bob.id);

  const asMember = await api('GET', `/api/chat/${chatId}/messages`, {
    token: bob.token,
  });
  assert.equal(asMember.status, 200);
  assert.ok(Array.isArray(asMember.json.messages));
  assert.equal(typeof asMember.json.hasMore, 'boolean');

  const asStranger = await api('GET', `/api/chat/${chatId}/messages`, {
    token: stranger.token,
  });
  assert.equal(asStranger.status, 403);

  const infoAsStranger = await api('GET', `/api/chat/${chatId}/info`, {
    token: stranger.token,
  });
  assert.equal(infoAsStranger.status, 403);
});

test('закрепление чата отражается в списке', async () => {
  const alice = await registerUser('pa');
  const bob = await registerUser('pb');

  const chatId = await createChat(alice, bob.id);

  const pinned = await api('POST', '/api/chat/toggle-pin', {
    token: alice.token,
    body: { chat_id: chatId },
  });
  assert.equal(pinned.status, 200);

  const list = await api('GET', '/api/chat/all', { token: alice.token });
  assert.equal(list.status, 200);

  const chat = list.json.find((item) => Number(item.chat_id) === Number(chatId));
  assert.ok(chat, 'чат должен быть в списке');
  assert.equal(chat.is_pinned, true);
});

test('email виден только владельцу профиля', async () => {
  const alice = await registerUser('ea');
  const bob = await registerUser('eb');

  const own = await api('GET', `/api/profile/${alice.id}`, { token: alice.token });
  assert.equal(own.status, 200);
  assert.equal(own.json.email, alice.email);

  const foreign = await api('GET', `/api/profile/${alice.id}`, { token: bob.token });
  assert.equal(foreign.status, 200);
  assert.equal(foreign.json.email, undefined);
});
