#!/usr/bin/env node
/**
 * Уборка `uploads/`: удаляет файлы, на которые больше не ссылается база —
 * старые аватары и вложения удалённых сообщений.
 *
 * По умолчанию это сухой прогон: печатает кандидатов и ничего не трогает.
 * Реальное удаление: node scripts/cleanup-uploads.js --delete
 *
 * Файлы моложе суток не трогаются: пока загрузка не завершилась, записи в БД
 * ещё нет, и такой файл выглядел бы осиротевшим.
 */

const fs = require('node:fs/promises');
const path = require('node:path');

const pool = require('../db');
const { UPLOADS_DIR } = require('../config/constants');
const { toUploadsRelative, selectOrphans } = require('../utils/orphanFiles');

const GRACE_MS = 24 * 60 * 60 * 1000;

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} Б`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} КБ`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} МБ`;
}

/** Все URL файлов, на которые ссылаются профили и сообщения. */
async function collectReferencedUrls() {
  const { rows } = await pool.query(`
    SELECT avatar_url AS url FROM user_info WHERE avatar_url IS NOT NULL
    UNION ALL
    SELECT image_url FROM messages WHERE image_url IS NOT NULL
    UNION ALL
    SELECT file_url FROM messages WHERE file_url IS NOT NULL
    UNION ALL
    SELECT voice_url FROM messages WHERE voice_url IS NOT NULL
  `);

  return rows.map((row) => row.url);
}

/** Рекурсивно собирает файлы загрузок вместе с размером и временем изменения. */
async function collectFiles(dir) {
  const files = [];

  let entries;
  try {
    entries = await fs.readdir(dir, { withFileTypes: true });
  } catch (error) {
    if (error.code === 'ENOENT') return files;
    throw error;
  }

  for (const entry of entries) {
    const absolute = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      files.push(...(await collectFiles(absolute)));
      continue;
    }
    if (!entry.isFile()) continue;

    const stat = await fs.stat(absolute);
    files.push({
      absolute,
      relative: path.relative(UPLOADS_DIR, absolute).split(path.sep).join('/'),
      size: stat.size,
      mtimeMs: stat.mtimeMs,
    });
  }

  return files;
}

async function main() {
  const shouldDelete = process.argv.includes('--delete');

  const referenced = new Set();
  for (const url of await collectReferencedUrls()) {
    const relative = toUploadsRelative(url);
    if (relative) referenced.add(relative);
  }

  const files = await collectFiles(UPLOADS_DIR);
  const orphans = selectOrphans({
    referenced,
    files,
    minAgeMs: GRACE_MS,
  });
  const totalBytes = orphans.reduce((sum, file) => sum + file.size, 0);

  console.log(
    `Файлов в uploads: ${files.length}, под ссылками в БД: ${referenced.size}, ` +
      `кандидатов на удаление: ${orphans.length} (${formatBytes(totalBytes)})`
  );

  for (const file of orphans) {
    console.log(`  ${shouldDelete ? 'удаляю' : 'кандидат'}: ${file.relative} (${formatBytes(file.size)})`);
  }

  if (!shouldDelete) {
    console.log('Сухой прогон: ничего не удалено. Для удаления запустите с --delete.');
    return;
  }

  let removed = 0;
  let removedBytes = 0;
  for (const file of orphans) {
    try {
      await fs.unlink(file.absolute);
      removed += 1;
      removedBytes += file.size;
    } catch (error) {
      console.error(`Не удалось удалить ${file.relative}: ${error.message}`);
    }
  }

  console.log(`Удалено файлов: ${removed} (${formatBytes(removedBytes)})`);
}

main()
  .catch((error) => {
    console.error('Уборка uploads завершилась ошибкой:', error.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
