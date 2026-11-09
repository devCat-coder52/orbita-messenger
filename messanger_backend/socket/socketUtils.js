/**
 * Чистые помощники сокетного слоя: без базы, firebase и socket.io.
 *
 * Вынесены отдельно, чтобы их поведение покрывалось тестами без поднятия
 * сервера и без сети.
 */

/**
 * Лимитер по сокету: не больше [limit] событий за [windowMs].
 *
 * Счётчик привязан к объекту сокета через WeakMap и умирает вместе с ним.
 */
function createRateLimiter(limit, windowMs) {
  const buckets = new WeakMap();

  return function allow(socket) {
    const now = Date.now();
    let hits = buckets.get(socket);
    if (!hits) {
      hits = [];
      buckets.set(socket, hits);
    }
    while (hits.length && now - hits[0] > windowMs) hits.shift();
    if (hits.length >= limit) return false;
    hits.push(now);
    return true;
  };
}

/**
 * Кому отправлять push: не тем, кто читает чат, и не тем, у кого он на мьюте.
 *
 * [participants] — строки из user_chats (user_id, is_muted);
 * [viewers] — Set пользователей, у которых чат открыт на экране.
 */
function selectPushRecipients(participants, viewers) {
  return (participants || []).filter(
    (p) => !viewers.has(p.user_id) && p.is_muted !== true
  );
}

const ATTACHMENT_PREFIXES = {
  image_url: '/uploads/messages/images/',
  file_url: '/uploads/messages/files/',
  voice_url: '/uploads/messages/voices/',
};

/**
 * Вложение должно быть файлом из наших загрузок нужного типа.
 *
 * Иначе клиент может подсунуть внешнюю ссылку (трекинг получателя) или
 * сослаться на чужой файл. `null` — вложения нет, это нормально.
 */
function isAllowedAttachmentUrl(field, url) {
  if (url == null) return true;
  if (typeof url !== 'string') return false;

  const prefix = ATTACHMENT_PREFIXES[field];
  if (!prefix || !url.startsWith(prefix)) return false;

  const fileName = url.slice(prefix.length);
  if (!fileName || fileName.length > 200) return false;
  // Только имя файла: без вложенных путей, query и перехода вверх.
  if (fileName.includes('/') || fileName.includes('\\')) return false;
  if (fileName.includes('..') || fileName.includes('?') || fileName.includes('#')) return false;

  return /^[A-Za-z0-9._-]+$/.test(fileName);
}

/**
 * Текст push, если у сообщения нет подписи: «Голосовое сообщение»,
 * «Фотография», «Файл: имя». Иначе push для вложения приходил без текста.
 */
function buildPushBody({
  text,
  is_encrypted,
  voice_url,
  image_url,
  file_url,
  file_name,
} = {}) {
  const trimmed = typeof text === 'string' ? text.trim() : '';
  // Шифротекст в уведомление не попадает: сервер не может его прочитать.
  if (trimmed && !is_encrypted) return trimmed;
  if (voice_url) return 'Голосовое сообщение';
  if (image_url) return 'Фотография';
  if (file_url) return file_name ? `Файл: ${file_name}` : 'Файл';
  return is_encrypted ? 'Новое сообщение' : '';
}

module.exports = {
  createRateLimiter,
  selectPushRecipients,
  isAllowedAttachmentUrl,
  buildPushBody,
};
