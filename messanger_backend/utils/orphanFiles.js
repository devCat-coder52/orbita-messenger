/**
 * Помощники для уборки `uploads/`: приведение ссылок из БД к путям
 * относительно папки загрузок и выбор файлов, на которые никто не ссылается.
 *
 * Вынесено отдельно от скрипта, чтобы логику можно было покрыть тестами
 * без файловой системы и базы.
 */

/**
 * Приводит URL вложения из БД к пути относительно `uploads/`.
 *
 * Понимает `/uploads/messages/images/a.jpg`, `uploads/a.jpg` и абсолютные
 * `http(s)://host/uploads/...`. Возвращает `null`, если это не файл внутри
 * `uploads/` (например, внешняя ссылка или попытка выйти через `..`).
 */
function toUploadsRelative(url) {
  if (!url || typeof url !== 'string') return null;

  let pathname = url;
  try {
    if (/^https?:\/\//i.test(pathname)) {
      pathname = new URL(pathname).pathname;
    }
  } catch {
    return null;
  }

  pathname = pathname.split('?')[0].split('#')[0];
  try {
    pathname = decodeURIComponent(pathname);
  } catch {
    return null;
  }

  const normalized = pathname.replace(/\\/g, '/').replace(/^\/+/, '');
  if (!normalized.startsWith('uploads/')) return null;

  const relative = normalized.slice('uploads/'.length);
  if (!relative) return null;

  // Никаких пустых сегментов и `..` — только файлы внутри папки загрузок.
  if (relative.split('/').some((segment) => segment === '' || segment === '..')) {
    return null;
  }

  return relative;
}

/**
 * Файлы, на которые нет ссылок в БД и которые старше `minAgeMs`.
 *
 * Порог по возрасту не даёт удалить файл, который прямо сейчас загружается:
 * запись в БД появляется чуть позже, чем файл на диске.
 */
function selectOrphans({ referenced, files, now = Date.now(), minAgeMs = 0 }) {
  const refs = referenced instanceof Set ? referenced : new Set(referenced || []);

  return files.filter(
    (file) => !refs.has(file.relative) && now - file.mtimeMs >= minAgeMs
  );
}

module.exports = { toUploadsRelative, selectOrphans };
