const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  createRateLimiter,
  selectPushRecipients,
  isAllowedAttachmentUrl,
  buildPushBody,
} = require('../socket/socketUtils');

test('push не уходит тому, у кого чат открыт на экране', () => {
  const recipients = selectPushRecipients(
    [{ user_id: 1 }, { user_id: 2 }, { user_id: 3 }],
    new Set([1])
  );

  assert.deepEqual(
    recipients.map((p) => p.user_id),
    [2, 3]
  );
});

test('push не уходит замьюченному чату', () => {
  const recipients = selectPushRecipients(
    [
      { user_id: 1, is_muted: true },
      { user_id: 2, is_muted: false },
    ],
    new Set()
  );

  assert.deepEqual(
    recipients.map((p) => p.user_id),
    [2]
  );
});

test('лимитер пропускает limit событий и блокирует следующие', () => {
  const limiter = createRateLimiter(3, 1000);
  const socket = { id: 's1' };

  assert.equal(limiter(socket), true);
  assert.equal(limiter(socket), true);
  assert.equal(limiter(socket), true);
  assert.equal(limiter(socket), false);
});

test('лимитер считает каждый сокет отдельно', () => {
  const limiter = createRateLimiter(1, 1000);
  const first = { id: 'a' };
  const second = { id: 'b' };

  assert.equal(limiter(first), true);
  assert.equal(limiter(second), true);
  assert.equal(limiter(first), false);
});

test('окно лимитера истекает', async () => {
  const limiter = createRateLimiter(1, 50);
  const socket = {};

  assert.equal(limiter(socket), true);
  assert.equal(limiter(socket), false);

  await new Promise((resolve) => setTimeout(resolve, 80));
  assert.equal(limiter(socket), true);
});

test('вложения принимаются только из наших загрузок', () => {
  assert.equal(
    isAllowedAttachmentUrl('image_url', '/uploads/messages/images/123-456.jpg'),
    true
  );
  assert.equal(
    isAllowedAttachmentUrl('file_url', '/uploads/messages/files/1-2.pdf'),
    true
  );
  assert.equal(isAllowedAttachmentUrl('image_url', null), true);
});

test('текст push для вложений без подписи', () => {
  assert.equal(buildPushBody({ text: 'привет' }), 'привет');
  assert.equal(buildPushBody({ text: '   ' }), '');
  assert.equal(buildPushBody({ voice_url: '/v.m4a' }), 'Голосовое сообщение');
  assert.equal(buildPushBody({ image_url: '/i.jpg' }), 'Фотография');
  assert.equal(buildPushBody({ file_url: '/f.pdf' }), 'Файл');
  assert.equal(buildPushBody({ file_url: '/f.pdf', file_name: 'a.pdf' }), 'Файл: a.pdf');
  assert.equal(buildPushBody({}), '');
});

test('шифротекст не попадает в push', () => {
  assert.equal(
    buildPushBody({ text: 'V2.abcdef', is_encrypted: true }),
    'Новое сообщение'
  );
  assert.equal(
    buildPushBody({ text: 'V2.abcdef', is_encrypted: true, image_url: '/i.jpg' }),
    'Фотография'
  );
  assert.equal(buildPushBody({ text: 'V2.abcdef' }), 'V2.abcdef');
});

test('внешние и подозрительные ссылки отклоняются', () => {
  assert.equal(
    isAllowedAttachmentUrl('image_url', 'http://evil.example/track.png'),
    false
  );
  assert.equal(
    isAllowedAttachmentUrl('image_url', '/uploads/avatars/a.png'),
    false
  );
  assert.equal(
    isAllowedAttachmentUrl('image_url', '/uploads/messages/images/../secret.jpg'),
    false
  );
  assert.equal(
    isAllowedAttachmentUrl('image_url', '/uploads/messages/images/sub/a.jpg'),
    false
  );
  assert.equal(
    isAllowedAttachmentUrl('image_url', '/uploads/messages/images/a.jpg?x=1'),
    false
  );
  assert.equal(
    isAllowedAttachmentUrl('file_url', '/uploads/messages/images/a.jpg'),
    false
  );
  assert.equal(isAllowedAttachmentUrl('voice_url', 42), false);
  assert.equal(isAllowedAttachmentUrl('unknown', '/uploads/messages/images/a.jpg'), false);
});
