const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  api,
  startServer,
  teardown,
  registerUser,
  createChat,
  setVerificationCode,
} = require('./helpers/env');

const PORT = 4108;

before(() => startServer(PORT));
after(() => teardown());

test('смена пароля отзывает старый токен и выдаёт новый', async () => {
  const alice = await registerUser('pa');
  await setVerificationCode(alice.email, '123456');

  const wrong = await api('POST', '/api/profile/change-password', {
    token: alice.token,
    body: {
      current_password: 'nope',
      new_password: 'newpass123',
      code: '123456',
    },
  });
  assert.equal(wrong.status, 400);

  const changed = await api('POST', '/api/profile/change-password', {
    token: alice.token,
    body: {
      current_password: alice.password,
      new_password: 'newpass123',
      code: '123456',
    },
  });
  assert.equal(changed.status, 200);
  assert.ok(changed.json.token, 'сервер должен вернуть новый токен');

  const oldToken = await api('GET', '/api/chat/all', { token: alice.token });
  assert.equal(oldToken.status, 401);

  const newToken = await api('GET', '/api/chat/all', {
    token: changed.json.token,
  });
  assert.equal(newToken.status, 200);

  const oldLogin = await api('POST', '/api/auth/login', {
    body: { login: alice.login, password: alice.password },
  });
  assert.equal(oldLogin.status, 401);

  const newLogin = await api('POST', '/api/auth/login', {
    body: { login: alice.login, password: 'newpass123' },
  });
  assert.equal(newLogin.status, 200);
});

test('короткий новый пароль отклоняется', async () => {
  const alice = await registerUser('pb');

  const response = await api('POST', '/api/profile/change-password', {
    token: alice.token,
    body: {
      current_password: alice.password,
      new_password: '123',
      code: '123456',
    },
  });

  assert.equal(response.status, 400);
});

test('смена пароля без кода отклоняется', async () => {
  const alice = await registerUser('pb2');

  const response = await api('POST', '/api/profile/change-password', {
    token: alice.token,
    body: { current_password: alice.password, new_password: 'newpass123' },
  });

  assert.equal(response.status, 400);
});

test('неверный код не меняет пароль', async () => {
  const alice = await registerUser('pb3');
  await setVerificationCode(alice.email, '123456');

  const response = await api('POST', '/api/profile/change-password', {
    token: alice.token,
    body: {
      current_password: alice.password,
      new_password: 'newpass123',
      code: '000000',
    },
  });

  assert.equal(response.status, 400);
});

test('приватность скрывает онлайн и «был(а) недавно» от собеседника', async () => {
  const alice = await registerUser('pc');
  const bob = await registerUser('pd');
  const chatId = await createChat(alice, bob.id);

  const updated = await api('POST', '/api/profile/privacy', {
    token: alice.token,
    body: { show_online: false, show_last_seen: false },
  });
  assert.equal(updated.status, 200);
  assert.equal(updated.json.show_online, false);
  assert.equal(updated.json.show_last_seen, false);

  const info = await api('GET', `/api/chat/${chatId}/info`, {
    token: bob.token,
  });
  assert.equal(info.status, 200);
  const partner = Array.isArray(info.json) ? info.json[0] : info.json;
  assert.equal(partner.is_online, false);
  assert.equal(partner.last_seen, null);
  assert.equal(partner.last_seen_hidden, true);
});

test('приватность не скрывает данные от самого владельца', async () => {
  const alice = await registerUser('pe');

  await api('POST', '/api/profile/privacy', {
    token: alice.token,
    body: { show_online: false, show_last_seen: false },
  });

  const profile = await api('GET', `/api/profile/${alice.id}`, {
    token: alice.token,
  });
  assert.equal(profile.status, 200);
  assert.equal(profile.json.show_online, false);
  assert.equal(profile.json.show_last_seen, false);
});

test('слишком длинное «О себе» отклоняется', async () => {
  const alice = await registerUser('pf');

  const long = await api('PUT', '/api/profile', {
    token: alice.token,
    body: { name: 'Alice', bio: 'x'.repeat(101) },
  });
  assert.equal(long.status, 400);

  const ok = await api('PUT', '/api/profile', {
    token: alice.token,
    body: { name: 'Alice', bio: 'x'.repeat(100) },
  });
  assert.equal(ok.status, 200);
});