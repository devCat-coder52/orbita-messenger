const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const { api, startServer, teardown, registerUser } = require('./helpers/env');

const PORT = 4104;

before(() => startServer(PORT));
after(() => teardown());

test('профиль пользователя доступен по числовому id', async () => {
  const alice = await registerUser('ua');

  const response = await api('GET', `/api/users/${alice.id}`, {
    token: alice.token,
  });

  assert.equal(response.status, 200);
  assert.equal(response.json.login, alice.login);
});

test('нечисловой id даёт 400, а не 500', async () => {
  const alice = await registerUser('ub');

  const users = await api('GET', '/api/users/abc', { token: alice.token });
  assert.equal(users.status, 400);

  const profile = await api('GET', '/api/profile/abc', { token: alice.token });
  assert.equal(profile.status, 400);
});

test('несуществующий пользователь даёт 404', async () => {
  const alice = await registerUser('uc');

  const response = await api('GET', '/api/users/99999999', {
    token: alice.token,
  });

  assert.equal(response.status, 404);
});

test('публичный ключ принимается только строкой', async () => {
  const alice = await registerUser('ud');

  const bad = await api('POST', '/api/users/public-key', {
    token: alice.token,
    body: { public_key: 123 },
  });
  assert.equal(bad.status, 400);

  const good = await api('POST', '/api/users/public-key', {
    token: alice.token,
    body: { public_key: 'v2:' + 'A'.repeat(40) },
  });
  assert.equal(good.status, 200);
});
