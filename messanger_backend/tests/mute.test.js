const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  api,
  startServer,
  teardown,
  registerUser,
  createChat,
} = require('./helpers/env');

const PORT = 4106;

before(() => startServer(PORT));
after(() => teardown());

const mute = (user, chatId) =>
  api('POST', '/api/chat/toggle-mute', {
    token: user.token,
    body: { chat_id: chatId },
  });

test('мьют чата включается, возвращается в списке и выключается', async () => {
  const alice = await registerUser('mua');
  const bob = await registerUser('mub');
  const chatId = await createChat(alice, bob.id);

  const muted = await mute(alice, chatId);
  assert.equal(muted.status, 200);
  assert.equal(muted.json.is_muted, true);

  const chats = await api('GET', '/api/chat/all', { token: alice.token });
  const chat = chats.json.find(
    (item) => Number(item.chat_id) === Number(chatId)
  );
  assert.ok(chat, 'чат должен быть в списке');
  assert.equal(chat.is_muted, true);

  const unmuted = await mute(alice, chatId);
  assert.equal(unmuted.json.is_muted, false);
});

test('мьют одного участника не влияет на другого', async () => {
  const alice = await registerUser('muc');
  const bob = await registerUser('mud');
  const chatId = await createChat(alice, bob.id);

  await mute(alice, chatId);

  const bobChats = await api('GET', '/api/chat/all', { token: bob.token });
  const chat = bobChats.json.find(
    (item) => Number(item.chat_id) === Number(chatId)
  );
  assert.equal(chat.is_muted, false);
});

test('чужой чат нельзя замьютить', async () => {
  const alice = await registerUser('mue');
  const bob = await registerUser('muf');
  const stranger = await registerUser('mug');
  const chatId = await createChat(alice, bob.id);

  const response = await mute(stranger, chatId);
  assert.equal(response.status, 403);
});
