const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const {
  api,
  startServer,
  teardown,
  registerUser,
  setVerificationCode,
} = require('./helpers/env');

const PORT = 4105;

before(() => startServer(PORT));
after(() => teardown());

test('сброс пароля меняет пароль и отзывает старые сессии', async () => {
  const user = await registerUser('ra');
  await setVerificationCode(user.email, '654321');

  const reset = await api('POST', '/api/auth/reset-password', {
    body: { email: user.email, code: '654321', password: 'new-secret-1' },
  });
  assert.equal(reset.status, 200);

  const oldToken = await api('GET', '/api/chat/all', { token: user.token });
  assert.equal(oldToken.status, 401);

  const oldLogin = await api('POST', '/api/auth/login', {
    body: { login: user.login, password: user.password },
  });
  assert.equal(oldLogin.status, 401);

  const newLogin = await api('POST', '/api/auth/login', {
    body: { login: user.login, password: 'new-secret-1' },
  });
  assert.equal(newLogin.status, 200);

  const fresh = await api('GET', '/api/chat/all', {
    token: newLogin.json.token,
  });
  assert.equal(fresh.status, 200);
});

test('неверный код не меняет пароль', async () => {
  const user = await registerUser('rb');
  await setVerificationCode(user.email, '111111');

  const bad = await api('POST', '/api/auth/reset-password', {
    body: { email: user.email, code: '222222', password: 'new-secret-2' },
  });
  assert.equal(bad.status, 400);

  const stillOld = await api('POST', '/api/auth/login', {
    body: { login: user.login, password: user.password },
  });
  assert.equal(stillOld.status, 200);
});

test('код сброса одноразовый', async () => {
  const user = await registerUser('rc');
  await setVerificationCode(user.email, '333333');

  const first = await api('POST', '/api/auth/reset-password', {
    body: { email: user.email, code: '333333', password: 'new-secret-3' },
  });
  assert.equal(first.status, 200);

  const second = await api('POST', '/api/auth/reset-password', {
    body: { email: user.email, code: '333333', password: 'new-secret-4' },
  });
  assert.equal(second.status, 400);
});

test('для неизвестного email код не отправляется', async () => {
  const response = await api('POST', '/api/auth/send-reset-code', {
    body: { email: 'no-such-user@example.com' },
  });
  assert.equal(response.status, 404);
});
