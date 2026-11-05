#!/usr/bin/env node
/**
 * Минимальный мигратор без внешних зависимостей.
 *
 * Применяет файлы migrations/*.sql по порядку, каждый — в своей транзакции,
 * и записывает имя файла в таблицу schema_migrations. Повторный запуск
 * безопасен: применённые файлы пропускаются.
 *
 * Использование:
 *   node scripts/migrate.js            # применить недостающие миграции
 *   node scripts/migrate.js --status   # только показать состояние
 */
const fs = require('fs');
const path = require('path');
const pool = require('../db');

const migrationsDir = path.join(__dirname, '..', 'migrations');

async function listMigrations() {
  if (!fs.existsSync(migrationsDir)) return [];
  return fs
    .readdirSync(migrationsDir)
    .filter((name) => name.endsWith('.sql'))
    .sort();
}

async function ensureMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name       TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function appliedMigrations(client) {
  const result = await client.query('SELECT name FROM schema_migrations ORDER BY name');
  return new Set(result.rows.map((row) => row.name));
}

async function main() {
  const statusOnly = process.argv.includes('--status');
  const files = await listMigrations();
  const client = await pool.connect();

  try {
    await ensureMigrationsTable(client);
    const applied = await appliedMigrations(client);
    const pending = files.filter((file) => !applied.has(file));

    if (statusOnly) {
      console.log(`Всего миграций: ${files.length}, применено: ${applied.size}`);
      for (const file of files) {
        console.log(`  [${applied.has(file) ? 'x' : ' '}] ${file}`);
      }
      return;
    }

    if (pending.length === 0) {
      console.log('Новых миграций нет.');
      return;
    }

    for (const file of pending) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      console.log(`Применяю ${file} ...`);

      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
        console.log(`  ок`);
      } catch (error) {
        await client.query('ROLLBACK');
        throw new Error(`Миграция ${file} не применилась: ${error.message}`);
      }
    }

    console.log(`Применено миграций: ${pending.length}`);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
