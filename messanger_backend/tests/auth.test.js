const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  api,
  startServer,
  teardown,
  registerUser,
  setVerificationCode,
  CODE,
} = require('./helpers/env');

const PORT = 4101;

before(() => startServer(PORT));
after(() => teardown());

test('регистрация выдаёт токен и числовой id', async () => {
  const user = await registerUser('a');

  assert.equal(typeof user.id, 'number');
  assert.ok(user.token.length > 20);
});

test('вход с верным паролем и отказ с неверным', async () => {
  const user = await registerUser('b');

  const ok = await api('POST', '/api/auth/login', {
    body: { login: user.login, password: user.password },
  });
  assert.equal(ok.status, 200);
  assert.equal(typeof ok.json.user.id, 'number');

  const bad = await api('POST', '/api/auth/login', {
    body: { login: user.login, password: 'wrong-password' },
  });
  assert.equal(bad.status, 401);
});

test('код подтверждения одноразовый', async () => {
  const user = await registerUser('c');

  const reuse = await api('POST', '/api/auth/register', {
    body: {
      login: `${user.login}_x`,
      email: user.email,
      password: user.password,
      code: CODE,
    },
  });

  assert.equal(reuse.status, 400);
});

test('проверка кода не расходует его и падает на неверном', async () => {
  const login = `zztest_v_${Date.now()}`;
  const email = `${login}@example.com`;
  await setVerificationCode(email, CODE);

  const wrong = await api('POST', '/api/auth/verify-code', {
    body: { email, code: '000000' },
  });
  assert.equal(wrong.status, 400);

  const right = await api('POST', '/api/auth/verify-code', {
    body: { email, code: CODE },
  });
  assert.equal(right.status, 200);

  const again = await api('POST', '/api/auth/verify-code', {
    body: { email, code: CODE },
  });
  assert.equal(again.status, 200, 'код не должен расходоваться на проверке');
});

test('после пяти неверных попыток код блокируется', async () => {
  const login = `zztest_lock_${Date.now()}`;
  const email = `${login}@example.com`;
  await setVerificationCode(email, CODE);

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const response = await api('POST', '/api/auth/verify-code', {
      body: { email, code: '000000' },
    });
    assert.equal(response.status, 400);
  }

  const locked = await api('POST', '/api/auth/verify-code', {
    body: { email, code: CODE },
  });
  assert.equal(locked.status, 400);
  assert.match(locked.json.error, /Слишком много попыток/);
});

test('без токена защищённые маршруты недоступны', async () => {
  const noToken = await api('GET', '/api/chat/all');
  assert.equal(noToken.status, 401);

  const garbage = await api('GET', '/api/chat/all', { token: 'not-a-token' });
  assert.equal(garbage.status, 401);
});
