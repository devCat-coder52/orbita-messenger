const { test } = require('node:test');
const assert = require('node:assert/strict');

const { toUploadsRelative, selectOrphans } = require('../utils/orphanFiles');

test('пути из БД приводятся к виду относительно uploads', () => {
  assert.equal(
    toUploadsRelative('/uploads/messages/images/a.jpg'),
    'messages/images/a.jpg'
  );
  assert.equal(toUploadsRelative('uploads/123.jpg'), '123.jpg');
  assert.equal(
    toUploadsRelative('http://192.168.0.7:3000/uploads/messages/files/doc.pdf'),
    'messages/files/doc.pdf'
  );
  assert.equal(
    toUploadsRelative('/uploads/messages/images/a%20b.png'),
    'messages/images/a b.png'
  );
});

test('опасные и посторонние URL отбрасываются', () => {
  assert.equal(toUploadsRelative('uploads/../etc/passwd'), null);
  assert.equal(toUploadsRelative('/other/a.jpg'), null);
  assert.equal(toUploadsRelative(''), null);
  assert.equal(toUploadsRelative(null), null);
  assert.equal(toUploadsRelative('https://example.com/uploads/../../x'), null);
});

test('удаляются только старые файлы без ссылок', () => {
  const now = 1_000_000_000;
  const files = [
    { relative: 'keep.jpg', size: 1, mtimeMs: now - 1000 },
    { relative: 'messages/images/orphan-old.jpg', size: 2, mtimeMs: now - 100000 },
    { relative: 'messages/images/orphan-fresh.jpg', size: 3, mtimeMs: now - 1000 },
  ];

  const orphans = selectOrphans({
    referenced: new Set(['keep.jpg']),
    files,
    now,
    minAgeMs: 50000,
  });

  assert.deepEqual(
    orphans.map((file) => file.relative),
    ['messages/images/orphan-old.jpg']
  );
});

test('без ссылок удаляются все достаточно старые файлы', () => {
  const now = 1_000_000_000;
  const files = [
    { relative: 'a.jpg', size: 1, mtimeMs: now - 100000 },
    { relative: 'b.jpg', size: 1, mtimeMs: now - 200000 },
  ];

  const orphans = selectOrphans({ referenced: [], files, now, minAgeMs: 50000 });

  assert.equal(orphans.length, 2);
});

test('свежие файлы остаются даже без ссылок', () => {
  const now = 1_000_000_000;
  const files = [{ relative: 'uploading.jpg', size: 1, mtimeMs: now - 1000 }];

  const orphans = selectOrphans({ referenced: [], files, now, minAgeMs: 50000 });

  assert.equal(orphans.length, 0);
});
